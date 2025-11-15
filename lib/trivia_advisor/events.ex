defmodule TriviaAdvisor.Events do
  @moduledoc """
  Context module for event-related queries (PublicEvents, Sources, Performers).
  All queries are read-only against the Eventasaurus database.

  Note: Events in trivia_events_export view represent recurring patterns
  (e.g., "Trivia every Wednesday at 7pm") with flat fields like day_of_week,
  start_time, frequency. No JSONB parsing needed.

  Reference: https://github.com/razrfly/eventasaurus/issues/2203
  """

  import Ecto.Query, warn: false
  alias TriviaAdvisor.Repo
  alias TriviaAdvisor.Events.{PublicEvent, PublicEventSource, PublicEventPerformer}

  # ============================================================================
  # PublicEvent Queries
  # ============================================================================

  @doc """
  Gets all trivia events for a venue from the trivia_events_export view.

  ## Examples

      iex> get_events_for_venue(123)
      [%PublicEvent{}, ...]

      iex> get_events_for_venue(999)
      []
  """
  def get_events_for_venue(venue_id) when is_integer(venue_id) do
    Repo.all(
      from e in PublicEvent,
        where: e.venue_id == ^venue_id,
        order_by: e.name
    )
  end

  @doc """
  Gets trivia events for a specific day of the week.
  Day: 1 = Monday, 2 = Tuesday, ..., 7 = Sunday (ISO 8601).

  ## Examples

      iex> get_events_for_weekday(3)  # Wednesday
      [%PublicEvent{}, ...]
  """
  def get_events_for_weekday(weekday, opts \\ []) when weekday in 1..7 do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from e in PublicEvent,
        where: e.day_of_week == ^weekday,
        order_by: e.name,
        limit: ^limit
    )
  end

  @doc """
  Gets trivia events from trivia_events_export view.
  The view already filters to trivia-only, so type parameter is ignored.

  ## Examples

      iex> get_events_by_type("trivia")
      [%PublicEvent{}, ...]
  """
  def get_events_by_type(_event_type, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from e in PublicEvent,
        order_by: e.name,
        limit: ^limit
    )
  end

  @doc """
  Gets a single trivia event by ID from trivia_events_export view.
  Returns nil if the event is not in the view.

  ## Examples

      iex> get_event(123)
      %PublicEvent{}

      iex> get_event(999)
      nil
  """
  def get_event(id) when is_integer(id) do
    Repo.one(
      from e in PublicEvent,
        where: e.id == ^id
    )
  end

  # ============================================================================
  # Event Pattern Helper Functions
  # ============================================================================

  @doc """
  Checks if an event occurs on a specific weekday.
  Weekday: 1 = Monday, 7 = Sunday (ISO 8601).

  ## Examples

      iex> event_on_weekday?(%PublicEvent{day_of_week: 3}, 3)
      true

      iex> event_on_weekday?(%PublicEvent{day_of_week: 5}, 3)
      false
  """
  def event_on_weekday?(%PublicEvent{day_of_week: day}, weekday)
      when is_integer(day) and weekday in 1..7 do
    day == weekday
  end

  def event_on_weekday?(_, _), do: false

  @doc """
  Formats an event's time for display based on country code.

  ## Examples

      iex> format_event_time(%PublicEvent{start_time: ~T[19:00:00], country_code: "US"})
      "7:00 PM"

      iex> format_event_time(%PublicEvent{start_time: ~T[19:00:00], country_code: "GB"})
      "19:00"
  """
  def format_event_time(%PublicEvent{} = event) do
    PublicEvent.format_time(event.start_time, event.country_code)
  end

  @doc """
  Formats an event's entry fee for display.

  ## Examples

      iex> format_event_fee(%PublicEvent{entry_fee_cents: 0})
      "Free"

      iex> format_event_fee(%PublicEvent{entry_fee_cents: 500})
      "$5.00"
  """
  def format_event_fee(%PublicEvent{} = event) do
    # Get currency code from country_code using Countries library
    currency_code = case Countries.get(event.country_code) do
      %{currency_code: code} when is_binary(code) -> code
      _ -> "USD"  # Default fallback
    end

    PublicEvent.format_entry_fee(event.entry_fee_cents, currency_code)
  end

  @doc """
  Gets the next occurrence of a recurring event.

  Currently only supports weekly events. Returns a map with formatted date
  and localized time, or nil if the event is not weekly or data is incomplete.

  ## Examples

      iex> event = %PublicEvent{frequency: "weekly", day_of_week: 7, start_time: ~T[19:30:00], country_code: "GB"}
      iex> get_next_occurrence(event)
      %{"date" => "Sunday, Nov 16", "start_time" => "7:30 PM"}

      iex> get_next_occurrence(%PublicEvent{frequency: "biweekly"})
      nil
  """
  def get_next_occurrence(%PublicEvent{
        frequency: "weekly",
        day_of_week: day_of_week,
        start_time: start_time,
        country_code: country_code
      })
      when is_integer(day_of_week) and not is_nil(start_time) and not is_nil(country_code) do
    today = Date.utc_today()
    today_dow = Date.day_of_week(today)
    now_utc = DateTime.utc_now()

    # Calculate days until next occurrence
    # If event is today but time hasn't passed yet, use today (0 days)
    # Otherwise, calculate days forward
    diff = day_of_week - today_dow

    days_until_next =
      cond do
        # Event is later this week
        diff > 0 -> diff
        # Event is today - check if time has passed
        diff == 0 ->
          event_time_today = Time.compare(start_time, DateTime.to_time(now_utc))
          if event_time_today == :gt, do: 0, else: 7
        # Event was earlier this week - schedule for next week
        true -> diff + 7
      end

    next_date = Date.add(today, days_until_next)

    # Format the date (e.g., "Sunday, Nov 16")
    day_name = PublicEvent.format_day_name(day_of_week)
    month_name = format_month_short(next_date.month)
    formatted_date = "#{day_name}, #{month_name} #{next_date.day}"

    # Format the time using existing localization
    formatted_time = PublicEvent.format_time(start_time, country_code)

    %{
      "date" => formatted_date,
      "start_time" => formatted_time,
      "date_value" => next_date  # For proper chronological sorting
    }
  end

  # Biweekly and monthly not yet supported
  def get_next_occurrence(%PublicEvent{frequency: freq})
      when freq in ["biweekly", "monthly"],
      do: nil

  # Missing required fields
  def get_next_occurrence(_event), do: nil

  # Helper for month abbreviations
  defp format_month_short(1), do: "Jan"
  defp format_month_short(2), do: "Feb"
  defp format_month_short(3), do: "Mar"
  defp format_month_short(4), do: "Apr"
  defp format_month_short(5), do: "May"
  defp format_month_short(6), do: "Jun"
  defp format_month_short(7), do: "Jul"
  defp format_month_short(8), do: "Aug"
  defp format_month_short(9), do: "Sep"
  defp format_month_short(10), do: "Oct"
  defp format_month_short(11), do: "Nov"
  defp format_month_short(12), do: "Dec"

  @doc """
  Gets upcoming occurrences of a recurring event.

  Note: This is a stub function for V2. Returns nil to gracefully hide
  the "Upcoming Occurrences" feature. Future implementation would calculate
  upcoming dates based on day_of_week, start_time, and frequency fields.

  ## Examples

      iex> get_upcoming_occurrences(%PublicEvent{})
      nil
  """
  def get_upcoming_occurrences(_event), do: nil

  @doc """
  Gets nearby trivia venues with event details for a given venue.
  Returns venues within radius (default 5km) with one representative event per venue,
  including day_of_week for badges and images for display.

  Uses PostGIS spatial queries (ST_DWithin, ST_Distance) for accurate geographic calculations.
  Results are cached for 15 minutes to improve venue show page performance.

  ## Examples

      iex> get_nearby_trivia_venues(venue, 5)
      [%{venue: %Venue{}, event: %PublicEvent{}, distance_km: 2.5}, ...]
  """
  def get_nearby_trivia_venues(venue, radius_km \\ 5)

  def get_nearby_trivia_venues(venue, radius_km)
      when not is_nil(venue.latitude) and not is_nil(venue.longitude) do
    # Cache key includes venue ID and radius for deterministic results
    cache_key = "nearby_venues_#{venue.id}_#{radius_km}km"

    ConCache.get_or_store(:city_cache, cache_key, fn ->
      # Convert to float for PostGIS
      lat = if is_float(venue.latitude), do: venue.latitude, else: Float.parse("#{venue.latitude}") |> elem(0)
      lon = if is_float(venue.longitude), do: venue.longitude, else: Float.parse("#{venue.longitude}") |> elem(0)
      radius_meters = radius_km * 1000

      # Query trivia_events_export grouped by venue
      # Select one event per venue with venue and city data
      results = Repo.all(
        from e in PublicEvent,
          join: v in TriviaAdvisor.Locations.Venue, on: e.venue_id == v.id,
          join: c in TriviaAdvisor.Locations.City, on: v.city_id == c.id,
          join: co in TriviaAdvisor.Locations.Country, on: c.country_id == co.id,
          where: v.id != ^venue.id,
          where: not is_nil(v.latitude) and not is_nil(v.longitude),
          where:
            fragment(
              "ST_DWithin(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography, ?)",
              v.longitude,
              v.latitude,
              ^lon,
              ^lat,
              ^radius_meters
            ),
          group_by: [v.id, c.id, co.id],
          # Select first event for each venue (arbitrary but consistent)
          select: %{
            venue_id: v.id,
            venue_name: v.name,
            venue_slug: v.slug,
            venue_address: v.address,
            venue_latitude: v.latitude,
            venue_longitude: v.longitude,
            venue_images: v.venue_images,
            venue_type: v.venue_type,
            city_id: c.id,
            city_name: c.name,
            city_slug: c.slug,
            city_images: c.unsplash_gallery,
            country_name: co.name,
            # Take any event from this venue (using MIN to get consistent result)
            day_of_week: fragment("MIN(?)", e.day_of_week),
            distance_km:
              fragment(
                "ROUND(CAST(ST_Distance(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography) / 1000 AS NUMERIC), 1)",
                ^lon,
                ^lat,
                v.longitude,
                v.latitude
              )
          },
          order_by:
            fragment(
              "ST_Distance(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography)",
              v.longitude,
              v.latitude,
              ^lon,
              ^lat
            ),
          limit: 3
      )

      # Return list of maps
      results
    end)
  end

  def get_nearby_trivia_venues(_venue, _radius_km), do: []

  # ============================================================================
  # Event Source Queries
  # ============================================================================

  @doc """
  Gets sources for an event.
  """
  def get_event_sources(event_id) when is_integer(event_id) do
    Repo.all(
      from s in PublicEventSource,
        where: s.public_event_id == ^event_id,
        order_by: [desc: s.last_scraped_at]
    )
  end

  # ============================================================================
  # Event Performer Queries
  # ============================================================================

  @doc """
  Gets performers for an event.
  """
  def get_event_performers(event_id) when is_integer(event_id) do
    Repo.all(
      from p in PublicEventPerformer,
        where: p.public_event_id == ^event_id,
        order_by: p.name
    )
  end
end
