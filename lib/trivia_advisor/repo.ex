defmodule TriviaAdvisor.Repo do
  @moduledoc """
  Read-only Ecto Repo for Trivia Advisor.

  Connects to PlanetScale read replicas using the |replica username suffix.
  This application is completely read-only - all data comes from the
  Eventasaurus database.

  ## Configuration

  In production (runtime.exs):
  - Uses hostname-based config (NOT URL-based) for proper SSL handling
  - Connects to PlanetScale replicas via |replica username suffix
  - Uses direct connection (port 5432) for replica routing

  In development (dev.exs):
  - Also connects to PlanetScale replicas (shared database)
  - Same SSL configuration as production

  ## Why Read-Only?

  This application only displays trivia event data from the shared
  Eventasaurus database. All writes happen in the main Eventasaurus
  application. Using read replicas:
  - Reduces load on the primary database
  - Provides better read performance
  - Acceptable replication lag for display purposes
  """

  use Ecto.Repo,
    otp_app: :trivia_advisor,
    adapter: Ecto.Adapters.Postgres,
    read_only: true
end
