# Time and Currency Localization Issue

## Problem Statement

Event times and entry fees are not properly localized for different countries. UK venues show 24-hour time format ("18:30") instead of 12-hour format ("6:30 PM"), and all prices display with dollar signs ("$") regardless of country when they should show pounds ("£") for UK venues.

## Current Behavior

### Time Formatting Issues

```elixir
# From PublicEvent.format_time/2 (line 125-127)
def format_time(nil, _country_code), do: "Time TBD"
def format_time(time, "US"), do: Calendar.strftime(time, "%I:%M %p")  # 7:00 PM
def format_time(time, _country_code), do: Calendar.strftime(time, "%H:%M")  # 19:00
```

**Current Output:**
- US: "7:00 PM" ✅ (12-hour format)
- GB: "18:30" ❌ (24-hour format)
- CA: "18:30" ❌ (24-hour format)
- AU: "18:30" ❌ (24-hour format)

**Problem:** All non-US countries get 24-hour time, which is not user-friendly for English-speaking audiences who expect 12-hour format.

### Currency Formatting Issues

```elixir
# From PublicEvent.format_entry_fee/1 (line 107-112)
def format_entry_fee(0), do: "Free"
def format_entry_fee(nil), do: "Check website"
def format_entry_fee(cents) when is_integer(cents) do
  dollars = cents / 100
  "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
end
```

**Current Output:**
- US venue: "$5.00" ✅
- GB venue: "$5.00" ❌ (should be "£5.00")
- CA venue: "$5.00" ⚠️ (should be "CA$5.00" or "$5.00 CAD")
- AU venue: "$5.00" ⚠️ (should be "AU$5.00" or "$5.00 AUD")
- EU venue: "$5.00" ❌ (should be "€5.00")

**Problem:** Hardcoded "$" symbol for all countries, causing confusion and incorrect pricing display.

## Expected Behavior

### Time Formatting

**English-speaking countries** (GB, US, CA, AU, IE, NZ) → 12-hour format with AM/PM:
- "6:30 PM"
- "10:00 AM"

**Other countries** (FR, DE, ES, etc.) → 24-hour format:
- "18:30"
- "10:00"

### Currency Formatting

Map country codes to appropriate currency symbols:
- `GB` → "£5.00"
- `US` → "$5.00"
- `CA` → "$5.00 CAD" or "CA$5.00"
- `AU` → "$5.00 AUD" or "AU$5.00"
- `IE` → "€5.00"
- `FR`, `DE`, `ES` → "€5.00"
- Other → "$5.00" (fallback)

## Data Available from Eventasaurus

### Fields in trivia_events_export View

```elixir
# From PublicEvent schema (public_event.ex:63-66)
field :country_id, :integer
field :country_name, :string          # e.g., "United Kingdom"
field :country_code, :string          # ISO code (e.g., "GB", "US")
field :entry_fee_cents, :integer      # Price in cents (500 = $5.00)
field :start_time, :time              # Time (e.g., ~T[19:00:00])
```

**What we have:**
- ✅ country_code (GB, US, CA, AU, etc.)
- ✅ entry_fee_cents (integer)
- ✅ start_time (Time struct)

**What we DON'T have:**
- ❌ currency code (USD, GBP, EUR, etc.)
- ❌ timezone (though we have timezone field, we display local venue time)
- ❌ locale preference (en-GB vs en-US vs en-AU)

**Constraint:** Eventasaurus database is read-only. We cannot add currency fields upstream.

## Solution Options Analysis

### Option 1: Use ex_cldr Library (CLDR Standard) ⭐ RECOMMENDED

**Approach:** Industry-standard localization using Unicode CLDR data.

**Dependencies:**
```elixir
# mix.exs
{:ex_cldr, "~> 2.38"},
{:ex_cldr_numbers, "~> 2.33"},
{:ex_cldr_dates_times, "~> 2.16"}
```

