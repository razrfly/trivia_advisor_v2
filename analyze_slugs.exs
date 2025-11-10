# Script to analyze slug uniqueness and patterns for URL matching analysis

alias TriviaAdvisor.Repo
alias TriviaAdvisor.Locations.{City, Venue, Country}
import Ecto.Query

IO.puts("\n=== SLUG UNIQUENESS ANALYSIS ===\n")

# Check for duplicate city slugs
IO.puts("Checking for duplicate city slugs...")
duplicate_city_slugs = 
  from(c in City,
    group_by: c.slug,
    having: count(c.id) > 1,
    select: {c.slug, count(c.id)}
  ) 
  |> Repo.all()

if Enum.empty?(duplicate_city_slugs) do
  IO.puts("✅ All city slugs are unique")
else
  IO.puts("❌ Found #{length(duplicate_city_slugs)} duplicate city slugs:")
  Enum.take(duplicate_city_slugs, 10) |> Enum.each(fn {slug, count} ->
    IO.puts("  - '#{slug}' appears #{count} times")
    
    # Show which cities share this slug
    cities = Repo.all(
      from c in City,
        join: country in Country, on: c.country_id == country.id,
        where: c.slug == ^slug,
        select: %{name: c.name, country_name: country.name}
    )
    
    Enum.each(cities, fn city ->
      IO.puts("    - #{city.name}, #{city.country_name}")
    end)
  end)
  
  if length(duplicate_city_slugs) > 10 do
    IO.puts("  ... and #{length(duplicate_city_slugs) - 10} more")
  end
end

# Check for duplicate venue slugs
IO.puts("\nChecking for duplicate venue slugs...")
duplicate_venue_slugs = 
  from(v in Venue,
    group_by: v.slug,
    having: count(v.id) > 1,
    select: {v.slug, count(v.id)}
  )
  |> Repo.all()

if Enum.empty?(duplicate_venue_slugs) do
  IO.puts("✅ All venue slugs are unique")
else
  IO.puts("❌ Found #{length(duplicate_venue_slugs)} duplicate venue slugs:")
  Enum.take(duplicate_venue_slugs, 10) |> Enum.each(fn {slug, count} ->
    IO.puts("  - '#{slug}' appears #{count} times")
    
    # Show which venues share this slug (limit to first 3)
    venues = Repo.all(
      from v in Venue,
        join: city in City, on: v.city_id == city.id,
        join: country in Country, on: city.country_id == country.id,
        where: v.slug == ^slug,
        limit: 3,
        select: %{name: v.name, city_name: city.name, country_name: country.name}
    )
    
    Enum.each(venues, fn venue ->
      IO.puts("    - #{venue.name}, #{venue.city_name}, #{venue.country_name}")
    end)
  end)
  
  if length(duplicate_venue_slugs) > 10 do
    IO.puts("  ... and #{length(duplicate_venue_slugs) - 10} more")
  end
end

# Get total counts
IO.puts("\n=== DATABASE STATISTICS ===\n")

total_cities = Repo.aggregate(City, :count)
total_venues = Repo.aggregate(Venue, :count)

IO.puts("Total cities: #{total_cities}")
IO.puts("Total venues: #{total_venues}")
IO.puts("Duplicate city slugs: #{length(duplicate_city_slugs)}")
IO.puts("Duplicate venue slugs: #{length(duplicate_venue_slugs)}")

# Calculate percentages
unique_cities_pct = Float.round((total_cities - length(duplicate_city_slugs)) / total_cities * 100, 1)
unique_venues_pct = Float.round((total_venues - length(duplicate_venue_slugs)) / total_venues * 100, 1)

IO.puts("Cities with unique slugs: #{unique_cities_pct}%")
IO.puts("Venues with unique slugs: #{unique_venues_pct}%")

# Sample some slugs to show format
IO.puts("\n=== SAMPLE SLUGS ===\n")

IO.puts("Sample city slugs:")
Repo.all(
  from c in City,
    join: country in Country, on: c.country_id == country.id,
    limit: 10,
    order_by: c.name,
    select: %{slug: c.slug, name: c.name, country: country.name}
)
|> Enum.each(fn city ->
  IO.puts("  - #{city.slug} (#{city.name}, #{city.country})")
end)

IO.puts("\nSample venue slugs:")
Repo.all(
  from v in Venue,
    join: city in City, on: v.city_id == city.id,
    limit: 10,
    order_by: v.name,
    select: %{slug: v.slug, name: v.name, city: city.name}
)
|> Enum.each(fn venue ->
  IO.puts("  - #{venue.slug} (#{venue.name}, #{venue.city})")
end)

# Check for slugs with numeric IDs at the end
IO.puts("\n=== SLUG PATTERN ANALYSIS ===\n")

IO.puts("Checking for city slugs with numeric IDs...")
city_slugs_with_ids_count = 
  from(c in City,
    where: fragment("? ~ ?", c.slug, "[0-9]+$"),
    select: count()
  )
  |> Repo.one()

city_slugs_with_ids = 
  from(c in City,
    where: fragment("? ~ ?", c.slug, "[0-9]+$"),
    select: c.slug,
    limit: 20
  )
  |> Repo.all()

if city_slugs_with_ids_count == 0 do
  IO.puts("✅ No city slugs with trailing numeric IDs found")
else
  IO.puts("Found #{city_slugs_with_ids_count} city slugs with trailing numeric IDs (showing first 20):")
  Enum.each(city_slugs_with_ids, fn slug ->
    IO.puts("  - #{slug}")
  end)
end

IO.puts("\nChecking for venue slugs with numeric IDs...")
venue_slugs_with_ids_count = 
  from(v in Venue,
    where: fragment("? ~ ?", v.slug, "[0-9]+$"),
    select: count()
  )
  |> Repo.one()

venue_slugs_with_ids = 
  from(v in Venue,
    where: fragment("? ~ ?", v.slug, "[0-9]+$"),
    select: v.slug,
    limit: 20
  )
  |> Repo.all()

if venue_slugs_with_ids_count == 0 do
  IO.puts("✅ No venue slugs with trailing numeric IDs found")
else
  IO.puts("Found #{venue_slugs_with_ids_count} venue slugs with trailing numeric IDs (showing first 20):")
  Enum.each(venue_slugs_with_ids, fn slug ->
    IO.puts("  - #{slug}")
  end)
end

IO.puts("\n=== ANALYSIS COMPLETE ===\n")
