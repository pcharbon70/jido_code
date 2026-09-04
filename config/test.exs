import Config

browser_port = String.to_integer(System.get_env("PORT") || "4002")

config :live_vue, ssr: false

config :jido_code, :knowledge_store, enabled: false
config :jido_code, :hypermedia_qualification_build, true

config :jido_code, :product_auth,
  credential_digest: :crypto.hash(:sha256, "test-operator-token"),
  session_ttl_seconds: 3_600,
  session_generation: "test-1"

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
