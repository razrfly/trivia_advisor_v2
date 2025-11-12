# Localization Migration Issue: Time and Currency Formatting

## Problem Statement

The 2025 project (trivia_advisor) has broken time and currency localization:

**Current Behavior (BROKEN):**
- 🇬🇧 UK venues show "18:30" instead of "6:30 PM" (24-hour format)
- 💷 UK venues show "$" instead of "£" (wrong currency symbol)
- 🌍 All non-US venues display incorrect formatting

**Expected Behavior:**
- 🇬🇧 UK: "6:30 PM" and "£5.00"
- 🇺🇸 US: "7:00 PM" and "$10.00"
- 🇦🇺 AU: "7:30 PM" and "A$8.00"

## Root Cause Analysis

### Currency Issue
**Location:** `lib/trivia_advisor/events/public_event.ex:107-112`
```elixir
def format_entry_fee(cents) when is_integer(cents) do
  dollars = cents / 100
  "$#{:erlang.float_to_binary(dollars, decimals: 2)}"  # ❌ Hardcoded $
end
```

**Problem:** The function doesn't accept a `country_code` parameter and hardcodes the dollar sign.

### Time Issue
**Location:** `lib/trivia_advisor/events/public_event.ex:125-127`
```elixir
def format_time(nil, _country_code), do: "Time TBD"
def format_time(time, "US"), do: Calendar.strftime(time, "%I:%M %p")  # 7:00 PM
def format_time(time, _country_code), do: Calendar.strftime(time, "%H:%M")  # ❌ 19:00 for GB
```

**Problem:** All non-US countries default to 24-hour format. UK and other English-speaking countries should use 12-hour format.

## Proven Solution from 2024 Project

The 2024 project (`/Users/holdenthomas/Code/paid-projects-2024/trivia_advisor`) has a complete, working solution using:
1. **Money library** (~> 1.12) - Currency formatting with proper symbols
2. **Countries library** (~> 1.6) - Country code → currency code mapping
3. **ex_cldr** with providers - Locale-based time formatting
4. **Custom helpers** - `LocalizationHelpers` module for intelligent formatting

### 2024 Dependencies Used

From `mix.exs`:
```elixir
{:countries, "~> 1.6"},
{:money, "~> 1.12"},
{:ex_cldr, "~> 2.40"},
{:ex_cldr_numbers, "~> 2.33"},
{:ex_cldr_dates_times, "~> 2.20"},
{:ex_cldr_calendars, "~> 1.26"}
```

## Migration Plan: Port 2024 Solution to 2025 Project

### Phase 1: Add Dependencies

**File:** `mix.exs`

Add to dependencies section:
```elixir
{:countries, "~> 1.6"},
{:money, "~> 1.12"},
{:ex_cldr, "~> 2.40"},
{:ex_cldr_numbers, "~> 2.33"},
{:ex_cldr_dates_times, "~> 2.20"},
{:ex_cldr_calendars, "~> 1.26"}
```

**Action:** Run `mix deps.get` after adding.

### Phase 2: Create LocalizationHelpers Module

**File:** `lib/trivia_advisor_web/helpers/localization_helpers.ex` (NEW FILE)

**Source:** `/Users/holdenthomas/Code/paid-projects-2024/trivia_advisor/lib/trivia_advisor_web/helpers/localization_helpers.ex`

**Key Features:**
1. **CLDR Configuration** (lines 10-15):
   ```elixir
   defmodule TriviaAdvisor.Cldr do
     use Cldr,
       locales: ["en", "fr", "de", "es", "it", "ja", "zh", "ru", "pt", "nl", "en-GB", "pl"],
       default_locale: "en",
       providers: [Cldr.Number, Cldr.DateTime, Cldr.Calendar]
   end
   ```

2. **Smart Time Formatting** (lines 30-86):
   - Uses Countries library to determine locale
   - Automatically selects 12-hour vs 24-hour based on country
   - Uses CLDR for proper formatting with fallback

3. **Country-Based Format Detection** (lines 88-130):
   ```elixir
   defp uses_24h_format?(country) do
     # English-speaking countries and North America (except Mexico) use 12h
     # Most other countries use 24h format
     # Uses Countries library data to determine intelligently
   end
   ```

4. **Timezone Support** (lines 281-323):
   - Extracts timezone from Countries library
   - Falls back to UTC if unavailable

