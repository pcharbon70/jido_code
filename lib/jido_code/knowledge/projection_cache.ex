defmodule JidoCode.Knowledge.ProjectionCache do
  @moduledoc """
  Optional in-memory cache for exact-context projection envelopes.

  Entries are usable only when the caller supplies the same current dataset,
  graph, ontology, authority, and consistency context. Any uncertainty is a
  miss and the canonical query must run again.
  """

  use GenServer

  alias JidoCode.Knowledge.ChangeEvent
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ProjectionEnvelope

  @max_entries 1_000

  def start_link(options \\ []) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, %{entries: %{}, order: []})
      name -> GenServer.start_link(__MODULE__, %{entries: %{}, order: []}, name: name)
    end
  end

  @spec key(ProjectionEnvelope.t()) :: String.t()
  def key(%ProjectionEnvelope{} = projection) do
    {
      projection.projection_name,
      projection.projection_version,
      projection.query_name,
      projection.query_version,
      projection.parameters_digest,
      projection.authorization_scope_digest,
      projection.source_graph_revisions,
      projection.ontology_version,
      projection.consistency.constraint_digest
    }
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec context(ProjectionEnvelope.t()) :: map()
  def context(%ProjectionEnvelope{} = projection) do
    %{
      dataset_revision: projection.dataset_revision,
      graph_revisions: projection.source_graph_revisions,
      ontology_version: projection.ontology_version,
      authorization_scope_digest: projection.authorization_scope_digest,
      consistency_digest: projection.consistency.constraint_digest
    }
  end

  @spec fetch(GenServer.server(), String.t(), map()) ::
          {:ok, ProjectionEnvelope.t(), :hit} | :miss
  def fetch(server \\ __MODULE__, key, current_context) do
    GenServer.call(server, {:fetch, key, current_context})
  catch
    :exit, _reason -> :miss
  end

  @spec put(GenServer.server(), ProjectionEnvelope.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def put(server \\ __MODULE__, %ProjectionEnvelope{} = projection) do
    GenServer.call(server, {:put, projection})
  catch
    :exit, _reason -> {:error, Error.new(:unavailable, :projection_cache)}
  end

  @spec invalidate_change(GenServer.server(), ChangeEvent.t()) :: :ok
  def invalidate_change(server \\ __MODULE__, %ChangeEvent{} = event) do
    GenServer.call(server, {:invalidate_change, event.dataset_revision})
  catch
    :exit, _reason -> :ok
  end

  @spec reset(GenServer.server()) :: :ok
  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  catch
    :exit, _reason -> :ok
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:fetch, key, current_context}, _from, state) do
    reply =
      case Map.get(state.entries, key) do
        %{projection: projection, context: ^current_context} -> {:ok, projection, :hit}
        _missing_or_stale -> :miss
      end

    {:reply, reply, state}
  end

  def handle_call({:put, projection}, _from, state) do
    key = key(projection)
    entry = %{projection: projection, context: context(projection)}
    entries = Map.put(state.entries, key, entry)
    order = [key | Enum.reject(state.order, &(&1 == key))]
    {entries, order} = evict(entries, order)
    {:reply, {:ok, key}, %{state | entries: entries, order: order}}
  end

  def handle_call({:invalidate_change, revision}, _from, state) do
    entries =
      Map.reject(state.entries, fn {_key, entry} ->
        entry.context.dataset_revision < revision
      end)

    order = Enum.filter(state.order, &Map.has_key?(entries, &1))
    {:reply, :ok, %{state | entries: entries, order: order}}
  end

  def handle_call(:reset, _from, _state),
    do: {:reply, :ok, %{entries: %{}, order: []}}

  defp evict(entries, order) when length(order) <= @max_entries, do: {entries, order}

  defp evict(entries, order) do
    {retained, evicted} = Enum.split(order, @max_entries)
    {Map.drop(entries, evicted), retained}
  end
end
