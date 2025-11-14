# Performance Optimization: 4-Phase Implementation Plan

**Status**: Ready for Implementation
**Priority**: Critical (All pages load slowly)
**Estimated Impact**: 5-10x performance improvement across all pages
**Estimated Effort**: 8-12 hours total implementation

---

## Executive Summary

Current performance analysis reveals significant bottlenecks across all 4 major pages:

- **Homepage**: 5 uncached queries including 3 full table scans on every load
- **Cities Index/Search**: N+1 query pattern and uncached search queries
- **City Show Page**: 2 uncached aggregation queries
- **Venue Show Page**: Expensive PostGIS spatial query without caching or indexes

**Root Causes**:
1. Missing ConCache implementation for frequently-accessed data
2. Missing database indexes on foreign keys and search columns
3. Missing PostGIS spatial indexes for location-based queries
4. N+1 query patterns in cities index page

**Expected Improvements**:
- Homepage: ~3-5s → ~200-500ms (10x faster)
- Cities Index: ~2-3s → ~300-600ms (5x faster)
- City Show: ~1-2s → ~200-400ms (5x faster)
- Venue Show: ~2-4s → ~300-700ms (6x faster)

---

## Phase 1: Homepage Performance (CRITICAL - Highest Impact)

### Current Performance Issues

**File**: `lib/trivia_advisor_web/live/home_live.ex:14-22`

**5 Uncached Queries on Every Page Load**:
1. `get_popular_cities(6)` - Joins PublicEvent, uses DISTINCT
2. `get_latest_venues(4)` - Complex DISTINCT query on venue_id
3. `count_venues_with_trivia()` - Full table scan with DISTINCT on venues
4. `count_cities_with_trivia()` - Full table scan with DISTINCT on cities
5. `count_countries_with_trivia()` - Full table scan with DISTINCT on countries

**Why This Is Slow**:
- All 5 queries run sequentially on every homepage visit
- COUNT queries scan entire PublicEvent table (could be thousands/millions of rows)
- No caching means database hit every single time
- DISTINCT operations are expensive without proper indexes

### Solutions

#### 1.1 Add Caching to `get_popular_cities/2`

**File**: `lib/trivia_advisor/locations.ex:191-208`

**Current Code** (lines 191-208):
```elixir
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
```

**New Code** (add caching):
```elixir
def get_popular_cities(limit \\ 20, opts \\ []) do
  country_id = Keyword.get(opts, :country_id)
  cache_key = "popular_cities_#{limit}_#{country_id}"

  ConCache.get_or_store(:city_cache, cache_key, fn ->
    query =
      from c in City,
        join: te in PublicEvent, on: te.city_id == c.id,
        where: c.discovery_enabled == true,
        distinct: true,
        order_by: c.name,
        limit: ^limit,
        preload: [:country]

    query =
      case country_id do
        nil -> query
        country_id -> where(query, [c], c.country_id == ^country_id)
      end

    Repo.all(query)
  end)
end
```

#### 1.2 Add Caching to `get_latest_venues/1`

**File**: `lib/trivia_advisor/locations.ex:511-560`

**Current Code** (lines 511-560):
```elixir
def get_latest_venues(limit \\ 20) do
  Repo.all(
    from te in PublicEvent,
      distinct: te.venue_id,
      order_by: [te.venue_id, desc: te.updated_at],
      limit: ^limit,
      select: %{
        # ... large select map
      }
  )
end
```

**New Code** (add caching):
```elixir
def get_latest_venues(limit \\ 20) do
  ConCache.get_or_store(:city_cache, "latest_venues_#{limit}", fn ->
    Repo.all(
      from te in PublicEvent,
        distinct: te.venue_id,
        order_by: [te.venue_id, desc: te.updated_at],
        limit: ^limit,
        select: %{
          # ... existing select map unchanged
        }
    )
  end)
end
```

#### 1.3 Add Caching to Statistics Queries

**File**: `lib/trivia_advisor/locations.ex:790-818`

