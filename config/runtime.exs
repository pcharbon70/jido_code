import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/jido_code start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :jido_code, JidoCodeWeb.Endpoint, server: true
end

case System.get_env("JIDO_CODE_HUI_QUALIFICATION_ENABLED") do
  nil ->
    :ok

  "false" ->
    :ok

  "true" ->
    hosts =
      System.get_env("JIDO_CODE_HUI_QUALIFICATION_HOSTS")
      |> case do
        nil -> raise "JIDO_CODE_HUI_QUALIFICATION_HOSTS is required when qualification is enabled"
        value -> value
      end
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if hosts == [] do
      raise "JIDO_CODE_HUI_QUALIFICATION_HOSTS must contain at least one host"
    end

    config :jido_code, :hypermedia_qualification,
      enabled: true,
      allowed_hosts: hosts

  invalid ->
    raise "JIDO_CODE_HUI_QUALIFICATION_ENABLED must be true or false, got: #{inspect(invalid)}"
end

session_ttl_seconds = fn ->
  value = System.get_env("JIDO_CODE_SESSION_TTL_SECONDS") || "28800"

  case Integer.parse(value) do
    {seconds, ""} when seconds in 300..86_400 -> seconds
    _invalid -> raise "JIDO_CODE_SESSION_TTL_SECONDS must be an integer from 300 through 86400"
  end
end

if operator_token = System.get_env("JIDO_CODE_OPERATOR_TOKEN") do
  if byte_size(operator_token) < 24 or byte_size(operator_token) > 512 do
    raise "JIDO_CODE_OPERATOR_TOKEN must contain from 24 through 512 bytes"
  end

  config :jido_code, :product_auth,
    credential_digest: :crypto.hash(:sha256, operator_token),
    session_ttl_seconds: session_ttl_seconds.(),
    session_generation: System.get_env("JIDO_CODE_SESSION_GENERATION") || "1"

  config :jido_code, :authority_bootstrap, %{
    enabled?: true,
    token_digest: :crypto.hash(:sha256, operator_token)
  }
end

case {System.get_env("JIDO_CODE_STORE_ROOT"), System.get_env("JIDO_CODE_BACKUP_ROOT")} do
  {nil, nil} ->
    :ok

  {store_root, backup_root} when is_binary(store_root) and is_binary(backup_root) ->
    config :jido_code, :knowledge_store,
      root: store_root,
      backup_root: backup_root

  _partial ->
    raise "JIDO_CODE_STORE_ROOT and JIDO_CODE_BACKUP_ROOT must be configured together"
end

if config_env() == :prod do
  operator_token =
    System.get_env("JIDO_CODE_OPERATOR_TOKEN") ||
      raise "environment variable JIDO_CODE_OPERATOR_TOKEN is missing"

  if byte_size(operator_token) < 24 or byte_size(operator_token) > 512 do
    raise "JIDO_CODE_OPERATOR_TOKEN must contain from 24 through 512 bytes"
  end

  config :jido_code, :product_auth,
    credential_digest: :crypto.hash(:sha256, operator_token),
    session_ttl_seconds: session_ttl_seconds.(),
    session_generation: System.get_env("JIDO_CODE_SESSION_GENERATION") || "1"

  config :jido_code, :authority_bootstrap, %{
    enabled?: true,
    token_digest: :crypto.hash(:sha256, operator_token)
  }

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :jido_code, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :jido_code, :knowledge_store,
    enabled: true,
    root: System.get_env("JIDO_CODE_STORE_ROOT") || "/var/lib/jido_code/knowledge",
    backup_root: System.get_env("JIDO_CODE_BACKUP_ROOT") || "/var/lib/jido_code/backups",
    schema: :quad,
    schema_version: 1,
    durability: :sync,
    open_timeout: 15_000

  config :jido_code, JidoCodeWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :jido_code, JidoCodeWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :jido_code, JidoCodeWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
