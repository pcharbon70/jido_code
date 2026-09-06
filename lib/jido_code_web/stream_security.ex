defmodule JidoCodeWeb.StreamSecurity do
  @moduledoc "SSE negotiation is explicit and completes before any response starts."
  import Plug.Conn
  alias JidoCodeWeb.ReadSecurity

  def init(options), do: options

  def call(conn, _options) do
    if get_req_header(conn, "accept") == ["text/event-stream"] do
      conn
    else
      ReadSecurity.reject(conn, 406)
    end
  end
end
