defmodule TriviaAdvisor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TriviaAdvisorWeb.Telemetry,
      TriviaAdvisor.Repo,
      {DNSCluster, query: Application.get_env(:trivia_advisor, :dns_cluster_query) || :ignore},
      # ConCache for query result caching with 24-hour TTL
      # Rationale: trivia_events_export materialized view refreshes daily at 5 AM UTC
      # See: https://github.com/razrfly/eventasaurus/issues/3026
      Supervisor.child_spec(
        {ConCache, [
          name: :city_cache,
          ttl_check_interval: :timer.minutes(5),
          global_ttl: :timer.hours(24)
        ]},
        id: :city_cache
      ),
      # ConCache for sitemap caching with 24-hour TTL (matches data refresh cycle)
      Supervisor.child_spec(
        {ConCache, [
          name: :sitemap_cache,
          ttl_check_interval: :timer.minutes(5),
          global_ttl: :timer.hours(24)
        ]},
        id: :sitemap_cache
      ),
      {Phoenix.PubSub, name: TriviaAdvisor.PubSub},
      # Start a worker by calling: TriviaAdvisor.Worker.start_link(arg)
      # {TriviaAdvisor.Worker, arg},
      # Start to serve requests, typically the last entry
      TriviaAdvisorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TriviaAdvisor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TriviaAdvisorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
