# Search Functionality Implementation - Two-Phase Approach

## Overview

Implement complete city search functionality matching production QuizAdvisor.com behavior. Currently, the homepage search form exists but doesn't filter results, making it non-functional.

**Reference URLs:**
- Production: https://quizadvisor.com/
- Current Dev: http://localhost:4003/

---

## Current State (Broken)

### What Exists Now

**Homepage (`lib/trivia_advisor_web/live/home_live.ex`):**

**Lines 88-104 - Search Form:**
```elixir
<!-- Search Form -->
<div class="max-w-2xl mx-auto mt-8">
  <form phx-submit="search" class="flex gap-2">
    <input
      type="text"
      name="city_search"
      placeholder="Search for a city..."
      class="flex-1 px-4 py-3 rounded-lg bg-white border border-gray-300 text-gray-900 placeholder:text-gray-500 shadow-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
    />
    <button type="submit" class="px-6 py-3 bg-white text-blue-600 font-semibold rounded-lg hover:bg-gray-100 transition-colors">
      Search
    </button>
  </form>
</div>
```

**Lines 167-171 - Search Handler:**
```elixir
@impl true
def handle_event("search", %{"city_search" => query}, socket) do
  # Redirect to cities page with search query parameter
  {:noreply, push_navigate(socket, to: ~p"/cities?search=#{query}")}
end
```

**Problem**: Form submits and navigates to `/cities?search={query}`, but cities page ignores the parameter.

---

**Cities Index (`lib/trivia_advisor_web/live/cities_index_live.ex`):**

**Line 13 - Mount Function:**
```elixir
def mount(_params, _session, socket) do
  countries = Locations.list_countries()
  # ... rest of mount logic
end
```

**Problem**: `_params` is ignored - search parameter never used. Always shows ALL cities regardless of search query.

---

### User Experience Issues

1. **No Filtering**: User types "London" → navigates to /cities?search=London → shows ALL cities (not just London)
2. **No Autocomplete**: No dropdown suggestions while typing
3. **No Direct Navigation**: Can't click a suggestion to go directly to city page
4. **Performance**: Cities page has severe performance issues (hundreds of COUNT queries causing timeouts)

---

## Production QuizAdvisor Analysis

### Phase 2 Behavior (Autocomplete) ✅ Working in Production

**Test Case**: Type "Lon" in search field

**Observed Behavior**:
1. Dropdown appears immediately showing matching cities:
   - Athlone (Ireland)
   - East Longmeadow (United States)
   - Geelong (Australia)
   - **London** (United Kingdom)
   - London Colney (United Kingdom)
2. Each suggestion shows city name and country
3. Clicking "London" navigates directly to `/cities/london`
4. City page loads successfully with 386 venues

**Implementation**: Production uses real-time autocomplete with LiveView to show dropdown suggestions and enable direct navigation.

---

### Phase 1 Behavior (Fallback Search) ⚠️ Unclear in Production

**Test Case**: Type "asdfzxcv" (gibberish) and press Enter

**Observed Behavior**:
- Navigates to `/?query=asdfzxcv` (homepage with query param)
- Shows regular homepage content (no filtering, no "no results" message)

**Expected Behavior**: Should navigate to `/cities` page and show filtered results (or "No cities found" message)

**Note**: Production fallback behavior differs from user requirements. User wants Phase 1 to filter on /cities page.

---

## Implementation Requirements

### PHASE 1: Fallback Search with Filtering (Priority 1)

When user types text (including gibberish) and presses Enter, the cities index page should filter results.

#### 1.1 - Add Search Function to Locations Context

**File**: `lib/trivia_advisor/locations.ex`

**New Function**:
```elixir
@doc """
Search cities by name (case-insensitive partial match).
Returns all cities if query is nil or empty.

## Examples

    iex> search_cities("lon")
    [%City{name: "London", ...}, %City{name: "London Colney", ...}, %City{name: "Athlone", ...}]

    iex> search_cities("asdfzxcv")
    []
"""
def search_cities(nil), do: list_all_cities()
def search_cities(""), do: list_all_cities()

def search_cities(query) when is_binary(query) do
  search_pattern = "%#{query}%"

  Repo.all(
    from c in City,
      join: co in assoc(c, :country),
      where: ilike(c.name, ^search_pattern),
      order_by: [asc: c.name],
      preload: [:country]
  )
end

defp list_all_cities do
  Repo.all(
    from c in City,
      join: co in assoc(c, :country),
      order_by: [asc: c.name],
      preload: [:country]
  )
end
```

