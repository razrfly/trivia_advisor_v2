# Trivia Advisor V1 → V2 Migration Roadmap

**Goal**: Migrate from legacy self-managed database to read-only Eventasaurus database consumer while preserving 100% SEO value and routing structure.

**Timeline**: 6-8 weeks
**Progress Tracking**: Sitemap URL coverage (0% → 100%)

---

## 🎯 Success Criteria

- ✅ **100% URL preservation** - All sitemap URLs functional in V2
- ✅ **100% SEO preservation** - JSON-LD, meta tags, Open Graph identical
- ✅ **100% route parity** - All public routes match V1 structure
- ✅ **Read-only database** - No write operations, Eventasaurus as single source of truth
- ✅ **Component reuse** - 18 working LiveView components migrated
- ✅ **Zero technical debt** - Clean, modern Phoenix 1.7+ patterns

---

## 📊 Sitemap Baseline Analysis

### URL Categories (from V1 sitemap code)

| Category | Route Pattern | Priority | Changefreq | Example |
|----------|--------------|----------|------------|---------|
| **Homepage** | `/` | 1.0 | weekly | `https://quizadvisor.com/` |
| **Cities Index** | `/cities` | 0.9 | weekly | `https://quizadvisor.com/cities` |
| **City Pages** | `/cities/:slug` | 0.8 | daily | `https://quizadvisor.com/cities/london-gb` |
| **Venue Pages** | `/venues/:slug` | 0.7 | daily | `https://quizadvisor.com/venues/the-crown-pub-london-gb` |

**Note**: Country pages (`/countries/:slug`) are NOT in V1 sitemap but exist in routes - clarify if needed.

### Expected URL Count (to be validated in Phase 0)
- **Static pages**: 2 (homepage + cities index)
- **City pages**: ~XXX (query: `SELECT COUNT(*) FROM cities`)
- **Venue pages**: ~XXX (query: `SELECT COUNT(*) FROM venues WHERE deleted_at IS NULL`)
- **Total URLs**: ~XXX

**Progress Metric**: Track `(migrated_urls / total_urls) * 100%`

---

## Phase 0: Sitemap Baseline & Database Validation
**Duration**: 1-2 days
**Goal**: Establish URL inventory and validate database connectivity

### Tasks

#### 0.1: Database Connectivity Validation
- [ ] Test Supabase connection with `SUPABASE_DATABASE_URL`
- [ ] Verify read-only permissions (attempt write should fail)
- [ ] Confirm PostGIS extension availability (`SELECT PostGIS_version()`)
- [ ] Test basic query execution

**Success Criteria**:
- Can connect to Eventasaurus database
- Read queries work, write queries fail (read-only enforced)
- PostGIS functions available for spatial queries

#### 0.2: Sitemap URL Inventory
- [ ] Query actual counts from database:
  ```sql
  -- Cities count
  SELECT COUNT(*) FROM cities;

  -- Active venues count (non-deleted)
  SELECT COUNT(*) FROM venues WHERE deleted_at IS NULL;

  -- Total sitemap URLs = 2 + cities + venues
  ```
- [ ] Document expected URL structure for each category
- [ ] Create baseline tracking document with URL counts
- [ ] Identify any edge cases (merged venues, redirects, etc.)

**Success Criteria**:
- Know exact number of URLs to migrate
- Have baseline for progress tracking
- Understand redirect requirements (merged venues)

#### 0.3: Route Preservation Analysis
- [ ] Extract all V1 public routes from `router.ex`
- [ ] Map routes to sitemap URL categories
- [ ] Identify any routes NOT in sitemap (country pages, latest venues, etc.)
- [ ] Document route parameters and slug formats
- [ ] Verify slug generation strategy (city: `name-country_code`, venue: `name-city-country`)

**Success Criteria**:
- Complete list of routes to preserve
- Slug format documentation
- Edge case identification (redirects, canonical URLs)

#### 0.4: SEO Asset Inventory
- [ ] Document all JSON-LD schemas (Event, Breadcrumb, Organization)
- [ ] List all Open Graph meta tags
- [ ] Identify Twitter Card implementation
- [ ] Document sitemap generation strategy (daily updates, S3/Tigris upload)
- [ ] List robots.txt configuration

**Success Criteria**:
- Complete SEO feature inventory
- Understand all structured data requirements
- Have checklist for SEO validation

---

