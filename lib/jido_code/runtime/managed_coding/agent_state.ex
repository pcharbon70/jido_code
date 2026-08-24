defmodule JidoCode.Runtime.ManagedCoding.AgentState do
  @moduledoc "Validated disposable state for one fenced managed coding agent."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.Vocabulary

  @enforce_keys [
    :attempt_iri,
    :fencing_token,
    :phase,
    :sequence,
    :profile_digest,
    :context_digest,
    :tool_digest,
    :model_digest,
    :current_invocation_iri,
    :budgets,
    :pending_decision,
    :candidate_digests,
    :cancellation,
    :terminal_classification,
    :reconstruction_watermark
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @digest ~r/^[a-f0-9]{64}$/

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Identity.validate_resource(attributes[:attempt_iri]),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         phase when is_atom(phase) <- attributes[:phase],
         true <- Vocabulary.valid?(:runtime_phase, phase),
         sequence when is_integer(sequence) and sequence >= 0 <- attributes[:sequence],
         true <-
           Enum.all?(
             ~w[profile_digest context_digest tool_digest model_digest]a,
             &digest?(attributes[&1])
           ),
         :ok <- optional_resource(attributes[:current_invocation_iri]),
         budgets when is_map(budgets) and map_size(budgets) <= 32 <- attributes[:budgets],
         true <- Enum.all?(budgets, &budget_entry?/1),
         pending when is_map(pending) and map_size(pending) <= 32 <- attributes[:pending_decision],
         candidates when is_list(candidates) and length(candidates) <= 64 <-
           attributes[:candidate_digests],
         true <- Enum.all?(candidates, &digest?/1),
         cancellation when is_atom(cancellation) <- attributes[:cancellation],
         true <- Vocabulary.valid?(:cancellation_state, cancellation),
         :ok <- terminal(attributes[:terminal_classification]),
         watermark when is_integer(watermark) and watermark >= 0 <-
           attributes[:reconstruction_watermark] do
      {:ok, struct!(__MODULE__, Map.take(attributes, @enforce_keys))}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec initial(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def initial(attributes) when is_map(attributes) do
    new(
      Map.merge(
        %{
          phase: :admitted,
          sequence: 0,
          current_invocation_iri: nil,
          budgets: %{},
          pending_decision: %{},
          candidate_digests: [],
          cancellation: :not_requested,
          terminal_classification: nil,
          reconstruction_watermark: 0
        },
        attributes
      )
    )
  end

  @spec from_agent(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def from_agent(state) when is_map(state), do: new(Map.take(state, @enforce_keys))
  def from_agent(_state), do: invalid()

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = state), do: Map.from_struct(state)

  @spec terminal?(t()) :: boolean()
  def terminal?(%__MODULE__{phase: phase}),
    do: phase in [:candidate_ready, :completed, :cancelled, :failed]

  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: Identity.validate_resource(value)

  defp budget_entry?({key, %{used: used, limit: limit, enforcement: enforcement}}) do
    is_atom(key) and is_integer(used) and used >= 0 and is_integer(limit) and limit > 0 and
      Vocabulary.valid?(:enforcement_class, enforcement)
  end

  defp budget_entry?(_entry), do: false

  defp terminal(nil), do: :ok

  defp terminal(value) when is_atom(value) do
    if Vocabulary.valid?(:terminal_classification, value), do: :ok, else: :error
  end

  defp terminal(_value), do: :error
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_agent_state)}
end
