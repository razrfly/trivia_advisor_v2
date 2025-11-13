# Venue Page Improvements - Match Production Quality

## Overview

Bring venue detail pages up to production quality by displaying all available event information with proper localization.

**Comparison**:
- Production: https://quizadvisor.com/venues/kings-arms-waterloo
- Local: http://localhost:4003/venues/kings-arms-waterloo

## Problem Statement

Current venue pages only show minimal event information (title, source, status) despite having rich data available in `trivia_events_export` view. Production shows complete event details, descriptions, contact info, and enhanced visuals.

## Data Availability ✅

All required data exists in database:

| Field | Available | Notes |
|-------|-----------|-------|
| `description` | ✅ | Event description (EN localized) |
| `day_of_week` | ✅ | 1-7 (Monday-Sunday) |
| `start_time` | ✅ | Event start time |
| `entry_fee_cents` | ✅ | Price in cents (0 = free) |
| `frequency` | ✅ | "weekly", "biweekly", "monthly" |
| `venue_images` | ✅ | JSONB array of venue photos |
| `venue_metadata` | ✅ | JSONB with phone, website, etc. |
| `hero_image` | ✅ | Featured event/venue image |
| `last_seen_at` | ✅ | Last scrape timestamp |

**Localization helpers already implemented** (Issue #20):
- `PublicEvent.format_time(time, country)` - 12h/24h based on country
- `PublicEvent.format_entry_fee(cents, currency_code)` - £/$/€ symbols
- `PublicEvent.format_day_name(day_of_week)` - Day name formatting

## Implementation Phases

### Phase 1: Event Details Card (CRITICAL)

Display structured event information matching production.

**Requirements:**
- Grid layout with 4 columns: Day, Time, Fee, Frequency
- Use Heroicons for visual appeal (calendar, clock, money, repeat)
- Apply localization helpers from #20

**Example:**
```elixir
# Display:
- Quiz Day: format_day_name(event.day_of_week) → "Sunday"
- Start Time: format_time(event.start_time, country) → "7:30 PM" (UK) or "19:30" (PL)
- Entry Fee: format_entry_fee(event.entry_fee_cents, currency_code) → "£2.00" (UK)
- Frequency: event.frequency → "Weekly"
```

**Files:**
- `lib/trivia_advisor_web/live/venue_show_live.ex` - pass country data
- `lib/trivia_advisor_web/live/venue_show_live.html.heex` - add card markup

---

### Phase 2: Event Description Section (CRITICAL)

Display full event description with source attribution.

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
- Use `activity_slug` for Wombie.com source links

**Files:**
- `lib/trivia_advisor_web/live/venue_show_live.html.heex`

---

### Phase 3: Contact Information (HIGH)

Extract and display venue contact details from `venue_metadata` JSONB.

**Expected Data Structure:**
```json
{
  "phone": "020 7207 0784",
  "website": "https://www.thekingsarmslondon.co.uk/"
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

**Files:**
- `lib/trivia_advisor_web/live/venue_show_live.html.heex`

---

### Phase 4: Multiple Venue Images (HIGH)

Display image gallery from `venue_images` JSONB array.

**Data Structure:**
```json
[
  {"url": "https://...", "alt": "Kings Arms exterior"},
  {"url": "https://...", "alt": "Kings Arms interior"}
]
```

**Requirements:**
- Display 4-5 images in grid layout
- Main hero image + thumbnail grid
- Fallback chain: venue_images → hero_image → city_images
- Responsive design

**Files:**
- `lib/trivia_advisor_web/live/venue_show_live.html.heex`

---

### Phase 5: Next Quiz Night Widget (MEDIUM)

Calculate and display next occurrence for weekly events.

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
- Display: "Sunday, Nov 16" + localized start time
- Return nil for biweekly/monthly (show generic text)

**Files:**
- `lib/trivia_advisor/events.ex` - add helper function
- `lib/trivia_advisor_web/live/venue_show_live.ex` - call and assign to socket
- `lib/trivia_advisor_web/live/venue_show_live.html.heex` - add widget

---

### Phase 6: Enhanced Nearby Venues (MEDIUM)

Show venue images and day-of-week badges on nearby venues.

**Current Issue:** Query returns venues without event details (day, images)

**Solution:**
```elixir
def get_nearby_venues(venue_id, limit \\ 10) do
  # Query trivia_events_export (not just venues)
  # Group by venue to get one event per venue
  # Include: venue_images, day_of_week for badge
end
```

**Requirements:**
- Display venue image (venue_images or city_images fallback)
- Show day badge: "Mondays", "Tuesdays" using format_day_name()
- Maintain distance calculation
- Use existing VenueCard component pattern

**Files:**
- `lib/trivia_advisor/locations.ex` or `lib/trivia_advisor/events.ex` - update query
- Nearby venues card component

---

## Out of Scope

Features not in current database (future enhancements):
- ❌ Reviews system (requires new tables)
- ❌ Calendar integration buttons (external service)
- ❌ User accounts / authentication
- ❌ "Set Reminder" functionality
- ❌ Biweekly/monthly next occurrence (needs pattern_start_date field)

## Success Criteria

**Phase 1-2 (Critical):**
- [ ] Event details card displays Day/Time/Fee/Frequency with localization
- [ ] Event description visible when available
- [ ] UK venues show £ + 12-hour time
- [ ] Polish venues show 24-hour time
- [ ] Source attribution with last updated timestamp

**Phase 3-4 (High):**
- [ ] Contact info displays phone and website when in venue_metadata
- [ ] Multiple venue images shown with fallbacks

**Phase 5-6 (Medium):**
- [ ] Next quiz night calculates correctly for weekly events
- [ ] Nearby venues show images and day badges

## Testing Checklist

- [ ] Test UK venue: shows £ and 12-hour time (e.g., "7:30 PM")
- [ ] Test US venue: shows $ and 12-hour time
- [ ] Test Polish venue: shows 24-hour time (e.g., "19:30")
- [ ] Description shows when available, hidden when null
- [ ] Contact info extracted from venue_metadata JSONB
- [ ] Multiple images display with proper fallbacks
- [ ] Next quiz night calculates for weekly events
- [ ] Nearby venues include images and day badges
- [ ] Source attribution links work (activity_slug)

## Files to Modify

**Critical Priority:**
- `lib/trivia_advisor_web/live/venue_show_live.ex`
- `lib/trivia_advisor_web/live/venue_show_live.html.heex`

**High Priority:**
- `lib/trivia_advisor/events.ex` (next_occurrence helper)

**Medium Priority:**
- `lib/trivia_advisor/locations.ex` (enhanced nearby venues query)

## References

- Issue #20: Time and Currency Localization ✅ Implemented
- Production: https://quizadvisor.com/venues/kings-arms-waterloo
- Local: http://localhost:4003/venues/kings-arms-waterloo
- Schema: `lib/trivia_advisor/events/public_event.ex`
- Full spec: `VENUE_PAGE_IMPROVEMENTS.md`
