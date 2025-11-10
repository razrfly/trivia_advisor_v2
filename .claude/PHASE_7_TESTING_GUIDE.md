# Phase 7: Testing & Validation Guide

**Status**: Ready for Execution
**Duration**: 4-5 days
**Goal**: Comprehensive validation before production deployment

---

## Prerequisites

### Environment Setup

1. **Create `.env` file from template**:
```bash
cp .env.example .env
```

2. **Configure required variables**:
```bash
# Edit .env with your values
SUPABASE_DATABASE_URL="postgresql://user:password@host:5432/database"
```

3. **Verify environment**:
```bash
source .env && echo "Database URL: ${SUPABASE_DATABASE_URL:0:30}..."
```

---

## 7.1: Sitemap Validation

**Goal**: Verify sitemap generates all expected URLs without errors

### Step 1: Generate Sitemap Locally

```bash
# Set environment and generate sitemap
source .env
mix run -e "
urls = TriviaAdvisor.Sitemap.generate()
IO.puts \"Total URLs generated: #{length(urls)}\"
IO.puts \"\"
IO.puts \"URL Breakdown:\"
IO.puts \"  Static pages: #{Enum.count(urls, & String.contains?(&1.loc, ~w(/about /)))}\"
IO.puts \"  Country pages: #{Enum.count(urls, & String.match?(&1.loc, ~r{^https://[^/]+/[^/]+/?$}) and not String.contains?(&1.loc, \"/about\"))}\"
IO.puts \"  City pages: #{Enum.count(urls, & String.match?(&1.loc, ~r{^https://[^/]+/[^/]+/[^/]+/?$}))}\"
IO.puts \"  Venue pages: #{Enum.count(urls, & String.match?(&1.loc, ~r{^https://[^/]+/[^/]+/[^/]+/[^/]+/?$}))}\"
"
```

**Expected Output**:
```
Total URLs generated: 6,976
URL Breakdown:
  Static pages: 2
  Country pages: 6
  City pages: 2,410
  Venue pages: 4,558
```

### Step 2: Compare to Baseline

**From Phase 5 SEO Validation**:
- Total URLs: 6,976
- Static: 2
- Countries: 6
- Cities: 2,410
- Venues: 4,558

**Validation**:
```bash
# Generate sitemap XML and count URLs
source .env
mix run -e "
xml = TriviaAdvisor.Sitemap.to_xml()
IO.puts \"Sitemap XML size: #{byte_size(xml)} bytes\"
IO.puts \"URL count in XML: #{(xml |> String.split(\"<loc>\") |> length()) - 1}\"
IO.puts \"\"
# Validate XML structure
if String.contains?(xml, \"<?xml version\") and String.contains?(xml, \"<urlset\") do
  IO.puts \"✅ Valid XML structure\"
else
  IO.puts \"❌ Invalid XML structure\"
end
"
```

### Step 3: Validate URL Format

```bash
# Check URL formats match V1 patterns
source .env
mix run -e "
urls = TriviaAdvisor.Sitemap.generate()
base_url = Application.get_env(:trivia_advisor, :base_url, \"https://quizadvisor.com\")

# Sample and validate URL patterns
samples = [
  urls |> Enum.find(&String.match?(&1.loc, ~r{/about})),
  urls |> Enum.find(&String.match?(&1.loc, ~r{^https://[^/]+/[^/]+/?$})),
  urls |> Enum.find(&String.match?(&1.loc, ~r{^https://[^/]+/[^/]+/[^/]+/?$})),
  urls |> Enum.find(&String.match?(&1.loc, ~r{^https://[^/]+/[^/]+/[^/]+/[^/]+/?$}))
]

IO.puts \"Sample URLs:\"
Enum.each(samples, fn url ->
  if url do
    IO.puts \"  ✅ #{url.loc}\"
    IO.puts \"     Priority: #{url.priority}, Changefreq: #{url.changefreq}\"
  end
end)
"
```

### Step 4: Validate Required Fields

