# Production Route Audit Report: QuizAdvisor → Trivia Advisor V2

**Date**: 2025-01-09
**Production Site**: https://quizadvisor.com/
**V2 Site**: http://localhost:4003/
**Status**: CRITICAL ISSUES FOUND - SEO at Risk

---

## Executive Summary

### 🚨 CRITICAL FINDINGS

1. **WRONG URL STRUCTURE**: Production uses `/cities/`, `/countries/`, and `/venues/` prefixes. V2 expects `/{country}/{city}/{venue}` pattern.
2. **ROUTE FALLBACK BUG**: V2 shows homepage for `/cities/*`, `/countries/*`, and `/venues/*` routes instead of proper 404 or redirect.
3. **SITEMAP BROKEN**: V2's `/sitemap.xml` endpoint crashes with FunctionClauseError.
4. **Missing /about Route**: Production returns 404, but this exists in V2.

### Route Preservation Score: 33% ⚠️

- **Working**: 2 of 6 critical route types
- **Broken/Incompatible**: 4 of 6 critical route types
- **SEO Risk**: HIGH - All indexed URLs will break

---

## 1. Sitemap Analysis

### Production Sitemap Status
- **URL**: https://quizadvisor.com/sitemap.xml
- **Status**: 404 Not Found
- **Note**: Robots.txt references sitemap, but file not accessible

### Route Discovery via Homepage
From production homepage (`https://quizadvisor.com/`), discovered:

**Cities Routes** (6 examples found):
- `/cities/austin`
- `/cities/denver`
- `/cities/dublin`
- `/cities/houston`
- `/cities/liverpool`
- `/cities/london`

**Countries Routes** (3 examples found):
- `/countries/ireland`
- `/countries/united-kingdom`
- `/countries/united-states`

**Venues Routes** (5 examples found):
- `/venues/albion-hotel-1759813035`
- `/venues/bradys`
- `/venues/broxton-brewery-public-house`
- `/venues/latest`
- `/venues/westbury-park-pub-and-kitchen`

### V2 Sitemap Status
- **URL**: http://localhost:4003/sitemap.xml
- **Status**: 500 Internal Server Error
- **Error**: `FunctionClauseError at GET /sitemap.xml`
- **Impact**: Search engines cannot discover V2 routes

---

## 2. URL Structure Comparison

### Production URL Patterns

| Type | Pattern | Example |
|------|---------|---------|
| Homepage | `/` | `https://quizadvisor.com/` |
| Country | `/countries/{slug}` | `/countries/united-states` |
| City | `/cities/{slug}` | `/cities/austin` |
| Venue | `/venues/{slug}` | `/venues/albion-hotel-1759813035` |
| About | `/about` | 404 in production |

### V2 URL Patterns (from router.ex)

| Type | Pattern | Route Definition |
|------|---------|------------------|
| Homepage | `/` | `live "/", HomeLive, :index` |
| Country | `/{country_slug}` | `live "/:country_slug", CountryShowLive, :show` |
| City | `/{country_slug}/{city_slug}` | `live "/:country_slug/:city_slug", CityShowLive, :show` |
| Venue | `/{country_slug}/{city_slug}/{venue_slug}` | `live "/:country_slug/:city_slug/:venue_slug", VenueShowLive, :show` |
| About | `/about` | `live "/about", AboutLive, :index` |
| Sitemap | `/sitemap.xml` | `get "/sitemap.xml", SitemapController, :sitemap` |
| Robots | `/robots.txt` | `get "/robots.txt", SitemapController, :robots` |

### 🔴 INCOMPATIBILITY DETECTED

**Production routes will NOT work in V2 without redirects or route aliases.**

---

## 3. Route Compatibility Matrix

### Critical Routes Testing Results