**Current Code** (lines 790-818):
```elixir
def count_venues_with_trivia do
  Repo.one(
    from v in Venue,
      join: te in PublicEvent, on: te.venue_id == v.id,
      select: count(v.id, :distinct)
  )
end

def count_cities_with_trivia do
  Repo.one(
    from c in City,
      join: te in PublicEvent, on: te.city_id == c.id,
      select: count(c.id, :distinct)
  )
end

def count_countries_with_trivia do
  Repo.one(
    from c in Country,
      join: te in PublicEvent, on: te.country_id == c.id,
      select: count(c.id, :distinct)
  )
end
```

**New Code** (add caching with 15-minute TTL):
```elixir
def count_venues_with_trivia do
  ConCache.get_or_store(:city_cache, "stats_venue_count", fn ->
    Repo.one(
      from v in Venue,
        join: te in PublicEvent, on: te.venue_id == v.id,
        select: count(v.id, :distinct)
    )
  end)
end

def count_cities_with_trivia do
  ConCache.get_or_store(:city_cache, "stats_city_count", fn ->
    Repo.one(
      from c in City,
        join: te in PublicEvent, on: te.city_id == c.id,
        select: count(c.id, :distinct)
    )
  end)
end

def count_countries_with_trivia do
  ConCache.get_or_store(:city_cache, "stats_country_count", fn ->
    Repo.one(
      from c in Country,
        join: te in PublicEvent, on: te.country_id == c.id,
        select: count(c.id, :distinct)
    )
  end)
end
```

#### 1.4 Add Database Indexes

**Rationale**: All queries join on `PublicEvent` foreign keys. Adding indexes will dramatically speed up these joins and DISTINCT operations.

**Create new file**: `create_indexes.sql` or add via `psql`

```sql
-- Index on PublicEvent foreign keys for faster joins
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_public_events_city_id
  ON public_events(city_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_public_events_venue_id
  ON public_events(venue_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_public_events_country_id
  ON public_events(country_id);

-- Index on City for discovery_enabled filter
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cities_discovery_enabled
  ON cities(discovery_enabled) WHERE discovery_enabled = true;
```

**Note**: Use `CONCURRENTLY` to avoid locking tables in production.

### Expected Improvements

**Before**: ~3-5 seconds (5 sequential database queries)
**After**: ~200-500ms (cached data with 15-minute TTL)
**Improvement**: **10x faster**

### Testing

```bash
# 1. Clear cache and test cold load
iex -S mix
ConCache.delete(:city_cache, "popular_cities_6_")
ConCache.delete(:city_cache, "latest_venues_4")
ConCache.delete(:city_cache, "stats_venue_count")
ConCache.delete(:city_cache, "stats_city_count")
ConCache.delete(:city_cache, "stats_country_count")

# 2. Time first load (cold cache)
:timer.tc(fn -> TriviaAdvisor.Locations.get_popular_cities(6) end)
# Should be ~500-1000ms initially

# 3. Time second load (warm cache)
:timer.tc(fn -> TriviaAdvisor.Locations.get_popular_cities(6) end)
# Should be <10ms from cache

# 4. Verify indexes created
psql -d trivia_advisor_dev -c "\d public_events"
# Should show indexes on city_id, venue_id, country_id
```

---

## Phase 2: Cities Index/Search Performance

### Current Performance Issues

**File**: `lib/trivia_advisor_web/live/cities_index_live.ex:18-39`

**Problems**:
1. **N+1 Query Pattern**: Calls `list_countries()` then loops calling `list_cities_for_country()` for each country
2. **Uncached Search**: `search_cities(query)` joins PublicEvent on every autocomplete keystroke
3. **Missing Index**: City name searches use ILIKE without index

**File**: `lib/trivia_advisor/locations.ex:228-239`

**search_cities/1 runs on every keystroke** (with 300ms debounce):
```elixir
def search_cities(query) when is_binary(query) do
  search_pattern = "%#{query}%"

  Repo.all(
    from c in City,
      join: te in PublicEvent, on: te.city_id == c.id,
      where: ilike(c.name, ^search_pattern),
      distinct: true,
      order_by: c.name,
      preload: [:country]
  )
end
```

