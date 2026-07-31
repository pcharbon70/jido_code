defmodule JidoCode.Knowledge.QueryRunner do
  @moduledoc false

  use GenServer

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.StoreServer

  def start_link(options \\ []) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec graph_metadata(String.t(), keyword()) :: {:ok, map() | nil} | {:error, Error.t()}
  def graph_metadata(graph_iri, options \\ []) do
    server = Keyword.get(options, :server, __MODULE__)
    timeout = Keyword.get(options, :timeout, 5_000)
    GenServer.call(server, {:graph_metadata, graph_iri, timeout}, timeout + 1_000)
  catch
    :exit, {:timeout, _details} -> {:error, Error.new(:timeout, :read_graph_metadata)}
    :exit, _reason -> {:error, Error.new(:unavailable, :read_graph_metadata)}
  end

  @impl true
  def init(options) do
    {:ok, %{store_server: Keyword.get(options, :store_server, StoreServer)}}
  end

  @impl true
  def handle_call({:graph_metadata, graph_iri, timeout}, _from, state) do
    reply = StoreServer.request(state.store_server, {:graph_metadata, graph_iri}, timeout)
    {:reply, reply, state}
  end
end
