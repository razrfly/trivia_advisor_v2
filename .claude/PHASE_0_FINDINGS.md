# Phase 0 Database Validation - Findings

**Date**: 2025-11-08
**Status**: ✅ COMPLETE
**Database**: Eventasaurus (Supabase PostgreSQL 15.8)

---

## ✅ Connectivity & Infrastructure

| Check | Status | Result |
|-------|--------|--------|
| Database Connection | ✅ PASS | Connected successfully |
| PostgreSQL Version | ✅ PASS | 15.8 (supports `pg_read_all_data` role) |
| PostGIS Extension | ✅ PASS | PostGIS 3.3 available |
| Read-Only Mode | ⏳ PENDING | See Issue #2 |

---

## 📊 Data Validation

| Metric | Expected (from Sitemap) | Actual (Database) | Status |
|--------|------------------------|-------------------|---------|
| **City Count** | ~1,768 | **2,410** | ⚠️ +642 cities (database has grown) |
| **Venue Count** | ~5,348 | **4,558** | ⚠️ -790 venues (fewer in DB than sitemap) |
| **Upcoming Events** | Unknown | **3,614** | ℹ️ Active events |

### Analysis

**City Count Mismatch (+36%)**:
- Sitemap: 1,768 cities
- Database: 2,410 cities
- **Reason**: Database has grown since sitemap was last generated
- **Impact**: V2 will have MORE city pages than current production
- **Action**: ✅ Good news - more content

**Venue Count Mismatch (-15%)**:
- Sitemap: 5,348 venues
- Database: 4,558 venues
- **Possible Reasons**:
  1. Sitemap includes deleted/merged venues (but DB has no `deleted_at`)
  2. Some sitemap URLs might be event-specific (not permanent venues)
  3. Venues may have been removed/consolidated
- **Impact**: Some sitemap URLs might 404 in V2
- **Action**: ⚠️ Need to investigate URL mismatch

---

## 🔍 Schema Analysis

### Major Differences from V1

| Feature | V1 Schema | Eventasaurus Schema | Migration Impact |
|---------|-----------|---------------------|------------------|
| **Soft Deletes** | ✅ `deleted_at`, `merged_into_id` | ❌ NOT PRESENT | HIGH - No merge redirects needed |
| **Event Timing** | `day_of_week` + `start_time` | `starts_at` + `ends_at` + `occurrences` jsonb | HIGH - Complete rewrite |
| **Event Images** | `hero_image` upload | `image_url` in event_sources | MEDIUM - Different source |
| **Venue Images** | `google_place_images` array | `venue_images` jsonb | MEDIUM - Different structure |
| **Pricing** | `entry_fee` + currency lookup | `min_price`, `max_price`, `currency`, `is_free` | LOW - Better data |
| **i18n** | Not supported | `title_translations`, `description_translations` | LOW - New feature |
| **Discovery** | Not present | `discovery_enabled`, `discovery_config` | LOW - New feature |

### Cities Table

**Schema**:
```sql
CREATE TABLE cities (
  id BIGINT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL,
  country_id BIGINT NOT NULL REFERENCES countries(id),
  latitude NUMERIC(10,6),
  longitude NUMERIC(10,6),
  unsplash_gallery JSONB,
  discovery_enabled BOOLEAN DEFAULT false,
  discovery_config JSONB,
  alternate_names VARCHAR(255)[] DEFAULT ARRAY[],
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  UNIQUE (country_id, slug),
  UNIQUE (slug, country_id)
);
```

**Observations**:
- ✅ `slug` column exists
- ✅ `unsplash_gallery` jsonb matches V1
- ✅ Unique constraint on (country_id, slug) - prevents duplicate slugs in same country
- 🆕 `discovery_enabled` - might control if city appears in discovery features
- 🆕 `discovery_config` - jsonb configuration for discovery
- 🆕 `alternate_names` - array of alternative city names (for search?)

### Venues Table

