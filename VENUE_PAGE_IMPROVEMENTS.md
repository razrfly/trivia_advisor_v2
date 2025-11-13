# Venue Page Improvements - Match Production Quality

**Comparison**: http://localhost:4003/venues/kings-arms-waterloo vs https://quizadvisor.com/venues/kings-arms-waterloo

## Current State Analysis

### What's Missing from Local Version

**Critical Missing Features:**
1. ❌ Event details card showing Day/Time/Price/Frequency
2. ❌ Event description text ("About This Trivia Night")
3. ❌ Contact information (phone, website)
4. ❌ Multiple venue images / image gallery
5. ❌ "Next Quiz Night" widget with specific date
6. ❌ Enhanced nearby venues (with images and day badges)
7. ❌ Rich source attribution (last updated, active since)

**What Currently Works:**
- ✅ Basic page layout and structure
- ✅ Single venue image display
- ✅ Location map integration
- ✅ Breadcrumb navigation
- ✅ Nearby venues list (basic)
- ✅ Distance calculations

## Data Availability Verification

**Confirmed Available in `trivia_events_export` View:**

| Field | Type | Status | Notes |
|-------|------|--------|-------|
| `description` | string | ✅ Available | Event description (EN localized) |
| `day_of_week` | integer | ✅ Available | 1-7 (Monday-Sunday) |
| `start_time` | time | ✅ Available | Event start time |
| `entry_fee_cents` | integer | ✅ Available | Price in cents (0 = free) |
| `frequency` | string | ✅ Available | "weekly", "biweekly", "monthly" |
| `venue_images` | jsonb array | ✅ Available | Multiple venue photos |
| `venue_metadata` | jsonb | ✅ Available | Contains phone, website, etc. |
| `hero_image` | string | ✅ Available | Featured event/venue image |
| `last_seen_at` | datetime | ✅ Available | Last scrape timestamp |
| `source_name` | string | ✅ Available | Source attribution |
| `activity_slug` | string | ✅ Available | Wombie.com link slug |

