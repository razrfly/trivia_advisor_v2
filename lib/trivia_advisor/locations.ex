defmodule TriviaAdvisor.Locations do
  @moduledoc """
  Context module for location-related queries (Countries, Cities, Venues).
  All queries are read-only against the Eventasaurus database.
  """

  import Ecto.Query, warn: false
  alias TriviaAdvisor.Repo
  alias TriviaAdvisor.Locations.{Country, City, Venue}
  alias TriviaAdvisor.Events.PublicEvent

  # ============================================================================
  # Country Queries
  # ============================================================================

  @doc """
  Gets a country by its slug.

  ## Examples

      iex> get_country_by_slug("united-states")
      %Country{}

      iex> get_country_by_slug("invalid")
      nil
  """
  def get_country_by_slug(slug) when is_binary(slug) do
    Repo.one(
      from c in Country,
        where: c.slug == ^slug
    )
  end

  @doc """
  Lists all countries that have trivia events, ordered by name.
  Queries the trivia_events_export view for simplicity.
  """
  def list_countries do
    Repo.all(
      from c in Country,
        join: te in PublicEvent, on: te.country_id == c.id,
        distinct: true,
        order_by: c.name
    )
  end

  # ============================================================================
  # City Queries
  # ============================================================================

  @doc """
  Gets a city by its slug with country preloaded.

  ## Examples

      iex> get_city_by_slug("london")
      %City{country: %Country{}}

      iex> get_city_by_slug("invalid")
      nil
  """
  def get_city_by_slug(slug) when is_binary(slug) do
    Repo.one(
      from c in City,
        where: c.slug == ^slug,
        preload: [:country]
    )
  end

  @doc """
  Gets a city by URL slug, handling both unique slugs and disambiguated slugs.

  Disambiguated slugs follow the pattern: {city-slug}-{country-slug}

  ## Examples

      iex> get_city_by_url_slug("austin")  # Unique slug
      %City{name: "Austin", country: %Country{name: "United States"}}

      iex> get_city_by_url_slug("aberdeen-united-kingdom")  # Disambiguated
      %City{name: "Aberdeen", country: %Country{name: "United Kingdom"}}
  """
  def get_city_by_url_slug(url_slug) when is_binary(url_slug) do
    # First, try as a unique city slug
    case get_unique_city_by_slug(url_slug) do
      %City{} = city ->
        # Found unique city
        city

      nil ->
        # Not found as unique slug, try parsing as disambiguated format
        # Format: {city-slug}-{country-slug}
        # We need to try all possible splits from the right since both parts can contain hyphens
        parts = String.split(url_slug, "-")
        try_disambiguated_slug(parts, [])
    end
  end

  # Helper to try different split positions for disambiguated slugs
  defp try_disambiguated_slug([_single_part], _acc), do: nil

  defp try_disambiguated_slug([part | rest], acc) do
    # Try current split: everything before as city slug, everything after as country slug
    city_slug = Enum.join(Enum.reverse([part | acc]), "-")
    country_slug = Enum.join(rest, "-")

    case get_city_by_slugs(city_slug, country_slug) do
      %City{} = city -> city
      nil -> try_disambiguated_slug(rest, [part | acc])
    end
  end

  defp try_disambiguated_slug([], _acc), do: nil

  @doc """
  Gets a city by city slug and country slug.
  """
  def get_city_by_slugs(city_slug, country_slug) when is_binary(city_slug) and is_binary(country_slug) do
    Repo.one(
      from c in City,
        join: country in assoc(c, :country),
        where: c.slug == ^city_slug and country.slug == ^country_slug,
        preload: [:country]
    )
  end

  @doc """
  Gets a unique city by slug (returns nil if multiple cities have the same slug).
  """
  def get_unique_city_by_slug(slug) when is_binary(slug) do
    case Repo.all(
      from c in City,
        where: c.slug == ^slug,
        preload: [:country]
    ) do
      [city] -> city  # Exactly one match
      _ -> nil        # Zero or multiple matches
    end
  end

  @doc """
  Checks if a city slug is duplicated (appears for multiple cities).
  """
  def is_duplicate_city_slug?(slug) when is_binary(slug) do
    count = Repo.one(
      from c in City,
        where: c.slug == ^slug,
        select: count(c.id)
    )

    count > 1
  end

  @doc """
  Generates the appropriate URL slug for a city.
  Returns city slug for unique cities, or city-slug-country-slug for duplicates.

  ## Examples

      iex> city_url_slug(%City{slug: "austin"})  # Unique
      "austin"

      iex> city_url_slug(%City{slug: "aberdeen", country: %Country{slug: "united-kingdom"}})  # Duplicate
      "aberdeen-united-kingdom"
  """
  def city_url_slug(%City{slug: slug, country: %Country{slug: country_slug}}) do
    if is_duplicate_city_slug?(slug) do
      "#{slug}-#{country_slug}"
    else
      slug
    end
  end

  def city_url_slug(%City{slug: slug}) do
    # If country not preloaded, assume unique
    slug
  end

  @doc """
  Gets cities with discovery enabled that have trivia events (popular cities).
  Queries the trivia_events_export view for simplicity.

  ## Examples

      iex> get_popular_cities(10)
      [%City{}, ...]

      iex> get_popular_cities(5, country_id: 123)
      [%City{}, ...]
  """
  def get_popular_cities(limit \\ 20, opts \\ []) do
    query =
      from c in City,
        join: te in PublicEvent, on: te.city_id == c.id,
        where: c.discovery_enabled == true,
        distinct: true,
        order_by: c.name,
        limit: ^limit,
        preload: [:country]

    query =
      case Keyword.get(opts, :country_id) do
        nil -> query
        country_id -> where(query, [c], c.country_id == ^country_id)
      end

    Repo.all(query)
  end

  @doc """
  Gets cities for a country (accepts Country struct).
  """
  def get_cities_for_country(%Country{id: country_id}) do
    list_cities_for_country(country_id)
  end

  @doc """
  Lists all cities for a country that have trivia events, ordered by venue count DESC then name.
  Prioritizes cities with more venues to surface major trivia destinations first.
  """
  def list_cities_for_country(country_id) do
    # Get cities with venue counts
    cities_with_counts =
      Repo.all(
        from c in City,
          join: te in PublicEvent,
          on: te.city_id == c.id,
          where: c.country_id == ^country_id,
          group_by: c.id,
          select: %{
            id: c.id,
            venue_count: count(te.venue_id, :distinct)
          },
          order_by: [desc: count(te.venue_id, :distinct), asc: c.name]
      )

    # Get city IDs in priority order
    city_ids = Enum.map(cities_with_counts, & &1.id)

    # Fetch full city records with preloads, maintaining the sort order
    cities =
      Repo.all(
        from c in City,
          where: c.id in ^city_ids,
          preload: [:country]
      )

    # Re-sort cities to match the priority order
    city_map = Map.new(cities, &{&1.id, &1})
    Enum.map(city_ids, &Map.get(city_map, &1))
  end

  # ============================================================================
  # Venue Queries
  # ============================================================================

  @doc """
  Gets a venue by its slug with city and country preloaded.

  ## Examples

      iex> get_venue_by_slug("the-phoenix-london")
      %Venue{city: %City{country: %Country{}}}

      iex> get_venue_by_slug("invalid")
      nil
  """
  def get_venue_by_slug(slug) when is_binary(slug) do
    Repo.one(
      from v in Venue,
        where: v.slug == ^slug,
        preload: [city: :country]
    )
  end

  @doc """
  Finds venues near a city using PostGIS spatial queries.
  Returns venues within the specified radius (in kilometers).

  ## Examples

      iex> find_venues_near_city(%City{latitude: lat, longitude: lon}, 10)
      [%Venue{}, ...]
  """
  def find_venues_near_city(city, radius_km \\ 50)

  def find_venues_near_city(%City{latitude: city_lat, longitude: city_lon}, radius_km)
      when not is_nil(city_lat) and not is_nil(city_lon) do
    # Convert Decimal to float for PostGIS
    lat = Decimal.to_float(city_lat)
    lon = Decimal.to_float(city_lon)

    # Convert km to meters for PostGIS
    radius_meters = radius_km * 1000

    Repo.all(
      from v in Venue,
        where: not is_nil(v.latitude) and not is_nil(v.longitude),
        where:
          fragment(
            "ST_DWithin(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography, ?)",
            v.longitude,
            v.latitude,
            ^lon,
            ^lat,
            ^radius_meters
          ),
        order_by:
          fragment(
            "ST_Distance(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography)",
            v.longitude,
            v.latitude,
            ^lon,
            ^lat
          ),
        preload: [city: :country]
    )
  end

  def find_venues_near_city(_city, _radius_km), do: []

  @doc """
  Finds venues near a specific venue using PostGIS spatial queries.
  Returns venues within the specified radius (in kilometers), excluding the venue itself.

  ## Examples

      iex> find_venues_near_venue(%Venue{latitude: lat, longitude: lon, id: 1}, 5)
      [%Venue{}, ...]
  """
  def find_venues_near_venue(venue, radius_km \\ 5)

  def find_venues_near_venue(%Venue{latitude: venue_lat, longitude: venue_lon, id: venue_id}, radius_km)
      when not is_nil(venue_lat) and not is_nil(venue_lon) do
    # Convert to float for PostGIS
    lat = if is_float(venue_lat), do: venue_lat, else: Float.parse("#{venue_lat}") |> elem(0)
    lon = if is_float(venue_lon), do: venue_lon, else: Float.parse("#{venue_lon}") |> elem(0)

    # Convert km to meters for PostGIS
    radius_meters = radius_km * 1000

    # Query with GROUP BY instead of DISTINCT to allow ORDER BY distance
    Repo.all(
      from v in Venue,
        join: te in PublicEvent, on: te.venue_id == v.id,
        where: v.id != ^venue_id,
        where: not is_nil(v.latitude) and not is_nil(v.longitude),
        where:
          fragment(
            "ST_DWithin(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography, ?)",
            v.longitude,
            v.latitude,
            ^lon,
            ^lat,
            ^radius_meters
          ),
        group_by: v.id,
        order_by:
          fragment(
            "ST_Distance(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography)",
            v.longitude,
            v.latitude,
            ^lon,
            ^lat
          ),
        limit: 10,
        preload: [city: :country]
    )
  end

  def find_venues_near_venue(_venue, _radius_km), do: []

  @doc """
  Calculates distance between two venues in kilometers using PostGIS.
  Returns nil if either venue lacks coordinates.
  """
  def distance_between_venues(
        %Venue{latitude: lat1, longitude: lon1},
        %Venue{latitude: lat2, longitude: lon2}
      )
      when not is_nil(lat1) and not is_nil(lon1) and not is_nil(lat2) and not is_nil(lon2) do
    # Convert to float for PostGIS
    lat1_f = if is_float(lat1), do: lat1, else: Float.parse("#{lat1}") |> elem(0)
    lon1_f = if is_float(lon1), do: lon1, else: Float.parse("#{lon1}") |> elem(0)
    lat2_f = if is_float(lat2), do: lat2, else: Float.parse("#{lat2}") |> elem(0)
    lon2_f = if is_float(lon2), do: lon2, else: Float.parse("#{lon2}") |> elem(0)

    result =
      Repo.one(
        from v in Venue,
          select:
            fragment(
              "ST_Distance(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography) / 1000",
              ^lon1_f,
              ^lat1_f,
              ^lon2_f,
              ^lat2_f
            ),
          limit: 1
      )

    if result, do: Float.round(result, 1), else: nil
  end

  def distance_between_venues(_, _), do: nil

  @doc """
  Gets the latest added venues that have trivia events.
  Returns flat maps from trivia_events_export view with event details.

  ## Examples

      iex> get_latest_venues(10)
      [%{venue_name: "...", day_of_week: 3, ...}, ...]
  """
  def get_latest_venues(limit \\ 20) do
    Repo.all(
      from te in PublicEvent,
        distinct: te.venue_id,
        order_by: [te.venue_id, desc: te.updated_at],
        limit: ^limit,
        select: %{
          # Event details
          event_id: te.id,
          event_name: te.name,
          day_of_week: te.day_of_week,
          start_time: te.start_time,
          timezone: te.timezone,
          frequency: te.frequency,
          entry_fee_cents: te.entry_fee_cents,
          description: te.description,
          hero_image: te.hero_image,

          # Source attribution
          source_name: te.source_name,
          source_url: te.source_url,
          source_logo_url: te.source_logo_url,
          source_website_url: te.source_website_url,
          activity_slug: te.activity_slug,
          last_seen_at: te.last_seen_at,
          updated_at: te.updated_at,

          # Venue details
          venue_id: te.venue_id,
          venue_name: te.venue_name,
          slug: te.venue_slug,  # Map to 'slug' for VenueCard compatibility
          venue_address: te.venue_address,
          venue_latitude: te.venue_latitude,
          venue_longitude: te.venue_longitude,
          venue_images: te.venue_images,
          venue_metadata: te.venue_metadata,  # For video_images fallback

          # City details
          city_id: te.city_id,
          city_name: te.city_name,
          city_slug: te.city_slug,
          city_images: te.city_images,  # For city image fallback

          # Country details
          country_id: te.country_id,
          country_name: te.country_name,
          country_code: te.country_code
        }
    )
  end

  @doc """
  Gets venues for a city by city ID.
  """
  def get_venues_for_city(city_id) do
    list_venues_for_city(city_id)
  end

  @doc """
  Lists all venues for a city that have trivia events, with full event details.
  Queries the trivia_events_export view which provides all fields pre-flattened.

  Returns event/venue data as maps (not Venue structs) with all fields from the view.
  All event data is pre-extracted from JSONB - no fragment queries needed!

  ## Options
  - `:weekday` - Filter by day of week (1=Monday, 7=Sunday). Default: nil (no filter)

  ## Examples

      iex> list_venues_for_city(123)
      [%{venue_name: "...", day_of_week: 1, start_time: ~T[19:00:00], ...}, ...]

      iex> list_venues_for_city(123, weekday: 3)
      [%{...}, ...]  # Only events on Wednesday
  """
  def list_venues_for_city(city_id, opts \\ []) do
    weekday = Keyword.get(opts, :weekday)

    # Query trivia_events_export view directly for all flat fields
    query =
      from te in PublicEvent,
        where: te.city_id == ^city_id,
        order_by: te.venue_name,
        # Select all event details as a map
        select: %{
          # Event details (all pre-extracted, no JSONB parsing!)
          event_id: te.id,
          event_name: te.name,
          day_of_week: te.day_of_week,          # 1-7, ready to use
          start_time: te.start_time,            # time field
          timezone: te.timezone,
          frequency: te.frequency,
          entry_fee_cents: te.entry_fee_cents,  # 0 = free
          description: te.description,
          hero_image: te.hero_image,

          # Source attribution (for "Updated X ago • Source: Y")
          source_name: te.source_name,
          source_url: te.source_url,
          source_logo_url: te.source_logo_url,
          source_website_url: te.source_website_url,
          activity_slug: te.activity_slug,
          last_seen_at: te.last_seen_at,
          updated_at: te.updated_at,

          # Venue details (all flat)
          venue_id: te.venue_id,
          venue_name: te.venue_name,
          slug: te.venue_slug,  # Map to 'slug' for VenueCard compatibility
          venue_address: te.venue_address,
          venue_latitude: te.venue_latitude,
          venue_longitude: te.venue_longitude,
          venue_images: te.venue_images,
          venue_metadata: te.venue_metadata,  # For video_images fallback

          # Location info (for distance calculations)
          city_id: te.city_id,
          city_name: te.city_name,
          city_slug: te.city_slug,
          city_latitude: te.city_latitude,
          city_longitude: te.city_longitude,
          city_images: te.city_images,  # For city image fallback
          country_id: te.country_id,
          country_name: te.country_name,
          country_code: te.country_code
        }

    # Filter by weekday using flat day_of_week field (simple integer comparison!)
    query =
      if weekday && weekday in 1..7 do
        from [te] in query, where: te.day_of_week == ^weekday
      else
        query
      end

    # Return list of events with all venue/event details merged
    Repo.all(query)
  end

  @doc """
  Gets event counts per day of week for a city.
  Returns a map with day numbers (1-7) as keys and counts as values.

  ## Examples

      iex> get_day_counts_for_city(53)
      %{1 => 12, 2 => 18, 3 => 26, 4 => 15, 5 => 20, 6 => 8, 7 => 4}
  """
  def get_day_counts_for_city(city_id) do
    # Query the view and group by day_of_week
    results =
      Repo.all(
        from te in PublicEvent,
          where: te.city_id == ^city_id,
          group_by: te.day_of_week,
          select: {te.day_of_week, count(te.id)}
      )

    # Convert list of tuples to map
    Map.new(results)
  end

  @doc """
  Searches venues by name (case-insensitive partial match).
  """
  def search_venues(query_string, limit \\ 20) when is_binary(query_string) do
    search_pattern = "%#{query_string}%"

    Repo.all(
      from v in Venue,
        where: ilike(v.name, ^search_pattern),
        order_by: v.name,
        limit: ^limit,
        preload: [city: :country]
    )
  end

  # ============================================================================
  # Statistics Queries
  # ============================================================================

  @doc """
  Counts venues that have trivia events.
  """
  def count_venues_with_trivia do
    Repo.one(
      from v in Venue,
        join: te in PublicEvent, on: te.venue_id == v.id,
        select: count(v.id, :distinct)
    )
  end

  @doc """
  Counts cities that have trivia events.
  """
  def count_cities_with_trivia do
    Repo.one(
      from c in City,
        join: te in PublicEvent, on: te.city_id == c.id,
        select: count(c.id, :distinct)
    )
  end

  @doc """
  Counts countries that have trivia events.
  """
  def count_countries_with_trivia do
    Repo.one(
      from c in Country,
        join: te in PublicEvent, on: te.country_id == c.id,
        select: count(c.id, :distinct)
    )
  end
end
