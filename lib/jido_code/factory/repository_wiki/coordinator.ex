defmodule JidoCode.Factory.RepositoryWiki.Coordinator do
  @moduledoc "Fleet coordinator for graph-admitted, repository-partitioned wiki maintainers."

  use GenServer

  alias JidoCode.Knowledge
  alias JidoCode.Runtime.RepositoryWikiMaintainerRegistry
  alias JidoCode.Runtime.RepositoryWikiMaintainerSupervisor
  alias JidoCode.Runtime.RepositoryWikiMaintainerWorker

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))
  end

  def ensure_owner(server \\ __MODULE__, enrollment, profile, context),
    do: GenServer.call(server, {:ensure_owner, enrollment, profile, context})

  def start_manual_owner(server \\ __MODULE__, enrollment, profile, context),
    do: GenServer.call(server, {:start_manual_owner, enrollment, profile, context})

  def status(server \\ __MODULE__, tenant_iri, repository_iri),
    do: GenServer.call(server, {:status, tenant_iri, repository_iri})

  def stop_owner(server \\ __MODULE__, tenant_iri, repository_iri),
    do: GenServer.call(server, {:stop_owner, tenant_iri, repository_iri})

  @impl true
  def init(options) do
    {:ok,
     %{
       registry:
         Keyword.get(options, :registry, JidoCode.Runtime.RepositoryWikiMaintainerRegistry),
       supervisor:
         Keyword.get(
           options,
           :supervisor,
           JidoCode.Runtime.RepositoryWikiMaintainerDynamicSupervisor
         ),
       lease_gateway: Keyword.get(options, :lease_gateway, &unavailable_gateway/1),
       current_lease: Keyword.get(options, :current_lease, fn _tenant, _repository -> nil end)
     }}
  end

  @impl true
  def handle_call({:ensure_owner, enrollment, profile, context}, _from, state) do
    key = {enrollment[:tenant_iri], enrollment[:repository_iri]}

    reply =
      with :ok <- Knowledge.repository_wiki_maintainer_eligibility(profile, enrollment, context),
           :error <- lookup(state, key),
           current <- state.current_lease.(elem(key, 0), elem(key, 1)),
           {:ok, lease} <- lease(profile, enrollment, context, current),
           {:ok, _receipt} <- state.lease_gateway.(lease),
           {:ok, pid} <- start_worker(state, enrollment, lease, context) do
        {:ok, %{pid: pid, lease: lease}}
      else
        {:ok, pid} -> {:already_started, pid}
        {:duplicate, lease} -> {:duplicate, lease}
        {:error, reason} -> {:error, reason}
      end

    {:reply, reply, state}
  end

  def handle_call({:start_manual_owner, enrollment, profile, context}, _from, state) do
    key = {enrollment[:tenant_iri], enrollment[:repository_iri]}

    reply =
      with true <- context[:manual_request_admitted?] == true,
           :ok <-
             Knowledge.repository_wiki_manual_maintainer_eligibility(
               profile,
               enrollment,
               context
             ),
           :error <- lookup(state, key),
           current <- state.current_lease.(elem(key, 0), elem(key, 1)),
           {:ok, lease} <- lease(profile, enrollment, context, current),
           {:ok, _receipt} <- state.lease_gateway.(lease),
           {:ok, pid} <- start_worker(state, enrollment, lease, context) do
        {:ok, %{pid: pid, lease: lease, purpose: :manual_request}}
      else
        false -> {:error, :manual_request_not_admitted}
        {:ok, pid} -> {:already_started, pid}
        {:duplicate, lease} -> {:duplicate, lease}
        {:error, reason} -> {:error, reason}
      end

    {:reply, reply, state}
  end

  def handle_call({:status, tenant_iri, repository_iri}, _from, state) do
    reply =
      case RepositoryWikiMaintainerRegistry.lookup(state.registry, tenant_iri, repository_iri) do
        {:ok, pid} ->
          {:ok, RepositoryWikiMaintainerWorker.status(pid)}

        :error ->
          {:ok,
           %{
             state: :not_running,
             health: :not_running,
             lease_age_ms: nil,
             queued_trigger_count: 0,
             coalesced_trigger_count: 0,
             active_attempt: nil,
             last_result: nil,
             disabled_reason: :not_enrolled
           }}
      end

    {:reply, reply, state}
  end

  def handle_call({:stop_owner, tenant_iri, repository_iri}, _from, state) do
    reply =
      case RepositoryWikiMaintainerRegistry.lookup(state.registry, tenant_iri, repository_iri) do
        {:ok, pid} -> RepositoryWikiMaintainerSupervisor.terminate_child(state.supervisor, pid)
        :error -> :ok
      end

    {:reply, reply, state}
  end

  defp lookup(state, {tenant_iri, repository_iri}),
    do: RepositoryWikiMaintainerRegistry.lookup(state.registry, tenant_iri, repository_iri)

  defp lease(profile, enrollment, context, current) do
    Knowledge.acquire_repository_wiki_maintainer_lease(
      %{
        repository_iri: enrollment.repository_iri,
        tenant_iri: enrollment.tenant_iri,
        holder_iri: context.holder_iri,
        profile_digest: profile.digest,
        enrollment_revision: enrollment.revision,
        cancellation_generation: enrollment.cancellation_generation,
        acquired_at: context.evaluated_at,
        expires_at: DateTime.add(context.evaluated_at, profile.lease.duration_ms, :millisecond)
      },
      current
    )
  end

  defp start_worker(state, enrollment, lease, context) do
    RepositoryWikiMaintainerSupervisor.start_child(state.supervisor,
      registry: state.registry,
      tenant_iri: enrollment.tenant_iri,
      repository_iri: enrollment.repository_iri,
      lease: lease,
      started_at: context.evaluated_at
    )
  end

  defp unavailable_gateway(_lease), do: {:error, :lease_gateway_unavailable}
end
