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
  Format entry fee in cents to display string.

  ## Examples

      iex> PublicEvent.format_entry_fee(0)
      "Free"

      iex> PublicEvent.format_entry_fee(500)
      "$5.00"

      iex> PublicEvent.format_entry_fee(nil)
      "Check website"
  """
  def format_entry_fee(0), do: "Free"
  def format_entry_fee(nil), do: "Check website"
  def format_entry_fee(cents) when is_integer(cents) do
    dollars = cents / 100
    "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end

  @doc """
  Format start time based on country code (localized time format).

  ## Examples

      iex> PublicEvent.format_time(~T[19:00:00], "US")
      "7:00 PM"

      iex> PublicEvent.format_time(~T[19:00:00], "GB")
      "19:00"
  """
  def format_time(nil, _country_code), do: "Time TBD"
  def format_time(time, "US"), do: Calendar.strftime(time, "%I:%M %p")  # 7:00 PM
  def format_time(time, _country_code), do: Calendar.strftime(time, "%H:%M")  # 19:00
end
