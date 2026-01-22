defmodule TriviaAdvisor.Repo do
  @moduledoc """
  Read-only Ecto Repo for Trivia Advisor.

  This application is completely read-only - all data comes from the
  Eventasaurus database.

  ## Configuration

  In production (runtime.exs):
  - Connects to Fly Managed Postgres using DATABASE_URL
  - Uses IPv6 for Fly.io internal network (.flympg.net domains)
  - PgBouncer compatibility with `prepare: :unnamed`

  In development (dev.exs):
  - Supports DATABASE_URL from .env file
  - Falls back to local eventasaurus_dev database if no DATABASE_URL
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