| Route Type | Production URL | Prod Status | V2 URL | V2 Status | Compatible? | Issues |
|------------|---------------|-------------|---------|-----------|-------------|---------|
| **Homepage** | `/` | ✅ 200 | `/` | ✅ 200 | ✅ YES | None |
| **About** | `/about` | ❌ 404 | `/about` | ✅ 200 | ⚠️ PARTIAL | Production missing |
| **Country (prod)** | `/countries/united-states` | ✅ 200 | `/countries/united-states` | 🟡 200* | ❌ NO | Shows homepage fallback |
| **Country (v2)** | N/A | N/A | `/united-states` | ✅ 200 | ✅ YES | Correct V2 pattern |
| **City (prod)** | `/cities/austin` | ✅ 200 | `/cities/austin` | 🟡 200* | ❌ NO | Shows homepage fallback |
| **City (v2)** | N/A | N/A | `/united-states/austin` | ✅ 200 | ✅ YES | Correct V2 pattern |
| **Venue (prod)** | `/venues/albion-hotel-1759813035` | ✅ 200 | `/venues/albion-hotel-1759813035` | 🟡 200* | ❌ NO | Shows homepage fallback |
| **Venue (v2)** | N/A | N/A | `/united-kingdom/liverpool/albion-hotel-1759813035` | 🟡 200* | ⚠️ PARTIAL | Shows homepage (wrong venue?) |

**Legend:**
- ✅ = Working correctly
- ❌ = Not working / incompatible
- ⚠️ = Partial compatibility
- 🟡 = Returns 200 but wrong content (fallback behavior)

---

## 4. Detailed Page Analysis

### Production Pages

#### Country Page: `/countries/united-states`
- **Status**: 200
- **Title**: "United States - Cities and Trivia Venues · Pub Quiz"
- **H1**: "United States"
- **Content**: Renders properly

#### City Page: `/cities/austin`
- **Status**: 200
- **Title**: "Austin - Trivia Venues · Pub Quiz"
- **H1**: "Austin, United States"
- **Content**: Renders properly

#### Venue Page: `/venues/albion-hotel-1759813035`
- **Status**: 200
- **Title**: (title extraction partial)
- **H1**: "Albion Hotel"
- **Content**: Renders properly

### V2 Pages

#### ✅ Working V2 Routes

**Country: `/united-states`**
- **Status**: 200
- **Title**: "Trivia Nights in United States - Trivia Advisor"
- **H1**: "Trivia Nights in United States"
- **Content**: "Explore 574 cities with trivia events"

**City: `/united-states/austin`**
- **Status**: 200
- **Title**: "Trivia Nights in Austin, United States - Trivia Advisor"
- **H1**: "Trivia Nights in Austin"
- **Content**: "United States • 24 venues"

#### ❌ Broken V2 Routes (Fallback to Homepage)

**Country (prod pattern): `/countries/united-states`**
- **Status**: 200 (but wrong content)
- **Title**: "Trivia Advisor - Find Trivia Nights Near You"
- **H1**: "Trivia Advisor"
- **Content**: Homepage hero and city grid
- **Issue**: Phoenix router doesn't match `/countries/*` pattern, falls back to homepage

**City (prod pattern): `/cities/austin`**
- **Status**: 200 (but wrong content)
- **Title**: "Trivia Advisor - Find Trivia Nights Near You"
- **H1**: "Trivia Advisor"
- **Content**: Homepage hero and city grid
- **Issue**: Phoenix router doesn't match `/cities/*` pattern, falls back to homepage

**Venue (prod pattern): `/venues/albion-hotel-1759813035`**
- **Status**: 200 (but wrong content)
- **Title**: "Trivia Advisor - Find Trivia Nights Near You"
- **H1**: "Trivia Advisor"
- **Content**: Homepage hero and city grid
- **Issue**: Phoenix router doesn't match `/venues/*` pattern, falls back to homepage

---

## 5. Critical Issues Found

### 🔴 Issue #1: URL Structure Incompatibility

**Severity**: CRITICAL
**Impact**: 100% of indexed URLs will break

**Details:**
- Production uses resource-based paths: `/cities/`, `/countries/`, `/venues/`
- V2 uses hierarchical paths: `/{country}/{city}/{venue}`
- No route aliases or redirects configured

**Example Breakage:**
- Production: `/cities/austin` ✅
- V2: `/cities/austin` → Shows homepage ❌
- V2 Correct: `/united-states/austin` ✅

**SEO Impact:**
- All Google-indexed city pages will show homepage
- Users will lose direct access to specific pages
- Search rankings will drop due to content mismatch

### 🔴 Issue #2: Silent Fallback Bug

**Severity**: CRITICAL
**Impact**: User confusion, SEO damage

