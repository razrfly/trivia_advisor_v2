defmodule TriviaAdvisor.Events.PublicEvent do
  @moduledoc """
  Ecto schema for the trivia_events_export VIEW in Eventasaurus database.
  Read-only schema consuming curated trivia events from trusted sources.

  The view filters to:
  - 6 trusted trivia sources (question-one, quizmeisters, inquizition, etc.)
  - Events with pattern data (occurrences.pattern)
  - Primary trivia category only

  This gives us 2,696 high-quality trivia events.
  """
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: false}
  schema "trivia_events_export" do
    field :title, :string
    field :slug, :string
    field :starts_at, :naive_datetime
    field :ends_at, :naive_datetime
    field :title_translations, :map
    field :occurrences, :map

    field :inserted_at, :naive_datetime
    field :updated_at, :naive_datetime

    # Denormalized venue fields from view
    field :venue_id, :integer
    field :venue_name, :string
    field :venue_slug, :string
    field :venue_address, :string
    field :venue_latitude, :decimal
    field :venue_longitude, :decimal

    # Denormalized city fields from view
    field :city_id, :integer
    field :city_name, :string
    field :city_slug, :string

    # Denormalized country fields from view
    field :country_id, :integer
    field :country_name, :string
    field :country_slug, :string

    # Source info from view
    field :source_id, :integer
    field :source_slug, :string
    field :source_name, :string
    field :source_url, :string
  end

  @doc """
  Returns upcoming occurrences from the occurrences JSONB field.
  Handles both V2 format (map with "dates" array) and legacy array format.
  """
  def upcoming_occurrences(%__MODULE__{occurrences: %{"dates" => dates}}) when is_list(dates) do
    today = Date.utc_today()

    dates
    |> Enum.filter(fn occ ->
      case Date.from_iso8601(occ["date"]) do
        {:ok, date} -> Date.compare(date, today) != :lt
        _ -> false
      end
    end)
    |> Enum.sort_by(& &1["date"])
  end

  def upcoming_occurrences(%__MODULE__{occurrences: occurrences}) when is_list(occurrences) do
    # Legacy format fallback
    today = Date.utc_today()

    occurrences
    |> Enum.filter(fn occ ->
      case Date.from_iso8601(occ["date"]) do
        {:ok, date} -> Date.compare(date, today) != :lt
        _ -> false
      end
    end)
    |> Enum.sort_by(& &1["date"])
  end

  def upcoming_occurrences(_), do: []
end
