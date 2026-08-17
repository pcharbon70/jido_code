defmodule JidoCode.Runtime.JidoHarness.RunRecord do
  @moduledoc "Bounded, disposable metadata for one delegated execution activity."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request

  @observation_types ~w[started progress provider_event tool_call tool_result completed failed cancelled timed_out]a
  @terminal_states ~w[completed failed cancelled timed_out terminated]a

  @derive {Inspect,
           only: [
             :runtime_key,
             :run_id,
             :attempt_iri,
             :profile_name,
             :state,
             :sequence,
             :runtime_ref,
             :session_ref,
             :provider_session_ref,
             :event_cursor,
             :versions,
             :observations,
             :observation_bytes,
             :final
           ]}
  @enforce_keys [
    :runtime_key,
    :run_id,
    :attempt_iri,
    :fencing_token,
    :profile_name,
    :state,
    :sequence,
    :event_cursor,
    :versions,
    :observations,
    :observation_bytes,
    :journal_bounds
  ]
  defstruct @enforce_keys ++
              [:runtime_ref, :session_ref, :provider_session_ref, :final]

  @type t :: %__MODULE__{}

  @spec new(Request.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%Request{} = request, profile) when is_map(profile) do
    journal = profile[:journal]

    with name when is_atom(name) <- profile[:name],
         %{record_bytes: record_bytes, total_bytes: total_bytes} <- journal,
         true <- record_bytes in 1..65_536,
         true <- total_bytes >= record_bytes and total_bytes <= 1_048_576 do
      {:ok,
       %__MODULE__{
         runtime_key: Request.runtime_key(request),
         run_id: opaque_id("run"),
         attempt_iri: request.attempt_iri,
         fencing_token: request.fencing_token,
         profile_name: name,
         state: :prepared,
         sequence: 0,
         event_cursor: 0,
         versions: %{},
         observations: [],
         observation_bytes: 0,
         journal_bounds: %{record_bytes: record_bytes, total_bytes: total_bytes}
       }}
    else
      _invalid -> invalid(:jido_harness_run_record)
    end
  end

  def new(_request, _profile), do: invalid(:jido_harness_run_record)

  @spec start(t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def start(%__MODULE__{state: :prepared} = record, receipt) when is_map(receipt) do
    with :ok <- required_ref(receipt[:runtime_ref]),
         :ok <- optional_ref(receipt[:session_ref]),
         :ok <- optional_ref(receipt[:provider_session_ref]),
         versions when is_map(versions) <- Map.get(receipt, :versions, %{}),
         true <- bounded?(versions, 4_096),
         false <- secret?(versions) do
      {:ok,
       %{
         record
         | state: :running,
           sequence: 1,
           runtime_ref: receipt[:runtime_ref],
           session_ref: receipt[:session_ref],
           provider_session_ref: receipt[:provider_session_ref],
           versions: versions
       }}
    else
      _invalid -> invalid(:jido_harness_start_receipt)
    end
  end

  def start(%__MODULE__{}, _receipt), do: invalid(:jido_harness_start_receipt)

  @spec observe(t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def observe(%__MODULE__{} = record, observation) when is_map(observation) do
    with sequence when is_integer(sequence) and sequence > record.event_cursor <-
           observation[:sequence],
         type when type in @observation_types <- observation[:type],
         %DateTime{} = occurred_at <- observation[:occurred_at],
         :ok <- optional_digest(observation[:payload_digest]),
         :ok <- optional_ref(observation[:tool_ref]),
         normalized = %{
           sequence: sequence,
           type: type,
           occurred_at: DateTime.truncate(occurred_at, :microsecond),
           payload_digest: observation[:payload_digest],
           tool_ref: observation[:tool_ref]
         },
         false <- secret?(normalized),
         size <- byte_size(:erlang.term_to_binary(normalized, [:deterministic])),
         true <- size <= record.journal_bounds.record_bytes do
      {observations, bytes} =
        retain(
          record.observations ++ [{normalized, size}],
          record.observation_bytes + size,
          record.journal_bounds.total_bytes
        )

      {:ok,
       %{
         record
         | observations: Enum.map(observations, &elem(&1, 0)),
           observation_bytes: bytes,
           event_cursor: sequence,
           sequence: max(record.sequence, sequence)
       }}
    else
      _invalid -> invalid(:jido_harness_observation)
    end
  rescue
    _error -> invalid(:jido_harness_observation)
  end

  def observe(%__MODULE__{}, _observation), do: invalid(:jido_harness_observation)

  @spec finish(t(), atom(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def finish(%__MODULE__{} = record, state, final)
      when state in @terminal_states and is_map(final) do
    with :ok <- optional_digest(final[:workspace_digest]),
         :ok <- optional_digest(final[:candidate_diff_digest]),
         artifacts when is_list(artifacts) and length(artifacts) <= 100 <-
           Map.get(final, :artifact_iris, []),
         true <- Enum.all?(artifacts, &safe_reference?/1),
         usage when is_map(usage) <- Map.get(final, :usage, %{}),
         true <- bounded?(usage, 4_096),
         false <- secret?(usage),
         bounded = %{
           workspace_digest: final[:workspace_digest],
           candidate_diff_digest: final[:candidate_diff_digest],
           artifact_iris: Enum.sort(artifacts),
           usage: usage
         } do
      {:ok, %{record | state: state, sequence: record.sequence + 1, final: bounded}}
    else
      _invalid -> invalid(:jido_harness_terminal_result)
    end
  rescue
    _error -> invalid(:jido_harness_terminal_result)
  end

  def finish(%__MODULE__{}, _state, _final), do: invalid(:jido_harness_terminal_result)

  @spec terminal?(t()) :: boolean()
  def terminal?(%__MODULE__{state: state}), do: state in @terminal_states

  defp retain(observations, _bytes, limit) do
    tagged =
      Enum.map(observations, fn
        {%{} = observation, size} ->
          {observation, size}

        %{} = observation ->
          {observation, byte_size(:erlang.term_to_binary(observation, [:deterministic]))}
      end)

    do_retain(tagged, Enum.sum(Enum.map(tagged, &elem(&1, 1))), limit)
  end

  defp do_retain(observations, bytes, limit) when bytes <= limit,
    do: {observations, bytes}

  defp do_retain([{_observation, size} | rest], bytes, limit),
    do: do_retain(rest, max(0, bytes - size), limit)

  defp do_retain([], _bytes, _limit), do: {[], 0}

  defp optional_ref(nil), do: :ok
  defp optional_ref(value) when is_binary(value) and byte_size(value) in 1..256, do: :ok
  defp optional_ref(_value), do: :error

  defp required_ref(value) when is_binary(value) and byte_size(value) in 1..256, do: :ok
  defp required_ref(_value), do: :error

  defp optional_digest(nil), do: :ok

  defp optional_digest(value) when is_binary(value) do
    if Regex.match?(~r/^[a-f0-9]{64}$/, value), do: :ok, else: :error
  end

  defp optional_digest(_value), do: :error

  defp safe_reference?(value) when is_binary(value) and byte_size(value) <= 512,
    do: String.starts_with?(value, "https://jido.run/id/")

  defp safe_reference?(_value), do: false

  defp bounded?(value, limit),
    do: byte_size(:erlang.term_to_binary(value, [:deterministic])) <= limit

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

  defp opaque_id(prefix) do
    prefix <> "_" <> (:crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false))
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
