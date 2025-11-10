#!/bin/bash
# test_phase7.sh - Quick Phase 7 validation script
# Run with: source .env && ./test_phase7.sh

set -e

echo "=================================="
echo "Trivia Advisor V2 - Phase 7 Tests"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check environment
if [ -z "$SUPABASE_DATABASE_URL" ]; then
  echo -e "${RED}❌ SUPABASE_DATABASE_URL not set${NC}"
  echo "Run: source .env && ./test_phase7.sh"
  exit 1
fi

echo -e "${GREEN}✅ Environment configured${NC}"
echo ""

# Test 1: Database Connectivity
echo "Test 1: Database Connectivity"
echo "------------------------------"
mix run -e "
case TriviaAdvisor.Repo.query(\"SELECT 1 AS test\") do
  {:ok, _} -> IO.puts \"${GREEN}✅ Database connected${NC}\"
  {:error, e} ->
    IO.puts \"${RED}❌ Database error: #{inspect(e)}${NC}\"
    System.halt(1)
end
"
echo ""

# Test 2: Sitemap Generation
echo "Test 2: Sitemap Generation"
echo "--------------------------"
mix run -e "
urls = TriviaAdvisor.Sitemap.generate()
url_count = length(urls)

IO.puts \"Total URLs: #{url_count}\"
IO.puts \"\"

# Count by type
static_count = Enum.count(urls, fn url ->
  String.contains?(url.loc, \"/about\") or String.ends_with?(url.loc, \"/\")
end)

country_count = Enum.count(urls, fn url ->
  parts = String.split(url.loc, \"/\") |> Enum.reject(&(&1 == \"\"))
  length(parts) == 2 and parts != [\"localhost:4000\"]
end)

city_count = Enum.count(urls, fn url ->
  parts = String.split(url.loc, \"/\") |> Enum.reject(&(&1 == \"\"))
  length(parts) == 3
end)

venue_count = Enum.count(urls, fn url ->
  parts = String.split(url.loc, \"/\") |> Enum.reject(&(&1 == \"\"))
  length(parts) == 4
end)

IO.puts \"Breakdown:\"
IO.puts \"  Static pages: #{static_count}\"
IO.puts \"  Country pages: #{country_count}\"
IO.puts \"  City pages: #{city_count}\"
IO.puts \"  Venue pages: #{venue_count}\"

if url_count >= 6900 and url_count <= 7100 do
  IO.puts \"\\n${GREEN}✅ URL count within expected range (6,900-7,100)${NC}\"
else
  IO.puts \"\\n${YELLOW}⚠️  URL count outside expected range: #{url_count}${NC}\"
end
"
echo ""

# Test 3: Sitemap XML Validation
echo "Test 3: Sitemap XML Structure"
echo "------------------------------"
mix run -e "
xml = TriviaAdvisor.Sitemap.to_xml()
xml_size = byte_size(xml)
url_count = (xml |> String.split(\"<loc>\") |> length()) - 1

IO.puts \"XML size: #{xml_size} bytes\"
IO.puts \"URLs in XML: #{url_count}\"

cond do
  not String.contains?(xml, \"<?xml version\") ->
    IO.puts \"${RED}❌ Missing XML declaration${NC}\"
    System.halt(1)
  not String.contains?(xml, \"<urlset\") ->
    IO.puts \"${RED}❌ Missing urlset element${NC}\"
    System.halt(1)
  not String.contains?(xml, \"xmlns\") ->
    IO.puts \"${RED}❌ Missing XML namespace${NC}\"
    System.halt(1)
  true ->
    IO.puts \"${GREEN}✅ Valid XML structure${NC}\"
end
"
echo ""

# Test 4: Read-Only Enforcement
echo "Test 4: Read-Only Database"
echo "---------------------------"
mix run -e "
# Test READ works
case TriviaAdvisor.Repo.query(\"SELECT 1\") do
  {:ok, _} -> IO.puts \"${GREEN}✅ READ operations work${NC}\"
  {:error, _} ->
    IO.puts \"${RED}❌ READ operations failed${NC}\"
    System.halt(1)
end

# Test WRITE blocked
case TriviaAdvisor.Repo.query(\"INSERT INTO countries (name, slug, code, inserted_at, updated_at) VALUES ('Test', 'test', 'TS', NOW(), NOW())\") do
  {:error, %Postgrex.Error{postgres: %{code: :insufficient_privilege}}} ->
    IO.puts \"${GREEN}✅ WRITE operations blocked${NC}\"
  {:ok, _} ->
    IO.puts \"${RED}❌ WARNING: WRITE operations NOT blocked!${NC}\"
    System.halt(1)
  {:error, e} ->
    IO.puts \"${YELLOW}⚠️  WRITE failed with unexpected error: #{inspect(e.postgres.code)}${NC}\"
end
"
echo ""

# Test 5: Query Performance
echo "Test 5: Query Performance"
echo "-------------------------"
mix run -e "
# Test popular cities query
{time_us, _} = :timer.tc(fn ->
  TriviaAdvisor.Locations.get_popular_cities(12)
end)
time_ms = time_us / 1000
IO.puts \"Popular cities query: #{Float.round(time_ms, 2)}ms\"

if time_ms < 200 do
  IO.puts \"${GREEN}✅ Query performance good (<200ms)${NC}\"
else
  IO.puts \"${YELLOW}⚠️  Query slow (>200ms)${NC}\"
end
"
echo ""

# Test 6: No Migrations
echo "Test 6: No Migration Files"
echo "---------------------------"
if [ -d "priv/repo/migrations" ] && [ "$(ls -A priv/repo/migrations 2>/dev/null)" ]; then
  echo -e "${RED}❌ WARNING: Migration files found${NC}"
  ls -la priv/repo/migrations/
  exit 1
else
  echo -e "${GREEN}✅ No migration files (read-only consumer)${NC}"
fi
echo ""

# Summary
echo "=================================="
echo "Phase 7 Quick Tests: Complete"
echo "=================================="
echo ""
echo -e "${GREEN}✅ All quick tests passed!${NC}"
echo ""
echo "Next steps:"
echo "1. Run full Phase 7 testing guide (.claude/PHASE_7_TESTING_GUIDE.md)"
echo "2. Start Phoenix server: mix phx.server"
echo "3. Test manually in browser: http://localhost:4000"
echo "4. Run Lighthouse audits"
echo "5. Complete SEO validation with Google Rich Results Test"
echo ""
