# City Page Improvements - Comparison Analysis

**Date**: 2025-11-12
**Pages Compared**:
- Production: https://quizadvisor.com/cities/london
- Local: http://localhost:4003/cities/london

## Executive Summary

Comprehensive comparison of London city page between production (QuizAdvisor V1) and local (Trivia Advisor V2) to identify visual differences, missing features, and performance improvements.

---

## 🎨 Visual & Layout Differences

### 1. Venue Card Grid Layout ⚠️ HIGH PRIORITY

**Issue**: Cards are too large, only 2 columns on large screens vs production's 3 columns

**Current Implementation**:
```html
<!-- city_show_live.ex:232 -->
<div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
```

**Production Layout**: 3 columns on desktop (more compact, shows more venues above fold)

**Recommendation**:
```html
<!-- Change to 3-column responsive grid -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
```

**Impact**:
- ✅ Shows 50% more venues above the fold (3 vs 2 per row)
- ✅ Reduces scroll fatigue for 103-venue listings
- ✅ Better visual parity with production
- ✅ Matches user expectations from V1

**Files to Modify**:
- `lib/trivia_advisor_web/live/city_show_live.ex:232`

---

### 2. Venue Card Image Height 🔧 MEDIUM PRIORITY

**Issue**: Card images may be too tall for 3-column layout

**Current Implementation**:
```elixir
# venue_card.ex:45
class="w-full h-48 object-cover rounded-t-lg"  # 192px tall
```

**Recommendation for 3-column layout**:
```elixir
# Reduce to h-40 (160px) or h-32 (128px) for more compact cards
class="w-full h-40 object-cover rounded-t-lg"
```

**Impact**:
- ✅ More compact cards fit better in 3-column layout
- ✅ Consistent visual rhythm across grid
- ⚠️ Test with actual images to ensure readability

**Files to Modify**:
- `lib/trivia_advisor_web/components/cards/venue_card.ex:45`

---

### 3. Card Spacing & Gap 🔧 LOW PRIORITY

**Current**: `gap-6` (24px between cards)

**Consideration**: May want to reduce to `gap-4` (16px) with 3-column layout for tighter density

**Recommendation**: Test both `gap-4` and `gap-6` with 3-column layout to find optimal balance

---

## 🚀 Performance Issues

### 1. No Caching on Venue Queries ⚠️ CRITICAL

**Issue**: London city page is slow because venue queries hit database on every request

**Current State**:
```elixir
# locations.ex:539 - list_venues_for_city does NOT use ConCache
def list_venues_for_city(city_id, opts \\ []) do
  weekday = Keyword.get(opts, :weekday)
  # Direct database query, no caching
  query = from te in PublicEvent, ...
  Repo.all(query)
end
```

**Comparison**: Country pages use ConCache with 15-minute TTL:
```elixir
# locations.ex:235 - list_cities_for_country DOES use ConCache
ConCache.get_or_store(:city_cache, cache_key, fn ->
  fetch_cities_for_country(country_id, page, per_page)
end)
```

**Impact of Missing Cache**:
- ❌ 103 venue query on EVERY page load (London)
- ❌ Database hit on EVERY day filter change
- ❌ No benefit from 15-minute cache TTL
- ❌ Slow user experience, especially for large cities

**Recommendation**:
```elixir
def list_venues_for_city(city_id, opts \\ []) do
  weekday = Keyword.get(opts, :weekday)

  # Cache key includes city_id and weekday filter
  cache_key = if weekday do
    "city_#{city_id}_venues_day_#{weekday}"
  else
    "city_#{city_id}_venues_all"
  end

  ConCache.get_or_store(:city_cache, cache_key, fn ->
    fetch_venues_for_city(city_id, weekday)
  end)
end

defp fetch_venues_for_city(city_id, weekday) do
  # Existing query logic moved to private function
  query = from te in PublicEvent, ...
  Repo.all(query)
end
```

**Expected Performance Improvement**:
- First load: <2s (database query)
- Cached loads: <100ms (cache hit)
- Database load reduction: 90%+ (15-minute TTL)

**Files to Modify**:
- `lib/trivia_advisor/locations.ex:539-590` (list_venues_for_city function)

---

## ✨ Missing Features

### 1. Filter by Suburb/Neighborhood ⚠️ HIGH PRIORITY

**Production Feature**: Suburb filtering with venue counts
- Example: "Camden (12), Westminster (23), Shoreditch (8)"

**Current State**: ❌ Not implemented

