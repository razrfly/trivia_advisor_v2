# QuizAdvisor V2 - Site Functionality Comparison & Task List
**Generated**: November 9, 2025
**Comparing**: Production (quizadvisor.com) vs V2 (localhost:4003)
**Purpose**: Complete feature parity assessment and implementation roadmap

---

## 📋 Table of Contents
1. [Page Inventory](#page-inventory)
2. [What Works on Production](#what-works-on-production)
3. [What Doesn't Work on V2](#what-doesnt-work-on-v2)
4. [Feature Comparison Matrix](#feature-comparison-matrix)
5. [Implementation Task List](#implementation-task-list)
6. [URL Migration Strategy](#url-migration-strategy)

---

## 1. Page Inventory

### Total URLs to Preserve: **7,118**
*(From production sitemap baseline)*

| Page Type | Count | Production URL Pattern | V2 URL Pattern | Status |
|-----------|-------|----------------------|----------------|--------|
| **Homepage** | 1 | `/` | `/` | ✅ Working |
| **Cities Index** | 1 | `/cities` | N/A | ❌ Missing |
| **Country Pages** | ? | `/countries/{slug}` | `/{country}` | ✅ Working |
| **City Pages** | 1,768 | `/cities/{slug}` | `/{country}/{city}` | ✅ Working |
| **Venue Pages** | 5,348 | `/venues/{slug}` | `/{country}/{city}/{venue}` | ❌ **BROKEN** |
| **About Page** | 1 | `/about` | `/about` | ✅ Working |
| **TOTAL** | **7,118+** | | | **57% Working** |

---

## 2. What Works on Production

### 🏠 Homepage (quizadvisor.com/)
**Status**: ✅ Fully functional on production

**Features**:
- ✅ Hero section with search bar
- ✅ "How TriviaAdvisor Works" section (3 cards)
- ✅ **Latest Venues** section (4 venues with images)
  - Venue image (or default fallback)
  - Venue name
  - Full address
  - Quiz night timing (e.g., "Monday at 8:00 pm")
  - "Added X days ago" timestamp
  - Entry fee information
  - Prize details
  - City, Country location tags
- ✅ **Popular Cities** section (6 cities with images)
  - City image
  - City name
  - Venue count (e.g., "216 Venues")
  - Country link
  - "Explore venues" CTA button
- ✅ Email subscription form
- ✅ Global stats (5348+ venues, 31+ countries)
- ✅ Navigation menu (Countries, Popular Cities, About)
- ✅ Footer with social links

**Images Used**:
- `/images/default-venue.jpg` - Fallback for missing venue images
- `http://cdn.quizadvisor.com/uploads/venues/{venue-slug}/original_*.jpg` - CDN-hosted venue images
- City background images (from Unsplash or similar)

---

### 🏙️ City Pages (/cities/{slug})
**Status**: ✅ Fully functional on production

**Example**: https://quizadvisor.com/cities/austin

**Features**:
- ✅ Page title: "Austin, United States"
- ✅ Section header: "Trivia Venues in Austin"
- ✅ **Filter by day** (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
- ✅ **Filter by suburb** (dropdown with neighborhood options)
- ✅ **Venue cards** (multiple per venue for recurring events):
  - Venue name
  - Event-specific details (e.g., "Starts on June 1!")
  - Address
  - Quiz timing
  - Link to venue page
  - Images for each venue

**Sample Structure**:
```html
<h1>Austin, United States</h1>
<h2>Trivia Venues in Austin</h2>
<h3>Filter by day:</h3>
<!-- Day filter buttons -->
<h3>Filter by suburb:</h3>
<!-- Suburb dropdown -->
<!-- Venue list -->
<h3>Bull & Bowl</h3>
<h3>Bull & Bowl (Starts on June 1!)</h3>
<h3>Remedy</h3>
<!-- etc. -->
```

---

### 🏢 Venue Pages (/venues/{slug})
**Status**: ✅ Fully functional on production

**Example**: https://quizadvisor.com/venues/bull-bowl

**Features**:
- ✅ **Hero section**:
  - Venue name (H1): "Bull & Bowl"
  - Venue image or fallback
  - Address
  - Map preview
- ✅ **About This Trivia Night** (H2)
  - Description text
  - Quiz format details
- ✅ **Location** (H3)
  - Full address
  - Interactive map (embedded)
  - Directions link
- ✅ **Contact** (H3)
  - Website link
  - Phone number (if available)
  - Email (if available)
- ✅ **Next Quiz Night** (H3)
  - Date and time
  - Recurring schedule info
- ✅ **Quiz Master** (H3)
  - Name (H4): "Mr. Badger"
  - Bio/details
  - Profile image
- ✅ **Reviews** (H2)
  - User reviews section
  - Rating display
  - Review submission form
- ✅ **Nearby Trivia Venues** (H2)
  - Recommended venues in same city
  - Distance from current venue
  - Quick links to other venues

**Additional Features**:
- Social sharing buttons
- Add to calendar functionality
- Report incorrect information link

---

### 🌍 Country Pages (/countries/{slug})
**Status**: ✅ Functional on production (assumed based on navigation)

**Expected Features** (based on site structure):
- Country name header
- List of cities in that country
- Venue count statistics
- Featured cities

---

## 3. What Doesn't Work on V2

### ❌ CRITICAL FAILURES

#### 1. Venue Pages - Complete Crash
**Severity**: 🔴 **BLOCKER**

**URL**: `/{country}/{city}/{venue}` (e.g., `/united-states/austin/bull-bowl`)

**Error**:
```elixir
** (KeyError) key :name not found in: %TriviaAdvisor.Events.PublicEvent{...}
```

**Root Cause**: VenueShowLive tries to access `venue.name` from associations, but the schema now uses the `trivia_events_export` view with denormalized fields:
- `event.venue_name` (not `venue.name`)
- `event.city_name` (not `city.name`)
- `event.country_name` (not `country.name`)

**Impact**:
- 🚫 Cannot view any venue details
- 🚫 Breaks 5,348 URLs (75% of sitemap)
- 🚫 No event schedules visible
- 🚫 No venue information accessible

**What's Missing vs Production**:
- ❌ Venue details page (entire page broken)
- ❌ About This Trivia Night section
- ❌ Location section with map
- ❌ Contact information
- ❌ Next Quiz Night details
- ❌ Quiz Master information
- ❌ Reviews section
- ❌ Nearby venues recommendations

---

### ❌ MISSING PAGES

#### 2. Cities Index Page (/cities)
**Severity**: 🟡 Medium

**Status**: Not implemented in V2

**Expected Features** (from production):
- List of all cities with trivia
- Search/filter functionality
- Alphabetical sorting
- Venue count per city
- Quick links to popular cities

---

### ❌ MISSING FEATURES

#### 3. Images & Visual Content
**Severity**: 🟡 Medium-High

**Missing on V2**:
- ❌ Venue images (homepage "Latest Venues" section)
- ❌ City background images (homepage "Popular Cities" section)
- ❌ Default fallback images
- ❌ Venue profile images (on venue pages when working)
- ❌ Quiz Master photos
- ❌ Map integrations

**What Production Has**:
- ✅ CDN-hosted venue images: `http://cdn.quizadvisor.com/uploads/venues/{slug}/original_*.jpg`
- ✅ Default fallback: `/images/default-venue.jpg`
- ✅ City images (Unsplash or similar service)

**Source in Database**:
```sql
-- Venues table has venue_images JSONB array
SELECT venue_images FROM venues LIMIT 1;
-- Returns: [{"url": "...", "quality_score": 85, "attribution": "..."}]
```

**Implementation Required**:
- Query `venue.venue_images` array
- Sort by `quality_score`
- Take first (highest quality) image
- Display with proper attribution
- Add fallback for venues without images

---

#### 4. City Page Filters
**Severity**: 🟡 Medium

**Missing on V2**:
- ❌ Filter by day of week (Mon, Tue, Wed, etc.)
- ❌ Filter by suburb/neighborhood
- ❌ Event count per day
- ❌ Suburb dropdown

**What Production Has**:
- ✅ Day filter with button grid
- ✅ Suburb dropdown for neighborhood filtering
- ✅ Dynamic filtering of venue list

**Data Required**:
- Parse `occurrences.pattern.days_of_week` from events
- Extract neighborhood from venue address
- Implement client-side or LiveView filtering

---

#### 5. Homepage Features
**Severity**: 🟢 Low

**Missing on V2**:
- ❌ "How TriviaAdvisor Works" section (3-card explainer)
- ❌ Email subscription form
- ❌ Global statistics (venue count, country count)
- ❌ Social proof elements
- ❌ Latest venues carousel (with images)

**What Production Has**:
- ✅ Complete marketing homepage
- ✅ Clear value proposition
- ✅ Lead capture form
- ✅ Visual interest with images

**V2 Currently Has**:
- ✅ Basic hero section
- ✅ City exploration cards (5 cities)
- ✅ Simple "Welcome" section
- ⚠️ Much simpler, minimal design

---

#### 6. Venue Page Features
**Severity**: 🔴 High (when venue pages are fixed)

**Missing on V2** (when crash is fixed):
- ❌ About This Trivia Night section
- ❌ Location with embedded map
- ❌ Contact information (website, phone, email)
- ❌ Next Quiz Night details
- ❌ Quiz Master profile (name, bio, photo)
- ❌ Reviews system
- ❌ Nearby venues recommendations
- ❌ Social sharing buttons
- ❌ Add to calendar
- ❌ Report information link

---

#### 7. Navigation Features
**Severity**: 🟢 Low

**Missing on V2**:
- ❌ "Countries" dropdown in main nav
- ❌ "Popular Cities" dropdown in main nav
- ❌ Search bar in header
- ❌ Sign In link (if authentication exists)

**V2 Currently Has**:
- ✅ Simple nav with Home, About

---

## 4. Feature Comparison Matrix

| Feature | Production | V2 | Priority | Effort |
|---------|-----------|-----|----------|--------|
| **PAGES** |
| Homepage | ✅ Full | ✅ Basic | P1 | Medium |
| Country Pages | ✅ | ✅ Different URL | P2 | Low |
| City Pages | ✅ | ✅ Basic | P1 | Medium |
| Venue Pages | ✅ | ❌ **BROKEN** | **P0** | **High** |
| Cities Index | ✅ | ❌ | P2 | Medium |
| About Page | ✅ | ✅ | P3 | Low |
| **VENUE PAGE SECTIONS** |
| Venue Header | ✅ | ❌ | P0 | High |
| About Section | ✅ | ❌ | P1 | Medium |
| Location + Map | ✅ | ❌ | P1 | Medium |
| Contact Info | ✅ | ❌ | P1 | Low |
| Next Quiz Night | ✅ | ❌ | P1 | Medium |
| Quiz Master | ✅ | ❌ | P2 | Medium |
| Reviews | ✅ | ❌ | P3 | High |
| Nearby Venues | ✅ | ❌ | P2 | Medium |
| **CITY PAGE FEATURES** |
| Venue List | ✅ | ✅ | P1 | ✅ Done |
| Filter by Day | ✅ | ❌ | P1 | Medium |
| Filter by Suburb | ✅ | ❌ | P2 | Medium |
| Venue Count | ✅ | ✅ | P3 | ✅ Done |
| **IMAGES & MEDIA** |
| Venue Images | ✅ | ❌ | P1 | Medium |
| City Images | ✅ | ❌ | P2 | Low |
| Quiz Master Photos | ✅ | ❌ | P2 | Low |
| Map Integration | ✅ | ❌ | P1 | High |
| Default Fallbacks | ✅ | ❌ | P1 | Low |
| **HOMEPAGE FEATURES** |
| Latest Venues | ✅ | ❌ | P2 | Medium |
| Popular Cities | ✅ | ✅ Basic | P2 | Low |
| Email Signup | ✅ | ❌ | P3 | Medium |
| Global Stats | ✅ | ❌ | P3 | Low |
| How It Works | ✅ | ❌ | P3 | Low |
| **NAVIGATION** |
| Search Bar | ✅ | ❌ | P2 | High |
| Country Dropdown | ✅ | ❌ | P3 | Medium |
| Cities Dropdown | ✅ | ❌ | P3 | Medium |
| **FUNCTIONALITY** |
| Social Sharing | ✅ | ❌ | P3 | Medium |
| Add to Calendar | ✅ | ❌ | P3 | Medium |
| Reviews System | ✅ | ❌ | P4 | Very High |
| User Auth | ✅? | ❌ | P4 | Very High |

**Priority Legend**:
- **P0**: Blocker - Must fix before any deployment
- **P1**: Critical - Needed for MVP launch
- **P2**: Important - Should have for full feature parity
- **P3**: Nice to have - Can be added post-launch
- **P4**: Future - Long-term improvements

---

## 5. Implementation Task List

### 🔴 PHASE 0: CRITICAL FIXES (Week 1)
**Must complete before any deployment**

#### Task 0.1: Fix Venue Page Crash
**Priority**: P0 | **Effort**: High | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Update `VenueShowLive` to use denormalized fields from `trivia_events_export` view
- [ ] Change `venue.name` → `event.venue_name`
- [ ] Change `venue.address` → `event.venue_address`
- [ ] Change `city.name` → `event.city_name`
- [ ] Change `country.name` → `event.country_name`
- [ ] Update all venue queries in `Locations` context
- [ ] Test venue page loads successfully
- [ ] Verify all 5,348 venue URLs work

**Acceptance Criteria**:
- ✅ Venue pages load without errors
- ✅ Basic venue information displays (name, address, city, country)
- ✅ Can navigate from city page → venue page
- ✅ URL pattern `/{country}/{city}/{venue}` works

---

### 🟡 PHASE 1: CORE FUNCTIONALITY (Week 2-3)
**Essential features for launch**

#### Task 1.1: Implement Venue Images
**Priority**: P1 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Query `venue.venue_images` JSONB array from database
- [ ] Sort images by `quality_score` (descending)
- [ ] Extract highest quality image URL
- [ ] Display image in venue card component
- [ ] Add default fallback image for venues without images
- [ ] Implement image attribution (if required)
- [ ] Add lazy loading for performance
- [ ] Test on homepage "Latest Venues"
- [ ] Test on city page venue lists
- [ ] Test on venue detail pages

**Acceptance Criteria**:
- ✅ Venues display images when available
- ✅ Default image shows when no venue image exists
- ✅ Images load efficiently (lazy loading)
- ✅ Attribution displayed when required

---

#### Task 1.2: Build City Page Filters
**Priority**: P1 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Parse `occurrences.pattern.days_of_week` from events
- [ ] Create day-of-week filter component (Mon-Sun buttons)
- [ ] Implement LiveView filter logic
- [ ] Filter venues by selected day
- [ ] Show event count per day
- [ ] Add "All Days" option
- [ ] Style filter buttons to match production
- [ ] Test filter updates venue list dynamically
- [ ] Ensure URL persistence (e.g., `?day=monday`)

**Acceptance Criteria**:
- ✅ Day filter buttons display correctly
- ✅ Clicking a day filters venues to only those with events on that day
- ✅ "All Days" shows all venues
- ✅ Filter state persists in URL query params

---

#### Task 1.3: Add Venue Page Location Section
**Priority**: P1 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Create "Location" section component
- [ ] Display full venue address
- [ ] Integrate map embedding (Google Maps or Leaflet)
- [ ] Add "Get Directions" link
- [ ] Show latitude/longitude from database
- [ ] Test map loads correctly
- [ ] Ensure responsive design

**Acceptance Criteria**:
- ✅ Address displays correctly
- ✅ Map shows venue location
- ✅ "Get Directions" link works
- ✅ Mobile responsive

---

#### Task 1.4: Add Venue Page Contact Section
**Priority**: P1 | **Effort**: Low | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Create "Contact" section component
- [ ] Display website URL (if available in metadata)
- [ ] Display phone number (if available)
- [ ] Display email (if available)
- [ ] Add click-to-call for mobile
- [ ] Add click-to-email functionality
- [ ] Style to match production

**Acceptance Criteria**:
- ✅ Contact information displays when available
- ✅ Links are functional
- ✅ Mobile-friendly (click-to-call/email)

---

#### Task 1.5: Add "Next Quiz Night" Section
**Priority**: P1 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Parse `occurrences.dates` array from event
- [ ] Find next upcoming occurrence (date >= today)
- [ ] Display date in human-readable format (e.g., "Monday, Nov 11 at 7:00 PM")
- [ ] Show recurring schedule if pattern exists
- [ ] Handle edge case: no upcoming events
- [ ] Add "Add to Calendar" button (Phase 2)
- [ ] Style to match production

**Acceptance Criteria**:
- ✅ Next event date displays correctly
- ✅ Recurring schedule shows pattern (e.g., "Every Monday at 7:00 PM")
- ✅ Handles venues with no upcoming events gracefully

---

### 🔵 PHASE 2: IMPORTANT FEATURES (Week 4-5)
**Feature parity with production**

#### Task 2.1: Implement Suburb/Neighborhood Filter
**Priority**: P2 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Extract neighborhood from `venue.address` field
- [ ] Parse address to identify suburb/neighborhood
- [ ] Build dropdown component
- [ ] Populate with unique neighborhoods
- [ ] Implement filter logic
- [ ] Test on cities with many suburbs (e.g., London)

---

#### Task 2.2: Add Quiz Master Section
**Priority**: P2 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Determine data source for quiz master info (check `public_event_performers`?)
- [ ] Create "Quiz Master" section component
- [ ] Display quiz master name
- [ ] Display bio/description
- [ ] Add profile photo (if available)
- [ ] Handle multiple quiz masters per event
- [ ] Test on venues with quiz master data

---

#### Task 2.3: Build "Nearby Venues" Section
**Priority**: P2 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Query venues within same city
- [ ] Calculate distance using lat/long (PostGIS)
- [ ] Sort by distance from current venue
- [ ] Display top 5-10 nearby venues
- [ ] Show distance in miles/km
- [ ] Add links to venue pages
- [ ] Style as card grid

---

#### Task 2.4: Enhance Homepage with Latest Venues
**Priority**: P2 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Query latest 4 venues from database (order by `inserted_at DESC`)
- [ ] Create venue card component with:
  - Venue image
  - Venue name
  - Address
  - Quiz timing
  - Entry fee
  - Prize details
  - "Added X days ago" timestamp
- [ ] Link to venue pages
- [ ] Style to match production

---

#### Task 2.5: Add Search Functionality
**Priority**: P2 | **Effort**: High | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Create search bar component (header or homepage)
- [ ] Implement search logic (cities, venues by name)
- [ ] Add autocomplete/suggestions
- [ ] Search by location (city name)
- [ ] Search by venue name
- [ ] Display search results page
- [ ] Handle no results state

---

#### Task 2.6: Create Cities Index Page (/cities)
**Priority**: P2 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Create `CityIndexLive` LiveView
- [ ] List all 1,768 cities with trivia
- [ ] Show venue count per city
- [ ] Add alphabetical sorting
- [ ] Add search/filter
- [ ] Group by country
- [ ] Add pagination (if needed)
- [ ] Link to city pages

---

### 🟢 PHASE 3: ENHANCEMENTS (Week 6+)
**Nice-to-have features**

#### Task 3.1: Add City Images
**Priority**: P3 | **Effort**: Low | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Integrate with Unsplash API or similar
- [ ] Query city images using `cities.unsplash_gallery` field
- [ ] Display on homepage "Popular Cities" section
- [ ] Add to city page headers
- [ ] Implement caching

---

#### Task 3.2: Add Email Subscription Form
**Priority**: P3 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Create email form component
- [ ] Integrate with email service (Mailchimp, ConvertKit, etc.)
- [ ] Add to homepage
- [ ] Implement validation
- [ ] Add success/error messages
- [ ] GDPR compliance (if needed)

---

#### Task 3.3: Add Global Statistics
**Priority**: P3 | **Effort**: Low | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Query total venue count from database
- [ ] Query total country count
- [ ] Display on homepage
- [ ] Style as cards or stat blocks

---

#### Task 3.4: Add "How It Works" Section
**Priority**: P3 | **Effort**: Low | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Create 3-card component (Find, Attend, Review)
- [ ] Add icons for each step
- [ ] Add copy for each card
- [ ] Style to match production

---

#### Task 3.5: Implement Social Sharing
**Priority**: P3 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Add social sharing buttons to venue pages
- [ ] Implement share to Facebook, Twitter, WhatsApp
- [ ] Add Open Graph meta tags
- [ ] Test social preview cards

---

#### Task 3.6: Add "Add to Calendar" Feature
**Priority**: P3 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Generate .ics file for events
- [ ] Add "Add to Calendar" button
- [ ] Support Google Calendar, Apple Calendar, Outlook
- [ ] Include event details (time, location, description)

---

### 🔮 PHASE 4: FUTURE FEATURES (Post-Launch)
**Long-term improvements**

#### Task 4.1: Implement Reviews System
**Priority**: P4 | **Effort**: Very High | **Status**: ❌ Not Planned

**Subtasks**:
- [ ] Design reviews database schema
- [ ] Build review submission form
- [ ] Implement moderation
- [ ] Display reviews on venue pages
- [ ] Add rating system (stars)
- [ ] Prevent spam/abuse
- [ ] User authentication required

---

#### Task 4.2: Add User Authentication
**Priority**: P4 | **Effort**: Very High | **Status**: ❌ Not Planned

**Subtasks**:
- [ ] Implement user registration
- [ ] Add login/logout
- [ ] Password reset flow
- [ ] Session management
- [ ] User profile pages
- [ ] OAuth integration (Google, Facebook)

---

## 6. URL Migration Strategy

### Current State
- **Production**: 7,118 URLs using flat structure (`/cities/{slug}`, `/venues/{slug}`)
- **V2**: Hierarchical structure (`/{country}/{city}/{venue}`)

### Migration Approach

#### Option A: 301 Redirects (RECOMMENDED)
**Preserve SEO value with permanent redirects**

**Implementation**:
1. Create `RedirectController` in V2
2. Add routes for legacy patterns:
   ```elixir
   get "/cities/:slug", RedirectController, :city_redirect
   get "/venues/:slug", RedirectController, :venue_redirect
   ```
3. Controller logic:
   - Look up resource by slug
   - Build new hierarchical URL
   - Return `redirect(conn, to: new_url, status: 301)`

**Example**:
```
GET /cities/austin
→ 301 Redirect to /united-states/austin

GET /venues/bull-bowl
→ 301 Redirect to /united-states/austin/bull-bowl
```

**Pros**:
- ✅ Preserves all 7,118 URLs
- ✅ Maintains SEO rankings
- ✅ User bookmarks still work
- ✅ Google search results automatically update

**Cons**:
- ⚠️ Extra database query per redirect
- ⚠️ Requires slug uniqueness for venues

---

#### Option B: Canonical Tags
**Keep both URL patterns, declare preferred version**

**Implementation**:
- Support both URL patterns
- Add `<link rel="canonical">` to pages
- Point to hierarchical version

**Not recommended** - increases complexity, duplicate content risk

---

### Redirect Implementation Plan

#### Task: Build URL Redirects
**Priority**: P1 | **Effort**: Medium | **Status**: ❌ Not Started

**Subtasks**:
- [ ] Create `RedirectController`
- [ ] Implement `city_redirect/2` action:
  - Query city by slug
  - Build `/{country_slug}/{city_slug}` URL
  - Return 301 redirect
- [ ] Implement `venue_redirect/2` action:
  - Query venue by slug
  - Get associated city and country
  - Build `/{country_slug}/{city_slug}/{venue_slug}` URL
  - Return 301 redirect
- [ ] Add routes to `router.ex`
- [ ] Test all legacy URL patterns
- [ ] Validate 301 status codes
- [ ] Test with sample sitemap URLs
- [ ] Monitor redirect performance (query time)

**Edge Cases**:
- [ ] Handle duplicate slugs (if any)
- [ ] Handle deleted/merged venues
- [ ] Handle 404 for non-existent slugs

---

## 7. Success Metrics

### Launch Readiness Criteria
- ✅ All P0 tasks completed (venue pages work)
- ✅ All P1 tasks completed (core features)
- ✅ 301 redirects implemented for all 7,118 URLs
- ✅ Venue images displaying
- ✅ City page filters working
- ✅ Basic venue information (location, contact, next event)
- ✅ Mobile responsive
- ✅ Performance acceptable (<2s page load)

### Feature Parity Score
**Target**: 80% feature parity with production by launch

**Current**: 57% (4/7 page types working)

**After P0+P1**: ~85% (all core pages + essential features)

---

## 8. Timeline Estimate

| Phase | Duration | Completion Target |
|-------|----------|------------------|
| Phase 0 (Critical) | 3-5 days | Week 1 |
| Phase 1 (Core) | 10-15 days | Week 2-3 |
| Phase 2 (Important) | 10-15 days | Week 4-5 |
| Phase 3 (Nice-to-have) | 5-10 days | Week 6+ |
| **TOTAL TO LAUNCH** | **~4 weeks** | End of Week 5 |

---

## 9. Risk Assessment

### HIGH RISK
- 🔴 **Venue page crash** - Blocks 75% of URLs (5,348 pages)
- 🔴 **URL migration** - Risk of broken links, lost SEO

### MEDIUM RISK
- 🟡 **Image loading** - CDN dependencies, missing fallbacks
- 🟡 **Data quality** - Incomplete venue information from view

### LOW RISK
- 🟢 **UI/UX differences** - Can be iterated post-launch
- 🟢 **Nice-to-have features** - Not blocking launch

---

## 10. Next Immediate Actions

**THIS WEEK**:
1. ✅ Fix venue page crash (Task 0.1) - **BLOCKER**
2. ✅ Implement venue images (Task 1.1) - Quick visual win
3. ✅ Add city page day filters (Task 1.2) - Core functionality
4. ✅ Test with real production data

**WEEK 2**:
5. Build venue page sections (location, contact, next event)
6. Implement 301 redirects for URL migration
7. Begin image integration (CDN setup)

---

**END OF DOCUMENT**
