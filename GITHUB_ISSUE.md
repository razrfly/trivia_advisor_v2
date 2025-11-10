# QuizAdvisor V2 - Comprehensive Page Audit & Implementation Roadmap

## Executive Summary

**Current Status**: V2 is 60% functional with one critical blocker preventing deployment.

| Component | Status | Impact |
|-----------|--------|--------|
| Homepage | ✅ Working | Ready |
| Country Pages | ✅ Working | Ready |
| City Pages | ✅ Working | Ready (24 venues in Austin) |
| **Venue Pages** | ❌ **CRITICAL FAILURE** | **BLOCKS 5,348 URLs (75% of sitemap)** |
| Legacy URLs | ✅ Working | Proper 302 redirects |

**Data Quality**: ✅ Excellent - Using `trivia_events_export` view with 2,696 curated trivia events from 6 trusted sources.

---

## 🚨 CRITICAL BLOCKER (Must Fix Before Deploy)

### Issue: Venue Pages Crash with KeyError

**Error**: `KeyError: key :name not found in: %TriviaAdvisor.Events.PublicEvent{...}`

**Root Cause**: The `VenueShowLive` component is trying to access old association fields that no longer exist. After migrating to the `trivia_events_export` view, we now use denormalized fields:

| Old (Association) | New (Denormalized) |
|-------------------|-------------------|
| `venue.name` | `event.venue_name` |
| `venue.address` | `event.venue_address` |
| `city.name` | `event.city_name` |
| `country.name` | `event.country_name` |

**Location**: `lib/trivia_advisor_web/live/venue_show_live.ex:156`

**Impact**:
- ❌ Cannot view any venue detail pages
- ❌ Breaks entire venue browsing flow
- ❌ Users cannot see event schedules or venue details
- ❌ Blocks 5,348 venue URLs (75% of sitemap)

**Fix Required**:
```elixir
# Update VenueShowLive to use denormalized fields:
- venue.name → event.venue_name
- venue.address → event.venue_address
- venue.latitude → event.venue_latitude
- venue.longitude → event.venue_longitude
- city.name → event.city_name
- country.name → event.country_name
```

---

## Current Implementation Status

### ✅ What Works (40% of features)

**Homepage**:
- ✅ Page loads successfully
- ✅ Clean, minimal design
- ✅ Explore by City section (Denver, Kraków, London, Melbourne, Warsaw)
- ✅ Hierarchical URLs (`/united-states/denver`)
- ❌ Missing: Latest venues, venue count stats, email signup

**Country Pages**:
- ✅ Loads with hierarchical URLs (`/united-states`)
- ✅ Shows cities within country
- ✅ Clean navigation

**City Pages**:
- ✅ Loads successfully (`/united-states/austin`)
- ✅ Displays correct venue count (24 venues in Austin)
- ✅ Breadcrumb navigation
- ✅ Venue list with addresses
- ❌ Missing: Venue images, day-of-week filter, suburb filter, venue details

**Data Architecture**:
- ✅ Using `trivia_events_export` PostgreSQL view
- ✅ 2,696 curated trivia events from 6 trusted sources
- ✅ Denormalized fields for optimal query performance
- ✅ Read-only architecture consuming Eventasaurus DB

### ❌ What Doesn't Work (60% of features)

**Venue Pages** (CRITICAL):
- ❌ Complete crash with KeyError
- ❌ Cannot display venue details
- ❌ Cannot show event schedules
- ❌ Cannot show location/contact info

**Missing Images**:
- ❌ No venue images on city pages
- ❌ No city hero images
- ❌ No venue detail page images

**Missing City Page Features**:
- ❌ Day of week filter
- ❌ Suburb/neighborhood filter
- ❌ Venue image thumbnails
- ❌ Event count per venue
- ❌ Next event date/time

**Missing Venue Page Features**:
- ❌ Location section with map
- ❌ Contact information
- ❌ Quiz master details
- ❌ Event schedule display
- ❌ "Nearby Venues" section
- ❌ Reviews section

**Missing Homepage Features**:
- ❌ Latest venues showcase
- ❌ Venue count statistics (5,348+ venues, 31+ countries)
- ❌ Email subscription form
- ❌ Popular cities with counts

**Other Missing Features**:
- ❌ Search functionality
- ❌ Cities index page
- ❌ Social sharing buttons
- ❌ Breadcrumb on all pages

---

## Implementation Roadmap

### PHASE 0: CRITICAL BLOCKER (Must Fix Immediately)

**Estimated Time**: 1-2 hours

- [ ] **Task 0.1**: Fix venue page crash
  - Update `VenueShowLive` to use denormalized view fields
  - Update all template references (`venue.name` → `event.venue_name`)
  - Test venue pages load without errors
  - Verify event schedule displays correctly
  - **Acceptance**: All venue URLs load successfully

