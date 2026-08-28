defmodule JidoCode.Runtime.Supervisor do
  @moduledoc "Supervises disposable Jido and execution-attempt runtime state."

  use Supervisor

  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(_options) do
    children = [
      JidoCode.Runtime.JidoInstance,
      JidoCode.Runtime.JidoHarness.RunRegistry,
      {Registry, keys: :unique, name: JidoCode.Runtime.AttemptRegistry},
      {Registry, keys: :unique, name: JidoCode.Runtime.RepositoryWikiMaintainerRegistry},
      {DynamicSupervisor,
       name: JidoCode.Runtime.AttemptSupervisor,
       strategy: :one_for_one,
       max_restarts: 20,
       max_seconds: 10},
      {DynamicSupervisor,
       name: JidoCode.Runtime.RepositoryWikiMaintainerDynamicSupervisor,
       strategy: :one_for_one,
       max_restarts: 20,
       max_seconds: 10},
      JidoCode.Factory.RepositoryWiki.Coordinator
    ]

    recovery = Application.get_env(:jido_code, :attempt_recovery, [])

    children =
      if Keyword.get(recovery, :enabled, false) do
        children ++ [{JidoCode.Factory.AttemptRecovery, Keyword.delete(recovery, :enabled)}]
      else
        children
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
