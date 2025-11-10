# 🚨 URGENT: Route Compatibility Issues - Action Plan

**Status**: BLOCKING DEPLOYMENT
**Severity**: CRITICAL
**Route Preservation Score**: 33% (F Grade)

---

## TL;DR - The Problem

**Production (QuizAdvisor) uses:**
- `/countries/united-states`
- `/cities/austin`
- `/venues/venue-name`

**V2 expects:**
- `/united-states` (country)
- `/united-states/austin` (city)
- `/united-states/austin/venue-name` (venue)

**Result**: ALL production URLs will show homepage instead of correct content.

---

## Critical Issues (MUST FIX)

### 🔴 Issue #1: URL Pattern Mismatch
- **Impact**: 100% of indexed URLs break
- **Symptom**: `/cities/austin` returns 200 OK but shows homepage
- **Expected**: Should redirect to `/united-states/austin` or return 404
- **Fix Time**: 1-2 days

### 🔴 Issue #2: Sitemap Crashes
- **Impact**: Search engines can't discover content
- **Error**: `FunctionClauseError at GET /sitemap.xml`
- **File**: `lib/trivia_advisor_web/controllers/sitemap_controller.ex`
- **Fix Time**: 2-4 hours

### 🔴 Issue #3: Silent Fallbacks
- **Impact**: Wrong content served with 200 OK status
- **Symptom**: Unknown routes show homepage instead of 404
- **Expected**: Proper 404 responses
- **Fix Time**: 1-2 hours

---

## Immediate Actions Required

### Today (Next 4 Hours)

#### 1. Fix Sitemap Controller ⏰ 2-4 hours
**File**: `lib/trivia_advisor_web/controllers/sitemap_controller.ex`

**Debug Steps:**
```bash
# Test current error
curl http://localhost:4003/sitemap.xml

# Check controller code
# Fix FunctionClauseError
# Verify XML output
```

**Success Criteria:**
- `/sitemap.xml` returns valid XML
- No crashes or errors
- Contains all V2 route patterns

---

#### 2. Add Production URL Redirects ⏰ 3-4 hours
**File**: `lib/trivia_advisor_web/router.ex`

**Implementation Options:**

**Option A: Database Lookups (RECOMMENDED)**
```elixir
# Add before existing dynamic routes

# Country redirect
get "/countries/:slug", RedirectController, :country_redirect

# City redirect (requires DB lookup to find country)
get "/cities/:slug", RedirectController, :city_redirect

# Venue redirect (requires DB lookup to find country + city)
get "/venues/:slug", RedirectController, :venue_redirect
```

Create `lib/trivia_advisor_web/controllers/redirect_controller.ex`:
```elixir
defmodule TriviaAdvisorWeb.RedirectController do
  use TriviaAdvisorWeb, :controller
  alias TriviaAdvisor.Locations

  def country_redirect(conn, %{"slug" => slug}) do
    # /countries/united-states -> /united-states
    redirect(conn, to: "/#{slug}")
  end

  def city_redirect(conn, %{"slug" => slug}) do
    case Locations.get_city_by_slug(slug) do
      %{country_slug: country_slug} ->
        # /cities/austin -> /united-states/austin
        redirect(conn, to: "/#{country_slug}/#{slug}")
      nil ->
        # City not found, show 404
        conn
        |> put_status(:not_found)
        |> put_view(html: TriviaAdvisorWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  def venue_redirect(conn, %{"slug" => slug}) do
    case Locations.get_venue_by_slug(slug) do
      %{country_slug: country, city_slug: city} ->
        # /venues/venue-name -> /country/city/venue-name
        redirect(conn, to: "/#{country}/#{city}/#{slug}")
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(html: TriviaAdvisorWeb.ErrorHTML)
        |> render(:"404")
    end
  end
end
```

**Option B: Simple Redirects (QUICK FIX)**
```elixir
# For countries, easy redirect
get "/countries/:slug", RedirectController, :country_redirect

# For cities/venues, show error page explaining URL change
get "/cities/*path", PageController, :url_changed
get "/venues/*path", PageController, :url_changed
```

**Success Criteria:**
- `/countries/united-states` redirects to `/united-states`
- `/cities/austin` redirects to correct country/city path OR returns helpful 404
- `/venues/venue-name` redirects to correct path OR returns helpful 404

---

#### 3. Fix 404 Handling ⏰ 1-2 hours
**File**: `lib/trivia_advisor_web/router.ex`

**Problem**: Unknown routes match catch-all `/:country_slug` and show homepage

**Solution**: Add explicit 404 handling for known invalid patterns
```elixir
scope "/", TriviaAdvisorWeb do
  pipe_through :browser

  # ... existing routes ...

  # Catch invalid patterns before dynamic routes
  get "/invalid/*path", ErrorController, :not_found

  # Dynamic routes (these should be LAST)
  live "/:country_slug/:city_slug/:venue_slug", VenueShowLive, :show
  live "/:country_slug/:city_slug", CityShowLive, :show
  live "/:country_slug", CountryShowLive, :show
end
```

**Alternative**: Update LiveViews to check if resource exists
```elixir
# In CountryShowLive.mount/3
def mount(%{"country_slug" => slug}, _session, socket) do
  case Locations.get_country_by_slug(slug) do
    nil ->
      {:ok, socket |> put_flash(:error, "Country not found") |> redirect(to: "/")}
    country ->
      {:ok, assign(socket, country: country)}
  end
end
```

---

### Tomorrow (Next 8 Hours)