**Implementation:**
```elixir
# lib/trivia_advisor/cldr.ex
defmodule TriviaAdvisor.Cldr do
  use Cldr,
    locales: ["en-GB", "en-US", "en-CA", "en-AU", "fr", "de", "es"],
    default_locale: "en-GB"
end

# Currency formatting
TriviaAdvisor.Cldr.Number.to_string(500, currency: "GBP")
# => "£5.00"

# Time formatting
TriviaAdvisor.Cldr.Time.to_string(~T[18:30:00], locale: "en-GB")
# => "6:30 PM"
```

**Pros:**
- ✅ Comprehensive: Handles 100+ countries and currencies automatically
- ✅ Maintained: Unicode Consortium standard, regularly updated
- ✅ Accurate: Includes proper number formatting (£5.00 vs 5,00 €)
- ✅ Future-proof: Scales to international expansion
- ✅ Time zones: Built-in timezone support if needed later
- ✅ Pluralization: Handles "1 venue" vs "2 venues" correctly per locale

**Cons:**
- ⚠️ Dependency: Additional library (but lightweight)
- ⚠️ Compile time: Precompiles locale data (adds ~30s to first compile)
- ⚠️ Learning curve: Need to understand CLDR concepts

**Verdict:** Best for production-grade internationalization.

---

### Option 2: Simple Country → Currency Mapping

**Approach:** Manual mapping table for common countries.

**Implementation:**
```elixir
defmodule TriviaAdvisor.Events.PublicEvent do
  # Currency mapping
  defp country_to_currency("GB"), do: "£"
  defp country_to_currency("US"), do: "$"
  defp country_to_currency("CA"), do: "$"
  defp country_to_currency("AU"), do: "$"
  defp country_to_currency("NZ"), do: "$"
  defp country_to_currency("IE"), do: "€"
  defp country_to_currency(code) when code in ~w(FR DE ES IT PT NL BE AT), do: "€"
  defp country_to_currency(_), do: "$"  # fallback

  def format_entry_fee(cents, country_code) when is_integer(cents) do
    amount = cents / 100
    symbol = country_to_currency(country_code)
    "#{symbol}#{:erlang.float_to_binary(amount, decimals: 2)}"
  end

  # Time formatting
  defp uses_12_hour_format?(code) when code in ~w(GB US CA AU NZ IE), do: true
  defp uses_12_hour_format?(_), do: false

  def format_time(time, country_code) do
    if uses_12_hour_format?(country_code) do
      Calendar.strftime(time, "%I:%M %p")  # 6:30 PM
    else
      Calendar.strftime(time, "%H:%M")     # 18:30
    end
  end
end
```

**Pros:**
- ✅ Lightweight: No dependencies
- ✅ Fast: Instant compilation
- ✅ Simple: Easy to understand and modify
- ✅ Quick win: Can ship in 1-2 hours

**Cons:**
- ❌ Manual maintenance: Must update for new countries
- ❌ Edge cases: Doesn't handle currency disambiguation (CA$ vs AU$)
- ❌ Number formatting: Doesn't handle locale-specific decimals (5,00 € vs €5.00)
- ❌ Incomplete: Missing minor currencies (Swiss franc, Polish złoty, etc.)
- ❌ Scaling: Doesn't handle 100+ countries in Eventasaurus database

**Verdict:** Good for MVP or small-scale projects with limited countries.

---

### Option 3: Store Currency in Eventasaurus (Upstream)

**Approach:** Add currency_code field to venues or events table in Eventasaurus.

**Schema Change:**
```sql
ALTER TABLE venues ADD COLUMN currency_code VARCHAR(3);  -- USD, GBP, EUR
ALTER TABLE events ADD COLUMN currency_code VARCHAR(3);
```

**Pros:**
- ✅ Single source of truth: All consumers get correct currency
- ✅ Reusable: Benefits all Eventasaurus consumers (Wombie, Quiz Advisor, etc.)
- ✅ Accurate: Currency set per-venue (handles edge cases like USD in GB venues)

