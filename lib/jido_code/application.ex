defmodule JidoCode.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ok = verify_release_contract!()

    qualification_children =
      if Application.get_env(:jido_code, :hypermedia_qualification, [])[:enabled] do
        [JidoCodeWeb.Qualification.HypermediaStreamCoordinator]
      else
        []
      end

    children =
      [
        JidoCodeWeb.Telemetry,
        TwMerge.Cache,
        {DNSCluster, query: Application.get_env(:jido_code, :dns_cluster_query) || :ignore},
        JidoCode.Knowledge.Supervisor,
        {Task.Supervisor, name: JidoCode.Factory.Model.StreamSupervisor},
        JidoCode.Runtime.Supervisor,
        {Phoenix.PubSub, name: JidoCode.PubSub}
      ] ++
        qualification_children ++
        [
          # Start a worker by calling: JidoCode.Worker.start_link(arg)
          # {JidoCode.Worker, arg},
          # Start to serve requests, typically the last entry
          JidoCodeWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JidoCode.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp verify_release_contract! do
    case JidoCode.ReleaseContract.verify() do
      :ok ->
        :ok

      {:error, error} ->
        raise "release contract failed: #{error.kind}/#{error.operation}"
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JidoCodeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
