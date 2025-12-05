defmodule TriviaAdvisor.Repo do
  @moduledoc """
  Read-only Ecto Repo for Trivia Advisor.

  This application is completely read-only - all data comes from the
  Eventasaurus database.

  ## Configuration

  In production (runtime.exs):
  - Uses hostname-based config (NOT URL-based) for proper SSL handling
  - Connects to PlanetScale via PgBouncer (port 6432)
  - SSL verification using CAStore

  In development (dev.exs):
  - Connects to local eventasaurus_dev database (same as Eventasaurus)
  - No SSL required for local development

  ## Why Read-Only?

  This application only displays trivia event data from the shared
  Eventasaurus database. All writes happen in the main Eventasaurus
  application.
  """

  use Ecto.Repo,
    otp_app: :trivia_advisor,
    adapter: Ecto.Adapters.Postgres,
    read_only: true
end
