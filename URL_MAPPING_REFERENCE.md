# URL Mapping Reference: Production → V2

Quick reference for converting QuizAdvisor (production) URLs to Trivia Advisor V2 format.

---

## URL Pattern Comparison

| Type | Production Pattern | V2 Pattern | Redirect Needed? |
|------|-------------------|------------|------------------|
| Homepage | `/` | `/` | ❌ No (same) |
| About | `/about` | `/about` | ❌ No (same) |
| Country | `/countries/{slug}` | `/{slug}` | ✅ YES |
| City | `/cities/{slug}` | `/{country}/{slug}` | ✅ YES (+ lookup) |
| Venue | `/venues/{slug}` | `/{country}/{city}/{slug}` | ✅ YES (+ lookup) |
| Sitemap | `/sitemap.xml` | `/sitemap.xml` | ⚠️ Fix crash |
| Robots | `/robots.txt` | `/robots.txt` | ❌ No |

---

## Concrete Examples

### Countries

| Production URL | V2 URL | Notes |
|---------------|--------|-------|
| `/countries/united-states` | `/united-states` | Simple prefix removal |
| `/countries/united-kingdom` | `/united-kingdom` | Simple prefix removal |
| `/countries/ireland` | `/ireland` | Simple prefix removal |

**Redirect Logic:**
```elixir
# /countries/:slug -> /:slug
"/countries/#{slug}" -> "/#{slug}"
```

---

### Cities

| Production URL | V2 URL | Database Lookup Required |
|---------------|--------|--------------------------|
| `/cities/austin` | `/united-states/austin` | ✅ Need country |
| `/cities/denver` | `/united-states/denver` | ✅ Need country |
| `/cities/dublin` | `/ireland/dublin` | ✅ Need country |
| `/cities/liverpool` | `/united-kingdom/liverpool` | ✅ Need country |
| `/cities/london` | `/united-kingdom/london` | ✅ Need country |
| `/cities/houston` | `/united-states/houston` | ✅ Need country |

**Redirect Logic:**
```elixir
# /cities/:slug -> /:country/:slug
# Requires: Locations.get_city_by_slug(slug) -> %{country_slug: "united-states"}
case Locations.get_city_by_slug(slug) do
  %{country_slug: country} -> "/#{country}/#{slug}"
  nil -> 404
end
```

**Database Query:**
```elixir
def get_city_by_slug(slug) do
  from(c in City,
    join: country in assoc(c, :country),
    where: c.slug == ^slug,
    select: %{
      city_slug: c.slug,
      country_slug: country.slug
    }
  )
  |> Repo.one()
end
```

---

### Venues

| Production URL | V2 URL | Lookups Required |
|---------------|--------|------------------|
| `/venues/albion-hotel-1759813035` | `/united-kingdom/liverpool/albion-hotel-1759813035` | ✅ Country + City |
| `/venues/bradys` | `/{country}/{city}/bradys` | ✅ Country + City |
| `/venues/broxton-brewery-public-house` | `/{country}/{city}/broxton-brewery-public-house` | ✅ Country + City |
| `/venues/westbury-park-pub-and-kitchen` | `/{country}/{city}/westbury-park-pub-and-kitchen` | ✅ Country + City |

**Redirect Logic:**
```elixir
# /venues/:slug -> /:country/:city/:slug
# Requires: Locations.get_venue_by_slug(slug) -> %{country_slug: "...", city_slug: "..."}
case Locations.get_venue_by_slug(slug) do
  %{country_slug: country, city_slug: city} -> "/#{country}/#{city}/#{slug}"
  nil -> 404
end
```

**Database Query:**
```elixir
def get_venue_by_slug(slug) do
  from(v in Venue,
    join: city in assoc(v, :city),
    join: country in assoc(city, :country),
    where: v.slug == ^slug,
    select: %{
      venue_slug: v.slug,
      city_slug: city.slug,
      country_slug: country.slug
    }
  )
  |> Repo.one()
end
```

---

## Special Cases

### Multiple Cities with Same Name

**Problem**: What if two cities have the same slug?
- Example: `austin` could exist in USA and Australia

**Solutions:**

**Option 1: Disambiguate in Database**
```
austin-usa
austin-australia
```

**Option 2: Show Disambiguation Page**
```
/cities/austin
  -> Shows: "Which Austin?"
     - Austin, United States
     - Austin, Australia
```

**Option 3: Use Most Popular**
```
/cities/austin
  -> Redirects to most popular (USA)
  -> Log analytics to verify assumption
```

---

### Venue Slug Uniqueness

**Production Evidence**: Some venues have IDs appended
- `albion-hotel-1759813035` (has unique ID)
- `bradys` (no ID - might not be unique)