**Rationale**: Case-insensitive ILIKE search matches partial city names. Handles nil/empty gracefully.

---

#### 1.2 - Update CitiesIndexLive to Accept Search Parameter

**File**: `lib/trivia_advisor_web/live/cities_index_live.ex`

**Line 13 - Update mount/3:**
```elixir
# Before:
def mount(_params, _session, socket) do

# After:
def mount(params, _session, socket) do
  search_query = Map.get(params, "search")
```

**Lines 14-26 - Update Cities Fetching Logic:**
```elixir
# Before:
countries = Locations.list_countries()

# Group cities by country
cities_by_country =
  countries
  |> Enum.map(fn country ->
    cities = Locations.list_cities_for_country(country.id)
    {country, cities}
  end)
  |> Enum.filter(fn {_country, cities} -> !Enum.empty?(cities) end)
  |> Enum.sort_by(fn {country, _cities} -> country.name end)

# After:
cities =
  if search_query do
    Locations.search_cities(search_query)
  else
    # Get all cities grouped by country (existing behavior)
    countries = Locations.list_countries()
    countries
    |> Enum.flat_map(fn country ->
      Locations.list_cities_for_country(country.id)
    end)
  end

cities_by_country =
  if search_query do
    # For search results, group filtered cities by country
    cities
    |> Enum.group_by(& &1.country)
    |> Enum.map(fn {country, cities} -> {country, cities} end)
    |> Enum.sort_by(fn {country, _cities} -> country.name end)
  else
    # Original behavior for non-search
    countries = Locations.list_countries()
    countries
    |> Enum.map(fn country ->
      cities = Locations.list_cities_for_country(country.id)
      {country, cities}
    end)
    |> Enum.filter(fn {_country, cities} -> !Enum.empty?(cities) end)
    |> Enum.sort_by(fn {country, _cities} -> country.name end)
  end
```

**Line 27-31 - Update Socket Assignment:**
```elixir
socket =
  socket
  |> assign(:page_title,
    if search_query,
      do: "Search: #{search_query} | Trivia Cities",
      else: "All Trivia Cities")
  |> assign(:cities_by_country, cities_by_country)
  |> assign(:search_query, search_query)  # Add this for conditional rendering
  |> assign(:base_url, base_url)
```

---

#### 1.3 - Update Template to Show Search Results

**File**: `lib/trivia_advisor_web/live/cities_index_live.ex`

**Lines 74-82 - Update Page Header:**
```elixir
<!-- Page Header -->
<div class="bg-white border-b">
  <div class="container mx-auto px-4 py-8">
    <%= if @search_query do %>
      <h1 class="text-4xl font-bold text-gray-900 mb-2">
        Search Results for "<%= @search_query %>"
      </h1>
      <p class="text-lg text-gray-600">
        Found <%= Enum.sum(Enum.map(@cities_by_country, fn {_, cities} -> length(cities) end)) %>
        <%= if Enum.sum(Enum.map(@cities_by_country, fn {_, cities} -> length(cities) end)) == 1, do: "city", else: "cities" %>
      </p>
    <% else %>
      <h1 class="text-4xl font-bold text-gray-900 mb-2">
        All Trivia Cities
      </h1>
      <p class="text-lg text-gray-600">
        Browse <%= Enum.sum(Enum.map(@cities_by_country, fn {_, cities} -> length(cities) end)) %> cities
        across <%= length(@cities_by_country) %> countries hosting trivia events
      </p>
    <% end %>
  </div>
</div>
```

**After Line 83 - Add "No Results" Message:**
```elixir
<!-- No Results Message -->
<%= if @search_query && Enum.empty?(@cities_by_country) do %>
  <div class="container mx-auto px-4 py-12 text-center">
    <div class="max-w-md mx-auto">
      <svg class="w-24 h-24 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
      </svg>
      <h2 class="text-2xl font-semibold text-gray-900 mb-2">No cities found</h2>
      <p class="text-gray-600 mb-6">
        We couldn't find any cities matching "<%= @search_query %>"
      </p>
      <.link
        navigate="/cities"
        class="inline-block px-6 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors"
      >
        View All Cities
      </.link>
    </div>
  </div>
<% end %>
```

---

### PHASE 2: Autocomplete with Direct Navigation (Priority 2)

Implement real-time autocomplete dropdown with LiveView.

#### 2.1 - Create Autocomplete Component

**New File**: `lib/trivia_advisor_web/live/components/city_autocomplete.ex`