```bash
# Verify all required sitemap fields present
source .env
mix run -e "
urls = TriviaAdvisor.Sitemap.generate()
sample_url = Enum.random(urls)

IO.puts \"Sample URL validation:\"
IO.puts \"  loc: #{sample_url.loc}\"
IO.puts \"  lastmod: #{sample_url.lastmod}\"
IO.puts \"  changefreq: #{sample_url.changefreq}\"
IO.puts \"  priority: #{sample_url.priority}\"

# Validate all URLs have required fields
invalid_urls = Enum.filter(urls, fn url ->
  is_nil(url.loc) or is_nil(url.lastmod) or
  is_nil(url.changefreq) or is_nil(url.priority)
end)

if length(invalid_urls) == 0 do
  IO.puts \"\\n✅ All URLs have required fields\"
else
  IO.puts \"\\n❌ #{length(invalid_urls)} URLs missing required fields\"
end
"
```

### Sitemap Validation Checklist

- [ ] Total URL count matches baseline (±10 for database changes)
- [ ] Static pages present (/, /about)
- [ ] Country pages present (6 countries)
- [ ] City pages present (~2,410 cities)
- [ ] Venue pages present (~4,558 venues)
- [ ] XML structure valid
- [ ] All URLs have `loc`, `lastmod`, `changefreq`, `priority`
- [ ] URL patterns match V1 format
- [ ] Priority scores appropriate (0.7-1.0)
- [ ] Changefreq values correct (daily/weekly/monthly)
- [ ] Lastmod dates recent and valid

---

## 7.2: SEO Validation

**Goal**: Verify JSON-LD schemas, meta tags, and social sharing

### Step 1: Start Development Server

```bash
source .env
mix phx.server
```

### Step 2: Test JSON-LD Schemas

**Venue Page with Events**:
1. Navigate to: `http://localhost:4003/{country}/{city}/{venue}`
2. View page source (right-click → View Page Source)
3. Find JSON-LD script tags
4. Copy Event schema JSON-LD
5. Validate at: https://search.google.com/test/rich-results
6. Copy BreadcrumbList schema
7. Validate at: https://search.google.com/test/rich-results
8. Copy LocalBusiness schema (if present)
9. Validate at: https://search.google.com/test/rich-results

**Expected Results**:
- ✅ Event schema valid (no errors)
- ✅ BreadcrumbList valid (no errors)
- ✅ LocalBusiness valid (no errors)
- ✅ Google preview shows rich results

**Test Script** (automated validation):
```bash
# Extract and validate JSON-LD from page
source .env
mix run -e "
# This requires the server to be running
# Use curl or HTTPoison to fetch page and parse JSON-LD
IO.puts \"Manual validation required - see testing steps above\"
"
```

### Step 3: Meta Tags Validation

**Test Pages**:
1. Home: `http://localhost:4003/`
2. About: `http://localhost:4003/about`
3. Country: `http://localhost:4003/{country-slug}`
4. City: `http://localhost:4003/{country-slug}/{city-slug}`
5. Venue: `http://localhost:4003/{country-slug}/{city-slug}/{venue-slug}`

**For Each Page, Verify**:
- [ ] `<title>` tag unique and descriptive
- [ ] `<meta name="description">` present and unique
- [ ] `<link rel="canonical">` matches current URL
- [ ] `<meta property="og:title">` present
- [ ] `<meta property="og:description">` present
- [ ] `<meta property="og:url">` matches current URL
- [ ] `<meta property="og:type">` appropriate (website/place)
- [ ] `<meta property="og:site_name">` = "Trivia Advisor"
- [ ] `<meta property="og:image">` present (where applicable)
- [ ] `<meta name="twitter:card">` present
- [ ] `<meta name="twitter:title">` present
- [ ] `<meta name="twitter:description">` present
- [ ] City/Venue pages have geo tags (`geo.position`, `ICBM`)

### Step 4: Social Sharing Preview

**Facebook Debugger**:
1. Go to: https://developers.facebook.com/tools/debug/
2. Enter production URL (or use ngrok for local testing)
3. Verify image, title, description display correctly

**Twitter Card Validator**:
1. Go to: https://cards-dev.twitter.com/validator
2. Enter production URL
3. Verify card preview displays correctly

### SEO Validation Checklist

#### JSON-LD Schemas
- [ ] Event schema validates (venue pages with events)
- [ ] BreadcrumbList validates (all pages)
- [ ] LocalBusiness validates (venue pages)
- [ ] All schemas pass Google Rich Results Test
- [ ] No errors or warnings in validation