#### 4. Database Query Functions ⏰ 4-6 hours

**File**: `lib/trivia_advisor/locations.ex` (or create if missing)

```elixir
defmodule TriviaAdvisor.Locations do
  import Ecto.Query
  alias TriviaAdvisor.Repo

  # Assuming you have schemas defined for countries, cities, venues

  def get_city_by_slug(slug) do
    # Query Eventasaurus DB for city by slug
    # Return %{slug: "austin", country_slug: "united-states"}
    # or nil if not found
  end

  def get_venue_by_slug(slug) do
    # Query for venue by slug
    # Return %{slug: "venue", city_slug: "austin", country_slug: "united-states"}
    # or nil if not found
  end

  def get_country_by_slug(slug) do
    # Query for country by slug
    # Return country record or nil
  end
end
```

**Success Criteria:**
- Functions return correct country/city for any slug
- Handle missing records gracefully
- Fast queries (indexed slugs)

---

#### 5. Testing Suite ⏰ 2-3 hours

**File**: `test/trivia_advisor_web/routes_test.exs`

```elixir
defmodule TriviaAdvisorWeb.RoutesTest do
  use TriviaAdvisorWeb.ConnCase

  describe "production URL compatibility" do
    test "redirects /countries/:slug to /:slug", %{conn: conn} do
      conn = get(conn, "/countries/united-states")
      assert redirected_to(conn) == "/united-states"
    end

    test "redirects /cities/:slug to /:country/:city", %{conn: conn} do
      conn = get(conn, "/cities/austin")
      assert redirected_to(conn) =~ ~r|/[^/]+/austin|
    end

    test "returns 404 for unknown routes", %{conn: conn} do
      conn = get(conn, "/invalid/route/here")
      assert conn.status == 404
    end
  end
end
```

Run tests:
```bash
mix test test/trivia_advisor_web/routes_test.exs
```

---

#### 6. Generate Valid Sitemap ⏰ 1-2 hours

After fixing controller, generate sitemap with V2 patterns:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://quizadvisor.com/</loc>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://quizadvisor.com/united-states</loc>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>https://quizadvisor.com/united-states/austin</loc>
    <priority>0.6</priority>
  </url>
  <!-- ... all countries, cities, venues ... -->
</urlset>
```

**Test:**
```bash
curl http://localhost:4003/sitemap.xml | xmllint --format -
```

---

## Testing Checklist

Before marking complete, verify:

### Redirects Working
- [ ] `/countries/united-states` → `/united-states` (301)
- [ ] `/cities/austin` → `/united-states/austin` (301)
- [ ] `/venues/venue-name` → `/country/city/venue-name` (301)

### 404s Working
- [ ] `/invalid-path` returns 404 (not homepage)
- [ ] `/cities/nonexistent` returns 404 (not homepage)
- [ ] `/venues/fake-venue` returns 404 (not homepage)

### Sitemap Working
- [ ] `/sitemap.xml` returns valid XML
- [ ] Sitemap contains all countries
- [ ] Sitemap contains sample cities
- [ ] Sitemap validates at sitemap.org/validator

### Content Correct
- [ ] Homepage shows homepage content
- [ ] Country pages show country content (not homepage)
- [ ] City pages show city content (not homepage)
- [ ] Venue pages show venue content (not homepage)

---

## Files to Modify

### Priority 1 (Today)
1. `lib/trivia_advisor_web/controllers/sitemap_controller.ex` - Fix crash
2. `lib/trivia_advisor_web/router.ex` - Add redirects
3. `lib/trivia_advisor_web/controllers/redirect_controller.ex` - Create new

### Priority 2 (Tomorrow)
4. `lib/trivia_advisor/locations.ex` - Database queries
5. `test/trivia_advisor_web/routes_test.exs` - Test coverage

### Nice to Have
6. `lib/trivia_advisor_web/controllers/page_controller.ex` - Helpful 404 pages
7. `lib/trivia_advisor_web/templates/error/url_changed.html.heex` - User messaging

---

## Success Criteria

### Deployment Ready When:
1. ✅ Sitemap generates without errors
2. ✅ All production URL patterns redirect or 404 properly
3. ✅ No routes return 200 with wrong content
4. ✅ Test suite passes 100%
5. ✅ Manual testing confirms all route types work

### Estimated Total Time: 12-18 hours
- Today: 6-10 hours
- Tomorrow: 6-8 hours

---

## Questions to Answer

Before implementing, clarify:

1. **City/Venue Slug Uniqueness**
   - Are city slugs globally unique? (e.g., only one "austin")
   - Or do we need country context? (e.g., "austin-usa" vs "austin-uk")

2. **Database Schema**
   - Do we have `countries`, `cities`, `venues` tables?
   - Are slugs indexed for fast lookups?
   - What are the exact column names?

3. **Redirect Strategy**
   - 301 (permanent) or 302 (temporary)?
   - Redirect or show helpful error page?

4. **Legacy Support**
   - How long to maintain redirects?
   - Track redirect usage in analytics?

---

## Communication Plan

**To Stakeholders:**
"We discovered critical URL compatibility issues between production and V2. All indexed URLs will break without fixes. Estimated 2-3 days to resolve. Deployment on hold until complete."

**To Team:**
"Need to add redirect layer for production URLs. Using database lookups to map old patterns to new. Also fixing sitemap generation crash."

---

**Created**: 2025-01-09
**Owner**: Development Team
**Deadline**: Before production deployment
**Tracking**: Link to ROUTE_AUDIT_REPORT.md for full details
