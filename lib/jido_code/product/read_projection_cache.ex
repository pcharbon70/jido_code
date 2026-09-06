defmodule JidoCode.Product.ReadProjectionCache do
  @moduledoc """
  Disposable, process-local cache for exact HUI-C4 read contexts.

  Keys digest the current named principal, browser-session generations, exact
  scope, route authorization, grant/revocation context, closed query intent,
  and query protocol. Cache values are never authoritative and every hit must
  be reauthorized by the projection provider before it can be rendered.
  """

  use GenServer

  alias JidoCode.Identity.AuthorizationResult
  alias JidoCode.Product.ReadProjection

  @fresh_ttl_ms 5_000
  @retention_ms 30_000
  @max_entries 512
  @cacheable_states [:ready, :empty, :stale, :incomplete, :contradicted, :truncated]

  def start_link(options \\ []) do
    name = Keyword.get(options, :name, __MODULE__)

    state = %{
      entries: %{},
      order: [],
      fresh_ttl_ms: Keyword.get(options, :fresh_ttl_ms, @fresh_ttl_ms),
      retention_ms: Keyword.get(options, :retention_ms, @retention_ms),
      max_entries: Keyword.get(options, :max_entries, @max_entries)
    }

    if is_nil(name),
      do: GenServer.start_link(__MODULE__, state),
      else: GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec key(map()) :: {:ok, String.t()} | {:error, :invalid_cache_context}
  def key(%{
        session_ref: session_ref,
        current_scope: scope,
        authorization: %AuthorizationResult{} = authorization,
        page: page
      })
      when is_binary(session_ref) and is_map(scope) and is_map(page) do
    with principal when is_binary(principal) <- scope[:principal_iri],
         session_generation when is_integer(session_generation) <- scope[:session_generation],
         account_generation when is_integer(account_generation) <- scope[:account_generation],
         scope_iri when is_binary(scope_iri) <- scope[:iri],
         resource_ref when is_binary(resource_ref) <- scope[:resource_ref],
         resource_kind when is_atom(resource_kind) <- scope[:resource_kind],
         resource_revision when is_integer(resource_revision) <- scope[:resource_revision],
         policy_revision when is_binary(policy_revision) <- authorization.policy_revision,
         grant_ref when is_binary(grant_ref) <- authorization.exact_grant_ref,
         surface when is_atom(surface) <- page[:key],
         route_params when is_map(route_params) <- page[:route_params],
         query when is_map(query) <- page[:query] do
      material = {
        "hui-c4-read-cache/1.0.0",
        "2.11.0",
        principal,
        session_ref,
        session_generation,
        account_generation,
        scope_iri,
        resource_ref,
        resource_kind,
        resource_revision,
        scope[:tenant_ref],
        scope[:project_ref],
        policy_revision,
        grant_ref,
        authorization.delegation_ref,
        authorization.obligations,
        authorization.graph_revisions,
        scope[:revocation_generations],
        surface,
        route_params,
        query
      }

      {:ok,
       material
       |> :erlang.term_to_binary([:deterministic])
       |> then(&:crypto.hash(:sha256, &1))
       |> Base.encode16(case: :lower)}
    else
      _invalid -> {:error, :invalid_cache_context}
    end
  rescue
    _error -> {:error, :invalid_cache_context}
  end

  def key(_context), do: {:error, :invalid_cache_context}

  @spec fetch(GenServer.server(), String.t(), integer()) ::
          {:fresh, ReadProjection.t()} | {:stale, ReadProjection.t()} | :miss
  def fetch(server \\ __MODULE__, key, now_ms)
      when is_binary(key) and is_integer(now_ms) do
    GenServer.call(server, {:fetch, key, now_ms})
  catch
    :exit, _reason -> :miss
  end

  @spec put(GenServer.server(), String.t(), ReadProjection.t(), integer()) :: :ok
  def put(server \\ __MODULE__, key, %ReadProjection{} = projection, now_ms)
      when is_binary(key) and is_integer(now_ms) do
    GenServer.call(server, {:put, key, projection, now_ms})
  catch
    :exit, _reason -> :ok
  end

  @spec invalidate(GenServer.server(), String.t()) :: :ok
  def invalidate(server \\ __MODULE__, key) when is_binary(key) do
    GenServer.call(server, {:invalidate, key})
  catch
    :exit, _reason -> :ok
  end

  @spec reset(GenServer.server()) :: :ok
  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  catch
    :exit, _reason -> :ok
  end

  @spec size(GenServer.server()) :: non_neg_integer()
  def size(server \\ __MODULE__) do
    GenServer.call(server, :size)
  catch
    :exit, _reason -> 0
  end

  @spec cacheable?(ReadProjection.t()) :: boolean()
  def cacheable?(%ReadProjection{state: state}), do: state in @cacheable_states

  @impl true
  def init(state) do
    with true <- valid_policy?(state) do
      {:ok, state}
    else
      false -> {:stop, :invalid_read_projection_cache_policy}
    end
  end

  @impl true
  def handle_call({:fetch, key, now_ms}, _from, state) do
    {entries, order} = purge_expired(state.entries, state.order, now_ms, state.retention_ms)

    reply =
      case Map.get(entries, key) do
        %{projection: projection, inserted_at_ms: inserted_at_ms} ->
          if now_ms - inserted_at_ms <= state.fresh_ttl_ms,
            do: {:fresh, projection},
            else: {:stale, projection}

        nil ->
          :miss
      end

    {:reply, reply, %{state | entries: entries, order: order}}
  end

  def handle_call({:put, key, projection, now_ms}, _from, state) do
    if cacheable?(projection) do
      entry = %{projection: projection, inserted_at_ms: now_ms}
      entries = Map.put(state.entries, key, entry)
      order = [key | Enum.reject(state.order, &(&1 == key))]
      {entries, order} = evict(entries, order, state.max_entries)
      {:reply, :ok, %{state | entries: entries, order: order}}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call({:invalidate, key}, _from, state) do
    {:reply, :ok,
     %{
       state
       | entries: Map.delete(state.entries, key),
         order: Enum.reject(state.order, &(&1 == key))
     }}
  end

  def handle_call(:reset, _from, state),
    do: {:reply, :ok, %{state | entries: %{}, order: []}}

  def handle_call(:size, _from, state), do: {:reply, map_size(state.entries), state}

  defp valid_policy?(state) do
    is_integer(state.fresh_ttl_ms) and state.fresh_ttl_ms >= 0 and
      is_integer(state.retention_ms) and state.retention_ms >= state.fresh_ttl_ms and
      is_integer(state.max_entries) and state.max_entries in 1..10_000
  end

  defp purge_expired(entries, order, now_ms, retention_ms) do
    entries =
      Map.reject(entries, fn {_key, entry} ->
        now_ms - entry.inserted_at_ms > retention_ms
      end)

    {entries, Enum.filter(order, &Map.has_key?(entries, &1))}
  end

  defp evict(entries, order, maximum) when length(order) <= maximum, do: {entries, order}

  defp evict(entries, order, maximum) do
    {retained, evicted} = Enum.split(order, maximum)
    {Map.drop(entries, evicted), retained}
  end
end