#### Meta Tags
- [ ] All pages have unique titles
- [ ] All pages have unique descriptions
- [ ] Canonical URLs present and correct
- [ ] OpenGraph tags complete
- [ ] Twitter Card tags complete
- [ ] Geo tags on city and venue pages

#### Social Sharing
- [ ] Facebook preview displays correctly
- [ ] Twitter preview displays correctly
- [ ] Images load properly
- [ ] Titles and descriptions accurate

---

## 7.3: Functional Testing

**Goal**: Verify all LiveView pages and features work correctly

### Homepage Tests

```bash
# Start server
source .env
mix phx.server
# Open: http://localhost:4003/
```

**Manual Tests**:
- [ ] Page loads without errors
- [ ] Popular cities display (should show 12 cities)
- [ ] City cards render with images
- [ ] City cards link to correct URLs
- [ ] Breadcrumb shows "Home"
- [ ] Navigation header present
- [ ] Footer present
- [ ] No JavaScript console errors
- [ ] Mobile responsive (test with browser DevTools)

### About Page Tests

```
# Open: http://localhost:4003/about
```

**Manual Tests**:
- [ ] Page loads without errors
- [ ] Content displays correctly
- [ ] Breadcrumb shows "Home > About"
- [ ] Navigation and footer present
- [ ] Mobile responsive

### Country Page Tests

```
# Open: http://localhost:4003/{country-slug}
# Example: http://localhost:4003/united-states
```

**Manual Tests**:
- [ ] Page loads without errors
- [ ] Country name displays correctly
- [ ] Cities list displays
- [ ] City cards render with images
- [ ] Venue count shows per city
- [ ] Breadcrumb shows "Home > Country"
- [ ] Links work correctly
- [ ] Mobile responsive

### City Page Tests

```
# Open: http://localhost:4003/{country-slug}/{city-slug}
# Example: http://localhost:4003/united-states/new-york
```

**Manual Tests**:
- [ ] Page loads without errors
- [ ] City name and details display
- [ ] Venues list displays
- [ ] Venue cards render correctly
- [ ] Events show on venue cards
- [ ] Empty state displays when no venues (test with city with no venues)
- [ ] Breadcrumb shows "Home > Country > City"
- [ ] Links work correctly
- [ ] Mobile responsive

### Venue Page Tests

```
# Open: http://localhost:4003/{country-slug}/{city-slug}/{venue-slug}
# Test multiple venues: with events, without events, with images, without images
```

**Manual Tests**:
- [ ] Page loads without errors
- [ ] Venue name and address display
- [ ] Events list displays (if venue has events)
- [ ] Event occurrences show correctly
- [ ] Empty state displays when no events
- [ ] Venue images display (if available)
- [ ] Map coordinates shown (if available)
- [ ] Breadcrumb shows "Home > Country > City > Venue"
- [ ] All links work correctly
- [ ] Mobile responsive

### Navigation Tests

**Test All Navigation Paths**:
- [ ] Home → City → Venue navigation works
- [ ] Breadcrumb links work at each level
- [ ] Back button works correctly
- [ ] Direct URL access works for all routes

### Error Handling Tests

**Test Invalid Routes**:
```bash
# 404 scenarios
http://localhost:4003/invalid-country
http://localhost:4003/united-states/invalid-city
http://localhost:4003/united-states/new-york/invalid-venue
```

**Manual Tests**:
- [ ] Invalid country slug returns 404 or error page
- [ ] Invalid city slug returns 404 or error page
- [ ] Invalid venue slug returns 404 or error page
- [ ] Error pages display user-friendly message
- [ ] Navigation still works from error pages

### Functional Testing Checklist

#### Core Functionality
- [ ] All routes accessible and functional
- [ ] LiveView mounts successfully on all pages
- [ ] Database queries execute without errors
- [ ] Images load correctly
- [ ] Links navigate correctly
- [ ] Breadcrumbs accurate on all pages

#### User Experience
- [ ] No JavaScript console errors
- [ ] No Elixir/Phoenix errors in logs
- [ ] Fast page loads (<3s on localhost)
- [ ] Smooth LiveView updates
- [ ] Mobile responsive on all pages
- [ ] Proper empty states when no data

