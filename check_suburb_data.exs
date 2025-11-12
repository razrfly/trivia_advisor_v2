#!/usr/bin/env elixir

# Script to check if suburb data exists in venue addresses

import Ecto.Query

alias TriviaAdvisor.Repo
alias TriviaAdvisor.Events.PublicEvent
alias TriviaAdvisor.Locations.City

# Get London city ID
london = Repo.one(from c in City, where: c.slug == "london", select: c)
IO.puts("\nLondon City ID: #{london.id}\n")

# Query 20 London venues to examine address patterns
venues = Repo.all(
  from te in PublicEvent,
    where: te.city_id == ^london.id,
    select: %{
      venue_id: te.venue_id,
      venue_name: te.venue_name,
      venue_address: te.venue_address,
      venue_metadata: te.venue_metadata
    },
    limit: 20
)

IO.puts("=== Sample London Venue Addresses ===\n")

Enum.each(venues, fn venue ->
  IO.puts("#{venue.venue_name}")
  IO.puts("  Address: #{venue.venue_address}")

  # Check metadata for any suburb/neighborhood fields
  if is_map(venue.venue_metadata) && map_size(venue.venue_metadata) > 0 do
    IO.puts("  Metadata keys: #{inspect(Map.keys(venue.venue_metadata))}")

    # Check for common suburb field names
    suburb_keys = ["suburb", "neighborhood", "neighbourhood", "area", "district", "locality"]
    found_suburbs = Enum.filter(suburb_keys, fn key -> Map.has_key?(venue.venue_metadata, key) end)

    if length(found_suburbs) > 0 do
      IO.puts("  ** FOUND SUBURB FIELDS: #{inspect(found_suburbs)}")
      Enum.each(found_suburbs, fn key ->
        IO.puts("     #{key}: #{venue.venue_metadata[key]}")
      end)
    end
  end

  IO.puts("")
end)

# Try parsing address to extract potential suburbs
IO.puts("\n=== Address Parsing Analysis ===\n")

Enum.take(venues, 5) |> Enum.each(fn venue ->
  address_parts = String.split(venue.venue_address, ",")
  IO.puts("#{venue.venue_name}")
  IO.puts("  Full: #{venue.venue_address}")
  IO.puts("  Parts: #{inspect(address_parts)}")

  # Common London address pattern: "123 Street Name, Suburb, London Postcode"
  if length(address_parts) >= 2 do
    potential_suburb = Enum.at(address_parts, -2) |> String.trim()
    IO.puts("  Potential suburb: #{potential_suburb}")
  end

  IO.puts("")
end)
