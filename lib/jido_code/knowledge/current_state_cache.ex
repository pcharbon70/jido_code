defmodule JidoCode.Knowledge.CurrentStateCache do
  @moduledoc """
  Disposable exact-revision materialization for current-state projections.

  Cache loss is a miss. Callers must recompute from transition graphs and may
  never use an entry for a different source revision.
  """

  use GenServer

  def start_link(options \\ []) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, %{})
      name -> GenServer.start_link(__MODULE__, %{}, name: name)
    end
  end

  @spec fetch(GenServer.server(), String.t(), String.t(), non_neg_integer()) ::
          {:ok, map()} | :miss
  def fetch(server \\ __MODULE__, graph_iri, subject_iri, revision) do
    GenServer.call(server, {:fetch, {graph_iri, subject_iri, revision}})
  end

  @spec put(GenServer.server(), String.t(), String.t(), non_neg_integer(), map()) :: :ok
  def put(server \\ __MODULE__, graph_iri, subject_iri, revision, projection) do
    GenServer.call(server, {:put, {graph_iri, subject_iri, revision}, projection})
  end

  @spec reset(GenServer.server()) :: :ok
  def reset(server \\ __MODULE__), do: GenServer.call(server, :reset)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:fetch, key}, _from, state) do
    reply =
      case Map.fetch(state, key) do
        {:ok, value} -> {:ok, value}
        :error -> :miss
      end

    {:reply, reply, state}
  end

  def handle_call({:put, {graph, subject, revision} = key, projection}, _from, state)
      when is_binary(graph) and is_binary(subject) and is_integer(revision) and revision >= 0 and
             is_map(projection) do
    {:reply, :ok, Map.put(state, key, projection)}
  end

  def handle_call(:reset, _from, _state), do: {:reply, :ok, %{}}
end