## Phase 1: Core Infrastructure Setup
**Duration**: 3-4 days
**Goal**: Phoenix 1.7 foundation with Ecto read-only configuration

### Tasks

#### 1.1: Ecto Configuration
- [ ] Configure Ecto repo for read-only access
- [ ] Add database connection pooling configuration
- [ ] Configure timeout settings for long-running spatial queries
- [ ] Set up dev/test/prod environment configs
- [ ] Add PostGIS types support (`geo_postgis` library)

**Files to create/update**:
- `config/config.exs`
- `config/dev.exs`
- `config/prod.exs`
- `lib/trivia_advisor_v2/repo.ex`

**Success Criteria**:
- Repo connects to Eventasaurus database
- Read-only mode enforced
- PostGIS queries supported

#### 1.2: Environment & Dependencies
- [ ] Audit V1 `mix.exs` dependencies
- [ ] Install required packages:
  - `phoenix ~> 1.7.21`
  - `phoenix_live_view`
  - `ecto_sql` + `postgrex`
  - `geo_postgis` (PostGIS support)
  - `sitemapper` (sitemap generation)
  - `ex_aws` + `ex_aws_s3` (S3/Tigris for sitemaps)
  - `countries` (currency/country data)
  - `jason` (JSON encoding)
- [ ] Remove unnecessary V1 dependencies (scraping, image upload, Oban, etc.)
- [ ] Configure Tailwind CSS with `@tailwindcss/forms` plugin
- [ ] Set up Heroicons

**Success Criteria**:
- Clean dependency list (no technical debt)
- All necessary libraries installed
- Tailwind configured and compiling

#### 1.3: Project Structure
- [ ] Set up standard Phoenix 1.7 directory structure
- [ ] Create context modules: `Locations`, `Events`
- [ ] Create web layer structure: `controllers/`, `live/`, `components/`
- [ ] Set up helper module structure

**Directory structure**:
```
lib/trivia_advisor_v2/
  ├── locations/          # Context: cities, venues, countries
  ├── events/             # Context: events, performers, sources
  └── repo.ex

lib/trivia_advisor_v2_web/
  ├── components/         # UI components (cards, search, map)
  ├── live/               # LiveView pages
  ├── controllers/        # If needed for static pages
  └── router.ex
```

**Success Criteria**:
- Clean project structure
- Contexts organized logically
- No legacy code pollution

---

## Phase 2: Database Layer & Core Queries
**Duration**: 5-7 days
**Goal**: Ecto schemas and query layer matching V1 functionality

### Tasks

#### 2.1: Ecto Schema Definitions
- [ ] **Countries schema** (`lib/trivia_advisor_v2/locations/country.ex`)
  - Fields: `id`, `name`, `iso_code`, `slug`, `inserted_at`, `updated_at`
  - Virtual fields if needed

- [ ] **Cities schema** (`lib/trivia_advisor_v2/locations/city.ex`)
  - Fields: `id`, `name`, `slug`, `coordinates` (PostGIS geometry), `country_id`
  - Associations: `belongs_to :country`
  - Unsplash metadata (if using)

- [ ] **Venues schema** (`lib/trivia_advisor_v2/locations/venue.ex`)
  - Fields: `id`, `name`, `slug`, `address`, `coordinates`, `city_id`, `deleted_at`, `merged_into_id`
  - Associations: `belongs_to :city`, `has_many :events`
  - Google Place metadata, hero images

- [ ] **Events schema** (`lib/trivia_advisor_v2/events/event.ex`)
  - Fields: `id`, `venue_id`, `day_of_week`, `start_time`, `frequency`, `entry_fee`, `currency`
  - Associations: `belongs_to :venue`, `has_many :event_sources`, `has_many :performers`

- [ ] **EventSources schema**
  - Fields: `id`, `event_id`, `source_type`, `source_url`, `last_seen_at`

- [ ] **Performers schema**
  - Fields: `id`, `event_id`, `name`, `role`

**Success Criteria**:
- All schemas match Eventasaurus table structure
- PostGIS types properly configured
- Associations defined correctly
- NO migrations created (read-only consumer)

#### 2.2: Locations Context Queries
- [ ] `Locations.get_country_by_slug(slug)`
- [ ] `Locations.get_city_by_slug(slug)`
- [ ] `Locations.get_venue_by_slug(slug)` - with merge redirect handling
- [ ] `Locations.find_venues_near_city(city, radius_km)` - PostGIS spatial query
- [ ] `Locations.get_popular_cities(limit, diverse_countries: true)` - for homepage
- [ ] `Locations.get_latest_venues(limit)` - for discovery page
- [ ] `Locations.get_cities_for_country(country)` - for country page

