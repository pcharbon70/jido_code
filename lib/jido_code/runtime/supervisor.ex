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
      {Registry, keys: :unique, name: JidoCode.Runtime.AttemptRegistry},
      {DynamicSupervisor,
       name: JidoCode.Runtime.AttemptSupervisor,
       strategy: :one_for_one,
       max_restarts: 20,
       max_seconds: 10}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
