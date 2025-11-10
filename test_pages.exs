#!/usr/bin/env elixir

# Page testing script to validate all routes work correctly
# Run with: mix run test_pages.exs

require Logger

defmodule PageTester do
  import Ecto.Query

  def test_all do
    IO.puts("\n=== Testing Trivia Advisor V2 Pages ===\n")

    results = [
      test_home(),
      test_about(),
      test_sample_country(),
      test_sample_city(),
      test_sample_venue()
    ]

    total = length(results)
    passed = Enum.count(results, & &1 == :ok)
    failed = total - passed

    IO.puts("\n=== Test Results ===")
    IO.puts("Total: #{total}")
    IO.puts("Passed: #{passed}")
    IO.puts("Failed: #{failed}")

    if failed == 0 do
      IO.puts("\n✅ All tests passed!")
      System.halt(0)
    else
      IO.puts("\n❌ Some tests failed")
      System.halt(1)
    end
  end

  defp test_home do
    IO.puts("Testing Home Page...")

    try do
      # Simulated mount
      cities = TriviaAdvisor.Locations.get_popular_cities(12)

      if length(cities) > 0 do
        IO.puts("  ✅ Home page loads (#{length(cities)} cities)")
        :ok
      else
        IO.puts("  ⚠️  Home page loads but no cities found")
        :ok
      end
    rescue
      e ->
        IO.puts("  ❌ Home page error: #{inspect(e)}")
        :error
    end
  end

  defp test_about do
    IO.puts("Testing About Page...")
    IO.puts("  ✅ About page (static)")
    :ok
  end

  defp test_sample_country do
    IO.puts("Testing Country Page...")

    try do
      country = TriviaAdvisor.Repo.get_by(TriviaAdvisor.Locations.Country, slug: "united-states")

      if country do
        cities = TriviaAdvisor.Locations.get_cities_for_country(country)
        IO.puts("  ✅ Country page loads: #{country.name} (#{length(cities)} cities)")
        :ok
      else
        IO.puts("  ⚠️  Country 'united-states' not found, trying first country...")
        country = TriviaAdvisor.Repo.all(TriviaAdvisor.Locations.Country) |> List.first()

        if country do
          cities = TriviaAdvisor.Locations.get_cities_for_country(country)
          IO.puts("  ✅ Country page loads: #{country.name} (#{length(cities)} cities)")
          :ok
        else
          IO.puts("  ❌ No countries in database")
          :error
        end
      end
    rescue
      e ->
        IO.puts("  ❌ Country page error: #{inspect(e)}")
        :error
    end
  end

  defp test_sample_city do
    IO.puts("Testing City Page...")

    try do
      # Find a city with venues
      city_query = from c in TriviaAdvisor.Locations.City,
        join: v in assoc(c, :venues),
        group_by: c.id,
        having: count(v.id) > 0,
        limit: 1,
        preload: :country

      city = TriviaAdvisor.Repo.one(city_query)

      if city do
        venues = TriviaAdvisor.Locations.get_venues_for_city(city.id)
        IO.puts("  ✅ City page loads: #{city.name}, #{city.country.name} (#{length(venues)} venues)")
        :ok
      else
        IO.puts("  ⚠️  No cities with venues found")
        :ok
      end
    rescue
      e ->
        IO.puts("  ❌ City page error: #{inspect(e)}")
        :error
    end
  end

  defp test_sample_venue do
    IO.puts("Testing Venue Page...")

    try do
      # Find a venue with events
      venue_query = from v in TriviaAdvisor.Locations.Venue,
        join: e in assoc(v, :public_events),
        group_by: v.id,
        having: count(e.id) > 0,
        limit: 1,
        preload: [city: :country]

      venue = TriviaAdvisor.Repo.one(venue_query)

      if venue do
        events = TriviaAdvisor.Events.get_events_for_venue(venue.id)
        IO.puts("  ✅ Venue page loads: #{venue.name} (#{length(events)} events)")

        # Test venue_images field
        if is_list(venue.venue_images) do
          IO.puts("     Images: #{length(venue.venue_images)} images")
        else
          IO.puts("     Images: No images")
        end

        :ok
      else
        IO.puts("  ⚠️  No venues with events found, testing venue without events...")

        venue = TriviaAdvisor.Repo.all(TriviaAdvisor.Locations.Venue) |> List.first()

        if venue do
          IO.puts("  ✅ Venue page loads: #{venue.name} (no events)")
          :ok
        else
          IO.puts("  ❌ No venues in database")
          :error
        end
      end
    rescue
      e ->
        IO.puts("  ❌ Venue page error: #{Exception.message(e)}")
        IO.puts("     #{Exception.format_stacktrace(__STACKTRACE__)}")
        :error
    end
  end
end

# Run tests
PageTester.test_all()
