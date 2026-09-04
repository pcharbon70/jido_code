defmodule JidoCodeWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Installs the response-scoped nonce and enforcing browser policy used by the
  local Datastar runtime.

  The nonce is presentation-only. It grants no identity, scope, action,
  revision, or command authority and is regenerated for every request.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(options), do: options

  @impl true
  def call(conn, _options) do
    nonce = Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", policy(nonce))
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("x-content-type-options", "nosniff")
  end

  @doc false
  def policy(nonce) when is_binary(nonce) and byte_size(nonce) > 0 do
    [
      "default-src 'self'",
      "base-uri 'self'",
      "object-src 'none'",
      "frame-ancestors 'none'",
      "form-action 'self'",
      "script-src 'self' 'nonce-#{nonce}'",
      "style-src 'self'",
      "img-src 'self' data:",
      "font-src 'self'",
      "connect-src 'self'",
      "manifest-src 'self'",
      "worker-src 'self'",
      "require-trusted-types-for 'script'",
      "trusted-types datastar"
    ]
    |> Enum.join("; ")
  end
end
