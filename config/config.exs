# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :jido_code,
  runtime_mode: config_env(),
  generators: [timestamp_type: :utc_datetime]

config :live_vue, ssr: true

config :phoenix_vite, PhoenixVite.Npm,
  assets: [args: [], cd: Path.expand("..", __DIR__)],
  vite: [
    args: ~w(exec -- vite),
    cd: Path.expand("../assets", __DIR__),
    env: %{"MIX_BUILD_PATH" => Mix.Project.build_path()}
  ]

# Configures the endpoint
config :jido_code, JidoCodeWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: JidoCodeWeb.ErrorHTML, json: JidoCodeWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: JidoCode.PubSub,
  live_view: [signing_salt: "HRoBfuPV"]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Use the Req-backed Swoosh API client instead of the Hackney default.
config :swoosh, api_client: Swoosh.ApiClient.Req

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