**PostGIS Query Example** (from V1):
```elixir
# Find venues within radius of city
from v in Venue,
  join: c in City, on: v.city_id == c.id,
  where: c.id == ^city.id,
  where: fragment("ST_Distance_Sphere(?, ?) <= ?",
    v.coordinates, c.coordinates, ^(radius_km * 1000)),
  where: is_nil(v.deleted_at),
  preload: [:city, events: :event_sources]
```

**Success Criteria**:
- All V1 queries replicated
- Spatial queries working with PostGIS
- Merge redirects handled (venues with `merged_into_id`)
- Soft-delete filtering (`deleted_at IS NULL`)

#### 2.3: Events Context Queries
- [ ] `Events.get_events_for_venue(venue_id)` - with event_sources preloaded
- [ ] `Events.get_latest_event_timestamp(venue_id)` - for sitemap lastmod
- [ ] Event date calculation logic (day_of_week + start_time → next occurrence)

**Success Criteria**:
- Event queries match V1 functionality
- Event date calculations accurate
- Event sources properly associated

---

## Phase 3: SEO & Structured Data (CRITICAL)
**Duration**: 4-5 days
**Goal**: 100% SEO preservation with JSON-LD schemas

### Tasks

#### 3.1: JSON-LD Schema Components
- [ ] **EventSchema component** (`lib/trivia_advisor_v2_web/components/seo/event_schema.ex`)
  - Generate schema.org Event JSON-LD
  - Calculate event dates from `day_of_week` + `start_time`
  - Extract organizer from `event_sources` or metadata
  - Handle price/currency with `Countries` library
  - Include venue location data
  - Image URLs (hero image + Google Place images)

- [ ] **BreadcrumbSchema component**
  - Generate schema.org BreadcrumbList
  - Hierarchy: Home > Country > City > Venue
  - URL generation for each breadcrumb

- [ ] **OpenGraph component**
  - `og:title`, `og:description`, `og:image`, `og:url`
  - `og:type` = "website" or "place"
  - Twitter Card tags (`twitter:card`, `twitter:title`, etc.)

**Migration from V1**:
- Copy `event_schema.ex` with minimal changes
- Copy `breadcrumb_schema.ex` as-is
- Copy `open_graph.ex` component

**Success Criteria**:
- JSON-LD validates on Google Rich Results Test
- All schema.org properties match V1
- Social sharing tags identical to V1

#### 3.2: Meta Tags & SEO Helpers
- [ ] **Meta tag generation helpers**
  - Page titles (format: "Venue Name - City, Country | QuizAdvisor")
  - Meta descriptions (dynamic per page)
  - Canonical URLs
  - Language tags

- [ ] **Image URL helpers**
  - City image selection (Unsplash with attribution)
  - Venue image handling (Google Place images + hero)
  - Fallback image logic

**Success Criteria**:
- Meta tags match V1 format exactly
- Titles and descriptions optimized for SEO
- Image URLs properly constructed

#### 3.3: Sitemap Generation (V2)
- [ ] **Migrate sitemap module** (`lib/trivia_advisor_v2/sitemap.ex`)
  - Copy V1 sitemap generation logic
  - Update module namespace: `TriviaAdvisor` → `TriviaAdvisorV2`
  - Preserve URL priorities and changefreq
  - Keep S3/Tigris upload logic
  - Maintain `lastmod` calculation (venue updated_at vs event last_seen_at)

- [ ] **Create Mix task** (`lib/mix/tasks/sitemap.generate.ex`)
  - `mix sitemap.generate` for local testing
  - `mix sitemap.generate --s3` for production upload

- [ ] **Robots.txt** (`priv/static/robots.txt`)
  - Copy V1 robots.txt
  - Ensure `Sitemap: https://quizadvisor.com/sitemap.xml` directive

**Success Criteria**:
- Sitemap generates all expected URLs
- Priorities and changefreq match V1
- S3/Tigris upload working
- Robots.txt points to sitemap

---

## Phase 4: Helper Modules & Utilities
**Duration**: 3-4 days
**Goal**: Reusable helper functions for LiveViews

### Tasks

