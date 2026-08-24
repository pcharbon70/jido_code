defmodule JidoCode.Runtime.ManagedCoding.Agent do
  @moduledoc "One disposable Jido agent for a graph-authorized managed coding attempt."

  alias JidoCode.Runtime.ManagedCoding.Strategy

  use Jido.Agent,
    name: "managed_coding_agent",
    description: "Bounded single-agent coding runtime with host-owned effects",
    strategy: Strategy,
    schema: [
      attempt_iri: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      phase: [type: :atom, required: true],
      sequence: [type: :non_neg_integer, required: true],
      profile_digest: [type: :string, required: true],
      context_digest: [type: :string, required: true],
      tool_digest: [type: :string, required: true],
      model_digest: [type: :string, required: true],
      current_invocation_iri: [type: :string, required: false],
      budgets: [type: :map, required: true],
      candidate_digests: [type: {:list, :string}, required: true],
      cancellation: [type: :atom, required: true],
      terminal_classification: [type: :atom, required: false],
      reconstruction_watermark: [type: :non_neg_integer, required: true]
    ]

  @spec new_managed(map(), keyword()) :: {:ok, Jido.Agent.t()} | {:error, term()}
  def new_managed(attributes, options \\ [])

  def new_managed(attributes, options) when is_map(attributes) and is_list(options) do
    with {:ok, state} <- JidoCode.Runtime.ManagedCoding.AgentState.initial(attributes) do
      id = Keyword.get(options, :id)
      agent_options = [state: JidoCode.Runtime.ManagedCoding.AgentState.to_map(state)]

      agent_options =
        if is_binary(id), do: Keyword.put(agent_options, :id, id), else: agent_options

      {:ok, new(agent_options)}
    end
  rescue
    _error -> {:error, :invalid_managed_coding_agent}
  end

  def new_managed(_attributes, _options), do: {:error, :invalid_managed_coding_agent}
end
