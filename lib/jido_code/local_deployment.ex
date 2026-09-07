defmodule JidoCode.LocalDeployment do
  @moduledoc "Closed single-writer, direct loopback production transport profile."

  @profile "local-loopback-v1"
  def profile, do: @profile
  def active?, do: Application.get_env(:jido_code, :deployment_profile) == @profile

  def request_log_level(_conn), do: if(active?(), do: false, else: :info)

  def stream_limits, do: if(active?(), do: %{factory: 4, tenant: 4}, else: %{})

  def transport(env) when is_map(env) do
    with profile when profile in [nil, @profile] <- env["JIDO_CODE_DEPLOYMENT_PROFILE"],
         host when host in ["127.0.0.1", "localhost"] <- env["PHX_HOST"] || "127.0.0.1",
         nil <- env["DNS_CLUSTER_QUERY"],
         {port, ""} when port in 1024..65_535 <- Integer.parse(env["PORT"] || "4000") do
      {:ok,
       [
         url: [host: host, port: port, scheme: "http"],
         check_origin: ["http://#{host}:#{port}"],
         http: [
           ip: {127, 0, 0, 1},
           port: port,
           http_options: [compress: false],
           http_1_options: [max_requests: 100, max_header_length: 8_192],
           http_2_options: [enabled: false],
           thousand_island_options: [
             num_acceptors: 4,
             num_connections: 32,
             read_timeout: 15_000,
             shutdown_timeout: 3_000,
             transport_options: [send_timeout: 2_000, send_timeout_close: true]
           ]
         ]
       ]}
    else
      _ -> {:error, :unsupported_local_deployment}
    end
  end

  def drain do
    JidoCode.Product.StreamCoordinator.drain()
  end

  def readiness do
    with %{enabled: true} <- JidoCode.Identity.capabilities(),
         true <- JidoCode.Knowledge.Health.ready?(JidoCode.Knowledge.health()),
         %{connections: connections, draining: false} <-
           JidoCode.Product.StreamCoordinator.stats() do
      %{ready?: true, connections: connections}
    else
      _ -> %{ready?: false}
    end
  catch
    :exit, _ -> %{ready?: false}
  end
end