### Solutions

#### 2.1 Fix N+1 Query Pattern in Cities Index

**File**: `lib/trivia_advisor_web/live/cities_index_live.ex:18-39`

**Current Code**:
```elixir
cities_by_country =
  if search_query && String.trim(search_query) != "" do
    cities = Locations.search_cities(search_query)
    cities
    |> Enum.group_by(& &1.country)
    |> Enum.map(fn {country, cities} -> {country, cities} end)
    |> Enum.sort_by(fn {country, _cities} -> country.name end)
  else
    # N+1 PROBLEM: Fetches countries, then queries for each country's cities
    countries = Locations.list_countries()

    countries
    |> Enum.map(fn country ->
      cities = Locations.list_cities_for_country(country.id)  # N queries!
      {country, cities}
    end)
    |> Enum.filter(fn {_country, cities} -> !Enum.empty?(cities) end)
    |> Enum.sort_by(fn {country, _cities} -> country.name end)
  end
```

**New Code** (batch load all cities at once):
```elixir
cities_by_country =
  if search_query && String.trim(search_query) != "" do
    cities = Locations.search_cities(search_query)
    cities
    |> Enum.group_by(& &1.country)
    |> Enum.map(fn {country, cities} -> {country, cities} end)
    |> Enum.sort_by(fn {country, _cities} -> country.name end)
  else
    # FIXED: Single query to get all cities with countries preloaded
    Locations.list_all_cities_grouped_by_country()
  end
```

#### 2.2 Add New Function to Batch Load Cities

**File**: `lib/trivia_advisor/locations.ex` (add new function after line 249)

```elixir
@doc """
Lists all cities with trivia events, grouped by country.
Single query with preload to avoid N+1 pattern.
Cached for 15 minutes.
"""
def list_all_cities_grouped_by_country do
  ConCache.get_or_store(:city_cache, "all_cities_by_country", fn ->
    # Single query: get all cities with country preloaded
    cities =
      Repo.all(
        from c in City,
          join: te in PublicEvent, on: te.city_id == c.id,
          distinct: true,
          order_by: c.name,
          preload: [:country]
      )

    # Group in memory (fast since all data already loaded)
    cities
    |> Enum.group_by(& &1.country)
    |> Enum.map(fn {country, cities} -> {country, cities} end)
    |> Enum.filter(fn {_country, cities} -> !Enum.empty?(cities) end)
    |> Enum.sort_by(fn {country, _cities} -> country.name end)
  end)
end
```

#### 2.3 Add Caching to Search Queries

**File**: `lib/trivia_advisor/locations.ex:228-239`

**New Code** (add simple caching for autocomplete):
```elixir
def search_cities(query) when is_binary(query) do
  # Normalize query for cache key (lowercase, trim)
  normalized_query = String.downcase(String.trim(query))
  cache_key = "city_search_#{normalized_query}"

  ConCache.get_or_store(:city_cache, cache_key, fn ->
    search_pattern = "%#{query}%"

    Repo.all(
      from c in City,
        join: te in PublicEvent, on: te.city_id == c.id,
        where: ilike(c.name, ^search_pattern),
        distinct: true,
        order_by: c.name,
        preload: [:country]
    )
  end)
end
```

#### 2.4 Add Database Index for City Name Searches

**SQL**:
```sql
-- Trigram index for fast ILIKE searches on city names
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cities_name_trgm
  ON cities USING gin(name gin_trgm_ops);

-- Regular index on city name for exact matches and sorting
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cities_name
  ON cities(name);
```

**Rationale**:
- `pg_trgm` (trigram) indexes make ILIKE queries extremely fast
- Supports partial matching like `ILIKE '%lon%'` efficiently

### Expected Improvements

