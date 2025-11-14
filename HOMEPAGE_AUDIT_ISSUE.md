# Homepage Audit: Align with Production QuizAdvisor Requirements

## Overview

Audit comparison between current Trivia Advisor V2 homepage implementation and production QuizAdvisor (https://quizadvisor.com/). This audit identifies required changes to match core features and optional enhancements based on production patterns.

**Reference URLs:**
- Production: https://quizadvisor.com/
- Current Dev: http://localhost:4003/

---

## Current State

### What We Have Now

**File:** `lib/trivia_advisor_web/live/home_live.ex`

**Data Fetching (lines 16-17):**
```elixir
popular_cities = Locations.get_popular_cities(12)
latest_venues = Locations.get_latest_venues(10)
```

**Latest Venues Section (lines 90-104):**
- **Count:** 10 venues displayed
- **Grid Layout:** `xl:grid-cols-5` (5-column grid on extra-large screens)
- **Cards:** Include image, name, address, event details

**Popular Cities Section (lines 106-119):**
- **Count:** 12 cities displayed
- **Grid Layout:** `xl:grid-cols-4` (4-column grid on extra-large screens)
- **Cards:** Include city image, name, venue count

**Other Sections:**
- ✅ Hero section with stats
- ✅ About section with "Learn More" button
- ❌ Missing: Search functionality
- ❌ Missing: "How It Works" section
- ❌ Missing: Newsletter signup

---

## Production QuizAdvisor Analysis

### What Production Has

**Latest Venues:**
- **Count:** 4 venues displayed (not 10)
- **Layout:** Clean card grid (appears to be 2x2 or 1x4 layout)
- **Cards:** Image, address, event day/time, entry fee, prize details

**Popular Cities:**
- **Count:** 6 cities displayed (not 12)
- **Layout:** Card grid (appears to be 2x3 or 3-column layout)
- **Cards:** City image with venue count overlay

**Hero Section:**
- Tagline: "Find the Best Pub Quizzes Near You"
- Global stats: "5348+ Active Venues, 31+ Countries"

**Additional Sections:**
- ✅ **"How It Works"** - 3-step explanation:
  1. Browse venues and events
  2. Find your perfect quiz night
  3. Join and compete
- ✅ **Newsletter Signup** - "Weekly Trivia Updates" subscription form

**Search:**
- No visible search bar in main content area (may be in navigation)

---

## Required Changes

### Priority 1: Core Feature Alignment

#### 1. Latest Venues - Reduce from 10 to 4

**File:** `lib/trivia_advisor_web/live/home_live.ex`

**Line 17 - Data Fetch:**
```elixir
# Current:
latest_venues = Locations.get_latest_venues(10)

# Change to:
latest_venues = Locations.get_latest_venues(4)
```

**Line 93 - Grid Layout:**
```elixir
# Current:
<div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-5 gap-6">

# Change to (for 4 items in 2x2 or 1x4):
<div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
```

**Rationale:** User specified "column of four" - matches production's cleaner, focused display

---

#### 2. Popular Cities - Reduce from 12 to 6

**File:** `lib/trivia_advisor_web/live/home_live.ex`

**Line 16 - Data Fetch:**
```elixir
# Current:
popular_cities = Locations.get_popular_cities(12)

# Change to:
popular_cities = Locations.get_popular_cities(6)
```

**Line 109 - Grid Layout:**
```elixir
# Current:
<div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">

# Change to (for 6 items in 2x3):
<div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
```

**Rationale:** User specified "six" popular cities - matches production's curated selection

---

#### 3. Add Search Functionality

**Requirement:** Implement city search capability

**Implementation Options:**

**Option A: Hero Section Search**
Add search input within hero section (lines 62-88) before stats:
```elixir
<!-- Search Form -->
<div class="max-w-2xl mx-auto mt-8">
  <form phx-submit="search" class="flex gap-2">
    <input
      type="text"
      name="city_search"
      placeholder="Search for a city..."
      class="flex-1 px-4 py-3 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
    />
    <button
      type="submit"
      class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
    >
      Search
    </button>
  </form>
</div>
```

**Option B: Navigation Bar Search**
Integrate with existing navigation structure (requires nav component investigation)

**Backend Handler:**
```elixir
def handle_event("search", %{"city_search" => query}, socket) do
  # Redirect to city search results or filter cities
  {:noreply, push_navigate(socket, to: ~p"/cities?search=#{query}")}
end
```

**Note:** Production doesn't show prominent search bar - investigate if it's in navigation or requires different pattern

---

## Optional Enhancements

### Priority 2: Value-Add Features from Production

#### 4. Add "How It Works" Section

**Location:** After Popular Cities section, before About section

**Implementation:**
```elixir
<!-- How It Works Section -->
<div class="bg-gray-50 py-16">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <h2 class="text-3xl font-bold text-center text-gray-900 mb-12">
      How It Works
    </h2>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
      <!-- Step 1 -->
      <div class="text-center">
        <div class="w-16 h-16 bg-blue-600 text-white rounded-full flex items-center justify-center text-2xl font-bold mx-auto mb-4">
          1
        </div>
        <h3 class="text-xl font-semibold mb-2">Browse Venues</h3>
        <p class="text-gray-600">
          Explore trivia venues and events in your city or around the world
        </p>
      </div>

      <!-- Step 2 -->
      <div class="text-center">
        <div class="w-16 h-16 bg-blue-600 text-white rounded-full flex items-center justify-center text-2xl font-bold mx-auto mb-4">
          2
        </div>
        <h3 class="text-xl font-semibold mb-2">Find Your Perfect Quiz</h3>
        <p class="text-gray-600">
          Check schedules, entry fees, and event details to find your ideal trivia night
        </p>
      </div>

      <!-- Step 3 -->
      <div class="text-center">
        <div class="w-16 h-16 bg-blue-600 text-white rounded-full flex items-center justify-center text-2xl font-bold mx-auto mb-4">
          3
        </div>
        <h3 class="text-xl font-semibold mb-2">Join & Compete</h3>
        <p class="text-gray-600">
          Show up, have fun, and test your trivia knowledge with friends
        </p>
      </div>
    </div>
  </div>
</div>
```

**Benefits:**
- Clarifies value proposition for new users
- Reduces bounce rate by explaining the service
- Matches production's user onboarding pattern

---

#### 5. Add Newsletter Signup Section

**Location:** Before footer, after About section

**Implementation:**
```elixir
<!-- Newsletter Section -->
<div class="bg-blue-600 py-16">
  <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
    <h2 class="text-3xl font-bold text-white mb-4">
      Stay Updated with Weekly Trivia
    </h2>
    <p class="text-blue-100 mb-8">
      Get the latest trivia events and venue updates delivered to your inbox
    </p>

    <form phx-submit="subscribe" class="flex flex-col sm:flex-row gap-4 max-w-md mx-auto">
      <input
        type="email"
        name="email"
        placeholder="Enter your email"
        required
        class="flex-1 px-4 py-3 rounded-lg border-0 focus:ring-2 focus:ring-blue-300"
      />
      <button
        type="submit"
        class="px-6 py-3 bg-white text-blue-600 font-semibold rounded-lg hover:bg-gray-100 transition-colors"
      >
        Subscribe
      </button>
    </form>
  </div>
</div>
```

**Backend Handler:**
```elixir
def handle_event("subscribe", %{"email" => email}, socket) do
  # Store subscription (future integration with email service)
  # For now, just show success message
  {:noreply, put_flash(socket, :info, "Thanks for subscribing!")}
end
```

**Benefits:**
- Builds email list for marketing
- Increases user engagement and retention
- Matches production's growth strategy

---

#### 6. Hero Section Refinement

**Current:** Stats-focused hero
**Production:** Tagline-focused with stats below

**Suggested Improvement:**
```elixir
<!-- Hero Section - Enhanced -->
<div class="text-center mb-12">
  <h1 class="text-5xl font-bold text-gray-900 mb-4">
    Find the Best Pub Quizzes Near You
  </h1>
  <p class="text-xl text-gray-600 mb-8">
    Discover trivia nights, check schedules, and never miss quiz night again
  </p>

  <!-- Stats below tagline -->
  <div class="flex justify-center gap-8 text-gray-700">
    <div>
      <div class="text-3xl font-bold text-blue-600"><%= @stats.total_venues %>+</div>
      <div class="text-sm">Active Venues</div>
    </div>
    <div>
      <div class="text-3xl font-bold text-blue-600"><%= @stats.total_countries %>+</div>
      <div class="text-sm">Countries</div>
    </div>
  </div>
</div>
```

---

## Implementation Notes

### Grid Layout Best Practices

**4 Items (Latest Venues):**
- Mobile: 1 column (`grid-cols-1`)
- Tablet: 2 columns (`md:grid-cols-2`) → 2x2 layout
- Desktop: 4 columns (`xl:grid-cols-4`) → 1x4 layout

**6 Items (Popular Cities):**
- Mobile: 1 column (`grid-cols-1`)
- Tablet: 2 columns (`md:grid-cols-2`) → 3x2 layout
- Desktop: 3 columns (`xl:grid-cols-3`) → 2x3 layout

### Testing Checklist

- [ ] Verify exactly 4 latest venues display
- [ ] Verify exactly 6 popular cities display
- [ ] Test grid layouts on mobile, tablet, desktop
- [ ] Verify search functionality works (if implemented)
- [ ] Test newsletter signup form (if implemented)
- [ ] Verify "How It Works" section displays correctly (if implemented)
- [ ] Check responsive behavior at all breakpoints

---

## Files to Modify

1. **`lib/trivia_advisor_web/live/home_live.ex`**
   - Lines 16-17: Data fetching (reduce counts)
   - Line 93: Latest venues grid class
   - Line 109: Popular cities grid class
   - Hero section: Add search form (optional)
   - After line 119: Add "How It Works" section (optional)
   - Before footer: Add newsletter section (optional)

2. **Backend handlers (if adding search/newsletter):**
   - Add `handle_event("search", ...)` for city search
   - Add `handle_event("subscribe", ...)` for newsletter signup

---

## Acceptance Criteria

### Required (Must Have):
- ✅ Latest venues limited to 4 items
- ✅ Latest venues grid uses 4-column layout on desktop
- ✅ Popular cities limited to 6 items
- ✅ Popular cities grid uses 3-column layout on desktop
- ✅ Search functionality implemented (method TBD)

### Optional (Should Have):
- ⚪ "How It Works" section added with 3-step explanation
- ⚪ Newsletter signup form integrated
- ⚪ Hero section refined with tagline focus

### Nice to Have:
- ⚪ Smooth animations for grid layouts
- ⚪ Loading states for search
- ⚪ Success/error toasts for newsletter signup

---

## References

- Production Site: https://quizadvisor.com/
- Current Implementation: `lib/trivia_advisor_web/live/home_live.ex`
- User Requirements: "column of four" for latest venues, "six" for popular cities, search functionality

---

## Estimated Effort

- **Required Changes:** 2-3 hours
  - Data fetching changes: 15 minutes
  - Grid layout adjustments: 30 minutes
  - Search functionality: 1-2 hours (depends on implementation approach)
  - Testing: 30 minutes

- **Optional Enhancements:** 3-4 hours
  - "How It Works" section: 1 hour
  - Newsletter signup: 1-2 hours (with backend integration)
  - Hero refinement: 1 hour
  - Testing: 1 hour

**Total: 5-7 hours** for complete implementation
