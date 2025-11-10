defmodule TriviaAdvisorWeb.JsonLd.VenueSchema do
  @moduledoc """
  Generates JSON-LD structured data for venues as LocalBusiness according to schema.org.

  This module converts venue data into properly formatted structured data
  for better SEO and Google rich results for local business listings.

  ## Schema.org LocalBusiness
  - Schema.org LocalBusiness: https://schema.org/LocalBusiness
  - Google Local Business: https://developers.google.com/search/docs/appearance/structured-data/local-business

  ## Venue Type Mapping
  Uses "EntertainmentBusiness" for trivia venues (bars, pubs, entertainment spaces).
  """

  alias TriviaAdvisorWeb.Helpers.SEOHelpers

  @doc """
  Generates JSON-LD structured data for a venue as LocalBusiness.

  ## Parameters
    - venue: Venue struct with preloaded associations:
      - :city (with :country)

  ## Returns
    - JSON-LD string ready to be included in <script type="application/ld+json">

  ## Example
      iex> venue = Locations.get_venue_by_slug!(country_slug, city_slug, venue_slug)
      iex> TriviaAdvisorWeb.JsonLd.VenueSchema.generate(venue)
      "{\"@context\":\"https://schema.org\",\"@type\":\"EntertainmentBusiness\",...}"
  """
  def generate(venue) do
    venue
    |> build_business_schema()
    |> Jason.encode!()
  end

  @doc """
  Builds the local business schema map (without JSON encoding).
  Useful for testing or combining with other schemas.
  """
  def build_business_schema(venue) do
    %{
      "@context" => "https://schema.org",
      "@type" => "EntertainmentBusiness",
      "name" => venue.name,
      "address" => build_address(venue)
    }
    |> add_geo_coordinates(venue)
    |> add_url(venue)
    |> add_description(venue)
  end

  # Build the postal address according to schema.org
  defp build_address(venue) do
    address = %{
      "@type" => "PostalAddress"
    }

    address =
      if venue.address do
        Map.put(address, "streetAddress", venue.address)
      else
        address
      end

    address =
      if venue.city do
        address
        |> Map.put("addressLocality", venue.city.name)
        |> add_country_info(venue.city)
      else
        address
      end

    address
  end

  defp add_country_info(address, city) do
    if city.country do
      address
      |> Map.put("addressCountry", city.country.code)
    else
      address
    end
  end

  # Add geographic coordinates
  defp add_geo_coordinates(schema, venue) do
    if venue.latitude && venue.longitude do
      # Convert Decimal to float for JSON compatibility
      lat = if is_float(venue.latitude), do: venue.latitude, else: Decimal.to_float(venue.latitude)
      lng = if is_float(venue.longitude), do: venue.longitude, else: Decimal.to_float(venue.longitude)

      Map.put(schema, "geo", %{
        "@type" => "GeoCoordinates",
        "latitude" => lat,
        "longitude" => lng
      })
    else
      schema
    end
  end

  # Add venue URL (using slug to build the URL)
  defp add_url(schema, venue) do
    if venue.slug && venue.city && venue.city.country do
      base_url = SEOHelpers.get_base_url()
      venue_url = "#{base_url}/#{venue.city.country.slug}/#{venue.city.slug}/#{venue.slug}"
      Map.put(schema, "url", venue_url)
    else
      schema
    end
  end

  # Add venue description
  defp add_description(schema, venue) do
    description = build_description(venue)
    if description, do: Map.put(schema, "description", description), else: schema
  end

  defp build_description(venue) do
    cond do
      venue.city && venue.city.name ->
        "Trivia venue in #{venue.city.name}. Find trivia nights, pub quizzes, and quiz events at #{venue.name}."

      true ->
        "Trivia venue hosting trivia nights, pub quizzes, and quiz events."
    end
  end
end
