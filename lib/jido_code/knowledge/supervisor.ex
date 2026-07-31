defmodule JidoCode.Knowledge.Supervisor do
  @moduledoc false

  use Supervisor

  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer

  def start_link(options \\ []) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> Supervisor.start_link(__MODULE__, options)
      name -> Supervisor.start_link(__MODULE__, options, name: name)
    end
  end

  @impl true
  def init(options) do
    readiness = Keyword.get(options, :readiness, Readiness)
    store_server = Keyword.get(options, :store_server, StoreServer)

    children = [
      {Readiness, name: readiness},
      {StoreServer, name: store_server, readiness: readiness},
      Writer
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 3, max_seconds: 30)
  end
end