**Details:**
- V2 returns 200 OK for non-existent routes
- Instead of 404, shows homepage content
- Search engines will index wrong content

**Affected Routes:**
- `/cities/*` → Homepage fallback
- `/countries/*` → Homepage fallback
- `/venues/*` → Homepage fallback

**Expected Behavior:**
- Return 404 Not Found
- OR redirect to correct V2 URL pattern

### 🔴 Issue #3: Sitemap Endpoint Broken

**Severity**: HIGH
**Impact**: Search engine discovery blocked

**Details:**
- `/sitemap.xml` crashes with FunctionClauseError
- Search engines cannot discover V2 content
- Manual submission required (temporary workaround)

**Error:**
```
FunctionClauseError at GET /sitemap.xml
```

**Location**: `TriviaAdvisorWeb.SitemapController`

### 🟡 Issue #4: Production /about Missing

**Severity**: LOW
**Impact**: Broken link in production

**Details:**
- V2 has `/about` route configured
- Production returns 404
- Not an issue for V2, but indicates incomplete production deployment

---

## 6. Priority Action Items

### P0 - Blocking (Must Fix Before Launch)

1. **Add Route Aliases/Redirects**
   - **File**: `/lib/trivia_advisor_web/router.ex`
   - **Action**: Add redirect routes for production URL patterns
   ```elixir
   # Add before dynamic routes
   live "/countries/:country_slug", CountryShowLive, :show
   live "/cities/:city_slug", CityRedirectLive, :redirect
   live "/venues/:venue_slug", VenueRedirectLive, :redirect
   ```
   - **Alt**: Use `get` routes with redirect logic to V2 patterns

2. **Fix Sitemap Generation**
   - **File**: `/lib/trivia_advisor_web/controllers/sitemap_controller.ex`
   - **Action**: Debug FunctionClauseError
   - **Test**: Ensure `/sitemap.xml` returns valid XML

3. **Implement Proper 404 Handling**
   - **Issue**: Unknown routes show homepage (200 OK)
   - **Action**: Configure proper 404 responses
   - **Test**: `/invalid-route` should return 404, not homepage

### P1 - High Priority (SEO Critical)

4. **Create URL Mapping Strategy**
   - **Challenge**: Map `/cities/{slug}` → `/{country}/{city}`
   - **Options**:
     - A) Database lookup to find country for city
     - B) Redirect to search results
     - C) Show disambiguation page
   - **Recommended**: Option A with database lookup

5. **Generate Complete Sitemap**
   - **Content**: All countries, cities, venues in V2 format
   - **Format**: `/{country}/{city}/{venue}` patterns
   - **Test**: Validate against sitemap.org schema

### P2 - Medium Priority (UX Improvement)

6. **Add Canonical Tags**
   - **Purpose**: Tell search engines about URL changes
   - **Implementation**: Add to all page templates
   ```html
   <link rel="canonical" href="https://quizadvisor.com/{v2-pattern}">
   ```

7. **Implement 301 Redirects**
   - **Purpose**: Preserve SEO juice from old URLs
   - **Method**: Server-side redirects (not meta refresh)
   - **Test**: Verify redirect chain length = 1

---

## 7. Route Preservation Score Calculation

### Total Routes Analyzed: 6

#### Working Routes (2):
1. Homepage: `/`
2. Country (V2 pattern): `/{country_slug}`

#### Partially Working (1):
3. About: `/about` (works in V2, 404 in production)

#### Broken/Incompatible (3):
4. Country (prod pattern): `/countries/{slug}`
5. City (prod pattern): `/cities/{slug}`
6. Venue (prod pattern): `/venues/{slug}`

### Final Score: 33% (2/6 working)

**Grade**: F (Failing)
**Risk Level**: CRITICAL
**Recommendation**: DO NOT DEPLOY until P0 issues resolved

---

## 8. Testing Methodology

### Tools Used:
- `curl` - HTTP requests and response analysis
- `grep`/`sed` - HTML parsing and content extraction
- Manual analysis of router.ex configuration

### Test Coverage:
- ✅ HTTP status codes
- ✅ Page titles
- ✅ H1 content
- ✅ URL pattern matching
- ✅ Fallback behavior detection
- ✅ Content validation (homepage vs. specific pages)

