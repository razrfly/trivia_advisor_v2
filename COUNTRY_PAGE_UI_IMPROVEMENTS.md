# Country Page UI/UX Improvements: Add City Images and Performance Optimization

## Issue Summary

The new UK country page (http://localhost:4003/united-kingdom) is missing critical visual features present in the legacy site (https://quizadvisor.com/countries/united-kingdom) and experiences severe performance issues despite not loading images. This issue documents the gaps and proposes solutions for achieving feature parity while improving performance.

## Current State Analysis

### Legacy Site (https://quizadvisor.com/countries/united-kingdom)
✅ **Visual Features:**
- Hero banner image (large UK photo at top)
- Individual city images (Unsplash photos for each city)
- Venue counts displayed prominently ("216 Venues", "95 Venues", etc.)
- Photographer attribution links
- Optimized image delivery via Unsplash CDN with query parameters

✅ **Layout:**
- Grid layout with 2-3 cities per row
- 686 cities sorted by venue count (London 216 → descending)
- Visual hierarchy with larger cards for top cities

✅ **Performance:**
- Image optimization through Unsplash CDN
- Progressive loading
- Responsive image URLs with crops and quality settings

### New Site (http://localhost:4003/united-kingdom)
✅ **Working Features:**
- Responsive grid layout (1/2/3/4 columns)
- City sorting by venue count (fixed in recent update)
- 914 cities displayed (33% more coverage than legacy)
- Clean card design with proper spacing

❌ **Missing Features:**
- No hero banner image
- No city images (despite `unsplash_gallery` data existing in database)
- No venue count displayed per city
- No photographer attribution
- Extremely slow page load times

❌ **Performance Issues:**
- Loading all 914 cities at once without pagination
- No caching layer for database queries
- Slow rendering despite no images being loaded
- No lazy loading or progressive enhancement

## Critical Findings

### 1. City Images Data EXISTS But Is Not Displayed

**Database Schema Evidence:**
```elixir
# lib/trivia_advisor/locations/city.ex:16
field :unsplash_gallery, :map
```

The `cities` table contains `unsplash_gallery` JSONB field with Unsplash image data, but the `CityCard` component doesn't render this data. This is purely a frontend display issue.

### 2. Performance Problem Despite No Images

The page is "extremely slow" even though images aren't being loaded. Root causes:

**Database Query Issues:**
- Loading all 914 cities in a single query without pagination
- No result caching (same query runs on every page load)
- Potential N+1 queries despite using `preload: [:country]`

**Missing Optimization:**
- No query result caching (Redis, ETS, or ConCache)
- No pagination or infinite scroll
- No lazy loading strategy
- All data processed synchronously on page mount

### 3. Missing Venue Count Aggregation

The legacy site shows venue counts ("216 Venues") but the new site doesn't. This requires database aggregation in the query.

## Proposed Solutions

### A. Visual Features Implementation

#### 1. Add City Images from unsplash_gallery
**File:** `lib/trivia_advisor_web/components/cards/city_card.ex`

**Current Implementation:**
```elixir
# Lines 28-78: Text-only card with no images
<div class="p-6 bg-white rounded-lg shadow-md hover:shadow-xl transition-shadow duration-200">
  <h3 class="text-xl font-semibold text-gray-900 mb-2 group-hover:text-blue-600 transition-colors">
    <%= @city.name %>
  </h3>
  <!-- No images rendered -->
</div>
```

**Proposed Enhancement:**
- Extract image URL from `city.unsplash_gallery` map
- Add image header to card (similar to VenueCard implementation)
- Include photographer attribution with Unsplash link
- Use responsive image sizing
- Handle fallback when no gallery images exist

**Reference:** Similar pattern already implemented in `venue_card.ex:38-48` for venue images

#### 2. Add Venue Count Display
**File:** `lib/trivia_advisor/locations.ex`

**Current Query:** (lines 217-251)
```elixir
# Aggregates count but doesn't return it
select: %{
  id: c.id,
  venue_count: count(te.venue_id, :distinct)  # Calculated but not attached to city
}
```

**Proposed Enhancement:**
- Modify `list_cities_for_country/1` to return venue counts with city records
- Update CityCard to display venue count badge
- Format: "X Venues" or "X Venue" (singular)

#### 3. Add Country Hero Banner
**File:** `lib/trivia_advisor_web/live/country_show_live.ex`

**Current Implementation:**
```elixir
# Lines 64-75: Text-only header, no hero image
<div class="bg-white border-b">
  <div class="container mx-auto px-4 py-8">
    <h1 class="text-4xl font-bold text-gray-900 mb-2">
      Trivia Nights in <%= @country.name %>
    </h1>
  </div>
</div>
```

**Proposed Enhancement:**
- Add country-specific hero image (from country images or Unsplash)
- Similar to legacy site's large UK banner photo
- Overlay title text on hero image with dark gradient
- Responsive height (mobile: 200px, desktop: 400px)

### B. Performance Optimization Strategy

#### 1. Implement Query Result Caching

**Problem:** Same query executes on every page load for 914 cities

**Solution Options:**

**Option 1: ETS Cache (Simplest, No Dependencies)**
```elixir
# Cache country city lists for 15 minutes
# Invalidate on data updates from Eventasaurus
defmodule TriviaAdvisor.Cache do
  def get_or_fetch(key, ttl_seconds, fetch_fn) do
    # ETS-based caching implementation
  end
end
```

**Option 2: ConCache (Recommended)**
```elixir
# Add to mix.exs
{:con_cache, "~> 1.0"}

# In application.ex
children = [
  {ConCache, [name: :city_cache, ttl_check_interval: :timer.minutes(1), global_ttl: :timer.minutes(15)]}
]

# In locations.ex
def list_cities_for_country(country_id) do
  ConCache.get_or_store(:city_cache, "country_#{country_id}", fn ->
    # Expensive query
  end)
end
```

**Option 3: Redis (If already in use)**
```elixir
# Cachex with Redis backend for distributed caching
```

**Recommended:** Start with ConCache for 15-minute TTL, invalidate on Eventasaurus updates

**Expected Performance Gain:** 90-95% reduction in database load, <50ms cache hits vs 500-1000ms query

#### 2. Implement Pagination or Infinite Scroll

**Problem:** Loading 914 cities at once causes slow rendering

**Solution Options:**

**Option 1: Pagination (Simplest)**
- Show 50 cities per page (covers top cities in first load)
- Use offset-based pagination with page numbers
- Maintain URL state: `/united-kingdom?page=2`

**Option 2: Infinite Scroll (Better UX)**
- Initial load: 50 cities
- Load 50 more on scroll near bottom
- LiveView hook for scroll detection
- Progressive loading without page refresh

**Recommended:** Pagination for V2, infinite scroll for future enhancement

**Expected Performance Gain:** 95% reduction in initial render time (914 → 50 cities)

#### 3. Add Database Indexes

**Current Schema:** Verify indexes exist for:
```sql
-- Required for efficient queries
CREATE INDEX IF NOT EXISTS idx_cities_country_id ON cities(country_id);
CREATE INDEX IF NOT EXISTS idx_public_events_city_id ON trivia_events_export(city_id);
CREATE INDEX IF NOT EXISTS idx_public_events_venue_id ON trivia_events_export(venue_id);
```

**Action:** Verify indexes in Eventasaurus database (read-only, can't create migrations)

#### 4. Implement Lazy Image Loading

**Current Implementation:** No images loaded

**Proposed Enhancement:**
- Use `loading="lazy"` attribute on `<img>` tags
- Only load images in viewport + 200px buffer
- Browser-native lazy loading (no JS required)
- Fallback to placeholder image while loading

```elixir
<img
  src={@city_image_url}
  loading="lazy"
  class="w-full h-48 object-cover"
  alt={@city.name}
/>
```

### C. Implementation Roadmap

#### Phase 1: Visual Parity (High Priority)
1. ✅ **Add venue counts to city cards**
   - Modify `list_cities_for_country/1` to include counts
   - Update `CityCard` component to display counts
   - Files: `locations.ex`, `city_card.ex`
   - Effort: 2-3 hours

2. ✅ **Implement city images from unsplash_gallery**
   - Extract image from `city.unsplash_gallery` map
   - Add image header to `CityCard` component
   - Include photographer attribution
   - Handle fallback for missing images
   - Files: `city_card.ex`
   - Effort: 3-4 hours

3. ✅ **Add country hero banner**
   - Extract country image from database
   - Update `CountryShowLive` template
   - Add responsive hero section with overlay
   - Files: `country_show_live.ex`
   - Effort: 2-3 hours

**Total Phase 1 Effort:** 7-10 hours

#### Phase 2: Performance Optimization (Critical)
1. ✅ **Implement ConCache for query results**
   - Add dependency to `mix.exs`
   - Configure cache in `application.ex`
   - Wrap queries in `list_cities_for_country/1`
   - Set 15-minute TTL
   - Files: `mix.exs`, `application.ex`, `locations.ex`
   - Effort: 2-3 hours

2. ✅ **Add pagination (50 cities per page)**
   - Update LiveView to handle page param
   - Modify query to use LIMIT/OFFSET
   - Add pagination controls to template
   - Maintain URL state
   - Files: `country_show_live.ex`, `locations.ex`
   - Effort: 3-4 hours

3. ✅ **Verify database indexes**
   - Check existing indexes in Eventasaurus
   - Document missing indexes (if any)
   - Request index creation from Eventasaurus team
   - Effort: 1 hour

**Total Phase 2 Effort:** 6-8 hours

#### Phase 3: Polish & Enhancement (Medium Priority)
1. ✅ **Lazy image loading**
   - Add `loading="lazy"` to all city images
   - Implement placeholder/skeleton while loading
   - Files: `city_card.ex`
   - Effort: 1-2 hours

2. ✅ **Image optimization**
   - Add Unsplash URL parameters (width, quality, fit)
   - Responsive image sizes based on viewport
   - Files: `city_card.ex`
   - Effort: 1-2 hours

3. ✅ **Performance monitoring**
   - Add Telemetry events for query timing
   - Monitor cache hit rates
   - Track page load metrics
   - Files: `locations.ex`, `country_show_live.ex`
   - Effort: 2-3 hours

**Total Phase 3 Effort:** 4-7 hours

**Overall Project Effort:** 17-25 hours

## Technical Specifications

### Unsplash Gallery Structure
Expected `city.unsplash_gallery` JSONB format:
```json
{
  "active_category": "general",
  "categories": {
    "general": {
      "images": [
        {
          "url": "https://images.unsplash.com/photo-...",
          "alt": "London cityscape",
          "photographer": "John Doe",
          "photographer_url": "https://unsplash.com/@johndoe"
        }
      ]
    }
  }
}
```

**Reference:** Similar structure used in `venue_metadata.video_images` (see `venue_card.ex:174-178`)

### Venue Count Query Pattern
```elixir
# Aggregate venue count with city data
from c in City,
  join: te in PublicEvent, on: te.city_id == c.id,
  where: c.country_id == ^country_id,
  group_by: c.id,
  select: %{
    city: c,
    venue_count: count(te.venue_id, :distinct)
  },
  order_by: [desc: count(te.venue_id, :distinct), asc: c.name]
```

### Cache Invalidation Strategy
- **TTL:** 15 minutes for city lists
- **Manual Invalidation:** When Eventasaurus data updates (webhook or scheduled job)
- **Cache Key Pattern:** `"country_cities_#{country_id}"`
- **Warming:** Pre-populate cache for top 10 countries on app startup

## Acceptance Criteria

### Visual Features
- [ ] City cards display Unsplash images from `unsplash_gallery` field
- [ ] Photographer attribution links visible on city cards
- [ ] Venue count badge shows on each city card ("X Venues")
- [ ] Country page has hero banner image at top
- [ ] Fallback behavior works when images missing
- [ ] Design matches legacy site visual hierarchy

### Performance
- [ ] Page load time <2 seconds (down from current 5-10 seconds)
- [ ] Initial render shows 50 cities (not all 914)
- [ ] Database queries use ConCache with 15-minute TTL
- [ ] Cache hit rate >80% for repeat visitors
- [ ] Images use lazy loading
- [ ] No N+1 query problems

### Functionality
- [ ] Pagination works correctly (50 cities per page)
- [ ] City sorting by venue count maintained
- [ ] All 914 cities accessible through pagination
- [ ] Links to city pages work correctly
- [ ] Responsive design works on mobile/tablet/desktop

## Testing Checklist

### Visual Testing
- [ ] Test on Chrome, Firefox, Safari
- [ ] Mobile viewport (375px, 414px)
- [ ] Tablet viewport (768px, 1024px)
- [ ] Desktop viewport (1280px, 1920px)
- [ ] Verify image aspect ratios and cropping
- [ ] Test fallback when no images available

### Performance Testing
- [ ] Measure page load time before/after
- [ ] Monitor database query time
- [ ] Check cache hit/miss rates
- [ ] Test with 50, 100, 500, 914 cities
- [ ] Verify no memory leaks with pagination
- [ ] Test concurrent user loads

### Functional Testing
- [ ] Navigate between pages
- [ ] Verify venue counts are accurate
- [ ] Test city links redirect correctly
- [ ] Verify photographer attribution links work
- [ ] Test back button behavior
- [ ] Verify URL state updates with pagination

## Success Metrics

**Before:**
- ❌ 0 city images displayed
- ❌ 0 venue counts shown
- ❌ ~5-10 second page load
- ❌ 914 cities loaded at once
- ❌ Database query on every page load

**After (Expected):**
- ✅ 914 city images from Unsplash gallery
- ✅ Venue counts on all city cards
- ✅ <2 second page load (60-80% improvement)
- ✅ 50 cities per page (95% less initial data)
- ✅ >80% cache hit rate (90%+ database load reduction)

## References

### Existing Implementations to Reference
1. **VenueCard image fallback pattern**: `lib/trivia_advisor_web/components/cards/venue_card.ex:162-243`
   - 3-level fallback: venue_images → video_images → city_images
   - Photographer attribution
   - Responsive image handling

2. **City list query pattern**: `lib/trivia_advisor/locations.ex:217-251`
   - Already aggregates venue counts
   - Proper ordering and preloading

3. **Time ago helper**: `lib/trivia_advisor_web/components/cards/venue_card.ex:246-256`
   - Uses Timex for pluralization
   - Pattern for formatting counts

### Database Schema Reference
- **City**: `lib/trivia_advisor/locations/city.ex:1-38`
- **PublicEvent**: `lib/trivia_advisor/events/public_event.ex`
- **Locations Context**: `lib/trivia_advisor/locations.ex`

### External Dependencies
- Unsplash API documentation: https://unsplash.com/documentation
- ConCache: https://hexdocs.pm/con_cache
- Phoenix LiveView Pagination: https://hexdocs.pm/phoenix_live_view

## Notes

- This is a **documentation-only issue** - no code changes implemented
- Database schema (`unsplash_gallery`) already supports required features
- Performance issues exist despite no images currently loading (query optimization needed)
- Legacy site has 686 cities, new site has 914 (33% more coverage - this is correct)
- New site properly sorts by venue count (fixed in recent update)
- Eventasaurus database is read-only - cannot add indexes/migrations

## Related Files

- `lib/trivia_advisor_web/live/country_show_live.ex` - Main country page LiveView
- `lib/trivia_advisor_web/components/cards/city_card.ex` - City card component
- `lib/trivia_advisor/locations.ex` - Location queries and context
- `lib/trivia_advisor/locations/city.ex` - City schema with unsplash_gallery field
- `lib/trivia_advisor_web/components/cards/venue_card.ex` - Reference for image implementation

---

**Created:** 2025-01-12
**Priority:** High
**Estimated Effort:** 17-25 hours
**Dependencies:** ConCache package, Unsplash gallery data verification