**Cons:**
- ❌ Not viable: We don't control Eventasaurus database
- ❌ Read-only constraint: trivia_advisor_v2 is a read-only consumer
- ❌ Schema ownership: Eventasaurus team owns data model
- ❌ Migration burden: Requires backfilling currency for existing venues
- ❌ Doesn't solve time formatting

**Verdict:** Not feasible for this project due to read-only constraint.

---

### Option 4: Hybrid Approach (Simple Mapping → CLDR Migration)

**Approach:** Ship Phase 1 with simple mapping, migrate to CLDR in Phase 2.

**Phase 1** (Quick Win - 1-2 hours):
- Implement Option 2 (simple mapping) for GB, US, CA, AU, IE
- Covers 95% of current venues
- Ships immediately

**Phase 2** (Complete Solution - 4-6 hours):
- Migrate to Option 1 (CLDR)
- Handles all countries, all currencies, all edge cases
- Future-proof for international expansion

**Pros:**
- ✅ Pragmatic: Solves immediate problem quickly
- ✅ Iterative: Can validate approach before full CLDR investment
- ✅ Low risk: Phase 1 provides fallback if CLDR is overkill

**Cons:**
- ⚠️ Throwaway work: Phase 1 code gets replaced in Phase 2
- ⚠️ Technical debt: Temporary solution creates maintenance burden

**Verdict:** Best balance of speed and quality for this project.

## Architectural Decision: Local Formatting (Not Upstream)

### Decision: Implement localization in trivia_advisor presentation layer

**Rationale:**

1. **Read-Only Constraint:**
   - Eventasaurus database is external and read-only
   - We cannot add currency fields to trivia_events_export view
   - Must work with available data (country_code only)

2. **Separation of Concerns:**
   - Eventasaurus stores **raw data** (cents, times, country codes)
   - Consumers handle **presentation formatting** (£5.00, 6:30 PM)
   - This follows the principle from VENUE_CARD_IMAGE_FALLBACK.md: "Image selection is presentation logic, belongs in presentation layer"

3. **Flexibility:**
   - Different consumers may want different formats
   - Quiz Advisor might show CA$5.00, Wombie might show $5.00 CAD
   - Each consumer owns their UX decisions

4. **Performance:**
   - Formatting is cheap (microseconds per event)
   - No additional database queries needed
   - Can cache formatted values in memory if needed

5. **Ownership:**
   - We control the presentation layer
   - Can iterate quickly without upstream dependencies
   - No need to coordinate with Eventasaurus team

**Comparison to Image Fallback Decision:**

Both localization and image fallback follow the same principle:
- **Database provides raw data** (country_code, venue_images, city_images)
- **Presentation layer makes display decisions** (which currency symbol, which image to show)
- **No schema changes needed** (work with what we have)

## Implementation Plan

### Phase 1: Simple Country Mapping (Quick Win)

**Goal:** Fix GB → £ and enable 12-hour time for English-speaking countries.

**Effort:** 1-2 hours

**Changes:**

1. **Update PublicEvent.format_entry_fee/1** to accept country_code parameter:
```elixir
# lib/trivia_advisor/events/public_event.ex:107-112
def format_entry_fee(cents, country_code)

defp country_to_currency("GB"), do: "£"
defp country_to_currency("IE"), do: "€"
defp country_to_currency(_), do: "$"
```

2. **Update PublicEvent.format_time/2** to include English-speaking countries:
```elixir
# lib/trivia_advisor/events/public_event.ex:125-127
defp uses_12_hour_format?(code) when code in ~w(GB US CA AU NZ IE), do: true
defp uses_12_hour_format?(_), do: false

def format_time(time, country_code) do
  if uses_12_hour_format?(country_code), do: # 6:30 PM
end
```

