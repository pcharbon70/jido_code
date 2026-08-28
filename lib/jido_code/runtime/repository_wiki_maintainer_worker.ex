defmodule JidoCode.Runtime.RepositoryWikiMaintainerWorker do
  @moduledoc "Disposable per-repository wiki maintainer owner; graph lease remains authority."

  use GenServer

  alias JidoCode.Runtime.RepositoryWikiMaintainerRegistry

  def child_spec(options) do
    %{
      id: {__MODULE__, {options[:tenant_iri], options[:repository_iri]}},
      start: {__MODULE__, :start_link, [options]},
      restart: :temporary,
      type: :worker
    }
  end

  def start_link(options) when is_list(options) do
    name =
      RepositoryWikiMaintainerRegistry.via(
        Keyword.fetch!(options, :registry),
        Keyword.fetch!(options, :tenant_iri),
        Keyword.fetch!(options, :repository_iri)
      )

    GenServer.start_link(__MODULE__, options, name: name)
  end

  def status(pid), do: GenServer.call(pid, :status)
  def stop(pid, reason \\ :normal), do: GenServer.stop(pid, reason)

  @impl true
  def init(options) do
    lease = Keyword.fetch!(options, :lease)

    {:ok,
     %{
       tenant_iri: Keyword.fetch!(options, :tenant_iri),
       repository_iri: Keyword.fetch!(options, :repository_iri),
       lease: lease,
       state: :idle,
       queue: [],
       coalesced_trigger_count: 0,
       active_attempt: nil,
       last_result: nil,
       started_at: Keyword.fetch!(options, :started_at)
     }}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      state: state.state,
      health: :ready,
      repository_iri: state.repository_iri,
      tenant_iri: state.tenant_iri,
      lease_generation: state.lease.generation,
      lease_fence: state.lease.fence,
      lease_expires_at: state.lease.expires_at,
      lease_age_ms:
        max(DateTime.diff(DateTime.utc_now(), state.lease.acquired_at, :millisecond), 0),
      queued_trigger_count: length(state.queue),
      coalesced_trigger_count: state.coalesced_trigger_count,
      active_attempt: state.active_attempt,
      last_result: state.last_result,
      disabled_reason: nil
    }

    {:reply, status, state}
  end
end