**Migration Notes:**
- Change module name from `TriviaAdvisorWeb.Helpers.LocalizationHelpers` (2024) to `TriviaAdvisorWeb.Helpers.LocalizationHelpers` (2025)
- Update CLDR module name from `TriviaAdvisor.Cldr` to match 2025 project naming

### Phase 3: Create CurrencyHelpers Module

**File:** `lib/trivia_advisor_web/helpers/currency_helpers.ex` (NEW FILE)

**Source:** `/Users/holdenthomas/Code/paid-projects-2024/trivia_advisor/lib/trivia_advisor_web/helpers/currency_helpers.ex`

**Key Functions to Port:**

1. **format_currency/2** (lines 22-28):
   ```elixir
   def format_currency(amount_cents, currency_code) when is_number(amount_cents) do
     money = Money.new(amount_cents, currency_code)
     Money.to_string(money)
   end
   def format_currency(_, _), do: "Free"
   ```

2. **get_country_currency/1** (lines 43-58):
   ```elixir
   def get_country_currency(venue) do
     country = get_country(venue)
     cond do
       country && country.code ->
         country_data = Countries.get(country.code)  # Uses Countries library
         if country_data && Map.has_key?(country_data, :currency_code),
           do: country_data.currency_code, else: "USD"
       true -> "USD"
     end
   end
   ```

**How It Works:**
- Takes country code (e.g., "GB", "US", "AU")
- Uses Countries library: `Countries.get("GB")` → `%{currency_code: "GBP", ...}`
- Creates Money struct: `Money.new(500, "GBP")` → `Money<5.00 GBP>`
- Formats with proper symbol: `Money.to_string(money)` → "£5.00"

**Migration Notes:**
- Port entire module from 2024 project
- Ensure all helper functions are included for proper country/currency resolution

### Phase 4: Update PublicEvent Module

**File:** `lib/trivia_advisor/events/public_event.ex`

**Changes Required:**

1. **Import helpers** (add to top of file):
   ```elixir
   alias TriviaAdvisorWeb.Helpers.{LocalizationHelpers, CurrencyHelpers}
   ```

2. **Update format_entry_fee** (lines 107-112):

   **BEFORE (BROKEN):**
   ```elixir
   def format_entry_fee(0), do: "Free"
   def format_entry_fee(nil), do: "Check website"
   def format_entry_fee(cents) when is_integer(cents) do
     dollars = cents / 100
     "$#{:erlang.float_to_binary(dollars, decimals: 2)}"  # ❌ Hardcoded $
   end
   ```

   **AFTER (FIXED):**
   ```elixir
   def format_entry_fee(0, _currency_code), do: "Free"
   def format_entry_fee(nil, _currency_code), do: "Check website"
   def format_entry_fee(cents, currency_code) when is_integer(cents) and is_binary(currency_code) do
     CurrencyHelpers.format_currency(cents, currency_code)  # ✅ Uses Money library
   end

   # Fallback for when currency_code is not provided
   def format_entry_fee(cents, _) when is_integer(cents) do
     CurrencyHelpers.format_currency(cents, "USD")  # Default to USD
   end
   ```

3. **Update format_time** (lines 125-127):

   **BEFORE (PARTIALLY BROKEN):**
   ```elixir
   def format_time(nil, _country_code), do: "Time TBD"
   def format_time(time, "US"), do: Calendar.strftime(time, "%I:%M %p")  # 7:00 PM
   def format_time(time, _country_code), do: Calendar.strftime(time, "%H:%M")  # ❌ 19:00 for GB
   ```

   **AFTER (FIXED):**
   ```elixir
   def format_time(nil, _country), do: "Time TBD"
   def format_time(time, country) when is_map(country) do
     LocalizationHelpers.format_localized_time(time, country)  # ✅ Uses CLDR + Countries
   end

   # Fallback for when country is just a code string
   def format_time(time, country_code) when is_binary(country_code) do
     country = %{code: country_code}
     LocalizationHelpers.format_localized_time(time, country)
   end
   ```

### Phase 5: Update VenueCard Component

**File:** `lib/trivia_advisor_web/components/cards/venue_card.ex`

**Current Implementation (lines 98-100):**
```elixir
<span><%= PublicEvent.format_time(@venue.start_time, @venue.country_code) %></span>
<!-- ... -->
<span><%= PublicEvent.format_entry_fee(@venue.entry_fee_cents) %></span>
```