**Before**: ~2-3 seconds (N+1 queries + uncached search)
**After**: ~300-600ms (single cached query)
**Improvement**: **5x faster**

### Testing

```elixir
# Test batch load vs N+1
:timer.tc(fn -> TriviaAdvisor.Locations.list_all_cities_grouped_by_country() end)
# Should be ~300-500ms first time, <10ms cached

# Test search with index
:timer.tc(fn -> TriviaAdvisor.Locations.search_cities("lon") end)
# Should be <100ms with trigram index
```

---

## Phase 3: City Show Page Performance

### Current Performance Issues

**File**: `lib/trivia_advisor_web/live/city_show_live.ex:51-65`

**Uncached Queries on Every Page Load**:
1. `list_venues_for_city(city_id, opts)` - **CACHED** ✓ (good!)
2. `get_day_counts_for_city(city_id)` - **NOT CACHED**, groups by day_of_week
3. `get_suburbs_for_city(city_id)` - **NOT CACHED**, extracts and counts suburbs

**Why This Is Slow**:
- Day counts and suburb queries run on every page load
- Both queries are deterministic (same city_id = same results)
- Perfect candidates for caching

### Solutions

#### 3.1 Add Caching to `get_day_counts_for_city/1`

**File**: `lib/trivia_advisor/locations.ex:694-706`

**Current Code**:
```elixir
def get_day_counts_for_city(city_id) do
  results =
    Repo.all(
      from te in PublicEvent,
        where: te.city_id == ^city_id,
        group_by: te.day_of_week,
        select: {te.day_of_week, count(te.id)}
    )

  Map.new(results)
end
```

**New Code** (add caching):
```elixir
def get_day_counts_for_city(city_id) do
  ConCache.get_or_store(:city_cache, "day_counts_#{city_id}", fn ->
    results =
      Repo.all(
        from te in PublicEvent,
          where: te.city_id == ^city_id,
          group_by: te.day_of_week,
          select: {te.day_of_week, count(te.id)}
      )

    Map.new(results)
  end)
end
```

#### 3.2 Add Caching to `get_suburbs_for_city/1`

**File**: `lib/trivia_advisor/locations.ex:749-766`

**Current Code**:
```elixir
def get_suburbs_for_city(city_id) do
  venue_names =
    Repo.all(
      from te in PublicEvent,
        where: te.city_id == ^city_id,
        distinct: te.venue_id,
        select: te.venue_name
    )

  venue_names
  |> Enum.map(&extract_suburb_from_venue_name/1)
  |> Enum.reject(&is_nil/1)
  |> Enum.frequencies()
  |> Enum.map(fn {suburb, count} -> %{suburb: suburb, count: count} end)
  |> Enum.sort_by(& &1.count, :desc)
end
```

**New Code** (add caching):
```elixir
def get_suburbs_for_city(city_id) do
  ConCache.get_or_store(:city_cache, "suburbs_#{city_id}", fn ->
    venue_names =
      Repo.all(
        from te in PublicEvent,
          where: te.city_id == ^city_id,
          distinct: te.venue_id,
          select: te.venue_name
      )

    venue_names
    |> Enum.map(&extract_suburb_from_venue_name/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.map(fn {suburb, count} -> %{suburb: suburb, count: count} end)
    |> Enum.sort_by(& &1.count, :desc)
  end)
end
```

### Expected Improvements

**Before**: ~1-2 seconds (2 uncached aggregation queries)
**After**: ~200-400ms (cached aggregations)
**Improvement**: **5x faster**

### Testing

```elixir
# Test day counts caching
ConCache.delete(:city_cache, "day_counts_53")  # London
:timer.tc(fn -> TriviaAdvisor.Locations.get_day_counts_for_city(53) end)
# First: ~200-300ms, Second: <5ms

# Test suburbs caching
ConCache.delete(:city_cache, "suburbs_53")
:timer.tc(fn -> TriviaAdvisor.Locations.get_suburbs_for_city(53) end)
# First: ~150-250ms, Second: <5ms
```

---

## Phase 4: Venue Show Page Performance

