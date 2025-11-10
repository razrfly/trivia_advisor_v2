# Export all city and venue slugs to files for analysis

alias TriviaAdvisor.Repo
alias TriviaAdvisor.Locations.{City, Venue, Country}
import Ecto.Query

IO.puts("\n=== EXPORTING SLUGS FOR ANALYSIS ===\n")

# Export city slugs with countries
IO.puts("Exporting city slugs...")
city_slugs =
  from(c in City,
    join: country in Country, on: c.country_id == country.id,
    order_by: c.slug,
    select: %{slug: c.slug, name: c.name, country: country.name, country_slug: country.slug}
  )
  |> Repo.all()

File.write!("city_slugs.txt", 
  Enum.map_join(city_slugs, "\n", fn city ->
    "#{city.slug}\t#{city.name}\t#{city.country}\t#{city.country_slug}"
  end)
)

IO.puts("✅ Exported #{length(city_slugs)} city slugs to city_slugs.txt")

# Export venue slugs with locations
IO.puts("Exporting venue slugs...")
venue_slugs =
  from(v in Venue,
    join: city in City, on: v.city_id == city.id,
    join: country in Country, on: city.country_id == country.id,
    order_by: v.slug,
    select: %{
      slug: v.slug,
      name: v.name,
      city: city.name,
      city_slug: city.slug,
      country: country.name,
      country_slug: country.slug
    }
  )
  |> Repo.all()

File.write!("venue_slugs.txt",
  Enum.map_join(venue_slugs, "\n", fn venue ->
    "#{venue.slug}\t#{venue.name}\t#{venue.city}\t#{venue.city_slug}\t#{venue.country}\t#{venue.country_slug}"
  end)
)

IO.puts("✅ Exported #{length(venue_slugs)} venue slugs to venue_slugs.txt")

# Export summary statistics
IO.puts("\n=== SUMMARY STATISTICS ===")

total_cities = length(city_slugs)
unique_city_slugs = city_slugs |> Enum.map(& &1.slug) |> Enum.uniq() |> length()
duplicate_cities = total_cities - unique_city_slugs

total_venues = length(venue_slugs)
unique_venue_slugs = venue_slugs |> Enum.map(& &1.slug) |> Enum.uniq() |> length()
duplicate_venues = total_venues - unique_venue_slugs

IO.puts("Cities: #{total_cities} total, #{unique_city_slugs} unique, #{duplicate_cities} duplicates")
IO.puts("Venues: #{total_venues} total, #{unique_venue_slugs} unique, #{duplicate_venues} duplicates")

summary = """
=== SLUG EXPORT SUMMARY ===

Database Statistics:
- Total Cities: #{total_cities}
- Unique City Slugs: #{unique_city_slugs}
- Duplicate City Slugs: #{duplicate_cities}
- City Uniqueness: #{Float.round(unique_city_slugs / total_cities * 100, 1)}%

- Total Venues: #{total_venues}
- Unique Venue Slugs: #{unique_venue_slugs}
- Duplicate Venue Slugs: #{duplicate_venues}
- Venue Uniqueness: #{Float.round(unique_venue_slugs / total_venues * 100, 1)}%

Files Generated:
- city_slugs.txt: All city slugs with country context
- venue_slugs.txt: All venue slugs with location context

Format:
City: slug<TAB>name<TAB>country<TAB>country_slug
Venue: slug<TAB>name<TAB>city<TAB>city_slug<TAB>country<TAB>country_slug
"""

File.write!("slug_export_summary.txt", summary)

IO.puts("\n✅ Export complete!")
IO.puts("Files created: city_slugs.txt, venue_slugs.txt, slug_export_summary.txt")
