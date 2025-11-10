defmodule TriviaAdvisor.Events.PublicEventPerformer do
  @moduledoc """
  Ecto schema for the public_event_performers table in Eventasaurus database.
  Represents hosts, quiz masters, or performers for events.
  Read-only schema.
  """
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: false}
  schema "public_event_performers" do
    field :name, :string
    field :role, :string
    field :bio, :string
    field :profile_url, :string

    timestamps(type: :utc_datetime)

    # Associations
    belongs_to :public_event, TriviaAdvisor.Events.PublicEvent
  end
end
