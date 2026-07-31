defmodule JidoCode.Knowledge.Revision do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Metadata
  alias JidoCode.Knowledge.RevisionReceipt
  alias TripleStore.QuadOperations

  @max_revision 9_223_372_036_854_775_807

  @type current :: %{
          dataset_revision: non_neg_integer(),
          system_graph_revision: non_neg_integer(),
          graph_revisions: %{String.t() => non_neg_integer()}
        }

  @type next :: current()

  @spec current(TripleStore.store(), Metadata.t(), [String.t()]) ::
          {:ok, current()} | {:error, Error.t()}
  def current(store, metadata, target_graphs) do
    with {:ok, graph_revisions} <- graph_revisions(store, target_graphs) do
      {:ok,
       %{
         dataset_revision: metadata.dataset_revision,
         system_graph_revision: metadata.system_graph_revision,
         graph_revisions: graph_revisions
       }}
    end
  end

  @spec verify_preconditions(current(), non_neg_integer(), map()) ::
          :ok | {:error, Error.t(), RevisionReceipt.t()}
  def verify_preconditions(current, expected_dataset_revision, expected_graph_revisions) do
    if current.dataset_revision == expected_dataset_revision and
         current.graph_revisions == expected_graph_revisions do
      :ok
    else
      receipt = %RevisionReceipt{
        dataset_revision: current.dataset_revision,
        graph_revisions: current.graph_revisions
      }

      {:error, Error.new(:stale_precondition, :atomic_commit), receipt}
    end
  end

  @spec next(current()) :: {:ok, next()} | {:error, Error.t()}
  def next(current) do
    revisions =
      [current.dataset_revision, current.system_graph_revision] ++
        Map.values(current.graph_revisions)

    if Enum.any?(revisions, &(&1 >= @max_revision)) do
      {:error, Error.new(:conflict, :revision_overflow)}
    else
      {:ok,
       %{
         dataset_revision: current.dataset_revision + 1,
         system_graph_revision: current.system_graph_revision + 1,
         graph_revisions:
           Map.new(current.graph_revisions, fn {graph, value} -> {graph, value + 1} end)
       }}
    end
  end

  def max_revision, do: @max_revision

  defp graph_revisions(store, target_graphs) do
    Enum.reduce_while(target_graphs, {:ok, %{}}, fn graph, {:ok, revisions} ->
      case current_graph_revision(store, graph) do
        {:ok, revision} -> {:cont, {:ok, Map.put(revisions, graph, revision)}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp current_graph_revision(store, graph) do
    case Metadata.graph_revision(store, graph) do
      {:ok, nil} -> ensure_unmanaged_graph_empty(store, graph)
      {:ok, revision} -> {:ok, revision}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp ensure_unmanaged_graph_empty(store, graph) do
    case QuadOperations.graph_quad_count(store.db, store.dict_manager, RDF.iri(graph)) do
      {:ok, 0} -> {:ok, 0}
      {:ok, _count} -> {:error, Error.new(:corrupt, :verify_graph_revision)}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :read_graph_revision)}
    end
  end
end