**Database Investigation Needed**:
- Check if suburb data exists in `venue_address` field
- Check if `city_metadata` or `venue_metadata` contains suburb/neighborhood data
- May require Eventasaurus database schema changes if no field exists

**Recommendation**:
1. **Phase 1**: Investigate data availability
   - Query sample venues from London to see if suburb can be parsed from address
   - Check metadata JSON fields for suburb information

2. **Phase 2**: If data exists
   - Add suburb extraction/parsing logic
   - Add suburb filter UI (similar to day filter)
   - Update queries to support suburb filtering
   - Add suburb to cache keys

3. **Phase 3**: If data doesn't exist
   - Submit feature request to Eventasaurus team
   - Consider client-side suburb extraction from address (less reliable)

**Files to Create/Modify**:
- TBD based on data availability investigation

---

### 2. Radius/Distance Filter 🔧 MEDIUM PRIORITY

**Production Feature**: Distance filter dropdown
- Options: 5 km, 10 km, 25 km, 50 km

**Current State**: ❌ Not implemented

**Blocker**: Requires user geolocation or address input

**Recommendation**: Lower priority - implement after suburb filtering
- Needs PostGIS distance calculations (already have geo_postgis dependency)
- Requires user location permission or address input
- Consider as Phase 3+ enhancement

---

### 3. Venue Ratings Display 🔧 LOW PRIORITY

**Production Feature**: Star ratings on venue cards
- Example: "4.5/5.0 stars"

**Current State**: ❌ Not implemented

**Blocker**: No ratings data in trivia_events_export view

**Recommendation**:
- Check if Eventasaurus has ratings data we can access
- If not available, consider as future enhancement
- Could implement simple "thumbs up" count as alternative

---

## 📊 Summary Matrix

| Feature | Production | Local V2 | Priority | Effort |
|---------|-----------|----------|----------|--------|
| 3-column grid layout | ✅ | ❌ | HIGH | 5 min |
| Compact card images | ✅ | ❌ (too tall) | MEDIUM | 2 min |
| Venue query caching | Unknown | ❌ | CRITICAL | 30 min |
| Suburb filtering | ✅ | ❌ | HIGH | 4-8 hours* |
| Radius filtering | ✅ | ❌ | MEDIUM | 8-12 hours |
| Venue ratings | ✅ | ❌ | LOW | TBD |
| Day filtering | ✅ | ✅ | - | Complete |
| Hero images | ✅ | ✅ | - | Complete |
| Pagination | ❌ (~100) | ✅ (50/page) | - | We're better! |

*Effort assumes suburb data exists in database

---

## 🎯 Recommended Implementation Order

### Phase 1: Quick Wins (1 hour)
1. ✅ Add ConCache to venue queries (30 min) - **CRITICAL for performance**
2. ✅ Change grid to 3 columns (5 min) - **HIGH visual impact**
3. ✅ Reduce card image height to h-40 (2 min)
4. ✅ Test with real data on London page

### Phase 2: Suburb Filtering (4-8 hours)
1. 🔍 Investigate suburb data availability (30 min)
2. 🏗️ Design suburb filter UI (1 hour)
3. 💻 Implement suburb extraction/parsing (2-3 hours)
4. 🔗 Update queries and caching (1-2 hours)
5. ✅ Test with London, NYC, other large cities (1 hour)

### Phase 3: Advanced Features (future)
1. Radius/distance filtering
2. Venue ratings integration
3. Additional filters (quiz format, difficulty, etc.)

---

## 🔍 Additional Observations

### What We're Doing Better ✅

1. **Pagination**: We have 50/page pagination, production shows ~100 without clear pagination
2. **Image Fallbacks**: Our 3-level fallback (venue → video → city) is more sophisticated
3. **Caching on Country Pages**: 15-minute ConCache already working well
4. **Modern Phoenix Patterns**: Clean LiveView architecture vs older codebase

### Technical Debt to Avoid ⚠️

1. Don't compromise on caching - 15-minute TTL is essential
2. Keep separation between city pages (cached) and venue pages (needs caching)
3. Ensure cache keys include all filter parameters (day, suburb, etc.)

---

## 📝 Notes

- No code changes made during this analysis per user request
- All recommendations based on production comparison and Tailwind CSS best practices
- Performance metrics based on current ConCache implementation on country pages
- Suburb filtering feasibility depends on data availability investigation

**Next Steps**:
1. Review and prioritize recommendations
2. Create GitHub issues for each phase
3. Begin Phase 1 implementation (performance + layout quick wins)