#### Edge Cases
- [ ] Cities with no venues display correctly
- [ ] Venues with no events display correctly
- [ ] Missing images have fallbacks
- [ ] Invalid slugs handled gracefully
- [ ] Long venue/city names don't break layout

---

## 7.4: Performance Testing

**Goal**: Verify application meets performance targets

### Step 1: Database Query Performance

```bash
# Test query performance
source .env
mix run -e "
{time_us, _} = :timer.tc(fn ->
  TriviaAdvisor.Locations.get_popular_cities(12)
end)
IO.puts \"Popular cities query: #{time_us / 1000}ms\"

{time_us, _} = :timer.tc(fn ->
  country = TriviaAdvisor.Locations.get_country_by_slug(\"united-states\")
  TriviaAdvisor.Locations.get_cities_for_country(country)
end)
IO.puts \"Cities for country query: #{time_us / 1000}ms\"

{time_us, _} = :timer.tc(fn ->
  city = TriviaAdvisor.Repo.get_by!(TriviaAdvisor.Locations.City, id: 1)
  TriviaAdvisor.Locations.find_venues_near_city(city, 50)
end)
IO.puts \"Venues near city query (PostGIS): #{time_us / 1000}ms\"
"
```

**Performance Targets**:
- Simple queries (<10 records): <100ms
- List queries (10-100 records): <200ms
- PostGIS spatial queries: <500ms

### Step 2: Page Load Time Testing

```bash
# Use curl to measure response times
source .env

# Home page
time curl -s -o /dev/null -w "%{time_total}s\n" http://localhost:4003/

# City page
time curl -s -o /dev/null -w "%{time_total}s\n" http://localhost:4003/united-states/new-york

# Venue page
time curl -s -o /dev/null -w "%{time_total}s\n" http://localhost:4003/united-states/new-york/example-venue
```

**Performance Targets**:
- Initial page load: <1s on localhost
- LiveView mount: <500ms
- Subsequent navigation: <300ms

### Step 3: Lighthouse Audit

**Prerequisites**:
```bash
npm install -g lighthouse
```

**Run Lighthouse**:
```bash
# Start server
source .env
mix phx.server

# In another terminal, run Lighthouse
lighthouse http://localhost:4003/ --output html --output-path ./lighthouse-home.html
lighthouse http://localhost:4003/united-states/new-york --output html --output-path ./lighthouse-city.html
lighthouse http://localhost:4003/united-states/new-york/example-venue --output html --output-path ./lighthouse-venue.html

# Open reports
open lighthouse-home.html
open lighthouse-city.html
open lighthouse-venue.html
```

**Performance Targets**:
- Performance Score: >90
- Accessibility Score: >90
- Best Practices Score: >90
- SEO Score: >90
- First Contentful Paint: <1.5s
- Time to Interactive: <3s
- Largest Contentful Paint: <2.5s

### Step 4: Load Testing (Optional)

**Using Apache Bench**:
```bash
# Install Apache Bench (comes with Apache)
brew install httpd  # macOS

# Test with 100 requests, 10 concurrent
ab -n 100 -c 10 http://localhost:4003/

# Test specific pages
ab -n 100 -c 10 http://localhost:4003/united-states/new-york
ab -n 50 -c 5 http://localhost:4003/united-states/new-york/example-venue
```

**Performance Targets**:
- Requests per second: >50 for simple pages
- Mean response time: <100ms
- 95th percentile: <500ms
- 0% failed requests

### Performance Testing Checklist

#### Database Performance
- [ ] Simple queries <100ms
- [ ] List queries <200ms
- [ ] PostGIS queries <500ms
- [ ] No N+1 query problems
- [ ] Proper use of preloading

#### Page Performance
- [ ] Initial load <1s (localhost)
- [ ] LiveView mount <500ms
- [ ] No slow database queries in logs
- [ ] Assets load quickly

#### Lighthouse Scores
- [ ] Performance >90
- [ ] Accessibility >90
- [ ] Best Practices >90
- [ ] SEO >90
- [ ] Core Web Vitals passing

#### Load Testing
- [ ] Handles concurrent requests
- [ ] Stable response times under load
- [ ] No memory leaks during sustained traffic
- [ ] Error rate <0.1%

