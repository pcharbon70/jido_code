defmodule JidoCode.Knowledge.Supervisor do
  @moduledoc false

  use Supervisor

  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.Maintenance
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
    writer = Keyword.get(options, :writer, Writer)
    maintenance = Keyword.get(options, :maintenance, Maintenance)

    store_options =
      options
      |> Keyword.take([:authorized_callers, :config, :config_overrides, :native])
      |> Keyword.merge(name: store_server, readiness: readiness)

    children = [
      {Readiness, name: readiness},
      {StoreServer, store_options},
      {Writer, name: writer, store_server: store_server},
      {Maintenance, name: maintenance, store_server: store_server}
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 3, max_seconds: 30)
  end
end
