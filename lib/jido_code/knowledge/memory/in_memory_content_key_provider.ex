defmodule JidoCode.Knowledge.Memory.InMemoryContentKeyProvider do
  @moduledoc "Process-local Phase 6 key-provider adapter for tests and explicit local deployments."

  use GenServer

  @behaviour JidoCode.Knowledge.Memory.ContentKeyProvider

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, Keyword.take(options, [:name]))
  end

  @impl true
  def init(options) do
    random_bytes = Keyword.get(options, :random_bytes, &:crypto.strong_rand_bytes/1)
    {:ok, %{keys: %{}, heads: %{}, random_bytes: random_bytes}}
  end

  @impl true
  def create_key(server, tenant_iri, object_iri),
    do: GenServer.call(server, {:create, tenant_iri, object_iri})

  @impl true
  def rotate_key(server, tenant_iri, object_iri),
    do: GenServer.call(server, {:rotate, tenant_iri, object_iri})

  @impl true
  def fetch_key(server, reference_iri), do: GenServer.call(server, {:fetch, reference_iri})

  @impl true
  def revoke_key(server, reference_iri), do: GenServer.call(server, {:revoke, reference_iri})

  @impl true
  def destroy_key(server, reference_iri), do: GenServer.call(server, {:destroy, reference_iri})

  @impl true
  def handle_call({operation, tenant, object}, _from, state)
      when operation in [:create, :rotate] do
    with :ok <- ResourceIdentity.validate(tenant),
         :ok <- ResourceIdentity.validate(object),
         :ok <- creation_allowed(operation, state, tenant, object),
         generation = Map.get(state.heads, {tenant, object}, 0) + 1,
         {:ok, reference} <- key_reference(tenant, object, generation),
         key when is_binary(key) and byte_size(key) == 32 <- state.random_bytes.(32) do
      record = %{
        reference_iri: reference,
        tenant_iri: tenant,
        object_iri: object,
        generation: generation,
        key: key,
        state: :active
      }

      {:reply, {:ok, record},
       %{
         state
         | keys: Map.put(state.keys, reference, record),
           heads: Map.put(state.heads, {tenant, object}, generation)
       }}
    else
      {:error, %Error{} = error} -> {:reply, {:error, error}, state}
      _invalid -> {:reply, invalid(:content_key_create), state}
    end
  end

  def handle_call({:fetch, reference}, _from, state) do
    reply =
      case Map.fetch(state.keys, reference) do
        {:ok, %{state: :active} = record} -> {:ok, record}
        {:ok, %{state: :revoked}} -> {:error, Error.new(:unauthorized, :content_key_revoked)}
        :error -> {:error, Error.new(:unavailable, :content_key)}
      end

    {:reply, reply, state}
  end

  def handle_call({:revoke, reference}, _from, state) do
    case Map.fetch(state.keys, reference) do
      {:ok, record} ->
        {:reply, :ok,
         %{state | keys: Map.put(state.keys, reference, %{record | state: :revoked})}}

      :error ->
        {:reply, {:error, Error.new(:unavailable, :content_key)}, state}
    end
  end

  def handle_call({:destroy, reference}, _from, state) do
    if Map.has_key?(state.keys, reference) do
      {:reply, :ok, %{state | keys: Map.delete(state.keys, reference)}}
    else
      {:reply, {:error, Error.new(:unavailable, :content_key)}, state}
    end
  end

  defp creation_allowed(:create, state, tenant, object) do
    if Map.has_key?(state.heads, {tenant, object}),
      do: {:error, Error.new(:conflict, :content_key_exists)},
      else: :ok
  end

  defp creation_allowed(:rotate, state, tenant, object) do
    if Map.has_key?(state.heads, {tenant, object}),
      do: :ok,
      else: {:error, Error.new(:unavailable, :content_key)}
  end

  defp key_reference(tenant, object, generation) do
    ResourceIdentity.deterministic(
      :content_key_reference,
      Enum.join([tenant, object, Integer.to_string(generation)], "\n")
    )
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
