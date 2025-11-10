defmodule TriviaAdvisor.Locations.Venue do
  @moduledoc """
  Ecto schema for the venues table in Eventasaurus database.
  Read-only schema with JSONB metadata and image enrichment.
  """
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: false}
  schema "venues" do
    field :name, :string
    field :normalized_name, :string
    field :slug, :string
    field :address, :string
    field :latitude, :float
    field :longitude, :float
    field :venue_type, :string
    field :source, :string

    # JSONB fields
    field :metadata, :map
    field :geocoding_performance, :map
    field :provider_ids, :map
    field :venue_images, {:array, :map}
    field :image_enrichment_metadata, :map

    timestamps(type: :naive_datetime)

    # Associations
    belongs_to :city, TriviaAdvisor.Locations.City
    has_many :public_events, TriviaAdvisor.Events.PublicEvent
  end

  @doc """
  Generates a PostGIS point from latitude and longitude.
  """
  def to_geo_point(%__MODULE__{latitude: lat, longitude: lon})
      when not is_nil(lat) and not is_nil(lon) do
    %Geo.Point{
      coordinates: {lon, lat},
      srid: 4326
    }
  end

  def to_geo_point(_), do: nil

  @doc """
  Extracts primary image from venue_images JSONB array.
  Returns the first image with highest quality_score or first image.
  """
  def primary_image(%__MODULE__{venue_images: images}) when is_list(images) and length(images) > 0 do
    images
    |> Enum.sort_by(& Map.get(&1, "quality_score", 0), :desc)
    |> List.first()
  end

  def primary_image(_), do: nil

  @doc """
  Extracts district/neighborhood from venue metadata.
  Checks geocoding metadata for district field from geocoding providers.
  """
  def district(%__MODULE__{metadata: metadata}) when is_map(metadata) do
    metadata
    |> get_in(["geocoding", "raw_response", "district"])
    |> case do
      nil -> get_in(metadata, ["geocoding_metadata", "raw_response", "district"])
      district -> district
    end
  end

  def district(_), do: nil
end
