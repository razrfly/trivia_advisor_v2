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
    PublicEvent.format_entry_fee(event.entry_fee_cents)
  end

  @doc """
  Gets the next occurrence of a recurring event.

  Note: This is a stub function for V2. Returns nil to gracefully hide
  the "Next Quiz Night" feature. Future implementation would calculate
  next occurrence based on day_of_week, start_time, and frequency fields.

  ## Examples

      iex> get_next_occurrence(%PublicEvent{})
      nil
  """
  def get_next_occurrence(_event), do: nil

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
