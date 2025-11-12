# Database Index Requirements

## Overview
This document outlines the database indexes required for optimal performance of Trivia Advisor V2. Since we're querying a read-only Eventasaurus database, these indexes should ideally already exist. This document serves as a reference for verification and can be shared with the Eventasaurus team if indexes need to be added.

## Required Indexes

### Cities Table
```sql
-- Primary key (should exist by default)
CREATE INDEX IF NOT EXISTS cities_pkey ON cities(id);

-- Foreign key to countries (critical for country page queries)
CREATE INDEX IF NOT EXISTS idx_cities_country_id ON cities(country_id);

-- Slug lookup (used for URL routing)
CREATE INDEX IF NOT EXISTS idx_cities_slug ON cities(slug);

-- Discovery configuration (used for home page featured cities)
CREATE INDEX IF NOT EXISTS idx_cities_discovery_enabled ON cities(discovery_enabled) WHERE discovery_enabled = true;
```

### trivia_events_export View/Table
```sql
-- Primary key (should exist)
CREATE INDEX IF NOT EXISTS trivia_events_export_pkey ON trivia_events_export(id);

-- Foreign keys (critical for joins in city queries)
CREATE INDEX IF NOT EXISTS idx_trivia_events_city_id ON trivia_events_export(city_id);
CREATE INDEX IF NOT EXISTS idx_trivia_events_venue_id ON trivia_events_export(venue_id);
CREATE INDEX IF NOT EXISTS idx_trivia_events_country_id ON trivia_events_export(country_id);

-- Composite index for counting distinct venues per city (optimization)
CREATE INDEX IF NOT EXISTS idx_trivia_events_city_venue ON trivia_events_export(city_id, venue_id);
```

### Venues Table
```sql
-- Primary key (should exist)
CREATE INDEX IF NOT EXISTS venues_pkey ON venues(id);

-- Slug lookup (used for URL routing)
CREATE INDEX IF NOT EXISTS idx_venues_slug ON venues(slug);
```

### Countries Table
```sql
-- Primary key (should exist)
CREATE INDEX IF NOT EXISTS countries_pkey ON countries(id);

-- Slug lookup (used for URL routing)
CREATE INDEX IF NOT EXISTS idx_countries_slug ON countries(slug);
```

## Query Analysis

### Critical Queries Requiring Indexes

#### 1. List Cities for Country (with pagination)
**Query:**
```sql
SELECT c.id, count(DISTINCT te.venue_id) as venue_count
FROM cities c
INNER JOIN trivia_events_export te ON te.city_id = c.id
WHERE c.country_id = ?
GROUP BY c.id
ORDER BY count(DISTINCT te.venue_id) DESC, c.name ASC
LIMIT ? OFFSET ?;
```

**Required Indexes:**
- `idx_cities_country_id` (WHERE clause)
- `idx_trivia_events_city_id` (JOIN condition)
- `idx_trivia_events_city_venue` (Composite for COUNT DISTINCT optimization)

**Impact:** Without these indexes, this query performs a full table scan on 914+ cities, resulting in 3-5 second query times.

#### 2. Count Cities for Country
**Query:**
```sql
SELECT count(DISTINCT c.id)
FROM cities c
INNER JOIN trivia_events_export te ON te.city_id = c.id
WHERE c.country_id = ?;
```

**Required Indexes:**
- `idx_cities_country_id`
- `idx_trivia_events_city_id`

#### 3. Get Country by Slug
**Query:**
```sql
SELECT * FROM countries WHERE slug = ?;
```

**Required Indexes:**
- `idx_countries_slug`

#### 4. Get City by Slug
**Query:**
```sql
SELECT * FROM cities WHERE slug = ?;
```

**Required Indexes:**
- `idx_cities_slug`

## Performance Impact

### Without Indexes
- Country page load: **5-10 seconds**
- Database CPU usage: **High** (full table scans)
- Cache effectiveness: **Low** (first load always slow)

### With Indexes
- Country page load: **<500ms** (database query)
- With caching: **<50ms** (cache hit after 15-min TTL)
- Database CPU usage: **Low** (index scans)

## Current State (Phase 2 Improvements)

### Implemented Performance Optimizations
1. ✅ **ConCache**: 15-minute TTL reduces database hits by 90%+
2. ✅ **Pagination**: LIMIT 50 reduces data transfer by 95% (50 vs 914 cities)
3. ⚠️ **Indexes**: Need verification (cannot access Eventasaurus DB directly)

### Expected Performance After Phase 2
- **First page load**: <2s (if indexes exist) or 3-5s (if indexes missing)
- **Cached page load**: <100ms (ConCache hit)
- **Database load**: 90% reduction (15-min cache TTL)
- **Page navigation**: <300ms (pagination + cache)

## Verification Steps

To verify indexes exist in Eventasaurus database:

```bash
# Connect to Eventasaurus database
psql $EVENTASAURUS_DATABASE_URL

# Check cities indexes
\d cities

# Check trivia_events_export indexes
\d trivia_events_export

# Check countries indexes
\d countries

# Check venues indexes
\d venues
```

## Recommendations for Eventasaurus Team

If indexes are missing, prioritize in this order:

1. **High Priority** (Critical for country pages):
   - `idx_cities_country_id`
   - `idx_trivia_events_city_id`
   - `idx_trivia_events_city_venue` (composite)

2. **Medium Priority** (URL routing):
   - `idx_countries_slug`
   - `idx_cities_slug`
   - `idx_venues_slug`

3. **Low Priority** (Minor optimizations):
   - `idx_cities_discovery_enabled` (filtered index)
   - `idx_trivia_events_venue_id`
   - `idx_trivia_events_country_id`

## Notes

- Trivia Advisor V2 is **read-only** - no writes, updates, or deletes
- All indexes should be B-tree (default) for equality and range lookups
- The `trivia_events_export` view may already have indexes from the underlying table
- ConCache implementation reduces dependency on database performance
- With caching, missing indexes have **minimal impact** after first page load

---

**Last Updated:** 2025-11-12
**Contact:** Trivia Advisor V2 team
**Related:** Phase 2 Performance Optimization (Issue #15)