### Limitations:
- Could not access production sitemap.xml (404)
- JavaScript-rendered content not tested
- Full site crawl not performed (limited to samples)

---

## 9. Recommendations

### Immediate Actions (Next 24 Hours)

1. **Fix Sitemap Controller**
   - Debug and resolve FunctionClauseError
   - Generate valid XML sitemap

2. **Add Redirect Routes**
   - Implement URL mapping logic
   - Test all production patterns

3. **Configure 404 Handling**
   - Prevent homepage fallback
   - Return proper HTTP status codes

### Short-Term (Next Week)

4. **Database Migration Planning**
   - Add slug mapping tables if needed
   - Index for fast lookups

5. **SEO Transition Plan**
   - Submit new sitemap to Google Search Console
   - Monitor crawl errors
   - Set up 301 redirects

6. **Testing Suite**
   - Automated tests for all route patterns
   - Redirect verification
   - SEO metadata validation

### Long-Term (Post-Launch)

7. **Monitor Search Console**
   - Track 404 errors
   - Monitor ranking changes
   - Validate sitemap processing

8. **Analytics Setup**
   - Track old URL patterns hitting server
   - Measure redirect effectiveness
   - Monitor user drop-off

---

## 10. Appendices

### A. Production Route Examples

**Countries:**
- `/countries/ireland`
- `/countries/united-kingdom`
- `/countries/united-states`

**Cities:**
- `/cities/austin`
- `/cities/denver`
- `/cities/dublin`
- `/cities/houston`
- `/cities/liverpool`
- `/cities/london`

**Venues:**
- `/venues/albion-hotel-1759813035`
- `/venues/bradys`
- `/venues/broxton-brewery-public-house`
- `/venues/westbury-park-pub-and-kitchen`

### B. V2 Router Configuration

```elixir
# From lib/trivia_advisor_web/router.ex
scope "/", TriviaAdvisorWeb do
  pipe_through :browser

  live "/", HomeLive, :index
  live "/about", AboutLive, :index

  get "/sitemap.xml", SitemapController, :sitemap
  get "/robots.txt", SitemapController, :robots

  # Dynamic routes matching V1 patterns for SEO preservation (COMMENT IS MISLEADING!)
  live "/:country_slug/:city_slug/:venue_slug", VenueShowLive, :show
  live "/:country_slug/:city_slug", CityShowLive, :show
  live "/:country_slug", CountryShowLive, :show
end
```

**Note**: Router comment claims "matching V1 patterns for SEO preservation" but patterns don't match production!

### C. Browser Testing Script

For comprehensive testing, use this script:

```bash
#!/bin/bash
# Test all route patterns

PROD_BASE="https://quizadvisor.com"
V2_BASE="http://localhost:4003"

test_url() {
  echo "Testing: $1"
  curl -sL -o /dev/null -w "Status: %{http_code}\n" "$1"
}

# Production patterns
test_url "$PROD_BASE/countries/united-states"
test_url "$PROD_BASE/cities/austin"
test_url "$PROD_BASE/venues/albion-hotel-1759813035"

# V2 patterns
test_url "$V2_BASE/countries/united-states"
test_url "$V2_BASE/cities/austin"
test_url "$V2_BASE/venues/albion-hotel-1759813035"

# V2 correct patterns
test_url "$V2_BASE/united-states"
test_url "$V2_BASE/united-states/austin"
```

---

## Summary & Next Steps

**Current State:**
- V2 is NOT ready for production deployment
- 67% of route types are incompatible
- Critical SEO issues will cause ranking loss

**Must Complete Before Launch:**
1. Fix sitemap.xml endpoint
2. Add production URL pattern support
3. Implement proper 404 handling
4. Test all redirect logic

**Estimated Fix Time:**
- P0 fixes: 1-2 days
- P1 fixes: 2-3 days
- Full testing: 1 day
- **Total**: 4-6 days

**Risk If Deployed Now:**
- Search rankings will drop
- Users will encounter broken links
- Direct traffic will decrease
- Bounce rate will increase

---

**Report Generated**: 2025-01-09
**Auditor**: Claude (Trivia Advisor V2 Analysis)
**Next Review**: After P0 fixes implemented