---

### PHASE 1: CORE FUNCTIONALITY (Week 1-2)

**Estimated Time**: 5-8 days

**Goal**: Achieve feature parity with essential city/venue browsing

- [ ] **Task 1.1**: Implement venue images (Priority: P0)
  - Display primary venue image on city pages
  - Handle missing images gracefully
  - Implement image thumbnails
  - **Acceptance**: 80%+ venues show images

- [ ] **Task 1.2**: Build city page filters (Priority: P0)
  - Day of week filter (Mon-Sun, Any day)
  - Filter venues by quiz night schedule
  - Update URL params for filters
  - **Acceptance**: Filters work, URL updates correctly

- [ ] **Task 1.3**: Add venue page location section (Priority: P0)
  - Display address, city, country
  - Integrate map component (Google Maps or Mapbox)
  - Show coordinates
  - **Acceptance**: Location displays on all venue pages

- [ ] **Task 1.4**: Add venue page contact section (Priority: P1)
  - Display phone, email, website
  - Handle missing contact info
  - Add "Get Directions" link
  - **Acceptance**: Contact info displays when available

- [ ] **Task 1.5**: Add "Next Quiz Night" section (Priority: P1)
  - Parse `occurrences.pattern` from view
  - Calculate next occurrence date
  - Display time and recurrence info
  - **Acceptance**: Shows next quiz date for 90%+ venues

---

### PHASE 2: IMPORTANT FEATURES (Week 2-3)

**Estimated Time**: 5-7 days

**Goal**: Add key missing features from production

- [ ] **Task 2.1**: Implement suburb/neighborhood filter (Priority: P1)
  - Extract suburb data from venue addresses
  - Add suburb filter to city pages
  - Update URL handling
  - **Acceptance**: Suburb filter works on major cities

- [ ] **Task 2.2**: Add quiz master section (Priority: P1)
  - Display quiz master name and bio
  - Handle missing quiz master data
  - **Acceptance**: Shows quiz master when available

- [ ] **Task 2.3**: Build "Nearby Venues" section (Priority: P1)
  - Query venues within 5km radius
  - Use PostGIS distance calculations
  - Display 5-10 nearest venues
  - **Acceptance**: Shows nearby venues with distances

- [ ] **Task 2.4**: Enhance homepage (Priority: P1)
  - Add "Latest Venues" section (10 most recent)
  - Add venue count statistics
  - Display country count
  - **Acceptance**: Homepage matches production layout

- [ ] **Task 2.5**: Add search functionality (Priority: P2)
  - Search by city name
  - Search by venue name
  - Autocomplete suggestions
  - **Acceptance**: Search returns relevant results

- [ ] **Task 2.6**: Create cities index page (Priority: P2)
  - List all cities with trivia
  - Group by country
  - Show venue count per city
  - **Acceptance**: `/cities` page displays all cities

---

### PHASE 3: ENHANCEMENTS (Week 3-4)

**Estimated Time**: 3-5 days

**Goal**: Polish and additional features

- [ ] **Task 3.1**: Email signup form (Priority: P2)
  - Add subscription form to homepage/footer
  - Integrate with email service
  - Validate email format
  - **Acceptance**: Users can subscribe

- [ ] **Task 3.2**: Social sharing buttons (Priority: P3)
  - Add share buttons to venue pages
  - Support Facebook, Twitter, WhatsApp
  - **Acceptance**: Share buttons work

- [ ] **Task 3.3**: Breadcrumb navigation (Priority: P2)
  - Add breadcrumbs to all pages
  - Show full hierarchy (Home → Country → City → Venue)
  - **Acceptance**: Breadcrumbs on all pages

- [ ] **Task 3.4**: City hero images (Priority: P3)
  - Add hero images to city pages
  - Fallback to default images
  - **Acceptance**: All major cities have images

---

### PHASE 4: URL MIGRATION (Week 4)

**Estimated Time**: 2-3 days

**Goal**: Preserve SEO value from 7,118 production URLs

- [ ] **Task 4.1**: Build 301 redirect controller (Priority: P0)
  - Redirect `/countries/:slug` → `/:country_slug`
  - Redirect `/cities/:slug` → `/:country_slug/:city_slug`
  - Redirect `/venues/:slug` → `/:country_slug/:city_slug/:venue_slug`
  - **Acceptance**: All legacy URLs redirect correctly

- [ ] **Task 4.2**: Add canonical tags (Priority: P0)
  - Prevent duplicate content issues
  - Add to all page layouts
  - **Acceptance**: Canonical tags on all pages

- [ ] **Task 4.3**: Update sitemap.xml (Priority: P0)
  - Generate new sitemap with hierarchical URLs
  - Include all 7,118+ URLs
  - Submit to Google Search Console
  - **Acceptance**: New sitemap submitted