#### 4.1: Web Helpers
- [ ] **FormatHelpers** (`lib/trivia_advisor_v2_web/helpers/format_helpers.ex`)
  - Time formatting (convert UTC to local, display time ranges)
  - Event source data extraction
  - Day of week formatting
  - Price formatting with currency symbols

- [ ] **ImageHelpers**
  - City image selection from Unsplash gallery
  - Image attribution text generation
  - Venue image URL construction
  - Fallback image logic

- [ ] **CurrencyHelpers**
  - Currency lookup by country (using `Countries` library)
  - Currency symbol formatting
  - Price display logic

- [ ] **LocalizationHelpers** (if needed)
  - Multi-language support structure
  - Date/time localization

**Migration Strategy**: Copy V1 helpers with namespace updates

**Success Criteria**:
- All helpers copied and tested
- No breaking changes in function signatures
- Tailwind-compatible HTML output

#### 4.2: LiveView Helpers
- [ ] **CityShowHelpers** (`lib/trivia_advisor_v2_web/live/city_show_helpers.ex`)
  - Spatial search logic (radius filtering)
  - Suburb filtering
  - Day-of-week filtering
  - Complex query building for city page

- [ ] **VenueShowHelpers**
  - Image URL generation
  - SEO description generation
  - Merge redirect handling
  - Event grouping/sorting logic

- [ ] **SlugHelper**
  - URL slug generation
  - Slug validation
  - Parameterization logic

**Success Criteria**:
- Helpers support all LiveView functionality
- Complex filtering logic preserved
- Edge cases handled (merged venues, missing data)

---

## Phase 5: LiveView Components & UI
**Duration**: 7-10 days
**Goal**: Migrate 18 working components with Tailwind styling

### Tasks

#### 5.1: Foundational UI Components

**Priority 1 (must-have for basic functionality)**:

- [ ] **VenueCard** (`lib/trivia_advisor_v2_web/components/venue_card.ex`)
  - Display venue name, address, event count
  - Link to venue show page
  - Tailwind styling preserved
  - Responsive design

- [ ] **CityCard** (`lib/trivia_advisor_v2_web/components/city_card.ex`)
  - Display city name, country, venue count
  - City image with Unsplash attribution
  - Link to city show page
  - Responsive grid layout

- [ ] **CitySearch** (`lib/trivia_advisor_v2_web/components/city_search.ex`)
  - Autocomplete search for cities
  - LiveView event handling
  - Keyboard navigation
  - Mobile-friendly

- [ ] **WorldMapComponent** (if using)
  - Interactive world map
  - City markers
  - Click to navigate

**Success Criteria**:
- Components render identically to V1
- Tailwind classes preserved
- LiveView reactivity working
- Responsive on mobile

#### 5.2: Layout & Root Components

- [ ] **Root layout** (`lib/trivia_advisor_v2_web/components/layouts/root.html.heex`)
  - HTML structure
  - Meta tag injection
  - JSON-LD script tags
  - Asset loading (CSS, JS)

- [ ] **App layout** (`lib/trivia_advisor_v2_web/components/layouts/app.html.heex`)
  - Header/navigation
  - Footer
  - Flash messages
  - LiveView container

- [ ] **Navigation component**
  - Logo
  - Search bar
  - Links (Home, Cities, Latest Venues)
  - Mobile menu toggle

**Success Criteria**:
- Layout matches V1 exactly
- SEO tags injected correctly
- Navigation functional
- Mobile responsive

#### 5.3: Page-Level LiveView Components

**Priority 1 (SEO-critical)**:

- [ ] **HomePage** (`lib/trivia_advisor_v2_web/live/home_live.ex`)
  - Featured venues
  - Popular cities (diverse countries)
  - World map component
  - City search
  - JSON-LD: BreadcrumbList (Home only)
  - Meta tags: homepage title, description

- [ ] **CityShow** (`lib/trivia_advisor_v2_web/live/city_show_live.ex`)
  - City header with image
  - Venue list (with spatial filtering)
  - Radius filter (5km, 10km, 25km, 50km)
  - Suburb toggle
  - Day-of-week filter
  - JSON-LD: BreadcrumbList (Home > Country > City)
  - Meta tags: city-specific title, description
  - Open Graph: city image, description