### Current Performance Issues

**File**: `lib/trivia_advisor_web/live/venue_show_live.ex:58-59`
**File**: `lib/trivia_advisor/events.ex:263-330`

**Expensive Spatial Query**:
```elixir
def get_nearby_trivia_venues(venue, radius_km \\ 5)
```

**Why This Is VERY Slow**:
- Joins 4 tables: PublicEvent, Venue, City, Country
- Uses PostGIS spatial functions: `ST_DWithin`, `ST_Distance`
- GROUP BY on 3 tables
- **No caching** - runs on every page load
- **No spatial indexes** - PostGIS queries are slow without GIST indexes

### Solutions

#### 4.1 Add Spatial Index on Venue Coordinates

**SQL**:
```sql
-- Create PostGIS spatial index (GIST) on venue coordinates
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_venues_location
  ON venues USING gist(
    ST_MakePoint(
      CAST(longitude AS double precision),
      CAST(latitude AS double precision)
    )
  )
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
```

**Rationale**:
- GIST (Generalized Search Tree) indexes are designed for PostGIS spatial queries
- Makes `ST_DWithin` and `ST_Distance` queries 10-100x faster
- Only indexes venues with valid coordinates

#### 4.2 Add Caching to `get_nearby_trivia_venues/2`

**File**: `lib/trivia_advisor/events.ex:263-330`

**Current Code** (lines 263-330):
```elixir
def get_nearby_trivia_venues(venue, radius_km \\ 5)
    when not is_nil(venue.latitude) and not is_nil(venue.longitude) do
  lat = if is_float(venue.latitude), do: venue.latitude, else: Float.parse("#{venue.latitude}") |> elem(0)
  lon = if is_float(venue.longitude), do: venue.longitude, else: Float.parse("#{venue.longitude}") |> elem(0)
  radius_meters = radius_km * 1000

  results = Repo.all(
    # ... complex query with 4-table join and PostGIS functions
  )

  results
end
```

**New Code** (add caching):
```elixir
def get_nearby_trivia_venues(venue, radius_km \\ 5)
    when not is_nil(venue.latitude) and not is_nil(venue.longitude) do
  # Cache key includes venue ID and radius
  cache_key = "nearby_venues_#{venue.id}_#{radius_km}km"

  ConCache.get_or_store(:city_cache, cache_key, fn ->
    lat = if is_float(venue.latitude), do: venue.latitude, else: Float.parse("#{venue.latitude}") |> elem(0)
    lon = if is_float(venue.longitude), do: venue.longitude, else: Float.parse("#{venue.longitude}") |> elem(0)
    radius_meters = radius_km * 1000

    results = Repo.all(
      from e in PublicEvent,
        join: v in TriviaAdvisor.Locations.Venue, on: e.venue_id == v.id,
        join: c in TriviaAdvisor.Locations.City, on: v.city_id == c.id,
        join: co in TriviaAdvisor.Locations.Country, on: c.country_id == co.id,
        where: v.id != ^venue.id,
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
        group_by: [v.id, c.id, co.id],
        select: %{
          venue_id: v.id,
          venue_name: v.name,
          venue_slug: v.slug,
          venue_address: v.address,
          venue_latitude: v.latitude,
          venue_longitude: v.longitude,
          venue_images: v.venue_images,
          venue_type: v.venue_type,
          city_id: c.id,
          city_name: c.name,
          city_slug: c.slug,
          city_images: c.unsplash_gallery,
          country_name: co.name,
          day_of_week: fragment("MIN(?)", e.day_of_week),
          distance_km:
            fragment(
              "ROUND(CAST(ST_Distance(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography) / 1000 AS NUMERIC), 1)",
              ^lon,
              ^lat,
              v.longitude,
              v.latitude
            )
        },
        order_by:
          fragment(
            "ST_Distance(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography)",
            v.longitude,
            v.latitude,
            ^lon,
            ^lat
          ),
        limit: 3
    )

    results
  end)
end
```

