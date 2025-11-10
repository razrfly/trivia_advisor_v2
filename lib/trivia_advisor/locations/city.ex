defmodule TriviaAdvisor.Locations.City do
  @moduledoc """
  Ecto schema for the cities table in Eventasaurus database.
  Read-only schema with discovery configuration and image galleries.
  """
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: false}
  schema "cities" do
    field :name, :string
    field :slug, :string
    field :latitude, :decimal
    field :longitude, :decimal
    field :discovery_enabled, :boolean, default: false
    field :discovery_config, :map
    field :unsplash_gallery, :map
    field :alternate_names, {:array, :string}

    timestamps(type: :naive_datetime)

    # Associations
    belongs_to :country, TriviaAdvisor.Locations.Country
    has_many :venues, TriviaAdvisor.Locations.Venue
  end

  @doc """
  Generates a PostGIS point from latitude and longitude.
  """
  def to_geo_point(%__MODULE__{latitude: lat, longitude: lon})
      when not is_nil(lat) and not is_nil(lon) do
    %Geo.Point{
      coordinates: {Decimal.to_float(lon), Decimal.to_float(lat)},
      srid: 4326
    }
  end

  def to_geo_point(_), do: nil
end