**Problem:** `format_entry_fee` doesn't receive country information for currency determination.

**Changes Required:**

1. **Pass country data to format functions:**
   ```elixir
   <span><%= PublicEvent.format_time(@venue.start_time, get_country(@venue)) %></span>
   <!-- ... -->
   <span><%= PublicEvent.format_entry_fee(@venue.entry_fee_cents, get_currency_code(@venue)) %></span>
   ```

2. **Add helper functions** (add to VenueCard module):
   ```elixir
   defp get_country(venue) do
     cond do
       Map.has_key?(venue, :country) && is_map(venue.country) ->
         venue.country
       Map.has_key?(venue, :country_code) && is_binary(venue.country_code) ->
         %{code: venue.country_code}
       true ->
         %{code: "US"}  # Default fallback
     end
   end

   defp get_currency_code(venue) do
     country = get_country(venue)
     CurrencyHelpers.get_country_currency(%{country: country})
   end
   ```

**Alternative Approach (from 2024 project):**

Reference the 2024 implementation at:
- `/Users/holdenthomas/Code/paid-projects-2024/trivia_advisor/lib/trivia_advisor_web/components/ui/venue_card.ex`
- Lines 264-291: `display_formatted_price/1` function
- Lines 403-407: `format_localized_time/2` function

This approach keeps all the complexity in the component helper functions rather than modifying PublicEvent.

### Phase 6: Database Query Updates (if needed)

**Current Query:** `lib/trivia_advisor/locations.ex`

**Verify:** Check if queries preload `:country` association for proper country data access.

**Expected Structure:**
```elixir
venue = %{
  start_time: ~T[18:30:00],
  entry_fee_cents: 500,
  country_code: "GB",
  country: %{
    code: "GB",
    name: "United Kingdom"
  }
}
```

**Action:** Ensure all venue queries preload country association:
```elixir
from(v in Venue, preload: [:country])
```

### Phase 7: Testing and Validation

**Test Cases:**

1. **UK Venue (GB):**
   ```elixir
   venue = %{
     start_time: ~T[18:30:00],
     entry_fee_cents: 500,
     country: %{code: "GB"}
   }

   PublicEvent.format_time(venue.start_time, venue.country)
   # Expected: "6:30 PM"

   PublicEvent.format_entry_fee(venue.entry_fee_cents, "GBP")
   # Expected: "£5.00"
   ```

2. **US Venue (US):**
   ```elixir
   venue = %{
     start_time: ~T[19:00:00],
     entry_fee_cents: 1000,
     country: %{code: "US"}
   }

   PublicEvent.format_time(venue.start_time, venue.country)
   # Expected: "7:00 PM"

   PublicEvent.format_entry_fee(venue.entry_fee_cents, "USD")
   # Expected: "$10.00"
   ```

3. **Australian Venue (AU):**
   ```elixir
   venue = %{
     start_time: ~T[19:30:00],
     entry_fee_cents: 800,
     country: %{code: "AU"}
   }

   PublicEvent.format_time(venue.start_time, venue.country)
   # Expected: "7:30 PM"

   PublicEvent.format_entry_fee(venue.entry_fee_cents, "AUD")
   # Expected: "A$8.00"
   ```

4. **German Venue (DE - 24h format):**
   ```elixir
   venue = %{
     start_time: ~T[18:30:00],
     entry_fee_cents: 600,
     country: %{code: "DE"}
   }

   PublicEvent.format_time(venue.start_time, venue.country)
   # Expected: "18:30" (24-hour format)

   PublicEvent.format_entry_fee(venue.entry_fee_cents, "EUR")
   # Expected: "6,00 €" (German formatting)
   ```

## Implementation Checklist

- [ ] **Phase 1:** Add dependencies to `mix.exs`
- [ ] **Phase 1:** Run `mix deps.get`
- [ ] **Phase 2:** Create `localization_helpers.ex` (port from 2024)
- [ ] **Phase 3:** Create `currency_helpers.ex` (port from 2024)
- [ ] **Phase 4:** Update `PublicEvent.format_entry_fee/2` signature
- [ ] **Phase 4:** Update `PublicEvent.format_time/2` implementation
- [ ] **Phase 5:** Update `VenueCard` component to pass country data
- [ ] **Phase 5:** Add helper functions to VenueCard for country/currency resolution
- [ ] **Phase 6:** Verify country association is preloaded in queries
- [ ] **Phase 7:** Test UK venues (12-hour time, £ symbol)
- [ ] **Phase 7:** Test US venues (12-hour time, $ symbol)
- [ ] **Phase 7:** Test Australian venues (12-hour time, A$ symbol)
- [ ] **Phase 7:** Test German venues (24-hour time, € symbol)
- [ ] **Phase 7:** Test edge cases (nil values, free events, missing country data)

