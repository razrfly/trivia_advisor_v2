defmodule TriviaAdvisor.Locations.Country do
  @moduledoc """
  Ecto schema for the countries table in Eventasaurus database.
  Read-only schema - no changesets or validations needed.
  """
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: false}
  schema "countries" do
    field :name, :string
    field :slug, :string
    field :code, :string

    timestamps(type: :naive_datetime)

    # Associations
    has_many :cities, TriviaAdvisor.Locations.City
  end
end
