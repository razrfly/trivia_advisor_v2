defmodule TriviaAdvisor.Events.PublicEvent do
  @moduledoc """
  Ecto schema for the trivia_events_export VIEW in Eventasaurus database.
  Read-only schema consuming curated trivia events from trusted sources.

  The view filters to:
  - 6 trusted trivia sources (question-one, quizmeisters, inquizition, etc.)
  - Events with pattern data (occurrences.pattern)
  - Primary trivia category only

  This gives us 2,696 high-quality trivia events with 38 pre-flattened fields.
  All event details are extracted from JSONB and provided as regular columns.

  Reference: https://github.com/razrfly/eventasaurus/issues/2203
  """
  use Ecto.Schema

  alias TriviaAdvisorWeb.Helpers.{LocalizationHelpers, CurrencyHelpers}

  @primary_key {:id, :id, autogenerate: false}
  schema "trivia_events_export" do
    # Event details (all flat, pre-extracted from occurrences.pattern)
    field :name, :string                    # Event name/title
    field :day_of_week, :integer            # 1=Monday, 2=Tuesday, ..., 7=Sunday
    field :start_time, :time                # Event start time (e.g., 19:00:00)
    field :timezone, :string                # Timezone (e.g., "America/New_York")
    field :frequency, :string               # "weekly", "biweekly", "monthly"
    field :entry_fee_cents, :integer        # 0 = free, otherwise price in cents
    field :description, :string             # Event description (localized to EN)
    field :hero_image, :string              # Event or venue image URL

    # Event relationships
    field :performer_id, :integer           # Host/performer ID (if applicable)

    # Source attribution (for "Updated X days ago • Source: Y")
    field :source_id, :integer
    field :source_name, :string             # e.g., "QuizMeisters"
    field :source_slug, :string
    field :source_logo_url, :string         # Source branding logo
    field :source_website_url, :string      # Source website
    field :source_url, :string              # Event URL on source site
    field :activity_slug, :string           # Wombie.com activity slug for URL construction
    field :last_seen_at, :naive_datetime    # When scraper last saw this event

    # Venue information (all flat, denormalized from venues table)
    field :venue_id, :integer
    field :venue_name, :string
    field :venue_slug, :string
    field :venue_address, :string
    field :venue_latitude, :decimal         # For distance calculations
    field :venue_longitude, :decimal        # For distance calculations
    field :venue_postcode, :string          # Postal code
    field :venue_place_id, :string          # Google Place ID
    field :venue_metadata, :map             # Additional venue metadata (JSONB object)
    field :venue_images, {:array, :map}     # Venue images array (JSONB array)

    # City information (for grouping/filtering, distance calculations)
    field :city_id, :integer
    field :city_slug, :string
    field :city_name, :string
    field :city_latitude, :decimal          # City center for radius searches
    field :city_longitude, :decimal         # City center for radius searches
    field :city_images, :map                # Unsplash gallery object with categories (JSONB object)

    # Country information (for localization, time formatting)
    field :country_id, :integer
    field :country_name, :string
    field :country_code, :string            # ISO code (e.g., "US", "GB")

    # Timestamps
    field :inserted_at, :naive_datetime
    field :updated_at, :naive_datetime
  end

  @doc """
  Format day of week integer to readable name.

  ## Examples

      iex> PublicEvent.format_day_name(1)
      "Monday"

      iex> PublicEvent.format_day_name(5)
      "Friday"
  """
  def format_day_name(1), do: "Monday"
  def format_day_name(2), do: "Tuesday"
  def format_day_name(3), do: "Wednesday"
  def format_day_name(4), do: "Thursday"
  def format_day_name(5), do: "Friday"
  def format_day_name(6), do: "Saturday"
  def format_day_name(7), do: "Sunday"
  def format_day_name(_), do: "Unknown"

  @doc """
  Format entry fee in cents to display string with proper currency symbol.

  ## Examples

      iex> PublicEvent.format_entry_fee(0, "USD")
      "Free"

      iex> PublicEvent.format_entry_fee(500, "GBP")
      "£5.00"

      iex> PublicEvent.format_entry_fee(nil, "USD")
      "Check website"
  """
  def format_entry_fee(0, _currency_code), do: "Free"
  def format_entry_fee(nil, _currency_code), do: "Check website"
  def format_entry_fee(cents, currency_code) when is_integer(cents) and is_binary(currency_code) do
    CurrencyHelpers.format_currency(cents, currency_code)
  end

  # Fallback for when currency_code is not provided (backwards compatibility)
  def format_entry_fee(cents, _) when is_integer(cents) do
    CurrencyHelpers.format_currency(cents, "USD")
  end

  @doc """
  Format start time based on country (localized time format).
  Uses CLDR to automatically determine 12-hour vs 24-hour format.

  ## Examples

      iex> PublicEvent.format_time(~T[19:00:00], %{code: "US"})
      "7:00 PM"

      iex> PublicEvent.format_time(~T[18:30:00], %{code: "GB"})
      "6:30 PM"

      iex> PublicEvent.format_time(~T[18:30:00], %{code: "DE"})
      "18:30"
  """
  def format_time(nil, _country), do: "Time TBD"
  def format_time(time, country) when is_map(country) do
    LocalizationHelpers.format_localized_time(time, country)
  end

  # Fallback for when country is just a code string (backwards compatibility)
  def format_time(time, country_code) when is_binary(country_code) do
    country = %{code: country_code}
    LocalizationHelpers.format_localized_time(time, country)
  end
end
