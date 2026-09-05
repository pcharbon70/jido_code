# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :jido_code,
  runtime_mode: config_env(),
  generators: [timestamp_type: :utc_datetime],
  product_surface: [
    factory_iri: "https://jido.run/id/repository-factory/default",
    factory_scope_iri: "https://jido.run/id/scope/factory/default",
    principal_iri: "https://jido.run/id/actor/local-operator",
    actor_iri: "https://jido.run/id/actor/local-operator",
    policy_boundary_iri: "https://jido.run/id/policy-boundary/default",
    policy_iris: ["https://jido.run/id/policy/default"]
  ],
  fleet_runtime_ceilings: %{
    concurrency: %{global: 16, cohort: 8, repository: 2, provider: 4, capability: 4},
    rate_units: 100,
    budget_units: 100,
    max_risk: 10,
    max_candidates: 200,
    max_campaign_repositories: 50,
    starvation_cycles: 5,
    emergency_priority: 100
  },
  knowledge_store: [
    enabled: true,
    root: Path.expand("../var/knowledge/#{config_env()}", __DIR__),
    backup_root: Path.expand("../var/backups/#{config_env()}", __DIR__),
    schema: :quad,
    schema_version: 1,
    durability: :sync,
    open_timeout: 15_000
  ]

config :live_vue, ssr: true

config :jido_code, :product_auth,
  credential_digest: nil,
  session_ttl_seconds: 28_800,
  session_generation: "1"

config :jido_code, :human_identity,
  enabled: false,
  persistence: false,
  path: nil,
  integrity_key: nil,
  policy_revision: "hui.identity.v1",
  pbkdf2_iterations: 210_000,
  max_failed_attempts: 5,
  lockout_seconds: 300,
  recovery_adapter: JidoCode.Identity.Recovery.Unconfigured,
  hard_lifetime_seconds: 43_200,
  idle_lifetime_seconds: 1_800,
  idle_warning_seconds: 300,
  maximum_authentication_age_seconds: 43_200,
  bootstrap: nil

config :jido_code, :secure_session_cookie, true

# HUI-B3's qualification consumer is compiled only into the test build. Runtime
# configuration may enable that test-only build with an explicit host allowlist;
# its Plug also restricts callers to the loopback interface.
config :jido_code, :hypermedia_qualification_build, false

config :jido_code, :hypermedia_qualification,
  enabled: false,
  allowed_hosts: []

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

# Model credentials are supplied explicitly by the Factory credential broker.
# Never let ReqLLM or its model catalog discover a repository-local dotenv file.
config :req_llm, load_dotenv: false, telemetry: [payloads: :none]
config :llm_db, load_dotenv: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