**Localization Helpers (Implemented in #20):**
- ✅ `PublicEvent.format_time(time, country)` - 12h/24h based on country
- ✅ `PublicEvent.format_entry_fee(cents, currency_code)` - £/$/€ symbols
- ✅ `PublicEvent.format_day_name(day_of_week)` - "Monday", "Tuesday", etc.

## Implementation Plan

### Phase 1: Event Details Card (CRITICAL)

**Objective**: Display structured event information matching production

**Location**: `lib/trivia_advisor_web/live/venue_show_live.ex`

**Requirements:**
```elixir
# Event card should display:
- Quiz Day: format_day_name(event.day_of_week) → "Sunday"
- Start Time: format_time(event.start_time, country) → "7:30 PM" (UK) or "19:30" (PL)
- Entry Fee: format_entry_fee(event.entry_fee_cents, currency_code) → "£2.00" (UK) or "$2.00" (US)
- Frequency: event.frequency → "Weekly"
```

**Design Pattern**:
- Grid layout with 4 columns (Day, Time, Fee, Frequency)
- Icons for each field (calendar, clock, money, repeat)
- Prominent display above description

**Files to Modify:**
- `lib/trivia_advisor_web/live/venue_show_live.ex` - pass country data to template
- `lib/trivia_advisor_web/live/venue_show_live.html.heex` - add event details card markup

---

### Phase 2: Event Description Section (CRITICAL)

**Objective**: Display full event description with source attribution

**Requirements:**
```heex
<div class="event-description">
  <h2>About This Trivia Night</h2>
  <p><%= @event.description %></p>

  <div class="source-attribution">
    Updated <%= time_ago(@event.last_seen_at) %>
    • Active since <%= format_active_since(@event.inserted_at) %>
    • Source: <a href={source_url(@event)}><%= @event.source_name %></a>
  </div>
</div>
```

**Edge Cases:**
- Handle nil/empty descriptions gracefully
- Format timestamps for readability
- Use activity_slug for Wombie.com source links

**Files to Modify:**
- `lib/trivia_advisor_web/live/venue_show_live.html.heex` - add description section

---

### Phase 3: Contact Information (HIGH)

**Objective**: Extract and display venue contact details

**Data Source**: `venue_metadata` JSONB field likely contains:
```json
{
  "phone": "020 7207 0784",
  "website": "https://www.thekingsarmslondon.co.uk/",
  ...
}
```

**Requirements:**
```heex
<div class="contact-info">
  <h3>Contact</h3>
  <%= if @venue.metadata["phone"] do %>
    <a href={"tel:#{@venue.metadata["phone"]}"}>
      <Heroicon.outline.phone /> <%= @venue.metadata["phone"] %>
    </a>
  <% end %>

  <%= if @venue.metadata["website"] do %>
    <a href={@venue.metadata["website"]} target="_blank">
      <Heroicon.outline.globe_alt /> Visit website
    </a>
  <% end %>
</div>
```

**Files to Modify:**
- `lib/trivia_advisor_web/live/venue_show_live.html.heex` - add contact sidebar

---

### Phase 4: Multiple Venue Images (HIGH)

**Objective**: Display image gallery from `venue_images` array

**Data Structure**: `venue_images` is JSONB array like:
```json
[
  {"url": "https://...", "alt": "Kings Arms exterior"},
  {"url": "https://...", "alt": "Kings Arms interior"},
  ...
]
```

**Requirements:**
- Display 4-5 images in grid layout
- Main hero image + thumbnail grid
- Fallback to city_images if venue_images empty
- Use hero_image field if available

**Files to Modify:**
- `lib/trivia_advisor_web/live/venue_show_live.html.heex` - enhance image display

---

### Phase 5: Next Quiz Night Widget (MEDIUM)

**Objective**: Calculate and display next occurrence for weekly events

**Calculation Logic:**
```elixir
def get_next_quiz_night(%PublicEvent{frequency: "weekly", day_of_week: dow, start_time: time}) do
  today = Date.utc_today()
  today_dow = Date.day_of_week(today)

  days_until_next = case dow - today_dow do
    diff when diff > 0 -> diff
    diff when diff <= 0 -> diff + 7
  end

  next_date = Date.add(today, days_until_next)
  DateTime.new!(next_date, time, "Etc/UTC")
end

def get_next_quiz_night(%PublicEvent{frequency: freq}) when freq in ["biweekly", "monthly"] do
  nil  # Future enhancement - requires pattern start date
end
```

**Requirements:**
- Only implement for "weekly" frequency
- Display formatted date (e.g., "Sunday, Nov 16")
- Show start time in localized format
- Return nil for biweekly/monthly (show generic text)

**Files to Add/Modify:**
- `lib/trivia_advisor/events.ex` - add `get_next_quiz_night/1` function
- `lib/trivia_advisor_web/live/venue_show_live.ex` - call helper and assign to socket
- `lib/trivia_advisor_web/live/venue_show_live.html.heex` - add widget

---

### Phase 6: Enhanced Nearby Venues (MEDIUM)

**Objective**: Show venue images and day-of-week badges

**Current Query**: Returns just venue data without event details

**Updated Query Needed:**
```elixir
def get_nearby_venues(venue_id, limit \\ 10) do
  # Query trivia_events_export (not just venues)
  # This view already joins events with venues
  # Group by venue to get one event per venue
  # Include: venue_images, day_of_week for badge
end
```

**Requirements:**
- Display venue image (from venue_images or city_images fallback)
- Show day badge (e.g., "Mondays", "Tuesdays") using format_day_name
- Maintain distance calculation
- Use existing VenueCard component pattern

**Files to Modify:**
- `lib/trivia_advisor/locations.ex` or `lib/trivia_advisor/events.ex` - update nearby venues query
- Nearby venues card component - add image and day badge

---

## Out of Scope (Future Enhancements)

**Features NOT in Current Database:**
- ❌ Reviews system (requires new tables)
- ❌ Calendar integration buttons (external service)
- ❌ User accounts / authentication
- ❌ "Set Reminder" functionality
- ❌ Biweekly/monthly next occurrence calculation (needs pattern_start_date field)

## Success Criteria

**Phase 1-2 (Critical)**: Venue page displays complete event information with localized formatting
- ✅ Event details card with all 4 fields
- ✅ Full event description visible
- ✅ Proper localization (UK: £ + 12h, US: $ + 12h, PL: PLN + 24h)

**Phase 3-4 (High)**: Rich venue information and visual appeal
- ✅ Contact information displayed when available
- ✅ Multiple venue images shown

**Phase 5-6 (Medium)**: Enhanced user experience
- ✅ Next quiz night for weekly events
- ✅ Better nearby venues presentation

## Testing Checklist

- [ ] Event details card displays for all events
- [ ] Description shows when available, gracefully hidden when null
- [ ] Localization works: UK shows £ and 12-hour, Poland shows 24-hour
- [ ] Contact info displays phone and website when in venue_metadata
- [ ] Multiple images display correctly with fallbacks
- [ ] Next quiz night calculates correctly for weekly events
- [ ] Nearby venues show images and day badges
- [ ] Source attribution links work correctly

## Files Requiring Changes

**Priority 1 (Critical):**
- `lib/trivia_advisor_web/live/venue_show_live.ex`
- `lib/trivia_advisor_web/live/venue_show_live.html.heex`

**Priority 2 (High):**
- `lib/trivia_advisor/events.ex` (for next_occurrence helper)

**Priority 3 (Medium):**
- `lib/trivia_advisor/locations.ex` (for enhanced nearby venues query)

## References

- Issue #20: Time and Currency Localization (✅ Implemented)
- Production page: https://quizadvisor.com/venues/kings-arms-waterloo
- Local page: http://localhost:4003/venues/kings-arms-waterloo
- Database schema: `lib/trivia_advisor/events/public_event.ex`
