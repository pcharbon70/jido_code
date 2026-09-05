import Config

browser_port = String.to_integer(System.get_env("PORT") || "4002")

config :live_vue, ssr: false

config :jido_code, :knowledge_store, enabled: false
config :jido_code, :hypermedia_qualification_build, true

config :jido_code, :product_auth,
  credential_digest: :crypto.hash(:sha256, "test-operator-token"),
  session_ttl_seconds: 3_600,
  session_generation: "test-1"

config :jido_code, :secure_session_cookie, false

config :jido_code, :human_identity,
  enabled: true,
  persistence: false,
  policy_revision: "hui.identity.test.v1",
  pbkdf2_iterations: 1_000,
  max_failed_attempts: 5,
  lockout_seconds: 300,
  hard_lifetime_seconds: 3_600,
  idle_lifetime_seconds: 1_800,
  idle_warning_seconds: 300,
  maximum_authentication_age_seconds: 3_600,
  bootstrap: %{
    subject_ref: "human_test_operator",
    authenticator_ref: "authenticator_test_password",
    display_name: "Test Operator",
    login: "operator@example.test",
    credential: "test-named-human-credential",
    roles: [
      :observer,
      :project_developer,
      :project_maintainer,
      :independent_verifier,
      :factory_operator,
      :security_auditor,
      :factory_administrator,
      :knowledge_steward,
      :cost_observer
    ],
    route_groups: [
      :developer,
      :reviewer,
      :operations,
      :security,
      :cost,
      :knowledge,
      :administration
    ]
  },
  authority_adapter: JidoCode.TestSupport.StaticHumanAuthorityAdapter

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :jido_code, JidoCodeWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "localhost", port: browser_port, scheme: "http"],
  http: [ip: {127, 0, 0, 1}, port: browser_port],
  secret_key_base: "L+F1ZqGJWNGCsnugBrzGc2B0FRtIP1u+NrRBM9G7CMj7I62hOAZwXbVn1mrBe6v1",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