---

## 7.5: Read-Only Database Validation

**Goal**: Verify database write operations are properly blocked

### Step 1: Verify Database User Permissions

```bash
# Test read operations work
source .env
mix run -e "
case TriviaAdvisor.Repo.query(\"SELECT 1 AS test\") do
  {:ok, _} -> IO.puts \"✅ Read operations work\"
  {:error, e} -> IO.puts \"❌ Read operations failed: #{inspect(e)}\"
end
"
```

### Step 2: Verify Write Operations Blocked

```bash
# Attempt INSERT (should fail)
source .env
mix run -e "
case TriviaAdvisor.Repo.query(\"INSERT INTO countries (name, slug, code, inserted_at, updated_at) VALUES ('Test', 'test', 'TS', NOW(), NOW())\") do
  {:ok, _} -> IO.puts \"❌ WARNING: Write operations not blocked!\"
  {:error, %Postgrex.Error{postgres: %{code: :insufficient_privilege}}} ->
    IO.puts \"✅ INSERT blocked (insufficient privileges)\"
  {:error, e} -> IO.puts \"⚠️ INSERT failed with: #{inspect(e)}\"
end
"
```

### Step 3: Verify UPDATE Blocked

```bash
# Attempt UPDATE (should fail)
source .env
mix run -e "
case TriviaAdvisor.Repo.query(\"UPDATE countries SET name = 'Test' WHERE id = 1\") do
  {:ok, _} -> IO.puts \"❌ WARNING: UPDATE operations not blocked!\"
  {:error, %Postgrex.Error{postgres: %{code: :insufficient_privilege}}} ->
    IO.puts \"✅ UPDATE blocked (insufficient privileges)\"
  {:error, e} -> IO.puts \"⚠️ UPDATE failed with: #{inspect(e)}\"
end
"
```

### Step 4: Verify DELETE Blocked

```bash
# Attempt DELETE (should fail)
source .env
mix run -e "
case TriviaAdvisor.Repo.query(\"DELETE FROM countries WHERE id = 999999\") do
  {:ok, _} -> IO.puts \"❌ WARNING: DELETE operations not blocked!\"
  {:error, %Postgrex.Error{postgres: %{code: :insufficient_privilege}}} ->
    IO.puts \"✅ DELETE blocked (insufficient privileges)\"
  {:error, e} -> IO.puts \"⚠️ DELETE failed with: #{inspect(e)}\"
end
"
```

### Step 5: Verify No Migrations in Codebase

```bash
# Check for migration files
if [ -d "priv/repo/migrations" ] && [ "$(ls -A priv/repo/migrations)" ]; then
  echo "❌ WARNING: Migration files found in priv/repo/migrations/"
  ls -la priv/repo/migrations/
else
  echo "✅ No migration files present (read-only consumer)"
fi
```

### Read-Only Validation Checklist

- [ ] Read operations (SELECT) work successfully
- [ ] Write operations (INSERT) blocked with insufficient_privilege error
- [ ] Update operations (UPDATE) blocked
- [ ] Delete operations (DELETE) blocked
- [ ] No migration files in `priv/repo/migrations/`
- [ ] Application never attempts write operations
- [ ] Database user has `pg_read_all_data` role only
- [ ] No accidental schema modifications possible

---

## Phase 7 Summary Report Template

After completing all testing, create a summary report:

