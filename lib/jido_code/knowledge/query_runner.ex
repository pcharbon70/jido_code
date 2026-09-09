defmodule JidoCode.Knowledge.QueryRunner do
  @moduledoc false

  use GenServer

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CatalogQueryRequest
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

  @spec execute(atom(), String.t(), map(), AuthorityContext.t(), String.t(), keyword()) ::
          {:ok, JidoCode.Knowledge.QueryResult.t()} | {:error, Error.t()}
  def execute(name, version, parameters, authority, scope_iri, options \\ [])

  def execute(name, version, parameters, %AuthorityContext{} = authority, scope_iri, options) do
    server = Keyword.get(options, :server, __MODULE__)

    with {:ok, request} <-
           CatalogQueryRequest.new(name, version, parameters, authority, scope_iri, options) do
      timeout = request.definition.limits.timeout_ms
      GenServer.call(server, {:catalog_query, request, timeout}, timeout + 1_000)
    end
  catch
    :exit, {:timeout, _details} -> {:error, Error.new(:timeout, :catalog_query)}
    :exit, _reason -> {:error, Error.new(:unavailable, :catalog_query)}
  end

  def execute(_name, _version, _parameters, _authority, _scope_iri, _options),
    do: {:error, Error.new(:invalid_input, :catalog_query)}

  @impl true
  def init(options) do
    {:ok, %{store_server: Keyword.get(options, :store_server, StoreServer)}}
  end

  def authorize(name, version, parameters, authority, scope_iri, options \\ []) do
    measure_authorization(:caller, fn ->
      authorize_request(name, version, parameters, authority, scope_iri, options)
    end)
  end

  defp authorize_request(name, version, parameters, authority, scope_iri, options) do
    with {:ok, request} <-
           CatalogQueryRequest.new(name, version, parameters, authority, scope_iri, options) do
      server = Keyword.get(options, :server, __MODULE__)
      GenServer.call(server, {:catalog_authorization, request, 1_000}, 1_250)
    end
  end

  @impl true
  def handle_call({:catalog_authorization, request, timeout}, _from, state) do
    reply =
      measure_authorization(:store, fn ->
        StoreServer.request(state.store_server, {:catalog_authorization, request}, timeout)
      end)

    {:reply, reply, state}
  end

  def handle_call({:graph_metadata, graph_iri, timeout}, _from, state) do
    reply = StoreServer.request(state.store_server, {:graph_metadata, graph_iri}, timeout)
    {:reply, reply, state}
  end

  def handle_call({:catalog_query, request, timeout}, _from, state) do
    reply = StoreServer.request(state.store_server, {:catalog_query, request}, timeout)
    {:reply, reply, state}
  end

  # Fixed stage/outcome dimensions only: no request, principal, graph, or error payload.
  # Caller duration includes QueryRunner queueing; store duration does not.
  defp measure_authorization(stage, run) do
    started = System.monotonic_time(:millisecond)

    {result, outcome} =
      try do
        result = run.()
        {result, if(match?({:ok, _}, result), do: :ok, else: :error)}
      catch
        :exit, {:timeout, _} ->
          {{:error, Error.new(:unavailable, :catalog_authorization)}, :timeout}

        :exit, _ ->
          {{:error, Error.new(:unavailable, :catalog_authorization)}, :unavailable}
      end

    :telemetry.execute(
      [:jido_code, :knowledge, :authorization_read],
      %{duration_ms: max(System.monotonic_time(:millisecond) - started, 0)},
      %{stage: stage, outcome: outcome}
    )

    result
  end
end
