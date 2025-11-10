defmodule TriviaAdvisor.Sitemap do
  @moduledoc """
  Sitemap generation for Trivia Advisor.
  Generates XML sitemaps with flat URL structure for production URL matching.
  """

  alias TriviaAdvisor.{Locations, Repo}
  import Ecto.Query

  @doc """
  Generates the complete sitemap with all URLs.
  Returns a list of sitemap entries compatible with Sitemapper.
  """
  def generate do
    base_url = Application.get_env(:trivia_advisor, :base_url)

    static_urls(base_url) ++
      country_urls(base_url) ++
      city_urls(base_url) ++
      venue_urls(base_url)
  end

  @doc """
  Generates static page URLs.
  """
  def static_urls(base_url) do
    [
      # Home page
      %{
        loc: base_url,
        changefreq: "daily",
        priority: 1.0,
        lastmod: Date.utc_today()
      },
      # About page
      %{
        loc: "#{base_url}/about",
        changefreq: "monthly",
        priority: 0.8,
        lastmod: Date.utc_today()
      }
    ]
  end

  @doc """
  Generates country page URLs.
  """
  def country_urls(base_url) do
    Locations.list_countries()
    |> Enum.map(fn country ->
      %{
        loc: "#{base_url}/#{country.slug}",
        changefreq: "weekly",
        priority: 0.9,
        lastmod: country.updated_at |> NaiveDateTime.to_date()
      }
    end)
  end

  @doc """
  Generates city page URLs (flat structure with disambiguation: /cities/{slug} or /cities/{slug-country-slug}).
  """
  def city_urls(base_url) do
    query =
      from c in TriviaAdvisor.Locations.City,
        preload: [:country]

    Repo.all(query)
    |> Enum.map(fn city ->
      # Use the Locations.city_url_slug/1 function to handle disambiguation
      city_url_slug = Locations.city_url_slug(city)

      %{
        loc: "#{base_url}/cities/#{city_url_slug}",
        changefreq: "weekly",
        priority: 0.8,
        lastmod: city.updated_at |> NaiveDateTime.to_date()
      }
    end)
  end

  @doc """
  Generates venue page URLs (flat structure: /venues/{slug}).
  """
  def venue_urls(base_url) do
    query =
      from v in TriviaAdvisor.Locations.Venue,
        select: %{
          venue_slug: v.slug,
          updated_at: v.updated_at
        }

    Repo.all(query)
    |> Enum.map(fn venue ->
      %{
        loc: "#{base_url}/venues/#{venue.venue_slug}",
        changefreq: "daily",
        priority: 0.7,
        lastmod: venue.updated_at |> NaiveDateTime.to_date()
      }
    end)
  end

  @doc """
  Returns the total count of URLs in the sitemap.
  """
  def url_count do
    2 + country_count() + city_count() + venue_count()
  end

  defp country_count do
    Repo.aggregate(TriviaAdvisor.Locations.Country, :count)
  end

  defp city_count do
    Repo.aggregate(TriviaAdvisor.Locations.City, :count)
  end

  defp venue_count do
    Repo.aggregate(TriviaAdvisor.Locations.Venue, :count)
  end

  @doc """
  Formats the sitemap as XML string.
  """
  def to_xml do
    urls = generate()

    url_entries =
      urls
      |> Enum.map(fn url ->
        """
            <url>
              <loc>#{url.loc}</loc>
              <lastmod>#{url.lastmod}</lastmod>
              <changefreq>#{url.changefreq}</changefreq>
              <priority>#{url.priority}</priority>
            </url>
        """
      end)
      |> Enum.join("\n")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{url_entries}
    </urlset>
    """
  end
end
