import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :trivia_advisor, TriviaAdvisorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "urtjtIlJprIfZLgZaA0VMRjFIO8Gu6Wf7x6p03QLpOG9YEV4+TrGKc4hI+B2PJzD",
  server: false

# =============================================================================
# Test Database Configuration
# =============================================================================
#
# In test environment, we connect to the same local eventasaurus_dev database
# that development uses. Since this is a read-only application, we don't need
# Ecto sandbox mode for transaction isolation - we're just reading data.
#
# PlanetScale is only used in production (configured in runtime.exs).

config :trivia_advisor, TriviaAdvisor.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "eventasaurus_dev",
  pool_size: 5

# In test we don't send emails
config :trivia_advisor, TriviaAdvisor.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
