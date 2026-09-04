defmodule JidoCodeWeb.Plugs.HypermediaQualificationAccess do
  @moduledoc """
  Conceals the HUI-B3 qualification-only surface unless explicitly enabled.

  The consumer is never production navigation. Even when enabled, requests
  must arrive over loopback and use an explicitly allowlisted host.
  """

  import Plug.Conn

  @behaviour Plug

  @loopback_v4 {127, 0, 0, 1}
  @loopback_v6 {0, 0, 0, 0, 0, 0, 0, 1}

  @impl true
  def init(options), do: options

  @impl true
  def call(conn, _options) do
    config = Application.get_env(:jido_code, :hypermedia_qualification, [])

    if enabled?(config) and loopback?(conn.remote_ip) and allowed_host?(conn.host, config) do
      assign(conn, :hypermedia_qualification?, true)
    else
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(:not_found, "Not Found")
      |> halt()
    end
  end

  defp enabled?(config), do: Keyword.get(config, :enabled, false) == true

  defp allowed_host?(host, config) do
    host in Keyword.get(config, :allowed_hosts, [])
  end

  defp loopback?(@loopback_v4), do: true
  defp loopback?(@loopback_v6), do: true
  defp loopback?(_remote_ip), do: false
end