- [ ] **VenueShow** (`lib/trivia_advisor_v2_web/live/venue_show_live.ex`) ⭐ **SEO-CRITICAL**
  - Venue details (name, address, coordinates)
  - Event list with times
  - Google Place images + hero image
  - Event source attribution
  - Performer information
  - JSON-LD: Event schema (with calculated dates)
  - JSON-LD: BreadcrumbList (Home > Country > City > Venue)
  - Open Graph: venue image, description, location
  - Meta tags: venue-specific title, description
  - **Merge redirect handling**: If `venue.merged_into_id`, redirect to merged venue

**Priority 2 (important but not critical)**:

- [ ] **LatestVenues** (`lib/trivia_advisor_v2_web/live/latest_venues_live.ex`)
  - List of recently added venues
  - VenueCard grid
  - Pagination (if needed)

- [ ] **CountryShow** (if implementing)
  - Country overview
  - Cities in country
  - Venue count statistics

**Success Criteria**:
- All LiveViews render correctly
- Filtering/search working
- JSON-LD schemas validate
- Meta tags match V1
- Responsive design preserved

---

## Phase 6: Routing & Navigation
**Duration**: 2-3 days
**Goal**: 100% route parity with V1

### Tasks

#### 6.1: Router Configuration
- [ ] Configure `TriviaAdvisorV2Web.Router`
- [ ] Define public routes:
  ```elixir
  scope "/", TriviaAdvisorV2Web do
    pipe_through :browser

    live "/", HomeLive, :index                        # Priority 1.0
    live "/cities", CitiesLive, :index                # Priority 0.9
    live "/cities/:slug", CityShowLive, :show         # Priority 0.8
    live "/venues/:slug", VenueShowLive, :show        # Priority 0.7
    live "/venues/latest", LatestVenuesLive, :index
    live "/countries/:slug", CountryShowLive, :show   # If implementing
  end
  ```

- [ ] Add sitemap route (if serving from Phoenix vs S3):
  ```elixir
  get "/sitemap.xml", SitemapController, :index
  ```

- [ ] Ensure slug format matches V1:
  - Cities: `name-country_code` (e.g., `london-gb`)
  - Venues: `name-city-country` (e.g., `the-crown-pub-london-gb`)

**Success Criteria**:
- All V1 public routes replicated
- Slug generation matches V1 exactly
- Route helpers generate correct URLs
- No 404s for migrated pages

#### 6.2: Redirect Handling
- [ ] Implement venue merge redirect logic in `VenueShowLive.mount/3`:
  ```elixir
  def mount(%{"slug" => slug}, _session, socket) do
    venue = Locations.get_venue_by_slug(slug)

    if venue.merged_into_id do
      merged_venue = Locations.get_venue!(venue.merged_into_id)
      {:ok, redirect(socket, to: ~p"/venues/#{merged_venue.slug}")}
    else
      # Normal venue show logic
    end
  end
  ```

- [ ] Handle canonical URLs for duplicate content

**Success Criteria**:
- Merged venues redirect properly
- Canonical URLs prevent duplicate content issues
- 301 redirects for permanent moves

#### 6.3: URL Helper Functions
- [ ] Create `Routes` helper module for consistent URL generation
- [ ] Ensure all internal links use `~p` sigil or route helpers
- [ ] Validate all URLs against sitemap structure

**Success Criteria**:
- All URLs generated consistently
- No hardcoded URLs in templates
- URL structure matches V1 exactly

---

## Phase 7: Testing & Validation
**Duration**: 4-5 days
**Goal**: Comprehensive validation before deployment

### Tasks

#### 7.1: Sitemap Validation
- [ ] Generate V2 sitemap locally
- [ ] Compare V2 sitemap URL count to V1 baseline
- [ ] Verify all URLs return 200 (no 404s)
- [ ] Check `lastmod` dates are reasonable
- [ ] Validate XML format
- [ ] Test S3/Tigris upload

**Validation Script**:
```bash
# Generate sitemap
mix sitemap.generate

# Count URLs in sitemap
grep -c "<loc>" priv/static/sitemaps/sitemap.xml

# Compare to baseline (from Phase 0)
echo "Expected: XXX URLs"
echo "Actual: $(grep -c '<loc>' priv/static/sitemaps/sitemap.xml)"

# Test each URL (sample)
curl -I https://quizadvisor.com/ | grep "HTTP"
curl -I https://quizadvisor.com/cities/london-gb | grep "HTTP"
```

**Success Criteria**:
- URL count matches baseline (±5 for data changes)
- All URLs return 200 OK
- Sitemap uploads to S3/Tigris successfully

