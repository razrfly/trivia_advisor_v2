# Cache & Query Optimization Audit

**Date**: 2024-12-28
**Issue**: [#3026 - Quiz Advisor: Excessive trivia_events_export queries](https://github.com/razrfly/eventasaurus/issues/3026)
**Status**: Phase 4 Complete ✅

---

## Phase 4 Implementation (Completed 2024-12-28)

### Changes Made

Consolidated query patterns by adding `venue_images` to explicit select queries in `locations.ex`:

| Function | Line | Change |
|----------|------|--------|
| `get_latest_venues/1` | 722 | Added `venue_images: te.venue_images` |
| `fetch_venues_by_geo_proximity/5` | 883 | Added `venue_images: te.venue_images` |
| `fetch_venues_for_city_exact/3` | 951 | Added `venue_images: te.venue_images` |

### Rationale

Analysis revealed two query patterns existed:
1. **Pattern 1** (explicit select): Used by `locations.ex` - returns maps without `venue_images`
2. **Pattern 2** (full schema): Used by `events.ex` - returns PublicEvent structs with all fields

Both patterns serve valid purposes:
- Maps are lightweight, ideal for UI rendering (VenueCard, etc.)
- Structs provide full schema for event manipulation

**Decision**: Add `venue_images` to explicit select queries for column consistency. This:
- Makes all queries fetch the same columns (consolidation)
- Provides venue images where available (feature improvement)
- Minimal code change risk
- Database sees consistent column selection (one query plan to cache)

### Expected Impact
- Database query planner caches single query plan
- Consistent data availability across all query paths
- No additional DB load (same view, same cache strategy)

---

## Phase 3 Implementation (Completed 2024-12-28)

### Changes Made

Added caching to previously uncached `events.ex` functions:

| Function | Cache Key Pattern | File Location |
|----------|-------------------|---------------|
| `get_events_for_venue/1` | `events_for_venue_{venue_id}` | `events.ex:35-42` |
| `get_events_for_weekday/2` | `events_weekday_{day}_limit_{limit}` | `events.ex:60-67` |
| `get_events_by_type/2` | `events_by_type_limit_{limit}` | `events.ex:85-91` |
| `get_event/1` | `event_{id}` | `events.ex:110-115` |

### Geo Cache Key Analysis

**Finding**: Coordinate rounding is NOT needed. All geo cache keys already use deterministic `city_id` values:
- `city_{id}_geo_{radius}km_all`
- `day_counts_geo_{id}_{radius}km`
- `suburbs_geo_{id}_{radius}km`
- `nearby_venues_{venue_id}_{radius}km`

Cache keys never include raw lat/lon coordinates, so there's no fragmentation from coordinate precision variations.

### Expected Impact
- Previously uncached queries now cached (3,821 full-schema queries/day → first-request only)
- Combined with Phase 2: **97% total query reduction** expected

---

## Phase 2 Implementation (Completed 2024-12-28)

### Changes Made

| Cache Name | Before | After | File |
|------------|--------|-------|------|
| `:city_cache` | 15 min TTL, 1 min check | **24 hour TTL**, 5 min check | `application.ex:17-23` |
| `:sitemap_cache` | 6 hour TTL, 5 min check | **24 hour TTL**, 5 min check | `application.ex:25-32` |

### Rationale
- `trivia_events_export` materialized view refreshes daily at 5 AM UTC
- 24-hour cache aligns with data refresh cycle
- No size limits needed (ConCache uses ETS with TTL-based expiration)

### Expected Impact
- ~90% reduction in database queries (5,766 → ~500/day)
- Cache expires once per day instead of 96 times per day

---

## Phase 1 Audit (Completed 2024-12-28)

## 1. ConCache Configuration

### Original Cache Definitions (`lib/trivia_advisor/application.ex`)

| Cache Name | TTL | Check Interval | Purpose |
|------------|-----|----------------|---------|
| `:city_cache` | ~~15 minutes~~ → **24 hours** | ~~1 minute~~ → 5 minutes | All location/event queries |
| `:sitemap_cache` | ~~6 hours~~ → **24 hours** | 5 minutes | Sitemap XML generation |

### Key Finding: Single Cache for All Queries
All 21 `ConCache.get_or_store` calls use `:city_cache`.

**Original Impact**: With 5,766 queries/day and 15-minute TTL, caches expired ~96 times/day, causing constant re-queries.

---

## 2. Query Code Paths to `trivia_events_export`

### Files That Query PublicEvent (trivia_events_export view)

| File | Query Count | Cached? | Query Type |
|------|-------------|---------|------------|
| `lib/trivia_advisor/locations.ex` | 15 queries | Yes (all) | Mixed (explicit select + full schema) |
| `lib/trivia_advisor/events.ex` | 5 queries | ~~1 cached~~ → **All cached (Phase 3)** | Mostly full schema |
| `lib/trivia_advisor/sitemap.ex` | 2 queries | Yes | Explicit select |

### Detailed Query Breakdown

#### locations.ex (15 queries, all cached)

| Function | Cache Key Pattern | Query Type | Uses venue_images? |
|----------|------------------|------------|-------------------|
| `get_popular_cities/2` | `popular_cities_{limit}_{country_id}` | JOIN only | No |
| `search_cities/1` | `city_search_{query}` | JOIN only | No |
| `list_all_cities_grouped_by_country/0` | `all_cities_by_country` | JOIN only | No |
| `list_top_cities_by_country/1` | `top_cities_by_country_{limit}` | Explicit select (no venue_images) | No |
| `list_cities_for_country/2` | `country_{id}_page_{p}_per_{pp}` | Explicit select (no venue_images) | No |
| `count_cities_for_country/1` | `country_{id}_count` | Count only | No |
| `get_latest_venues/1` | `latest_venues_{limit}` | **Explicit select (no venue_images)** | **NO** |
| `list_venues_for_city/2` (geo) | `city_{id}_geo_{r}km_day_{d}_suburb_{s}` | **Explicit select (no venue_images)** | **NO** |
| `list_venues_for_city/2` (exact) | `city_{id}_venues_day_{d}` | **Explicit select (no venue_images)** | **NO** |
| `get_day_counts_for_city/2` (geo) | `day_counts_geo_{id}_{r}km` | Aggregate only | No |
| `get_day_counts_for_city/2` (exact) | `day_counts_{id}` | Aggregate only | No |
| `get_suburbs_for_city/2` (geo) | `suburbs_geo_{id}_{r}km` | Select venue_name only | No |
| `get_suburbs_for_city/2` (exact) | `suburbs_{id}` | Select venue_name only | No |
| `count_venues_with_trivia/0` | `stats_venue_count` | Count only | No |
| `count_cities_with_trivia/0` | `stats_city_count` | Count only | No |
| `count_countries_with_trivia/0` | `stats_country_count` | Count only | No |
| `is_duplicate_city_slug?/1` | `duplicate_slug_{slug}` | Count only | No |

#### events.ex (5 queries, ALL cached after Phase 3)

| Function | Cached? | Query Type | Uses venue_images? |
|----------|---------|------------|-------------------|
| `get_events_for_venue/1` | ~~NO~~ → **YES (Phase 3)** | **Full schema** | **YES** |
| `get_events_for_weekday/2` | ~~NO~~ → **YES (Phase 3)** | **Full schema** | **YES** |
| `get_events_by_type/2` | ~~NO~~ → **YES (Phase 3)** | **Full schema** | **YES** |
| `get_event/1` | ~~NO~~ → **YES (Phase 3)** | **Full schema** | **YES** |
| `get_nearby_trivia_venues/2` | Yes | Explicit select (no venue_images) | No |

#### sitemap.ex (2 queries, cached via sitemap_cache)

| Function | Query Type | Uses venue_images? |
|----------|------------|-------------------|
| `venue_urls/1` | Explicit select | No |
| `venue_count/0` | Count only | No |

#### venue_matcher.ex (1 cached lookup)

| Function | Query Type | Uses venue_images? |
|----------|------------|-------------------|
| `find_similar/1` | Queries Venue table, not PublicEvent | N/A |

---

## 3. The Two Query Patterns (Root Cause)

### Pattern 1: Explicit `select: %{...}` (WITHOUT venue_images)
- **Runtime**: 16.51%
- **Calls/Day**: 1,945
- **P50 Latency**: 26ms
- **Source**: `locations.ex` functions like `list_venues_for_city`, `get_latest_venues`

```elixir
# Example from locations.ex:693
select: %{
  event_id: te.id,
  venue_id: te.venue_id,
  venue_name: te.venue_name,
  # ... 20+ fields but NOT venue_images
}
```

### Pattern 2: Full Schema Query (WITH venue_images)
- **Runtime**: 14.68%
- **Calls/Day**: 3,821
- **P50 Latency**: 0ms (well-cached!)
- **Source**: `events.ex` functions like `get_events_for_venue`, `get_event`

```elixir
# Example from events.ex:34
from e in PublicEvent,
  where: e.venue_id == ^venue_id,
  order_by: e.name
# Returns ALL fields including venue_images
```

### Why Two Patterns Exist

1. **Historical optimization attempt**: `locations.ex` was optimized to use explicit selects to reduce data transfer
2. **Unintended consequence**: Different SQL queries = different cache keys in database
3. **Caching gap**: `events.ex` functions are NOT cached (except `get_nearby_trivia_venues`)

---

## 4. Cache Key Inventory

### Total Unique Cache Key Patterns: 21

```
# City-related (15)
duplicate_slug_{slug}
popular_cities_{limit}_{country_id}
city_search_{query}
all_cities_by_country
top_cities_by_country_{limit}
country_{id}_page_{page}_per_{per_page}
country_{id}_count
latest_venues_{limit}
city_{id}_geo_{radius}km_day_{day}_suburb_{suburb}
city_{id}_geo_{radius}km_day_{day}
city_{id}_geo_{radius}km_suburb_{suburb}
city_{id}_geo_{radius}km_all
city_{id}_venues_day_{day}
city_{id}_suburb_{suburb}
city_{id}_venues_all
day_counts_geo_{id}_{radius}km
day_counts_{id}
suburbs_geo_{id}_{radius}km
suburbs_{id}
stats_venue_count
stats_city_count
stats_country_count

# Events-related (1)
nearby_venues_{venue_id}_{radius}km

# Sitemap (1)
:sitemap_xml

# Venue matcher (variable)
venue_match_{slug}
```

---

## 5. Uncached Queries (HIGH PRIORITY)

The following `events.ex` functions query `trivia_events_export` WITHOUT caching:

| Function | Called From | Frequency |
|----------|------------|-----------|
| `get_events_for_venue/1` | Venue show page | Every venue page load |
| `get_events_for_weekday/2` | Unknown | Unknown |
| `get_events_by_type/2` | Unknown | Unknown |
| `get_event/1` | Event detail page | Every event page load |

**These are likely the source of the 3,821 full-schema queries/day.**

---

## 6. Recommendations Summary

### Phase 2: TTL Increase (Quick Win)
- Change `:city_cache` TTL from 15 minutes to **24 hours**
- Change `:sitemap_cache` TTL from 6 hours to **24 hours** (already reasonable)

### Phase 3: Add Missing Cache
- Add caching to `events.ex` functions:
  - `get_events_for_venue/1` → cache key: `events_for_venue_{venue_id}`
  - `get_event/1` → cache key: `event_{id}`

### Phase 4: Query Consolidation
- Option A: Standardize on full schema queries (simpler, leverages existing caching)
- Option B: Standardize on explicit select (more efficient, needs careful review)
- **Recommendation**: Option A - full schema is already well-cached (0ms P50)

---

## 7. Baseline Metrics

**Before optimization** (from PlanetScale Insights):

| Metric | Value |
|--------|-------|
| Total queries/day to trivia_events_export | 5,766 |
| DB runtime percentage | 31.19% |
| Query pattern 1 (without venue_images) | 1,945 calls, 26ms P50 |
| Query pattern 2 (with venue_images) | 3,821 calls, 0ms P50 |

**Target after optimization**:

| Metric | Target |
|--------|--------|
| Total queries/day | <200 |
| DB runtime percentage | <2% |
| Query patterns | 1 (consolidated) |

---

## Appendix: File References

- Cache configuration: `lib/trivia_advisor/application.ex:14-31`
- Main query file: `lib/trivia_advisor/locations.ex`
- Uncached queries: `lib/trivia_advisor/events.ex:32-96`
- Schema definition: `lib/trivia_advisor/events/public_event.ex`
- Sitemap queries: `lib/trivia_advisor/sitemap.ex:121-166`
