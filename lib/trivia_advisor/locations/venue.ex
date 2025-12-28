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
  Gets the primary image URL for a venue from the cached_images table.
  Returns an image map with "url" key, or nil if no cached image exists.
  """
  def primary_image(%__MODULE__{slug: slug} = _venue) when is_binary(slug) do
    case TriviaAdvisor.CachedImages.get_venue_image_url(slug, 0) do
      url when is_binary(url) ->
        %{"url" => url}

      nil ->
        nil
    end
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
