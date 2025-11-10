defmodule TriviaAdvisorWeb.JsonLd.CitySchema do
  @moduledoc """
  Generates JSON-LD structured data for city pages according to schema.org and Google guidelines.

  This module converts city data into properly formatted structured data
  for better SEO and Google rich results.

  ## Schema.org Types
  - schema.org/City
  - schema.org/Place

  ## References
  - Schema.org Place: https://schema.org/Place
  - Schema.org City: https://schema.org/City
  - Google Rich Results: https://developers.google.com/search/docs/appearance/structured-data
  """

  alias TriviaAdvisorWeb.Helpers.SEOHelpers

  @doc """
  Generates JSON-LD structured data for a city page.

  ## Parameters
    - city: City struct with preloaded :country association
    - stats: Map containing aggregated statistics:
      - venue_count: Number of trivia venues in the city (optional)

  ## Returns
    - JSON-LD string ready to be included in <script type="application/ld+json">

  ## Example
      iex> city = Locations.get_city_by_slug!(country_slug, city_slug)
      iex> stats = %{venue_count: 42}
      iex> TriviaAdvisorWeb.JsonLd.CitySchema.generate(city, stats)
      "{\"@context\":\"https://schema.org\",\"@type\":\"City\",...}"
  """
  def generate(city, stats \\ %{}) do
    city
    |> build_city_schema(stats)
    |> Jason.encode!()
  end

  @doc """
  Builds the city schema map (without JSON encoding).
  Useful for testing or combining with other schemas.
  """
  def build_city_schema(city, stats \\ %{}) do
    base_url = SEOHelpers.get_base_url()

    url = if city.country do
      "#{base_url}/#{city.country.slug}/#{city.slug}"
    else
      "#{base_url}/cities/#{city.slug}"
    end

    %{
      "@context" => "https://schema.org",
      "@type" => "City",
      "name" => city.name,
      "url" => url,
      "description" => build_description(city, stats)
    }
    |> add_geo_coordinates(city)
    |> add_contained_in_place(city)
    |> add_additional_properties(stats)
  end

  # Build a compelling description for the city
  defp build_description(city, stats) do
    venue_count = Map.get(stats, :venue_count, 0)
    country_name = if city.country, do: city.country.name, else: ""

    cond do
      venue_count > 0 and country_name != "" ->
        "Discover #{venue_count} trivia venues in #{city.name}, #{country_name}. Find trivia nights, pub quizzes, and quiz events happening in the city."

      venue_count > 0 ->
        "Discover #{venue_count} trivia venues in #{city.name}. Find trivia nights, pub quizzes, and quiz events happening in the city."

      country_name != "" ->
        "Discover trivia venues in #{city.name}, #{country_name}. Find trivia nights, pub quizzes, and quiz events happening in the city."

      true ->
        "Discover trivia venues in #{city.name}. Find trivia nights, pub quizzes, and quiz events happening in the city."
    end
  end

  # Add geo coordinates if available
  defp add_geo_coordinates(schema, city) do
    if city.latitude && city.longitude do
      # Convert Decimal to float for JSON compatibility
      lat = if is_float(city.latitude), do: city.latitude, else: Decimal.to_float(city.latitude)
      lng = if is_float(city.longitude), do: city.longitude, else: Decimal.to_float(city.longitude)

      Map.put(schema, "geo", %{
        "@type" => "GeoCoordinates",
        "latitude" => lat,
        "longitude" => lng
      })
    else
      schema
    end
  end

  # Add country information
  defp add_contained_in_place(schema, city) do
    if city.country do
      Map.put(schema, "containedInPlace", %{
        "@type" => "Country",
        "name" => city.country.name
      })
    else
      schema
    end
  end

  # Add additional structured data properties using AdditionalProperty
  # This is a flexible way to include custom stats without breaking schema.org compliance
  defp add_additional_properties(schema, stats) do
    venue_count = Map.get(stats, :venue_count, 0)

    # Only add if we have meaningful stats
    if venue_count > 0 do
      additional_properties = [
        %{
          "@type" => "PropertyValue",
          "name" => "Trivia Venues",
          "value" => venue_count
        }
      ]

      Map.put(schema, "additionalProperty", additional_properties)
    else
      schema
    end
  end
end
