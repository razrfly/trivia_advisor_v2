# Test script for list_top_cities_by_country function
alias TriviaAdvisor.Locations

IO.puts("\n========================================")
IO.puts("Testing list_top_cities_by_country(12)")
IO.puts("========================================\n")

# Test with limit of 12 (default)
{time_microseconds, result} = :timer.tc(fn ->
  Locations.list_top_cities_by_country(12)
end)

time_ms = time_microseconds / 1_000
time_s = time_ms / 1_000

IO.puts("✓ Query completed in #{Float.round(time_ms, 2)}ms (#{Float.round(time_s, 2)}s)")
IO.puts("✓ Found #{length(result)} countries\n")

# Calculate total cities
total_cities = Enum.reduce(result, 0, fn {_country, cities}, acc ->
  acc + length(cities)
end)

IO.puts("✓ Total cities returned: #{total_cities}\n")

# Show first 3 countries
IO.puts("Top 3 countries with their cities:\n")
result
|> Enum.take(3)
|> Enum.each(fn {country, cities} ->
  IO.puts("#{country.name} (#{length(cities)} cities):")
  cities
  |> Enum.take(5)
  |> Enum.each(fn city ->
    IO.puts("  #{city.venue_count}× #{city.name}")
  end)
  if length(cities) > 5 do
    IO.puts("  ... and #{length(cities) - 5} more")
  end
  IO.puts("")
end)

IO.puts("\n========================================")
IO.puts("Performance Comparison")
IO.puts("========================================\n")

# Test the old function for comparison (WARNING: This might be slow!)
IO.puts("Testing old list_all_cities_grouped_by_country()...")
{old_time_microseconds, old_result} = :timer.tc(fn ->
  Locations.list_all_cities_grouped_by_country()
end)

old_time_ms = old_time_microseconds / 1_000
old_time_s = old_time_ms / 1_000

old_total_cities = Enum.reduce(old_result, 0, fn {_country, cities}, acc ->
  acc + length(cities)
end)

IO.puts("✓ Old query completed in #{Float.round(old_time_ms, 2)}ms (#{Float.round(old_time_s, 2)}s)")
IO.puts("✓ Old query returned #{old_total_cities} cities\n")

IO.puts("\n========================================")
IO.puts("Results")
IO.puts("========================================\n")

# Calculate improvement (guard against division by zero)
if old_total_cities == 0 do
  IO.puts("⚠️  Database is empty - cannot calculate performance improvement")
else
  speedup = old_time_ms / time_ms
  reduction_percent = ((old_total_cities - total_cities) / old_total_cities * 100)

  IO.puts("Performance Improvement:")
  IO.puts("  • #{Float.round(speedup, 2)}x faster")
  IO.puts("  • #{Float.round(reduction_percent, 1)}% fewer cities loaded")
  IO.puts("  • Reduced from #{old_total_cities} to #{total_cities} cities")
  IO.puts("  • Saved #{Float.round(old_time_ms - time_ms, 2)}ms query time\n")
end

IO.puts("✓ Test completed successfully!\n")