- [ ] **Task 4.4**: Test URL migration (Priority: P0)
  - Verify all production URLs redirect
  - Check HTTP status codes (301)
  - Validate no 404 errors
  - **Acceptance**: Zero 404s from production URLs

---

## URL Pattern Migration

### Production (QuizAdvisor)
```
Homepage:  /
Country:   /countries/{country}
City:      /cities/{city}
Venue:     /venues/{venue}
```

### V2 (Hierarchical)
```
Homepage:  /
Country:   /{country}
City:      /{country}/{city}
Venue:     /{country}/{city}/{venue}
```

### SEO Benefits of V2
- ✅ Better URL hierarchy (clear parent-child relationships)
- ✅ More descriptive URLs (full geographic context)
- ✅ No namespace conflicts (countries, cities, venues can share slugs)
- ✅ Search engines understand geographic hierarchy
- ⚠️ Requires 301 redirects for all 7,118 URLs

---

## Data Quality Assessment

### Trivia Events View (`trivia_events_export`)

**Statistics**:
- **Total Events**: 2,696 curated trivia events
- **Sources**: 6 trusted providers (question-one, quizmeisters, inquizition, speed-quizzing, pubquiz-pl, geeks-who-drink)
- **Countries**: 5 (United States, United Kingdom, Poland, Australia, UAE)
- **Cities**: 1,666 cities with trivia
- **Venues**: 2,685 venues hosting trivia

**Filtering Quality**: ✅ **EXCELLENT**
- Only trusted trivia sources
- Events with valid pattern data
- Primary trivia category only (category_id = 29)
- No concerts, sports, or other event types

---

## Success Metrics

### Deployment Readiness Checklist
- [ ] **Blocker Fixed**: All venue pages load without errors
- [ ] **Core Features**: Images, filters, location sections working
- [ ] **URL Migration**: 301 redirects implemented and tested
- [ ] **SEO Preserved**: Sitemap updated, canonical tags added
- [ ] **Data Quality**: Confirmed 2,696 trivia events loading
- [ ] **Performance**: Page load times <3s on 3G
- [ ] **Testing**: All critical paths tested with Playwright

### Launch Criteria
- **Minimum**: Phase 0 + Phase 1 + Phase 4 (URL migration)
- **Recommended**: Phase 0-3 + Phase 4
- **Ideal**: All phases complete

---

## Timeline Estimate

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| **Phase 0** (Critical) | 1-2 hours | None |
| **Phase 1** (Core) | 5-8 days | Phase 0 complete |
| **Phase 2** (Features) | 5-7 days | Phase 1 complete |
| **Phase 3** (Polish) | 3-5 days | Phase 2 complete |
| **Phase 4** (Migration) | 2-3 days | Phase 0 complete |
| **Total** | ~3-4 weeks | Sequential execution |

**Fast Track**: Phase 0 + Phase 4 + critical P0 tasks = ~1 week minimum viable launch

---

## Risk Assessment

### High Risk
- ❌ **Venue page crash**: Blocks 75% of site functionality
- ⚠️ **URL migration**: Must preserve 7,118 URLs for SEO

### Medium Risk
- ⚠️ Missing images: Impacts user experience
- ⚠️ Missing filters: Reduces discoverability

### Low Risk
- ℹ️ Email signup: Nice-to-have feature
- ℹ️ Social sharing: Enhancement only

---

## Testing Strategy

### Automated Testing (Playwright)
- [ ] Homepage loads and displays cities
- [ ] Country pages show correct cities
- [ ] City pages display all venues
- [ ] Venue pages load without errors
- [ ] Filters work correctly
- [ ] Legacy URLs redirect properly (301)
- [ ] Images load correctly
- [ ] Search returns results

### Manual Testing
- [ ] Verify design matches production
- [ ] Check responsive design (mobile/tablet/desktop)
- [ ] Test all user workflows
- [ ] Validate SEO meta tags
- [ ] Confirm accessibility compliance

---

## References

- **Full Page Audit**: `PAGE_AUDIT_REPORT.md`
- **Feature Comparison**: `SITE_FUNCTIONALITY_COMPARISON.md`
- **Original Issue**: https://github.com/razrfly/eventasaurus/issues/1992
- **Production Site**: https://quizadvisor.com/
- **Production Sitemap**: https://quizadvisor.com/sitemap.xml (7,118 URLs)

---

## Next Steps

1. **Immediate**: Fix venue page crash (Task 0.1)
2. **Week 1**: Complete Phase 1 (core functionality)
3. **Week 2**: Complete Phase 2 (important features)
4. **Week 3**: Complete Phase 3 (enhancements)
5. **Week 4**: Complete Phase 4 (URL migration) and deploy

**Deployment Readiness**: After Phase 0 + Phase 1 + Phase 4 are complete.