#### 7.2: SEO Validation
- [ ] **Google Rich Results Test** for venue pages
  - Validate Event schema
  - Validate BreadcrumbList schema
  - Check for errors/warnings

- [ ] **Meta tag validation**
  - Titles unique and descriptive
  - Descriptions unique per page
  - Open Graph tags complete
  - Twitter Card tags present

- [ ] **Social sharing preview**
  - Test on Facebook Debugger
  - Test on Twitter Card Validator
  - Verify images load correctly

**Tools**:
- https://search.google.com/test/rich-results
- https://developers.facebook.com/tools/debug/
- https://cards-dev.twitter.com/validator

**Success Criteria**:
- JSON-LD validates with no errors
- Rich results preview correctly
- Social sharing cards display properly

#### 7.3: Functional Testing
- [ ] **Homepage**
  - Featured venues display
  - Popular cities load
  - City search works
  - Map renders (if applicable)

- [ ] **City Show Page**
  - Venues display correctly
  - Radius filter works
  - Day-of-week filter works
  - Suburb toggle works
  - Pagination works (if implemented)

- [ ] **Venue Show Page**
  - Venue details correct
  - Events display with times
  - Images load
  - Event sources shown
  - Merge redirects work

- [ ] **Latest Venues Page**
  - Recent venues display
  - Pagination works

**Success Criteria**:
- All features work as in V1
- No JavaScript errors in console
- Mobile responsive
- Fast load times (<3s on 3G)

#### 7.4: Performance Testing
- [ ] Measure page load times (Lighthouse)
- [ ] Check database query performance
- [ ] Test with realistic data volumes
- [ ] Verify PostGIS spatial queries are indexed

**Metrics**:
- Lighthouse score: >90 for Performance, SEO, Accessibility
- First Contentful Paint: <1.5s
- Time to Interactive: <3s
- Database queries: <100ms for simple, <500ms for spatial

**Success Criteria**:
- Performance meets or exceeds V1
- No N+1 query problems
- Spatial queries optimized

#### 7.5: Read-Only Database Validation
- [ ] Attempt write operation (should fail)
- [ ] Verify no migrations exist in V2 codebase
- [ ] Test connection pool settings under load
- [ ] Validate transaction isolation level

**Success Criteria**:
- Write operations properly blocked
- Read-only mode enforced
- No accidental schema changes

---

## Phase 8: Deployment & Cutover
**Duration**: 3-4 days
**Goal**: Production deployment with zero downtime

### Tasks

#### 8.1: Environment Setup
- [ ] Configure production environment variables
  - `SUPABASE_DATABASE_URL`
  - `SECRET_KEY_BASE`
  - `PHX_HOST=quizadvisor.com`
  - S3/Tigris credentials (for sitemap uploads)
  - Sentry DSN (error tracking)

- [ ] Set up deployment pipeline
  - Docker configuration (if using)
  - Fly.io deployment (if using)
  - Environment-specific configs

**Success Criteria**:
- Production env vars configured
- Deployment pipeline tested
- Rollback plan documented

#### 8.2: Pre-Deployment Checklist
- [ ] All tests passing
- [ ] Sitemap validation complete
- [ ] SEO validation complete
- [ ] Performance benchmarks met
- [ ] Error tracking configured (Sentry)
- [ ] Monitoring set up (health checks, uptime)

**Success Criteria**:
- No blockers for deployment
- Monitoring in place
- Rollback plan ready

#### 8.3: Deployment Strategy
- [ ] **Option A: Blue-Green Deployment**
  1. Deploy V2 to new infrastructure
  2. Test thoroughly on staging domain
  3. Switch DNS to V2
  4. Monitor for 24h
  5. Decomission V1

- [ ] **Option B: Gradual Rollout**
  1. Deploy V2 alongside V1
  2. Route 10% traffic to V2 (load balancer)
  3. Monitor metrics, errors, SEO
  4. Gradually increase to 100%
  5. Decomission V1

**Recommended**: Blue-Green for simplicity

**Success Criteria**:
- Zero downtime cutover
- SEO rankings stable
- No increase in error rates

#### 8.4: Post-Deployment Validation
- [ ] Generate sitemap in production (`mix sitemap.generate --s3`)
- [ ] Submit sitemap to Google Search Console
- [ ] Monitor search rankings (expect temporary fluctuations)
- [ ] Check error logs for issues
- [ ] Verify all routes returning 200
- [ ] Test social sharing on real pages