### Expected Improvements

**Before**: ~2-4 seconds (expensive PostGIS query with 4-table join)
**After**: ~300-700ms first load (with spatial index), <10ms cached
**Improvement**: **6x faster** (first load), **200x faster** (cached)

### Testing

```sql
-- 1. Verify spatial index created
\d venues
-- Should show: idx_venues_location | gist

-- 2. Test query with EXPLAIN ANALYZE
EXPLAIN ANALYZE
SELECT v.id, v.name,
  ST_Distance(
    ST_MakePoint(v.longitude, v.latitude)::geography,
    ST_MakePoint(-0.1276, 51.5074)::geography
  ) / 1000 AS distance_km
FROM venues v
WHERE v.latitude IS NOT NULL
  AND v.longitude IS NOT NULL
  AND ST_DWithin(
    ST_MakePoint(v.longitude, v.latitude)::geography,
    ST_MakePoint(-0.1276, 51.5074)::geography,
    5000
  )
ORDER BY distance_km
LIMIT 3;

-- Should show "Index Scan using idx_venues_location"
```

```elixir
# Test caching
venue = TriviaAdvisor.Locations.get_venue_by_slug("some-venue-slug")
ConCache.delete(:city_cache, "nearby_venues_#{venue.id}_5km")

:timer.tc(fn -> TriviaAdvisor.Events.get_nearby_trivia_venues(venue, 5) end)
# First: ~500-1000ms with spatial index
# Second: <10ms from cache
```

---

## Implementation Checklist

### Database Preparation
- [ ] Connect to database: `psql trivia_advisor_dev`
- [ ] Enable PostGIS extension (if not already): `CREATE EXTENSION IF NOT EXISTS postgis;`
- [ ] Enable pg_trgm extension: `CREATE EXTENSION IF NOT EXISTS pg_trgm;`

### Phase 1: Homepage (2-3 hours)
- [ ] Add caching to `get_popular_cities/2`
- [ ] Add caching to `get_latest_venues/1`
- [ ] Add caching to `count_venues_with_trivia/0`
- [ ] Add caching to `count_cities_with_trivia/0`
- [ ] Add caching to `count_countries_with_trivia/0`
- [ ] Create indexes on `public_events(city_id, venue_id, country_id)`
- [ ] Create index on `cities(discovery_enabled)`
- [ ] Test homepage load time (target: <500ms)

### Phase 2: Cities Index/Search (2-3 hours)
- [ ] Create `list_all_cities_grouped_by_country/0` function
- [ ] Update `cities_index_live.ex` to use batch loading
- [ ] Add caching to `search_cities/1`
- [ ] Create trigram index on `cities(name)`
- [ ] Create regular index on `cities(name)`
- [ ] Test cities index page load time (target: <600ms)
- [ ] Test autocomplete search speed (target: <100ms)

### Phase 3: City Show Page (1-2 hours)
- [ ] Add caching to `get_day_counts_for_city/1`
- [ ] Add caching to `get_suburbs_for_city/1`
- [ ] Test city show page load time (target: <400ms)
- [ ] Test day filter and suburb filter performance

### Phase 4: Venue Show Page (2-3 hours)
- [ ] Create spatial GIST index on `venues(latitude, longitude)`
- [ ] Add caching to `get_nearby_trivia_venues/2`
- [ ] Test venue show page load time (target: <700ms first, <50ms cached)
- [ ] Verify `EXPLAIN ANALYZE` shows index usage

### Final Validation
- [ ] Run full test suite: `mix test`
- [ ] Check ConCache configuration in `application.ex`
- [ ] Verify cache TTL is 15 minutes (900 seconds)
- [ ] Load test all 4 pages with browser devtools
- [ ] Document cache invalidation strategy (if needed)

---

## Performance Testing Strategy

### Baseline Measurements (Before Optimization)

```bash
# 1. Start server
mix phx.server

# 2. Open browser devtools (Network tab)
# 3. Record load times for each page:
#    - Homepage: _________ ms
#    - Cities Index: _________ ms
#    - City Show (London): _________ ms
#    - Venue Show: _________ ms
```

