import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/trivia_advisor start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :trivia_advisor, TriviaAdvisorWeb.Endpoint, server: true
end

# =============================================================================
# Production Configuration
# =============================================================================
#
# In production, we connect to Fly Managed Postgres for the shared
# Eventasaurus database. Since Trivia Advisor is completely read-only,
# we use the pooled connection for efficient connection management.
#
# CRITICAL: Fly Managed Postgres requires special DNS and IPv6 configuration.
# See: https://fly.io/docs/postgres/

if config_env() == :prod do
  # Configure Erlang's inet resolver to use Fly's internal DNS server
  # This is required for Fly Managed Postgres .flympg.net domains
  # Erlang's built-in inet_res resolver doesn't read /etc/resolv.conf by default
  # and fails with nxdomain on Fly.io's internal DNS
  #
  # Fly's internal DNS server at fdaa::3 can resolve .flympg.net domains
  # Parse the IPv6 address into a tuple for :inet_db
  fly_dns_server = {0xFDAA, 0, 0, 0, 0, 0, 0, 3}

  # Configure Erlang's inet to use Fly's DNS server
  # This affects all DNS resolution including Postgrex hostname lookups
  :inet_db.set_lookup([:dns, :file, :native])
  :inet_db.add_ns(fly_dns_server)

  # Validate required environment variables
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      This should be the connection string for Fly Managed Postgres.
      """

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

  host = System.get_env("PHX_HOST") || "quizadvisor.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  # Production base URL for sitemap and SEO
  config :trivia_advisor,
    base_url: System.get_env("BASE_URL") || "https://#{host}"

  config :trivia_advisor, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Configure Fly Managed Postgres database connection
  #
  # Connection Architecture:
  # - DATABASE_URL: Connection string from Fly Managed Postgres
  # - Uses IPv6 for Fly internal network (.flympg.net resolves to IPv6)
  # - prepare: :unnamed for PgBouncer compatibility (if using pooler)
  config :trivia_advisor, TriviaAdvisor.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    queue_target: 5000,
    queue_interval: 30000,
    # Disable prepared statements for PgBouncer Transaction mode compatibility
    prepare: :unnamed,
    # Force IPv6 for Fly.io internal network (.flympg.net resolves to IPv6)
    socket_options: [:inet6]

  config :trivia_advisor, TriviaAdvisorWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    # Allow WebSocket connections from the configured host and www subdomain
    # This is critical for LiveView to work - without it, the WebSocket upgrade
    # fails silently and pages appear to never finish loading
    # Using protocol-agnostic format (//) to handle both HTTP and HTTPS
    # This is important because some proxies may send HTTP origin headers
    check_origin: [
      "//#{host}",
      "//www.#{host}"
    ]

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :trivia_advisor, TriviaAdvisorWeb.Endpoint,
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
  #     config :trivia_advisor, TriviaAdvisorWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :trivia_advisor, TriviaAdvisor.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
