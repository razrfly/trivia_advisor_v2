defmodule TriviaAdvisor.Events do
  @moduledoc """
  Context module for event-related queries (PublicEvents, Sources, Performers).
  All queries are read-only against the Eventasaurus database.

  Note: Events in Eventasaurus use an `occurrences` JSONB field to store
  recurring schedules, which is a different model from V1.
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
        order_by: e.title
    )
  end

  @doc """
  Gets trivia events with upcoming occurrences from trivia_events_export view.
  Filters events where at least one occurrence is today or later.

  ## Examples

      iex> get_upcoming_events(limit: 20)
      [%PublicEvent{}, ...]
  """
  def get_upcoming_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    today = Date.utc_today()

    query =
      from e in PublicEvent,
        where: fragment(
          "EXISTS (SELECT 1 FROM jsonb_array_elements(?->'dates') AS occ WHERE (occ->>'date')::date >= ?)",
          e.occurrences,
          ^today
        ),
        order_by: e.title,
        limit: ^limit

    Repo.all(query)
  end

  @doc """
  Gets trivia events for a specific date from trivia_events_export view.
  Searches the occurrences JSONB array for matching dates.

  ## Examples

      iex> get_events_for_date(~D[2025-01-15])
      [%PublicEvent{}, ...]
  """
  def get_events_for_date(%Date{} = date) do
    date_string = Date.to_iso8601(date)

    query =
      from e in PublicEvent,
        where: fragment(
          "EXISTS (SELECT 1 FROM jsonb_array_elements(?->'dates') AS occ WHERE occ->>'date' = ?)",
          e.occurrences,
          ^date_string
        ),
        order_by: e.title

    Repo.all(query)
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
        order_by: e.title,
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
  # Occurrence Helper Functions
  # ============================================================================

  @doc """
  Extracts upcoming occurrences from an event's occurrences JSONB field.
  Returns a list of occurrence maps sorted by date.

  ## Examples

      iex> get_upcoming_occurrences(%PublicEvent{occurrences: [...]})
      [%{"date" => "2025-01-15", "start_time" => "19:00", ...}, ...]
  """
  def get_upcoming_occurrences(%PublicEvent{} = event) do
    PublicEvent.upcoming_occurrences(event)
  end

  @doc """
  Gets the next occurrence for an event.

  ## Examples

      iex> get_next_occurrence(%PublicEvent{occurrences: [...]})
      %{"date" => "2025-01-15", "start_time" => "19:00", ...}

      iex> get_next_occurrence(%PublicEvent{occurrences: []})
      nil
  """
  def get_next_occurrence(%PublicEvent{} = event) do
    event
    |> get_upcoming_occurrences()
    |> List.first()
  end

  @doc """
  Checks if an event has occurrences on a specific weekday.
  Weekday: 1 = Monday, 7 = Sunday (ISO 8601).

  ## Examples

      iex> has_occurrences_on_weekday?(%PublicEvent{}, 3)
      true
  """
  def has_occurrences_on_weekday?(%PublicEvent{occurrences: occurrences}, weekday)
      when is_list(occurrences) and weekday in 1..7 do
    Enum.any?(occurrences, fn occ ->
      case Date.from_iso8601(occ["date"]) do
        {:ok, date} -> Date.day_of_week(date) == weekday
        _ -> false
      end
    end)
  end

  def has_occurrences_on_weekday?(_, _), do: false

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
