defmodule TriviaAdvisor.Events.PublicEventSource do
  @moduledoc """
  Ecto schema for the public_event_sources table in Eventasaurus database.
  Tracks the source of event data (website, API, manual entry, etc.).
  Read-only schema.
  """
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: false}
  schema "public_event_sources" do
    field :source_type, :string
    field :source_url, :string
    field :source_identifier, :string
    field :last_scraped_at, :utc_datetime

    timestamps(type: :utc_datetime)

    # Associations
    belongs_to :public_event, TriviaAdvisor.Events.PublicEvent
  end
end