**Monitoring (first 7 days)**:
- [ ] Daily Lighthouse audits
- [ ] Daily error log review
- [ ] Weekly search ranking check
- [ ] Weekly traffic analysis (Google Analytics)

**Success Criteria**:
- No critical errors in production
- SEO rankings recover within 2 weeks
- Traffic metrics match or exceed V1

---

## Progress Tracking

### URL Migration Progress

| Category | Expected Count | Migrated | % Complete |
|----------|----------------|----------|------------|
| Static Pages | 2 | 0 | 0% |
| City Pages | XXX | 0 | 0% |
| Venue Pages | XXX | 0 | 0% |
| **TOTAL** | **XXX** | **0** | **0%** |

*Update this table as routes are implemented and validated*

### Component Migration Progress

| Component | Status | Phase |
|-----------|--------|-------|
| VenueCard | ⬜ Not Started | 5.1 |
| CityCard | ⬜ Not Started | 5.1 |
| CitySearch | ⬜ Not Started | 5.1 |
| WorldMapComponent | ⬜ Not Started | 5.1 |
| HomeLive | ⬜ Not Started | 5.3 |
| CityShowLive | ⬜ Not Started | 5.3 |
| VenueShowLive | ⬜ Not Started | 5.3 |
| LatestVenuesLive | ⬜ Not Started | 5.3 |
| EventSchema | ⬜ Not Started | 3.1 |
| BreadcrumbSchema | ⬜ Not Started | 3.1 |
| OpenGraph | ⬜ Not Started | 3.1 |
| Sitemap | ⬜ Not Started | 3.3 |

*Legend: ⬜ Not Started | 🟡 In Progress | ✅ Complete*

---

## Risk Mitigation

### High-Risk Areas

1. **SEO Ranking Loss** (CRITICAL)
   - **Mitigation**: 100% URL preservation, identical JSON-LD, gradual rollout
   - **Validation**: Pre-deployment Google Rich Results testing
   - **Rollback**: Keep V1 running for 30 days, ready to switch back

2. **Database Performance** (HIGH)
   - **Mitigation**: Test with realistic data volumes, optimize PostGIS queries
   - **Validation**: Load testing before production deployment
   - **Rollback**: Scale up database resources if needed

3. **Merge Redirect Loops** (MEDIUM)
   - **Mitigation**: Test merge redirect logic thoroughly
   - **Validation**: Automated tests for redirect chains
   - **Rollback**: Fix redirect logic before full cutover

4. **Broken Image URLs** (MEDIUM)
   - **Mitigation**: Validate image URL generation logic
   - **Validation**: Visual regression testing
   - **Rollback**: Fix image helpers before deployment

### Success Metrics

**SEO Metrics** (monitor weekly):
- Organic traffic: ±10% within 4 weeks
- Search rankings: Top 10 keywords maintain position ±2
- Click-through rate: Stable or improved

**Performance Metrics** (monitor daily):
- Uptime: >99.9%
- Response time: <200ms median
- Error rate: <0.1%

**User Metrics** (monitor weekly):
- Bounce rate: <50%
- Session duration: >2 minutes
- Pages per session: >2.5

---

## Next Steps

1. **Validate Phase 0 approach** - Confirm sitemap baseline strategy
2. **Run Phase 0.2 queries** - Get actual URL counts from database
3. **Review Phase 1-8 tasks** - Adjust timeline and priorities
4. **Begin Phase 1** - Set up Ecto configuration and dependencies

---

## Questions to Resolve

1. **Country pages**: Should `/countries/:slug` route be in sitemap? Not in V1 sitemap but exists in routes.
2. **Latest venues**: Should `/venues/latest` be in sitemap? Exists in routes but not sitemap.
3. **Read-only enforcement**: Database-level permissions or application-level validation?
4. **Sitemap upload**: Continue using Tigris (S3-compatible) or switch to different CDN?
5. **Image hosting**: Where are venue/city images hosted? Waffle + S3, or Eventasaurus provides URLs?

---

## References

- **V1 Codebase**: `/Users/holdenthomas/Code/paid-projects-2024/trivia_advisor`
- **V2 Codebase**: `/Users/holdenthomas/Code/paid-projects-2025/trivia_advisor`
- **Database**: Eventasaurus (Supabase PostgreSQL with PostGIS)
- **Production URL**: https://quizadvisor.com
- **Sitemap URL**: https://quizadvisor.com/sitemap.xml (currently 404 - needs investigation)
