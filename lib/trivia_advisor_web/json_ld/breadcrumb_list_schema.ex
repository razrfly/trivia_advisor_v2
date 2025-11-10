defmodule TriviaAdvisorWeb.JsonLd.BreadcrumbListSchema do
  @moduledoc """
  Generates JSON-LD structured data for breadcrumb navigation according to schema.org.

  This module creates properly formatted breadcrumb structured data
  for better SEO and Google search result appearance.

  ## Schema.org BreadcrumbList
  - Schema.org BreadcrumbList: https://schema.org/BreadcrumbList
  - Google Breadcrumbs: https://developers.google.com/search/docs/appearance/structured-data/breadcrumb

  ## Breadcrumb Items
  Each breadcrumb is represented as a ListItem with:
  - position: Integer position in the list (1-indexed)
  - name: Display name of the page
  - item: Full URL to the page
  """

  @doc """
  Generates JSON-LD structured data for breadcrumb navigation.

  ## Parameters
    - breadcrumbs: List of maps with :name and :url keys
      Example: [
        %{name: "Home", url: "https://quizadvisor.com"},
        %{name: "United States", url: "https://quizadvisor.com/united-states"},
        %{name: "Austin", url: "https://quizadvisor.com/united-states/austin"}
      ]

  ## Returns
    - JSON-LD string ready to be included in <script type="application/ld+json">

  ## Example
      iex> breadcrumbs = [
      ...>   %{name: "Home", url: "https://quizadvisor.com"},
      ...>   %{name: "United States", url: "https://quizadvisor.com/united-states"},
      ...>   %{name: "Austin", url: "https://quizadvisor.com/united-states/austin"}
      ...> ]
      iex> TriviaAdvisorWeb.JsonLd.BreadcrumbListSchema.generate(breadcrumbs)
      "{\"@context\":\"https://schema.org\",\"@type\":\"BreadcrumbList\",...}"
  """
  def generate(breadcrumbs) when is_list(breadcrumbs) do
    breadcrumbs
    |> build_breadcrumb_schema()
    |> Jason.encode!()
  end

  @doc """
  Builds the breadcrumb schema map (without JSON encoding).
  Useful for testing or combining with other schemas.
  """
  def build_breadcrumb_schema(breadcrumbs) when is_list(breadcrumbs) do
    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => build_breadcrumb_items(breadcrumbs)
    }
  end

  # Build the list of breadcrumb items
  defp build_breadcrumb_items(breadcrumbs) do
    breadcrumbs
    |> Enum.with_index(1)
    |> Enum.map(fn {breadcrumb, position} ->
      %{
        "@type" => "ListItem",
        "position" => position,
        "name" => breadcrumb.name,
        "item" => breadcrumb.url
      }
    end)
  end

  @doc """
  Helper function to build breadcrumbs for a venue page.

  ## Parameters
    - venue: Venue struct with preloaded :city (with :country)
    - base_url: Base URL of the application (e.g., "https://quizadvisor.com")

  ## Returns
    - List of breadcrumb maps suitable for generate/1

  ## Example
      iex> breadcrumbs = BreadcrumbListSchema.build_venue_breadcrumbs(venue, base_url)
      iex> BreadcrumbListSchema.generate(breadcrumbs)
  """
  def build_venue_breadcrumbs(venue, base_url) do
    breadcrumbs = [
      %{name: "Home", url: base_url}
    ]

    breadcrumbs =
      if venue.city && venue.city.country do
        country = venue.city.country
        city = venue.city

        breadcrumbs ++
          [
            %{name: country.name, url: "#{base_url}/#{country.slug}"},
            %{name: city.name, url: "#{base_url}/#{country.slug}/#{city.slug}"}
          ]
      else
        breadcrumbs
      end

    breadcrumbs ++
      [%{name: venue.name, url: "#{base_url}/#{venue.city.country.slug}/#{venue.city.slug}/#{venue.slug}"}]
  end

  @doc """
  Helper function to build breadcrumbs for a city page.

  ## Parameters
    - city: City struct with preloaded :country
    - base_url: Base URL of the application (e.g., "https://quizadvisor.com")

  ## Returns
    - List of breadcrumb maps suitable for generate/1
  """
  def build_city_breadcrumbs(city, base_url) do
    breadcrumbs = [
      %{name: "Home", url: base_url}
    ]

    breadcrumbs =
      if city.country do
        breadcrumbs ++
          [%{name: city.country.name, url: "#{base_url}/#{city.country.slug}"}]
      else
        breadcrumbs
      end

    breadcrumbs ++
      [%{name: city.name, url: "#{base_url}/#{city.country.slug}/#{city.slug}"}]
  end

  @doc """
  Helper function to build breadcrumbs for a country page.

  ## Parameters
    - country: Country struct
    - base_url: Base URL of the application (e.g., "https://quizadvisor.com")

  ## Returns
    - List of breadcrumb maps suitable for generate/1
  """
  def build_country_breadcrumbs(country, base_url) do
    [
      %{name: "Home", url: base_url},
      %{name: country.name, url: "#{base_url}/#{country.slug}"}
    ]
  end
end