### Post-Implementation Measurements

```bash
# 1. Clear all caches
iex -S mix
ConCache.ets(:city_cache) |> :ets.delete_all_objects()

# 2. Test cold cache performance (first load)
# 3. Test warm cache performance (second load)
# 4. Compare with baseline
```

### Automated Performance Testing

```elixir
# Add to test/performance/page_load_test.exs
defmodule TriviaAdvisorWeb.Performance.PageLoadTest do
  use ExUnit.Case

  test "homepage loads under 500ms (warm cache)" do
    # Warm up cache
    TriviaAdvisor.Locations.get_popular_cities(6)

    # Measure
    {time_us, _result} = :timer.tc(fn ->
      TriviaAdvisor.Locations.get_popular_cities(6)
      TriviaAdvisor.Locations.get_latest_venues(4)
      TriviaAdvisor.Locations.count_venues_with_trivia()
      TriviaAdvisor.Locations.count_cities_with_trivia()
      TriviaAdvisor.Locations.count_countries_with_trivia()
    end)

    time_ms = time_us / 1000
    assert time_ms < 500, "Homepage queries took #{time_ms}ms (target: <500ms)"
  end
end
```

---

## Cache Invalidation Strategy

**Current TTL**: 15 minutes (900 seconds) via ConCache configuration

**When to Invalidate Cache Manually**:
1. After data imports from Eventasaurus
2. After venue/city updates
3. When statistics seem stale

**Manual Cache Clear**:
```elixir
# Clear all caches
ConCache.ets(:city_cache) |> :ets.delete_all_objects()

# Clear specific cache keys
ConCache.delete(:city_cache, "popular_cities_6_")
ConCache.delete(:city_cache, "stats_venue_count")
```

**Future Enhancement**: Add cache invalidation hooks in data import process.

---

## Risk Assessment

**Low Risk**:
- Adding ConCache (already used in project)
- Adding database indexes with CONCURRENTLY (non-blocking)
- Caching read-only queries

**Medium Risk**:
- Changing N+1 query pattern (requires testing all cities index scenarios)
- Spatial index creation (test on staging first)

**Mitigation**:
1. Test all changes in development environment first
2. Use `CONCURRENTLY` for all index creation to avoid table locks
3. Keep old query code commented out for easy rollback
4. Monitor cache hit rates with ConCache stats
5. Add performance tests to catch regressions

---

## Success Metrics

**Primary Metrics**:
- Homepage load time: <500ms (currently ~3-5s)
- Cities index load time: <600ms (currently ~2-3s)
- City show load time: <400ms (currently ~1-2s)
- Venue show load time: <700ms (currently ~2-4s)

**Secondary Metrics**:
- Cache hit rate: >90% for popular pages
- Database query count: Reduced by 80%+
- User-perceived performance: Improved page responsiveness

**Monitoring**:
```elixir
# Check cache stats
ConCache.size(:city_cache)
ConCache.ets(:city_cache) |> :ets.info()
```

---

## Next Steps After Implementation

1. **Monitor Performance**: Use Phoenix LiveDashboard or AppSignal to track query times
2. **Optimize Images**: Implement lazy loading and CDN for venue/city images
3. **Add ETS for Hot Data**: Consider ETS for extremely hot paths (stats counters)
4. **Database Connection Pooling**: Verify Repo pool size is appropriate for load
5. **Consider Fragment Caching**: Cache rendered HTML fragments in LiveView for even faster renders

---

## References

- **Phoenix LiveView Performance**: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html
- **Ecto Query Optimization**: https://hexdocs.pm/ecto/Ecto.Query.html
- **ConCache Documentation**: https://hexdocs.pm/con_cache/ConCache.html
- **PostgreSQL Indexing**: https://www.postgresql.org/docs/current/indexes.html
- **PostGIS Performance**: https://postgis.net/docs/performance_tips.html
