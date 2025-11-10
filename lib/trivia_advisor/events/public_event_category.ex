defmodule TriviaAdvisor.Events.PublicEventCategory do
  @moduledoc """
  Ecto schema for the public_event_categories join table.
  Links events to categories with confidence scoring.
  """
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: false}
  schema "public_event_categories" do
    field :is_primary, :boolean
    field :source, :string
    field :confidence, :float

    belongs_to :public_event, TriviaAdvisor.Events.PublicEvent, foreign_key: :event_id
    belongs_to :category, TriviaAdvisor.Events.Category

    field :inserted_at, :naive_datetime
  end
end