```markdown
# Phase 7: Testing & Validation - Completion Report

**Date Completed**: YYYY-MM-DD
**Tested By**: [Your Name]

## Sitemap Validation Results

- Total URLs Generated: X,XXX
- Static Pages: X
- Country Pages: X
- City Pages: X,XXX
- Venue Pages: X,XXX
- **Status**: ✅ PASS / ❌ FAIL

## SEO Validation Results

### JSON-LD Schemas
- Event Schema: ✅ PASS / ❌ FAIL
- BreadcrumbList Schema: ✅ PASS / ❌ FAIL
- LocalBusiness Schema: ✅ PASS / ❌ FAIL

### Meta Tags
- All pages have unique titles: ✅ / ❌
- Meta descriptions present: ✅ / ❌
- OpenGraph tags complete: ✅ / ❌
- Twitter Cards working: ✅ / ❌

## Functional Testing Results

- Home Page: ✅ PASS / ❌ FAIL
- About Page: ✅ PASS / ❌ FAIL
- Country Pages: ✅ PASS / ❌ FAIL
- City Pages: ✅ PASS / ❌ FAIL
- Venue Pages: ✅ PASS / ❌ FAIL
- Navigation: ✅ PASS / ❌ FAIL
- Error Handling: ✅ PASS / ❌ FAIL

## Performance Testing Results

### Database Performance
- Simple queries: XX ms (target: <100ms)
- List queries: XX ms (target: <200ms)
- PostGIS queries: XX ms (target: <500ms)

### Lighthouse Scores
- Performance: XX/100 (target: >90)
- Accessibility: XX/100 (target: >90)
- Best Practices: XX/100 (target: >90)
- SEO: XX/100 (target: >90)

## Read-Only Database Validation

- Read operations: ✅ PASS / ❌ FAIL
- Write blocking: ✅ PASS / ❌ FAIL
- No migrations: ✅ PASS / ❌ FAIL

## Issues Found

1. [Issue description]
   - Severity: Critical / High / Medium / Low
   - Status: Fixed / In Progress / Deferred
   - Resolution: [How it was resolved]

2. [Issue description]
   ...

## Recommendations

1. [Recommendation for improvement]
2. [Recommendation for optimization]
3. [Recommendation for monitoring]

## Ready for Production?

- [ ] All critical tests passing
- [ ] All high-severity issues resolved
- [ ] Performance targets met
- [ ] SEO validation complete
- [ ] Read-only database confirmed

**Decision**: ✅ READY FOR PRODUCTION / ⚠️ NEEDS WORK / ❌ NOT READY

## Next Steps

1. [Next action item]
2. [Next action item]
3. [Next action item]
```

---

## Quick Test Script

Create a bash script for quick validation:

```bash
#!/bin/bash
# test.sh - Quick validation script

echo "=== Trivia Advisor V2 - Quick Validation ==="
echo ""

# Check environment
if [ -z "$SUPABASE_DATABASE_URL" ]; then
  echo "❌ SUPABASE_DATABASE_URL not set. Run: source .env"
  exit 1
fi

echo "✅ Environment configured"
echo ""

# Test database connectivity
echo "Testing database connectivity..."
mix run -e "
case TriviaAdvisor.Repo.query(\"SELECT 1\") do
  {:ok, _} -> IO.puts \"✅ Database connected\"
  {:error, e} -> IO.puts \"❌ Database error: #{inspect(e)}\"
end
" || exit 1

echo ""

# Test sitemap generation
echo "Testing sitemap generation..."
mix run -e "
urls = TriviaAdvisor.Sitemap.generate()
IO.puts \"✅ Generated #{length(urls)} URLs\"
" || exit 1

echo ""

# Test read-only enforcement
echo "Testing read-only enforcement..."
mix run -e "
case TriviaAdvisor.Repo.query(\"INSERT INTO countries (name, slug, code, inserted_at, updated_at) VALUES ('Test', 'test', 'TS', NOW(), NOW())\") do
  {:error, %Postgrex.Error{postgres: %{code: :insufficient_privilege}}} ->
    IO.puts \"✅ Write operations blocked\"
  {:ok, _} ->
    IO.puts \"❌ WARNING: Write operations not blocked!\"
    System.halt(1)
  {:error, e} ->
    IO.puts \"⚠️ Unexpected error: #{inspect(e)}\"
end
" || exit 1

echo ""
echo "=== Quick Validation Complete ==="
echo "Run full Phase 7 tests for comprehensive validation"
```

**Make executable and run**:
```bash
chmod +x test.sh
source .env && ./test.sh
```

---

## Notes

- All tests should be run with `MIX_ENV=dev` (default) for local testing
- Some tests require the Phoenix server to be running
- Performance metrics will be slower on localhost than production
- Social sharing tests may require ngrok or production URL
- Load testing is optional but recommended before production launch

**Estimated Time**:
- Sitemap Validation: 1-2 hours
- SEO Validation: 2-3 hours
- Functional Testing: 4-6 hours
- Performance Testing: 2-3 hours
- Read-Only Validation: 30 minutes
- **Total: 10-15 hours (2 days)**
