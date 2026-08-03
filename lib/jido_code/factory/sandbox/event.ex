defmodule JidoCode.Factory.Sandbox.Event do
  @moduledoc "Bounded sandbox lifecycle event without local paths or handles."

  alias JidoCode.Factory.AdapterError

  @operations ~w[provision materialize execute inspect cancel collect destroy quarantine orphan_cleanup]a
  @outcomes ~w[success failure timeout cancelled denied exhausted partial quarantined]a
  @enforce_keys [:attempt_iri, :operation, :outcome, :occurred_at, :provider_ref, :details]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with attempt when is_binary(attempt) <- attributes[:attempt_iri],
         true <- String.starts_with?(attempt, "https://jido.run/id/"),
         operation when operation in @operations <- attributes[:operation],
         outcome when outcome in @outcomes <- attributes[:outcome],
         %DateTime{} = occurred <- attributes[:occurred_at],
         provider_ref when is_binary(provider_ref) and byte_size(provider_ref) == 64 <-
           attributes[:provider_ref],
         details when is_map(details) <- attributes[:details],
         true <- byte_size(:erlang.term_to_binary(details, [:deterministic])) <= 16_384,
         false <- private_detail?(details),
         false <- secret_detail?(details) do
      {:ok,
       %__MODULE__{
         attempt_iri: attempt,
         operation: operation,
         outcome: outcome,
         occurred_at: DateTime.truncate(occurred, :microsecond),
         provider_ref: provider_ref,
         details: details
       }}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :sandbox_event)}
    end
  rescue
    _error -> {:error, AdapterError.new(:invalid_input, :sandbox_event)}
  end

  def new(_attributes), do: {:error, AdapterError.new(:invalid_input, :sandbox_event)}

  defp private_detail?(details) do
    Enum.any?(details, fn {key, value} -> private_key?(key) or private_value?(value) end)
  end

  defp private_value?(value) when is_map(value), do: private_detail?(value)
  defp private_value?(value) when is_list(value), do: Enum.any?(value, &private_value?/1)
  defp private_value?(_value), do: false

  defp private_key?(key) when is_atom(key), do: key in [:path, :handle, :pid, :port, :session]

  defp private_key?(key) when is_binary(key),
    do: key in ["path", "handle", "pid", "port", "session"]

  defp private_key?(_key), do: false

  defp secret_detail?(value) when is_map(value) do
    Enum.any?(value, fn {key, item} -> secret_detail?(key) or secret_detail?(item) end)
  end

  defp secret_detail?(value) when is_list(value), do: Enum.any?(value, &secret_detail?/1)

  defp secret_detail?(value) when is_binary(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp secret_detail?(_value), do: false
end