**Implementation**:
```elixir
defmodule TriviaAdvisorWeb.Components.CityAutocomplete do
  @moduledoc """
  LiveView component for city autocomplete search.
  Provides real-time search suggestions with direct navigation.
  """
  use TriviaAdvisorWeb, :live_component

  alias TriviaAdvisor.Locations

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:suggestions, [])
     |> assign(:show_dropdown, false)
     |> assign(:selected_index, -1)}
  end

  @impl true
  def handle_event("search_input", %{"value" => query}, socket) do
    suggestions =
      if String.length(query) >= 2 do
        Locations.search_cities(query)
        |> Enum.take(5)  # Limit to 5 suggestions
      else
        []
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:suggestions, suggestions)
     |> assign(:show_dropdown, !Enum.empty?(suggestions))
     |> assign(:selected_index, -1)}
  end

  @impl true
  def handle_event("select_city", %{"slug" => slug}, socket) do
    {:noreply, push_navigate(socket, to: "/cities/#{slug}")}
  end

  @impl true
  def handle_event("submit_search", %{"city_search" => query}, socket) do
    # Fallback: navigate to cities index with search parameter
    {:noreply, push_navigate(socket, to: "/cities?search=#{query}")}
  end

  @impl true
  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative" id={@id} phx-click-away="close_dropdown" phx-target={@myself}>
      <form phx-submit="submit_search" phx-target={@myself} class="flex gap-2">
        <input
          type="text"
          name="city_search"
          value={@search_query}
          placeholder="Search for a city..."
          phx-change="search_input"
          phx-debounce="300"
          phx-target={@myself}
          class="flex-1 px-4 py-3 rounded-lg bg-white border border-gray-300 text-gray-900 placeholder:text-gray-500 shadow-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          autocomplete="off"
        />
        <button
          type="submit"
          class="px-6 py-3 bg-white text-blue-600 font-semibold rounded-lg hover:bg-gray-100 transition-colors"
        >
          Search
        </button>
      </form>

      <!-- Dropdown Suggestions -->
      <%= if @show_dropdown do %>
        <div class="absolute z-50 w-full mt-2 bg-white rounded-lg shadow-xl border border-gray-200 max-h-96 overflow-y-auto">
          <%= for {city, index} <- Enum.with_index(@suggestions) do %>
            <button
              type="button"
              phx-click="select_city"
              phx-value-slug={Locations.city_url_slug(city)}
              phx-target={@myself}
              class={"px-4 py-3 w-full text-left hover:bg-blue-50 transition-colors border-b border-gray-100 last:border-b-0 #{if index == @selected_index, do: "bg-blue-50", else: ""}"}
            >
              <p class="font-semibold text-gray-900"><%= city.name %></p>
              <p class="text-sm text-gray-600"><%= city.country.name %></p>
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
```

**Features**:
- Real-time search with 300ms debounce
- Dropdown appears when 2+ characters typed
- Shows max 5 suggestions with city name and country
- Click suggestion → direct navigation to `/cities/{slug}`
- Press Enter → fallback to /cities?search={query} (Phase 1)
- Click-away closes dropdown
- Keyboard navigation ready (can be enhanced)

---

#### 2.2 - Update HomePage to Use Autocomplete Component

**File**: `lib/trivia_advisor_web/live/home_live.ex`

**Replace Lines 88-104 (old search form):**
```elixir
<!-- Search with Autocomplete -->
<div class="max-w-2xl mx-auto mt-8">
  <.live_component
    module={TriviaAdvisorWeb.Components.CityAutocomplete}
    id="city-search-autocomplete"
  />
</div>
```

**Remove Lines 167-171 (old search handler)** - Now handled by component

---

## Testing Strategy

### Phase 1 Testing

**Test Case 1: Valid City Search**
- Input: "Lon" → Press Enter
- Expected: Navigate to /cities?search=Lon
- Expected: Show London, London Colney, Athlone (any city containing "lon")
- Expected: Page header shows "Search Results for 'Lon'"

**Test Case 2: Gibberish Search**
- Input: "asdfzxcv" → Press Enter
- Expected: Navigate to /cities?search=asdfzxcv
- Expected: Show "No cities found" message with button to view all cities

**Test Case 3: Empty Search**
- Input: "" (empty) → Press Enter
- Expected: Navigate to /cities
- Expected: Show all cities grouped by country (original behavior)

**Test Case 4: Case Sensitivity**
- Input: "LONDON" → Press Enter
- Expected: Match "London" (case-insensitive)

---

### Phase 2 Testing