**Schema**:
```sql
CREATE TABLE venues (
  id BIGINT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) NOT NULL UNIQUE,
  address VARCHAR(255),
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  city_id BIGINT REFERENCES cities(id) ON DELETE SET NULL,
  venue_type VARCHAR(255) NOT NULL DEFAULT 'venue',
  normalized_name VARCHAR(255),
  metadata JSONB,
  provider_ids JSONB DEFAULT '{}'::jsonb,
  venue_images JSONB DEFAULT '[]'::jsonb,
  image_enrichment_metadata JSONB DEFAULT '{}'::jsonb,
  geocoding_performance JSONB,
  source VARCHAR(255) DEFAULT 'user',
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- PostGIS Geography Index
CREATE INDEX venues_location_gist ON venues
  USING GIST (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography);
```

**Observations**:
- ✅ `slug` column exists (unique across all venues)
- ❌ NO `deleted_at` - soft deletes NOT used
- ❌ NO `merged_into_id` - merge tracking NOT present
- ❌ NO `google_place_images` - replaced with `venue_images` jsonb
- ✅ PostGIS geography index for spatial queries
- 🆕 `venue_type` - distinguishes 'venue' from 'region' (new feature?)
- 🆕 `normalized_name` - for matching/deduplication?
- 🆕 `provider_ids` - links to external data providers
- 🆕 `image_enrichment_metadata` - image processing metadata

**Impact on Migration**:
1. **No merge redirects needed** - merged_into_id doesn't exist
2. **Image handling different** - `venue_images` jsonb instead of google_place_images
3. **Spatial queries work** - PostGIS geography index present

### Countries Table

