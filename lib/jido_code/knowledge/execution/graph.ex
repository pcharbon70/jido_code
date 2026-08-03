defmodule JidoCode.Knowledge.Execution.Graph do
  @moduledoc false

  alias JidoCode.Knowledge.Control.Graph, as: ControlGraph
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @spec append_target(String.t(), non_neg_integer(), String.t(), String.t(), DateTime.t(), list()) ::
          {:ok, map()} | {:error, Error.t()}
  def append_target(graph_iri, revision, owner_scope, activity, recorded_at, additions)
      when is_integer(revision) and revision >= 0 and is_list(additions) do
    with {:ok, family} <- GraphRegistry.identify(graph_iri),
         :ok <- ResourceIdentity.validate(owner_scope),
         :ok <- ResourceIdentity.validate(activity),
         true <- match?(%DateTime{}, recorded_at) do
      case family do
        :repository_control ->
          ControlGraph.target(graph_iri, revision, owner_scope, activity, recorded_at, additions)

        :run_attempt when revision > 0 ->
          {:ok,
           %{
             family: :run_attempt,
             graph_iri: graph_iri,
             operation: :append,
             metadata: %{lifecycle_state: :open},
             additions: additions,
             supersessions: [],
             invalidations: [],
             removals: []
           }}

        _unsupported ->
          invalid(:execution_graph_target)
      end
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_graph_target)
    end
  end

  def append_target(_graph, _revision, _scope, _activity, _recorded_at, _additions),
    do: invalid(:execution_graph_target)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