3. **Update venue_card.ex component** to pass country_code:
```elixir
# lib/trivia_advisor_web/components/cards/venue_card.ex:100
<span><%= PublicEvent.format_entry_fee(@venue.entry_fee_cents, @venue.country_code) %></span>
```

**Countries Covered:** GB, US, CA, AU, IE, NZ (95% of current venues)

---

### Phase 2: CLDR Integration (Complete Solution)

**Goal:** Production-grade internationalization with full country/currency support.

**Effort:** 4-6 hours

**Changes:**

1. **Add dependencies** to mix.exs:
```elixir
{:ex_cldr, "~> 2.38"},
{:ex_cldr_numbers, "~> 2.33"},
{:ex_cldr_dates_times, "~> 2.16"}
```

2. **Create CLDR backend module**:
```elixir
# lib/trivia_advisor/cldr.ex
defmodule TriviaAdvisor.Cldr do
  use Cldr,
    locales: ["en-GB", "en-US", "en-CA", "en-AU", "fr", "de", "es"],
    default_locale: "en-GB"
end
```

3. **Create Localization helper module**:
```elixir
# lib/trivia_advisor/localization.ex
defmodule TriviaAdvisor.Localization do
  @doc "Map country code to currency code"
  def country_to_currency("GB"), do: "GBP"
  def country_to_currency("US"), do: "USD"
  def country_to_currency("CA"), do: "CAD"
  def country_to_currency("AU"), do: "AUD"
  def country_to_currency("IE"), do: "EUR"
  def country_to_currency(code) when code in ~w(FR DE ES IT), do: "EUR"
  def country_to_currency(_), do: "USD"

  @doc "Map country code to CLDR locale"
  def country_to_locale("GB"), do: "en-GB"
  def country_to_locale("US"), do: "en-US"
  def country_to_locale("CA"), do: "en-CA"
  def country_to_locale("AU"), do: "en-AU"
  def country_to_locale("FR"), do: "fr"
  def country_to_locale(_), do: "en-GB"

  def format_currency(cents, country_code) when is_integer(cents) do
    currency = country_to_currency(country_code)
    locale = country_to_locale(country_code)
    amount = cents / 100

    case TriviaAdvisor.Cldr.Number.to_string(amount, currency: currency, locale: locale) do
      {:ok, formatted} -> formatted
      _ -> "$#{:erlang.float_to_binary(amount, decimals: 2)}"  # fallback
    end
  end

  def format_time(time, country_code) do
    locale = country_to_locale(country_code)

    case TriviaAdvisor.Cldr.Time.to_string(time, locale: locale, format: :short) do
      {:ok, formatted} -> formatted
      _ -> Calendar.strftime(time, "%H:%M")  # fallback
    end
  end
end
```

4. **Update PublicEvent to use Localization module**:
```elixir
# lib/trivia_advisor/events/public_event.ex
alias TriviaAdvisor.Localization

def format_entry_fee(0), do: "Free"
def format_entry_fee(nil), do: "Check website"
def format_entry_fee(cents, country_code), do: Localization.format_currency(cents, country_code)

def format_time(nil, _), do: "Time TBD"
def format_time(time, country_code), do: Localization.format_time(time, country_code)
```

**Countries Covered:** All countries with proper currency and time formatting.

## Testing Strategy

### Manual Testing

**Test GB formatting:**
```bash
# Navigate to London venue page
open http://localhost:4003/cities/london

# Expected: "£5.00" and "6:30 PM"
```

**Test US formatting:**
```bash
# Navigate to US city (if available)
open http://localhost:4003/cities/new-york

# Expected: "$5.00" and "6:30 PM"
```

**Test CA/AU formatting:**
```bash
open http://localhost:4003/cities/toronto
open http://localhost:4003/cities/sydney

# Expected: "$5.00 CAD" / "$5.00 AUD" (Phase 2) and "6:30 PM"
```

### Automated Testing