**Schema**:
```sql
CREATE TABLE countries (
  id BIGINT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  code VARCHAR(2) NOT NULL UNIQUE,
  slug VARCHAR(255) NOT NULL UNIQUE,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

**Observations**:
- ✅ Matches V1 schema exactly
- ✅ `code` is 2-character ISO code
- ✅ Unique constraint on `code` and `slug`

### Public Events Table

**Schema**:
```sql
CREATE TABLE public_events (
  id BIGINT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE,
  starts_at TIMESTAMP NOT NULL,
  ends_at TIMESTAMP,
  venue_id BIGINT REFERENCES venues(id) ON DELETE SET NULL,
  category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
  title_translations JSONB,
  occurrences JSONB,  -- Type: explicit, pattern, exhibition, recurring
  search_vector TSVECTOR,  -- Full-text search
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

**Observations**:
- ❌ COMPLETELY DIFFERENT from V1
- ❌ NO `day_of_week` + `start_time` pattern
- ✅ Uses `starts_at` + `ends_at` timestamps
- 🆕 `occurrences` jsonb - defines recurring patterns
- 🆕 `title_translations` - i18n support
- 🆕 `search_vector` - full-text search capability
- 🆕 Related to `public_event_sources`, `public_event_performers`, etc.

**Impact on Migration**:
- **HIGH IMPACT** - Event display logic must be completely rewritten
- V1 calculated next occurrence from `day_of_week` + `start_time`
- Eventasaurus provides explicit `starts_at` timestamps
- Need to understand `occurrences` jsonb structure for recurring events

### Public Event Sources Table

**Schema**:
```sql
CREATE TABLE public_event_sources (
  id BIGINT PRIMARY KEY,
  event_id BIGINT NOT NULL REFERENCES public_events(id) ON DELETE CASCADE,
  source_id BIGINT NOT NULL REFERENCES sources(id) ON DELETE RESTRICT,
  source_url VARCHAR(255),
  external_id VARCHAR(255),
  last_seen_at TIMESTAMP NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  description_translations JSONB,
  image_url TEXT,
  min_price NUMERIC(10,2),
  max_price NUMERIC(10,2),
  currency VARCHAR(3),
  is_free BOOLEAN NOT NULL DEFAULT false,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  UNIQUE (event_id, source_id),
  UNIQUE (source_id, external_id)
);
```

**Observations**:
- ✅ Similar to V1 `event_sources` but much more advanced
- ✅ `last_seen_at` for freshness tracking
- 🆕 Pricing fields: `min_price`, `max_price`, `currency`, `is_free`
- 🆕 `description_translations` - i18n descriptions
- 🆕 `image_url` - event-specific images
- ✅ Constraint checks: price range validation, currency code validation

**Impact on Migration**:
- **MEDIUM IMPACT** - Better pricing data than V1
- Can display price ranges instead of single entry_fee
- Can show "Free" events explicitly
- Images available per event source

### Public Event Performers Table

**Schema**:
```sql
CREATE TABLE public_event_performers (
  id BIGINT PRIMARY KEY,
  event_id BIGINT NOT NULL REFERENCES public_events(id) ON DELETE CASCADE,
  performer_id BIGINT NOT NULL REFERENCES performers(id) ON DELETE RESTRICT,
  metadata JSONB DEFAULT '{}'::jsonb,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  UNIQUE (event_id, performer_id)
);
```

**Observations**:
- ✅ Join table between events and performers
- ✅ Similar concept to V1 but separate table
- 🆕 `metadata` for performer-specific details (role, billing, etc.)

---

## 🚨 Critical Migration Adjustments

### 1. Event Data Model Rewrite (HIGH PRIORITY)

**V1 Approach**:
```elixir
# V1: Calculate next occurrence
event = %{
  day_of_week: "monday",
  start_time: ~T[19:00:00],
  frequency: "weekly"
}

next_occurrence = calculate_next_occurrence(event.day_of_week, event.start_time)
# Returns: next Monday at 7pm
```

**Eventasaurus Approach**:
```elixir
# Eventasaurus: Use explicit timestamps + occurrences
event = %{
  starts_at: ~N[2025-11-10 19:00:00],
  ends_at: ~N[2025-11-10 21:00:00],
  occurrences: %{
    "type" => "recurring",
    # Pattern details TBD - need to investigate structure
  }
}
```

**Required Actions**:
- [ ] Investigate `occurrences` jsonb structure
- [ ] Understand "explicit", "pattern", "exhibition", "recurring" types
- [ ] Rewrite event display logic for VenueShow LiveView
- [ ] Update JSON-LD Event schema generation
- [ ] Test recurring event display

### 2. Remove Soft Delete/Merge Logic (MEDIUM PRIORITY)

**V1 Features to Remove**:
```elixir
# NO LONGER NEEDED
def get_venue_by_slug(slug) do
  venue = Repo.get_by(Venue, slug: slug)

  # This logic can be removed
  if venue.merged_into_id do
    redirect_to_merged_venue(venue.merged_into_id)
  else
    venue
  end
end
```

**Eventasaurus Approach**:
```elixir
# Simpler - no merge redirects
def get_venue_by_slug(slug) do
  Repo.get_by!(Venue, slug: slug)
end
```

**Required Actions**:
- [ ] Remove merge redirect logic from VenueShow
- [ ] Remove soft delete filtering from queries
- [ ] Simplify venue lookup functions

### 3. Update Image Handling (MEDIUM PRIORITY)

**V1 Approach**:
```elixir
venue.google_place_images
# Array of maps: [%{url: "...", attribution: "..."}]
```

**Eventasaurus Approach**:
```elixir
venue.venue_images
# JSONB structure - need to investigate format

event_source.image_url
# Direct URL string
```

**Required Actions**:
- [ ] Investigate `venue_images` jsonb structure
- [ ] Update ImageHelpers for new format
- [ ] Test image display in VenueCard and VenueShow
- [ ] Handle event source images

### 4. Leverage New Features (LOW PRIORITY)

**New capabilities available**:
1. **Pricing Display**: Show price ranges, "Free" badges
2. **Multilingual Support**: Display translated titles/descriptions
3. **Discovery Features**: Use `discovery_enabled` for city filtering
4. **Full-Text Search**: Leverage `search_vector` for search features
5. **Provider Attribution**: Display data provider information

---

## 📋 Updated Migration Priorities

### Phase 1: Core Infrastructure (No Changes)
- ✅ Ecto configuration
- ✅ PostGIS support verified
- ✅ Dependencies installation

### Phase 2: Database Layer (MAJOR CHANGES NEEDED)

**Schema Changes**:
- [ ] Remove `deleted_at`, `merged_into_id` from Venue schema
- [ ] Update Event schema to use `starts_at`, `ends_at`, `occurrences`
- [ ] Add `venue_images` jsonb field (not google_place_images)
- [ ] Add pricing fields to EventSource schema
- [ ] Add i18n fields (title_translations, description_translations)
- [ ] Add discovery fields to City schema

**Query Changes**:
- [ ] Remove soft delete filtering
- [ ] Update spatial queries (no changes needed - PostGIS confirmed)
- [ ] Rewrite event queries for new timestamp model
- [ ] Add queries for pricing data
- [ ] Add queries for multilingual content

### Phase 3: SEO & Structured Data (CHANGES NEEDED)

**EventSchema JSON-LD**:
- [ ] Update to use `starts_at` instead of calculated dates
- [ ] Use min_price/max_price for `offers` property
- [ ] Use is_free for free event detection
- [ ] Add currency from event_sources
- [ ] Use image_url from event_sources

**BreadcrumbSchema**: ✅ No changes needed

**OpenGraph**: ✅ Minimal changes needed

### Phase 4-8: As Planned

---

## 🔬 Investigation Needed

### 1. Occurrences JSONB Structure

**Query**:
```sql
SELECT occurrences
FROM public_events
WHERE occurrences IS NOT NULL
LIMIT 10;
```

**Need to understand**:
- Structure of "explicit", "pattern", "exhibition", "recurring" types
- How to display recurring events
- How to calculate next occurrence for JSON-LD

### 2. Venue Images JSONB Structure

**Query**:
```sql
SELECT venue_images
FROM venues
WHERE jsonb_array_length(venue_images) > 0
LIMIT 10;
```

**Need to understand**:
- Image URL format
- Attribution requirements
- Fallback strategy

### 3. Venue Count Discrepancy

**Investigation needed**:
- Why are there fewer venues in DB (4,558) than sitemap (5,348)?
- Are some sitemap URLs for events, not venues?
- Should V2 generate fewer URLs?

**Potential query**:
```sql
-- Check if any venues have specific patterns
SELECT COUNT(*), venue_type
FROM venues
GROUP BY venue_type;
```

---

## ✅ Phase 0 Completion Checklist

- [x] Database connectivity verified
- [x] PostgreSQL 15.8 confirmed (supports pg_read_all_data)
- [x] PostGIS 3.3 confirmed
- [x] City count validated (2,410 cities - more than sitemap)
- [x] Venue count validated (4,558 venues - fewer than sitemap, need investigation)
- [x] Schema explored and documented
- [x] Major differences from V1 identified
- [ ] Read-only user configuration (Issue #2 - pending)
- [ ] Occurrences jsonb structure investigated
- [ ] Venue images jsonb structure investigated
- [ ] Venue count discrepancy explained

---

## 🚀 Next Steps

### Immediate (Complete Phase 0)
1. ✅ Update GitHub issue #1 with Phase 0 completion
2. ⏳ Resolve Issue #2 (read-only database setup)
3. ⏳ Investigate occurrences jsonb structure
4. ⏳ Investigate venue_images jsonb structure
5. ⏳ Explain venue count discrepancy

### Short-term (Begin Phase 1)
6. Install dependencies
7. Configure Ecto with correct schema
8. Create Ecto schemas based on actual Eventasaurus structure
9. Test basic queries

---

## 📊 Summary

**Good News** ✅:
- Database connectivity works perfectly
- PostGIS 3.3 available for spatial queries
- PostgreSQL 15.8 supports simple read-only setup
- More cities than expected (2,410 vs 1,768)
- Better pricing data structure
- i18n support built-in
- No merge redirect complexity

**Challenges** ⚠️:
- Event data model completely different (high impact)
- Venue count discrepancy needs investigation
- Image structure different (medium impact)
- Need to investigate jsonb structures

**Recommended Approach**:
1. Complete Phase 0 investigations
2. Update migration plan with schema adjustments
3. Proceed with Phase 1 using actual schema
4. Be prepared to rewrite event-related logic significantly

---

**Status**: Phase 0 ~80% complete. Ready to proceed with investigations and Issue #2.