**Implication**: If slugs aren't globally unique, we MUST include country/city in URL

**Query Strategy:**
```elixir
# If slug not unique globally
def get_venue_by_slug(slug) do
  case Repo.all(from v in Venue, where: v.slug == ^slug) do
    [] -> nil  # Not found
    [venue] -> venue  # Only one match, return it
    _multiple -> nil  # Ambiguous, return nil and show error
  end
end
```

---

## Router Implementation Plan

### Step 1: Add Redirect Routes

**File**: `lib/trivia_advisor_web/router.ex`

```elixir
scope "/", TriviaAdvisorWeb do
  pipe_through :browser

  # Static routes (no changes)
  live "/", HomeLive, :index
  live "/about", AboutLive, :index
  get "/sitemap.xml", SitemapController, :sitemap
  get "/robots.txt", SitemapController, :robots

  # NEW: Production compatibility redirects
  # Add BEFORE dynamic routes to prevent catch-all matching
  get "/countries/:slug", RedirectController, :country
  get "/cities/:slug", RedirectController, :city
  get "/venues/:slug", RedirectController, :venue

  # Existing dynamic routes (KEEP LAST)
  live "/:country_slug/:city_slug/:venue_slug", VenueShowLive, :show
  live "/:country_slug/:city_slug", CityShowLive, :show
  live "/:country_slug", CountryShowLive, :show
end
```

### Step 2: Create Redirect Controller

**File**: `lib/trivia_advisor_web/controllers/redirect_controller.ex`

```elixir
defmodule TriviaAdvisorWeb.RedirectController do
  use TriviaAdvisorWeb, :controller
  alias TriviaAdvisor.Locations

  # /countries/:slug -> /:slug
  def country(conn, %{"slug" => slug}) do
    redirect(conn, to: ~p"/#{slug}", status: 301)
  end

  # /cities/:slug -> /:country/:city
  def city(conn, %{"slug" => slug}) do
    case Locations.get_city_with_country(slug) do
      %{country_slug: country} ->
        redirect(conn, to: ~p"/#{country}/#{slug}", status: 301)

      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(html: TriviaAdvisorWeb.ErrorHTML)
        |> render(:"404", message: "City not found: #{slug}")
    end
  end

  # /venues/:slug -> /:country/:city/:venue
  def venue(conn, %{"slug" => slug}) do
    case Locations.get_venue_with_location(slug) do
      %{country_slug: country, city_slug: city} ->
        redirect(conn, to: ~p"/#{country}/#{city}/#{slug}", status: 301)

      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(html: TriviaAdvisorWeb.ErrorHTML)
        |> render(:"404", message: "Venue not found: #{slug}")
    end
  end
end
```

### Step 3: Add Database Queries

**File**: `lib/trivia_advisor/locations.ex`

```elixir
defmodule TriviaAdvisor.Locations do
  import Ecto.Query
  alias TriviaAdvisor.Repo
  # Assuming schemas: Country, City, Venue

  @doc """
  Get city with country slug for URL building.
  Returns %{country_slug: "...", city_slug: "..."} or nil
  """
  def get_city_with_country(city_slug) do
    from(c in City,
      join: country in assoc(c, :country),
      where: c.slug == ^city_slug,
      select: %{
        city_slug: c.slug,
        country_slug: country.slug
      }
    )
    |> Repo.one()
  end

  @doc """
  Get venue with full location for URL building.
  Returns %{country_slug: "...", city_slug: "...", venue_slug: "..."} or nil
  """
  def get_venue_with_location(venue_slug) do
    from(v in Venue,
      join: city in assoc(v, :city),
      join: country in assoc(city, :country),
      where: v.slug == ^venue_slug,
      select: %{
        venue_slug: v.slug,
        city_slug: city.slug,
        country_slug: country.slug
      }
    )
    |> Repo.one()
  end
end
```

---

## Testing Matrix

### Manual Test Cases

| Test | Production URL | Expected V2 Redirect | Status |
|------|---------------|----------------------|--------|
| T1 | `/` | `/` (no redirect) | ⬜️ |
| T2 | `/about` | `/about` (no redirect) | ⬜️ |
| T3 | `/countries/united-states` | `/united-states` (301) | ⬜️ |
| T4 | `/countries/ireland` | `/ireland` (301) | ⬜️ |
| T5 | `/cities/austin` | `/united-states/austin` (301) | ⬜️ |
| T6 | `/cities/dublin` | `/ireland/dublin` (301) | ⬜️ |
| T7 | `/cities/fake-city` | 404 Not Found | ⬜️ |
| T8 | `/venues/albion-hotel-1759813035` | `/{country}/{city}/albion-hotel-1759813035` (301) | ⬜️ |
| T9 | `/venues/fake-venue` | 404 Not Found | ⬜️ |
| T10 | `/invalid-path` | 404 Not Found (not homepage!) | ⬜️ |

