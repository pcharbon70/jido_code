defmodule JidoCode.Factory.DelegatedResultGate do
  @moduledoc "Current-fence gate for every delegated event, candidate, callback, or result sink."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request

  @kinds ~w[event stream file diff artifact candidate callback verification result terminal]a

  @spec dispatch(Request.t(), map(), atom(), term(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def dispatch(%Request{} = request, current, kind, payload, options)
      when is_map(current) and kind in @kinds and is_list(options) do
    at = Keyword.get(options, :at, DateTime.utc_now())
    sink = Keyword.get(options, :sink)

    with :ok <- current_fence?(request, current, at),
         {:ok, bytes, digest} <- bounded_payload(payload),
         receipt = %{
           attempt_iri: request.attempt_iri,
           lease_iri: request.lease_iri,
           fencing_token: request.fencing_token,
           kind: kind,
           payload_bytes: bytes,
           payload_digest: digest,
           observed_at: DateTime.truncate(at, :microsecond)
         },
         :ok <- dispatch_sink(sink, receipt) do
      {:ok, receipt}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:unauthorized, :delegated_result_fence)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :delegated_result_fence)}
  end

  def dispatch(_request, _current, _kind, _payload, _options),
    do: {:error, AdapterError.new(:invalid_input, :delegated_result_fence)}

  defp current_fence?(request, current, %DateTime{} = at) do
    if current[:attempt_iri] == request.attempt_iri and
         current[:lease_iri] == request.lease_iri and
         current[:fencing_token] == request.fencing_token and
         current[:lease_state] == :active and
         match?(%DateTime{}, current[:lease_expires_at]) and
         DateTime.compare(current.lease_expires_at, at) == :gt do
      :ok
    else
      {:error, AdapterError.new(:unauthorized, :delegated_result_fence)}
    end
  end

  defp current_fence?(_request, _current, _at),
    do: {:error, AdapterError.new(:invalid_input, :delegated_result_fence)}

  defp bounded_payload(payload) do
    encoded = :erlang.term_to_binary(payload, [:deterministic])

    if byte_size(encoded) <= 1_048_576 and not secret?(payload) do
      digest = :crypto.hash(:sha256, encoded) |> Base.encode16(case: :lower)
      {:ok, byte_size(encoded), digest}
    else
      {:error, AdapterError.new(:invalid_input, :delegated_result_payload)}
    end
  end

  defp dispatch_sink(nil, _receipt), do: :ok

  defp dispatch_sink(sink, receipt) when is_function(sink, 1) do
    case sink.(receipt) do
      :ok -> :ok
      _invalid -> {:error, AdapterError.new(:unavailable, :delegated_result_sink)}
    end
  end

  defp dispatch_sink(_sink, _receipt),
    do: {:error, AdapterError.new(:invalid_input, :delegated_result_sink)}

  defp secret?(%_{} = value), do: value |> Map.from_struct() |> secret?()

  defp secret?(value) when is_map(value),
    do: Enum.any?(value, fn {key, item} -> secret?(key) or secret?(item) end)

  defp secret?(value) when is_list(value), do: Enum.any?(value, &secret?/1)

  defp secret?(value) when is_binary(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp secret?(_value), do: false
end