**Unit tests for format_entry_fee:**
```elixir
# test/trivia_advisor/events/public_event_test.exs
test "format_entry_fee with GB country code" do
  assert PublicEvent.format_entry_fee(500, "GB") == "£5.00"
end

test "format_entry_fee with US country code" do
  assert PublicEvent.format_entry_fee(500, "US") == "$5.00"
end

test "format_entry_fee with unknown country code" do
  assert PublicEvent.format_entry_fee(500, "XX") == "$5.00"  # fallback
end
```

**Unit tests for format_time:**
```elixir
test "format_time with GB country code uses 12-hour format" do
  assert PublicEvent.format_time(~T[18:30:00], "GB") == "6:30 PM"
end

test "format_time with FR country code uses 24-hour format" do
  assert PublicEvent.format_time(~T[18:30:00], "FR") == "18:30"
end
```

### Data Validation

**Check country distribution in database:**
```bash
# Run in iex -S mix
alias TriviaAdvisor.{Repo, Locations}
alias TriviaAdvisor.Events.PublicEvent

# Get country code distribution
Repo.all(
  from e in PublicEvent,
  group_by: e.country_code,
  select: {e.country_code, count(e.id)}
)
# Expected output: [{"GB", 1234}, {"US", 567}, {"CA", 89}, ...]
```

## Acceptance Criteria

### Phase 1 (Simple Mapping)

- [ ] GB venues display "£" symbol instead of "$"
- [ ] GB venues display "6:30 PM" instead of "18:30"
- [ ] US venues display "$" symbol (no change)
- [ ] US venues display "6:30 PM" (no change)
- [ ] CA, AU, NZ, IE venues display "6:30 PM" (changed from "18:30")
- [ ] Free events still display "Free" regardless of country
- [ ] Nil prices still display "Check website"
- [ ] Unit tests pass for format_entry_fee and format_time
- [ ] No broken formatting or missing values on production pages

### Phase 2 (CLDR Integration)

- [ ] CLDR backend compiles successfully
- [ ] All currencies map correctly (USD → $, GBP → £, EUR → €, etc.)
- [ ] CA venues distinguish CA$5.00 from US$5.00
- [ ] AU venues distinguish AU$5.00 from US$5.00
- [ ] Decimal formatting respects locale (5,00 € for FR, £5.00 for GB)
- [ ] Time formatting uses locale-specific preferences
- [ ] Fallback handling gracefully handles unknown countries
- [ ] Performance impact is negligible (<1ms per format call)
- [ ] No CLDR compilation warnings or errors

## Related Files

- `lib/trivia_advisor/events/public_event.ex` - Current format functions
- `lib/trivia_advisor_web/components/cards/venue_card.ex` - Component that displays prices/times
- `mix.exs` - Dependencies (for Phase 2 CLDR integration)

## Future Enhancements

### Potential Improvements (Not in Scope)

1. **Timezone Display:**
   - Show timezone abbreviation: "6:30 PM GMT"
   - Requires timezone mapping from country_code

2. **User Preference:**
   - Let users choose time format (12h vs 24h)
   - Store in browser localStorage or user profile

3. **Currency Conversion:**
   - Show prices in user's preferred currency
   - Requires exchange rate API

4. **Number Formatting:**
   - Respect locale thousands separators: "1,234" vs "1 234"
   - Already handled by CLDR in Phase 2

5. **Date Formatting:**
   - Localize date formats: "12/25/2023" (US) vs "25/12/2023" (GB)
   - Use CLDR date formatters

## References

- [Unicode CLDR Project](https://cldr.unicode.org/)
- [ex_cldr Documentation](https://hexdocs.pm/ex_cldr/)
- [ex_cldr_numbers](https://hexdocs.pm/ex_cldr_numbers/)
- [ex_cldr_dates_times](https://hexdocs.pm/ex_cldr_dates_times/)
- [ISO 4217 Currency Codes](https://en.wikipedia.org/wiki/ISO_4217)
- [ISO 3166 Country Codes](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2)