**Test Case 1: Autocomplete Dropdown**
- Input: Type "Lon"
- Expected: Dropdown appears with matching cities (London, London Colney, Athlone, etc.)
- Expected: Each suggestion shows city name and country

**Test Case 2: Direct Navigation**
- Input: Type "Lon" → Click "London" suggestion
- Expected: Navigate directly to `/cities/london`
- Expected: London city page loads with venues

**Test Case 3: Debouncing**
- Input: Type "L" (pause) "o" (pause) "n"
- Expected: Only one search request after 300ms of no typing

**Test Case 4: Dropdown Close**
- Input: Type "Lon" → Click outside dropdown
- Expected: Dropdown closes

**Test Case 5: Fallback Behavior**
- Input: Type "Lon" → Press Enter (don't click suggestion)
- Expected: Navigate to /cities?search=Lon (Phase 1 behavior)

**Test Case 6: Mobile Responsiveness**
- Test: Open on mobile device
- Expected: Dropdown appears below search field without overflow issues

---

## Acceptance Criteria

### Phase 1 (Must Have)
- ✅ Typing "London" and pressing Enter navigates to /cities?search=London
- ✅ Cities index page filters results to show only matching cities
- ✅ Gibberish search shows "No cities found" message
- ✅ Empty search shows all cities (original behavior)
- ✅ Search is case-insensitive (LONDON matches London)
- ✅ Page title updates to show search query
- ✅ Search results show count ("Found 3 cities")

### Phase 2 (Should Have)
- ✅ Typing in search field shows real-time dropdown suggestions
- ✅ Dropdown shows max 5 suggestions with city name and country
- ✅ Clicking suggestion navigates directly to city page
- ✅ Search is debounced (300ms) to reduce DB queries
- ✅ Dropdown closes when clicking outside
- ✅ Pressing Enter with text triggers fallback (Phase 1)
- ✅ Works on mobile devices without UI issues

### Nice to Have
- ⚪ Keyboard navigation (arrow keys to select, Enter to navigate)
- ⚪ Escape key closes dropdown
- ⚪ Loading indicator while fetching suggestions
- ⚪ Highlight matching text in suggestions
- ⚪ Recently searched cities (local storage)

---

## Files to Modify

### Phase 1
1. **`lib/trivia_advisor/locations.ex`**
   - Add `search_cities/1` function
   - Add `list_all_cities/0` private function

2. **`lib/trivia_advisor_web/live/cities_index_live.ex`**
   - Line 13: Change `_params` to `params` in mount/3
   - Lines 14-31: Add search logic with conditional city fetching
   - Lines 74-82: Update page header for search context
   - After line 83: Add "No results" message

### Phase 2
3. **`lib/trivia_advisor_web/live/components/city_autocomplete.ex`** (NEW FILE)
   - Create autocomplete component with dropdown

4. **`lib/trivia_advisor_web/live/home_live.ex`**
   - Lines 88-104: Replace old form with live_component
   - Lines 167-171: Remove old search handler

---

## Implementation Priority

**Recommended Order:**
1. Implement Phase 1 first (2-3 hours)
   - Provides baseline functional search
   - Simpler implementation
   - Immediate value to users

2. Enhance with Phase 2 (3-4 hours)
   - Better UX with real-time feedback
   - Matches production QuizAdvisor behavior
   - Reduces friction for users

**Total Effort**: 5-7 hours for complete implementation

---

## Known Issues to Address

### Performance Issue
The cities index page has severe performance problems with hundreds of COUNT queries:
```
[debug] QUERY OK source="cities" db=213.8ms idle=1797.6ms
SELECT count(c0."id") FROM "cities"...
```

**Recommendation**: Investigate and optimize COUNT queries before implementing search. Search will exacerbate existing performance issues.

### Production Discrepancy
Production QuizAdvisor's fallback behavior (navigating to /?query={query}) differs from requirements. User wants /cities page filtering. This implementation follows user requirements, not production behavior.

---

## References

- **Production Site**: https://quizadvisor.com/
- **Playwright Test Screenshots**:
  - `.playwright-mcp/production-autocomplete-london.png` - Working autocomplete
  - `.playwright-mcp/production-fallback-search-gibberish.png` - Fallback behavior
- **Current Implementation**: `lib/trivia_advisor_web/live/home_live.ex:88-104, 167-171`
- **Cities Index**: `lib/trivia_advisor_web/live/cities_index_live.ex`
- **Locations Context**: `lib/trivia_advisor/locations.ex`
