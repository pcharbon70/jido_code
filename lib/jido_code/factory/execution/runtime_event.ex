defmodule JidoCode.Factory.Execution.RuntimeEvent do
  @moduledoc "Bounded, provider-neutral event emitted by an execution runtime."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @types ~w[prepared started heartbeat progress waiting_tool tool_result cancelling cancelled completed failed timed_out crashed stale_lease]a
  @outcomes ~w[pending success failure timeout cancelled rejected unknown]a
  @enforce_keys [:attempt_iri, :sequence, :type, :occurred_at, :outcome_class, :usage]
  defstruct @enforce_keys ++ [:tool_ref, :payload_digest, :diagnostic]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Knowledge.validate_resource_identity(attributes[:attempt_iri]),
         sequence when is_integer(sequence) and sequence >= 0 <- attributes[:sequence],
         type when type in @types <- attributes[:type],
         %DateTime{} = occurred_at <- attributes[:occurred_at],
         outcome when outcome in @outcomes <- attributes[:outcome_class],
         usage when is_map(usage) <- attributes[:usage],
         true <- bounded?(usage, 4_096),
         :ok <- optional_text(attributes[:tool_ref], 256),
         :ok <- optional_digest(attributes[:payload_digest]),
         :ok <- optional_text(attributes[:diagnostic], 1_024) do
      {:ok,
       %__MODULE__{
         attempt_iri: attributes.attempt_iri,
         sequence: sequence,
         type: type,
         occurred_at: DateTime.truncate(occurred_at, :microsecond),
         outcome_class: outcome,
         usage: usage,
         tool_ref: attributes[:tool_ref],
         payload_digest: attributes[:payload_digest],
         diagnostic: attributes[:diagnostic]
       }}
    else
      _invalid -> invalid(:runtime_event)
    end
  rescue
    _error -> invalid(:runtime_event)
  end

  def new(_attributes), do: invalid(:runtime_event)

  defp optional_text(nil, _limit), do: :ok

  defp optional_text(value, limit) when is_binary(value) and byte_size(value) <= limit,
    do: :ok

  defp optional_text(_value, _limit), do: :error

  defp optional_digest(nil), do: :ok

  defp optional_digest(value) when is_binary(value) do
    if Regex.match?(~r/^[a-f0-9]{64}$/, value), do: :ok, else: :error
  end

  defp optional_digest(_value), do: :error

  defp bounded?(value, limit) do
    byte_size(:erlang.term_to_binary(value, [:deterministic])) <= limit
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