## Expected Results

After migration:

**UK Venue Display:**
```
🇬🇧 The Dog & Duck
📍 London, United Kingdom
⏰ Wednesday, 6:30 PM
💷 £5.00
```

**US Venue Display:**
```
🇺🇸 O'Malley's Pub
📍 Boston, United States
⏰ Wednesday, 7:00 PM
💵 $10.00
```

**German Venue Display:**
```
🇩🇪 Das Bierhaus
📍 Munich, Germany
⏰ Mittwoch, 18:30
💶 6,00 €
```

## Technical Notes

### Why This Approach?

1. **Proven Solution:** The 2024 project has been in production with this working correctly
2. **Library-Based:** Uses mature libraries (Money, Countries, CLDR) instead of manual formatting
3. **Intelligent Defaults:** Uses country metadata to automatically determine formatting rules
4. **Extensible:** Easy to add new countries/currencies without code changes
5. **Localization-Ready:** CLDR integration provides proper locale-based formatting

### Key Design Decisions

1. **Countries Library for Mapping:**
   - Maps country codes to currency codes automatically
   - Provides timezone and language metadata
   - Handles edge cases and special territories

2. **Money Library for Currency:**
   - Proper decimal handling (avoids floating point errors)
   - Supports 150+ currencies with correct symbols
   - Handles currency formatting rules per locale

3. **CLDR for Time Formatting:**
   - Industry-standard localization data
   - Supports 12-hour vs 24-hour preferences by region
   - Proper AM/PM formatting and translations

4. **Smart Format Detection:**
   - English-speaking countries → 12-hour format
   - Commonwealth countries → 12-hour format
   - North America (except Mexico) → 12-hour format
   - Rest of world → 24-hour format

### Migration Complexity

**Estimated Effort:** 4-6 hours
- Phase 1: 15 minutes (dependencies)
- Phase 2: 1 hour (port LocalizationHelpers)
- Phase 3: 30 minutes (port CurrencyHelpers)
- Phase 4: 30 minutes (update PublicEvent)
- Phase 5: 1 hour (update VenueCard and queries)
- Phase 6: 15 minutes (verify queries)
- Phase 7: 1.5 hours (comprehensive testing)

**Risk Level:** Low
- Using proven code from 2024 project
- Libraries are stable and well-maintained
- Fallback mechanisms prevent display errors

## References

### 2024 Project Files to Reference

1. **LocalizationHelpers:**
   - `/Users/holdenthomas/Code/paid-projects-2024/trivia_advisor/lib/trivia_advisor_web/helpers/localization_helpers.ex`
   - Complete implementation with CLDR integration

2. **CurrencyHelpers:**
   - `/Users/holdenthomas/Code/paid-projects-2024/trivia_advisor/lib/trivia_advisor_web/helpers/currency_helpers.ex`
   - Lines 22-28: `format_currency/2`
   - Lines 43-58: `get_country_currency/1`

3. **VenueCard Implementation:**
   - `/Users/holdenthomas/Code/paid-projects-2024/trivia_advisor/lib/trivia_advisor_web/components/ui/venue_card.ex`
   - Lines 264-291: Currency formatting in component
   - Lines 403-407: Time formatting in component

4. **Dependencies:**
   - `/Users/holdenthomas/Code/paid-projects-2024/trivia_advisor/mix.exs`
   - Lines with `:countries`, `:money`, `:ex_cldr*` dependencies

### Library Documentation

- **Money:** https://hexdocs.pm/money/readme.html
- **Countries:** https://hexdocs.pm/countries/readme.html
- **ex_cldr:** https://hexdocs.pm/ex_cldr/readme.html
- **ex_cldr_dates_times:** https://hexdocs.pm/ex_cldr_dates_times/readme.html

---

**Issue Status:** 📋 Ready for Implementation
**Priority:** 🔴 High (User-facing localization bug)
**Complexity:** 🟡 Medium (Port existing solution)
**Estimated Time:** ⏱️ 4-6 hours