### Automated Tests

**File**: `test/trivia_advisor_web/redirect_controller_test.exs`

```elixir
defmodule TriviaAdvisorWeb.RedirectControllerTest do
  use TriviaAdvisorWeb.ConnCase

  describe "country redirects" do
    test "redirects /countries/:slug to /:slug", %{conn: conn} do
      conn = get(conn, "/countries/united-states")
      assert redirected_to(conn, 301) == "/united-states"
    end
  end

  describe "city redirects" do
    test "redirects /cities/:slug to /:country/:city", %{conn: conn} do
      # Assumes austin exists in DB with country = united-states
      conn = get(conn, "/cities/austin")
      assert redirected_to(conn, 301) == "/united-states/austin"
    end

    test "returns 404 for unknown city", %{conn: conn} do
      conn = get(conn, "/cities/nonexistent-city")
      assert conn.status == 404
    end
  end

  describe "venue redirects" do
    test "redirects /venues/:slug to full path", %{conn: conn} do
      # Assumes venue exists in DB
      conn = get(conn, "/venues/albion-hotel-1759813035")
      assert redirected_to(conn, 301) =~ ~r|/[^/]+/[^/]+/albion-hotel-1759813035|
    end

    test "returns 404 for unknown venue", %{conn: conn} do
      conn = get(conn, "/venues/fake-venue")
      assert conn.status == 404
    end
  end
end
```

---

## Performance Considerations

### Database Query Optimization

**Index Requirements:**
```sql
CREATE INDEX idx_cities_slug ON cities(slug);
CREATE INDEX idx_venues_slug ON venues(slug);
CREATE INDEX idx_countries_slug ON countries(slug);
```

**Query Performance:**
- Expected: <10ms per lookup
- Acceptable: <50ms per lookup
- Red Flag: >100ms per lookup

**Caching Strategy:**
```elixir
# Cache common redirects in memory
# Use ETS or GenServer with periodic refresh
def get_city_with_country_cached(slug) do
  case :ets.lookup(:city_redirects, slug) do
    [{^slug, result}] -> result
    [] ->
      result = get_city_with_country(slug)
      :ets.insert(:city_redirects, {slug, result})
      result
  end
end
```

---

## Analytics & Monitoring

### Track Redirect Usage

**Log Each Redirect:**
```elixir
def city(conn, %{"slug" => slug}) do
  Logger.info("Production URL redirect: /cities/#{slug}")
  # ... rest of redirect logic
end
```

**Metrics to Track:**
1. Number of redirects per day
2. Most common redirected URLs
3. 404 rate for production URLs
4. Average redirect lookup time

**Goal**: Reduce redirect usage over time as search engines re-index

---

## Migration Timeline

### Week 1: Implementation
- ✅ Add redirect routes
- ✅ Create redirect controller
- ✅ Add database queries
- ✅ Write tests

### Week 2: Testing
- ✅ Manual testing of all patterns
- ✅ Performance testing
- ✅ Analytics setup
- ✅ Monitor error rates

### Week 3-4: Deployment
- ✅ Deploy to staging
- ✅ Run full site crawl
- ✅ Submit new sitemap to Google
- ✅ Deploy to production

### Month 2-3: Monitoring
- 📊 Monitor redirect usage
- 📊 Track 404 errors
- 📊 Verify search rankings stable
- 📊 Measure page load times

### Month 4+: Optimization
- 🔄 Add caching if needed
- 🔄 Remove redirects for re-indexed URLs
- 🔄 Update any remaining old links

---

## FAQ

**Q: Can we keep the old URLs forever?**
A: Yes, but it adds complexity. Better to maintain redirects for 6-12 months, then remove.

**Q: What if a city name changes?**
A: Redirect from old slug to new slug, same pattern as production → V2.

**Q: Will redirects slow down the site?**
A: Minimal impact (<10ms per redirect) if database is properly indexed.

**Q: Should we use 301 (permanent) or 302 (temporary)?**
A: Use 301 - we're permanently changing URL structure.

**Q: What about query parameters?**
A: Preserve and forward: `/cities/austin?foo=bar` → `/united-states/austin?foo=bar`

---

**Last Updated**: 2025-01-09
**Status**: Implementation Guide
**Related**: ROUTE_AUDIT_REPORT.md, URGENT_ACTION_PLAN.md
