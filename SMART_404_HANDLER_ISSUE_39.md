# Smart 404 Handler for Missing Venue Pages

## 🎯 Overview

Implement intelligent 404 handling for venue pages that uses fuzzy matching to either auto-redirect users to the correct venue (high confidence) or show relevant suggestions (medium confidence), improving user experience and SEO for the 790 missing V1 venue URLs (15% of total venues).

**Priority**: High
**Type**: Feature Enhancement
**Impact**: SEO, User Experience, Conversion Rate

---

## 📊 Problem Statement

### Current Situation

Based on sitemap analysis (Issue #37):
- **790 venue URLs from V1 will return 404 in V2** (15% of venues)
- These include:
  - 385 venues with numeric ID suffixes (merged duplicates)
  - 813 event-specific venues (temporary events)
  - 200-400 closed/removed venues

### Current Behavior

```
User visits: /venues/albion-hotel-1759813035
↓
V2 returns: Generic 404 error
↓
User experience: Dead end, likely bounces
```

### Business Impact

**Without smart 404s**:
- Lost traffic from 790 historical URLs
- Higher bounce rates
- Lost SEO link equity
- Poor user experience
- No data on what users are looking for

**With smart 404s**:
- 301 redirects preserve link equity
- Reduced bounce rates
- Improved user satisfaction
- Analytics data on missing content
- Graceful degradation

---

## 🎯 Proposed Solution

### Smart 404 Decision Tree

```
User requests: /venues/{missing-slug}
         ↓
Does venue exist in database?
         ↓ No
Extract and normalize slug
         ↓
Fuzzy match against existing venues
         ↓
┌────────────────────────────────────┐
│  Confidence ≥90% + Single Match?   │
│              ↓ Yes                 │
│     301 Redirect to venue          │
└────────────────────────────────────┘
         ↓ No
┌────────────────────────────────────┐
│  Confidence ≥70% + Multiple Matches│
│              ↓ Yes                 │
│   Show "Did you mean?" page        │
│   (Custom 404 with suggestions)    │
└────────────────────────────────────┘
         ↓ No
┌────────────────────────────────────┐
│  Confidence <70% or No Matches     │
│              ↓                     │
│     Standard 404 error page        │
└────────────────────────────────────┘
```

### Response Types

| Scenario | Confidence | Matches | HTTP Status | Response |
|----------|-----------|---------|-------------|----------|
| **High confidence single match** | ≥90% | 1 | 301 | Auto-redirect to correct venue |
| **Medium confidence multiple** | 70-89% | 2-5 | 404 | Custom 404 with suggestions |
| **Low confidence** | 50-69% | 1+ | 404 | Custom 404 with suggestions |
| **No matches** | <50% | 0 | 404 | Standard 404 page |

---

## 🔧 Technical Implementation

### 1. Route Detection

**Identify venue-specific 404s**:

```elixir
# lib/trivia_advisor_web/router.ex
live "/venues/:venue_slug", VenueShowLive, :show do
  # In VenueShowLive.mount/3
  case Locations.get_venue_by_slug(venue_slug) do
    nil -> 
      # Delegate to smart 404 handler
      {:error, {:not_found, :venue, venue_slug}}
    venue -> 
      # Render venue page
      {:ok, assign(socket, venue: venue)}
  end
end
```

**Alternative: Fallback Controller**:

```elixir
# lib/trivia_advisor_web/fallback_controller.ex
defmodule TriviaAdvisorWeb.FallbackController do
  use TriviaAdvisorWeb, :controller

  def call(conn, {:error, {:not_found, :venue, slug}}) do
    # Delegate to VenueMatcher
    case TriviaAdvisor.VenueMatcher.find_similar(slug) do
      {:redirect, venue, confidence} when confidence >= 0.90 ->
        redirect_with_tracking(conn, venue, slug, confidence)
      
      {:suggestions, venues} ->
        render_suggestions_page(conn, slug, venues)
      
      :no_match ->
        render_standard_404(conn)
    end
  end
end
```

---

### 2. Fuzzy Matching Module

**Core matching logic**:

```elixir
# lib/trivia_advisor/venue_matcher.ex
defmodule TriviaAdvisor.VenueMatcher do
  @moduledoc """
  Intelligent fuzzy matching for venue slugs.
  Handles numeric ID suffixes, event-specific patterns, and typos.
  """

  alias TriviaAdvisor.{Repo, Locations.Venue}
  import Ecto.Query

  @doc """
  Find similar venues for a missing slug.
  Returns {:redirect, venue, confidence} or {:suggestions, venues} or :no_match
  """
  def find_similar(missing_slug) do
    missing_slug
    |> normalize_slug()
    |> query_candidates()
    |> score_candidates(missing_slug)
    |> decide_action()
  end

  # Normalization strategies
  defp normalize_slug(slug) do
    slug
    |> String.downcase()
    |> strip_numeric_suffix()
    |> strip_event_patterns()
    |> clean_special_chars()
  end

  defp strip_numeric_suffix(slug) do
    # Pattern: "albion-hotel-1759813035" → "albion-hotel"
    String.replace(slug, ~r/-\d{10}$/, "")
  end

  defp strip_event_patterns(slug) do
    # Pattern: "00s-quiz-vol-1-at-border-city-ale-house" → "border-city-ale-house"
    case Regex.run(~r/at-(.+)$/, slug) do
      [_, venue_name] -> venue_name
      nil -> slug
    end
  end

  # Query database for candidate matches
  defp query_candidates(normalized_slug) do
    # Strategy 1: Exact match on normalized slug
    exact_matches = from(v in Venue, where: v.slug == ^normalized_slug)
    
    # Strategy 2: LIKE match (starts with, contains)
    like_matches = from(v in Venue, where: like(v.slug, ^"%#{normalized_slug}%"))
    
    # Strategy 3: Similar slugs (levenshtein distance ≤3)
    # Note: May need pg_trgm extension for efficient similarity search
    similar_matches = from(v in Venue, 
      where: fragment("similarity(?, ?) > 0.5", v.slug, ^normalized_slug),
      order_by: [desc: fragment("similarity(?, ?)", v.slug, ^normalized_slug)],
      limit: 10
    )

    # Combine strategies and deduplicate
    Repo.all(exact_matches)
    |> combine_results(Repo.all(like_matches))
    |> combine_results(Repo.all(similar_matches))
    |> Enum.uniq_by(& &1.id)
  end

  # Score each candidate
  defp score_candidates(candidates, original_slug) do
    Enum.map(candidates, fn venue ->
      confidence = calculate_confidence(venue.slug, original_slug)
      {venue, confidence}
    end)
    |> Enum.sort_by(fn {_venue, conf} -> conf end, :desc)
  end

  # Confidence scoring algorithm
  defp calculate_confidence(venue_slug, original_slug) do
    # Multiple signals combined
    base_score = 0.0
    
    # 1. Exact match after normalization (+40%)
    base_score = if normalized_match?(venue_slug, original_slug), 
      do: base_score + 0.40, 
      else: base_score

    # 2. Jaro-Winkler distance (+30% weighted)
    jaro_score = String.jaro_distance(venue_slug, original_slug)
    base_score = base_score + (jaro_score * 0.30)

    # 3. Levenshtein distance (+20% weighted)
    # Lower distance = higher score
    lev_distance = String.levenshtein(venue_slug, original_slug)
    max_length = max(String.length(venue_slug), String.length(original_slug))
    lev_score = 1 - (lev_distance / max_length)
    base_score = base_score + (lev_score * 0.20)

    # 4. Common prefix bonus (+10%)
    prefix_score = common_prefix_ratio(venue_slug, original_slug)
    base_score = base_score + (prefix_score * 0.10)

    # Cap at 1.0
    min(base_score, 1.0)
  end

  # Decision logic
  defp decide_action([]), do: :no_match
  
  defp decide_action([{venue, confidence}]) when confidence >= 0.90 do
    {:redirect, venue, confidence}
  end

  defp decide_action(scored_venues) do
    # Filter venues with confidence ≥70%
    suggestions = Enum.filter(scored_venues, fn {_, conf} -> conf >= 0.70 end)
    
    case suggestions do
      [] -> :no_match
      venues -> {:suggestions, Enum.take(venues, 5)}
    end
  end
end
```

---

### 3. Suggestions Page (Custom 404)

**LiveView component for "Did you mean?" page**:

```elixir
# lib/trivia_advisor_web/live/venue_suggestions_live.ex
defmodule TriviaAdvisorWeb.VenueSuggestionsLive do
  use TriviaAdvisorWeb, :live_view

  def mount(%{"slug" => missing_slug, "suggestions" => suggestions}, _session, socket) do
    {:ok,
     socket
     |> assign(:missing_slug, missing_slug)
     |> assign(:suggestions, suggestions)
     |> assign(:page_title, "Venue Not Found")}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-16">
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold text-gray-900 mb-4">
          Venue Not Found
        </h1>
        <p class="text-xl text-gray-600">
          We couldn't find "<%= @missing_slug %>", but we found similar venues:
        </p>
      </div>

      <div class="space-y-4">
        <%= for {venue, confidence} <- @suggestions do %>
          <.link navigate={~p"/venues/#{venue.slug}"} 
                class="block p-6 bg-white rounded-lg shadow hover:shadow-lg transition">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-xl font-semibold text-gray-900">
                  <%= venue.name %>
                </h3>
                <p class="text-gray-600">
                  <%= venue.city_name %>, <%= venue.country_name %>
                </p>
                <p class="text-sm text-gray-500 mt-2">
                  <%= venue.slug %>
                </p>
              </div>
              <div class="text-right">
                <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
                  <%= Float.round(confidence * 100, 0) %>% match
                </span>
              </div>
            </div>
          </.link>
        <% end %>
      </div>

      <div class="mt-12 text-center">
        <p class="text-gray-600 mb-4">
          Can't find what you're looking for?
        </p>
        <.link navigate={~p"/search"} 
              class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700">
          Search All Venues
        </.link>
      </div>
    </div>
    """
  end
end
```

---

### 4. 301 Redirect with Tracking

**Track successful redirects for analytics**:

```elixir
# In FallbackController
defp redirect_with_tracking(conn, venue, original_slug, confidence) do
  # Log redirect for analytics
  TriviaAdvisor.Analytics.log_venue_redirect(%{
    original_slug: original_slug,
    matched_slug: venue.slug,
    confidence: confidence,
    timestamp: DateTime.utc_now(),
    user_agent: get_req_header(conn, "user-agent"),
    referer: get_req_header(conn, "referer")
  })

  conn
  |> put_status(:moved_permanently)
  |> redirect(to: ~p"/venues/#{venue.slug}")
end
```

---

## 📊 Expected Impact

### By Missing Venue Category

| Category | Count | Expected Outcome | Confidence | Action |
|----------|-------|------------------|------------|--------|
| **Numeric ID duplicates** | 385 | 95% auto-redirect | ≥95% | 301 redirect |
| **Event venues** | 813 | 60% suggestions, 40% 404 | 50-80% | Suggestions or 404 |
| **Closed venues** | 200-400 | 30% suggestions, 70% 404 | 30-70% | Mix |
| **Total** | 790 | ~50% saved (395 redirects) | - | - |

### User Experience Improvements

**Before**:
- 790 URLs → 404 → User bounces (100% loss)

**After**:
- ~385 URLs → 301 redirect → User reaches venue (0% loss) ✅
- ~200 URLs → Suggestions page → 50% click through (50% loss) ✅
- ~205 URLs → Standard 404 (100% loss)

**Net improvement**: Save ~485 of 790 users (61% recovery rate)

### SEO Benefits

1. **Link Equity Preservation**
   - 301 redirects pass ~90-99% of link equity
   - Prevents loss of backlinks to merged venues

2. **Reduced Bounce Rate**
   - Current: 100% bounce on 404
   - Expected: 40% bounce (users find alternatives)

3. **Improved Crawl Budget**
   - Search engines appreciate helpful 404s
   - Better site quality signals

4. **Analytics Data**
   - Learn which old URLs still get traffic
   - Prioritize redirect creation

---

## 🎨 User Interface Mockup

### High Confidence Redirect (301)

```
User requests: /venues/albion-hotel-1759813035
         ↓
[Instant redirect, user doesn't see anything]
         ↓
Page loads: /venues/albion-hotel
```

**User experience**: Seamless, appears to work normally

---

### Medium Confidence Suggestions (Custom 404)

```
┌─────────────────────────────────────────────────┐
│                                                 │
│           🔍 Venue Not Found                    │
│                                                 │
│   We couldn't find "00s-quiz-at-border-city",  │
│   but we found similar venues:                 │
│                                                 │
│  ┌────────────────────────────────────────┐    │
│  │ 📍 Border City Ale House         85% ✓ │    │
│  │    Austin, United States               │    │
│  │    /venues/border-city-ale-house       │    │
│  └────────────────────────────────────────┘    │
│                                                 │
│  ┌────────────────────────────────────────┐    │
│  │ 📍 City Ale House                 72% ✓ │    │
│  │    Austin, United States               │    │
│  │    /venues/city-ale-house              │    │
│  └────────────────────────────────────────┘    │
│                                                 │
│   Can't find what you're looking for?          │
│   [Search All Venues]                          │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

### Standard 404 (No Matches)

```
┌─────────────────────────────────────────────────┐
│                                                 │
│           ❌ Venue Not Found                    │
│                                                 │
│   The venue "xyz123abc" could not be found.    │
│                                                 │
│   This venue may have closed or been removed.  │
│                                                 │
│   [Browse All Venues] [Search] [Go Home]       │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 🧪 Testing Strategy

### Unit Tests

```elixir
# test/trivia_advisor/venue_matcher_test.exs
defmodule TriviaAdvisor.VenueMatcherTest do
  use TriviaAdvisor.DataCase

  describe "normalize_slug/1" do
    test "strips numeric ID suffix" do
      assert normalize_slug("albion-hotel-1759813035") == "albion-hotel"
    end

    test "extracts venue from event pattern" do
      assert normalize_slug("00s-quiz-vol-1-at-border-city-ale-house") 
             == "border-city-ale-house"
    end
  end

  describe "calculate_confidence/2" do
    test "returns high confidence for exact match" do
      assert calculate_confidence("albion-hotel", "albion-hotel") >= 0.95
    end

    test "returns medium confidence for similar slugs" do
      confidence = calculate_confidence("district-hotel", "distric-hotel")
      assert confidence >= 0.80 && confidence < 0.95
    end

    test "returns low confidence for different slugs" do
      assert calculate_confidence("albion-hotel", "xyz-restaurant") < 0.50
    end
  end

  describe "find_similar/1" do
    setup do
      # Insert test venues
      insert(:venue, slug: "albion-hotel")
      insert(:venue, slug: "border-city-ale-house")
      :ok
    end

    test "redirects for high-confidence single match" do
      assert {:redirect, venue, confidence} = find_similar("albion-hotel-1759813035")
      assert venue.slug == "albion-hotel"
      assert confidence >= 0.90
    end

    test "suggests for medium-confidence multiple matches" do
      assert {:suggestions, venues} = find_similar("city-ale")
      assert length(venues) > 0
    end

    test "returns no_match for unrelated slug" do
      assert :no_match = find_similar("xyz-completely-different-123")
    end
  end
end
```

### Integration Tests

```elixir
# test/trivia_advisor_web/integration/smart_404_test.exs
defmodule TriviaAdvisorWeb.Smart404Test do
  use TriviaAdvisorWeb.ConnCase

  describe "venue 404 handling" do
    setup do
      insert(:venue, slug: "test-venue")
      :ok
    end

    test "301 redirects for high-confidence match", %{conn: conn} do
      # Request with numeric ID suffix
      conn = get(conn, ~p"/venues/test-venue-1234567890")
      
      assert redirected_to(conn) == ~p"/venues/test-venue"
      assert conn.status == 301
    end

    test "shows suggestions for medium-confidence matches", %{conn: conn} do
      conn = get(conn, ~p"/venues/test-venu")
      
      assert html_response(conn, 404) =~ "similar venues"
      assert html_response(conn, 404) =~ "test-venue"
    end

    test "shows standard 404 for no matches", %{conn: conn} do
      conn = get(conn, ~p"/venues/completely-nonexistent-xyz-123")
      
      assert html_response(conn, 404) =~ "not found"
      refute html_response(conn, 404) =~ "similar venues"
    end
  end
end
```

### Manual Testing Checklist

- [ ] Test numeric ID pattern: `/venues/albion-hotel-1759813035`
- [ ] Test event pattern: `/venues/00s-quiz-at-venue-name`
- [ ] Test typo: `/venues/distric-hotel` (missing 't')
- [ ] Test partial match: `/venues/city-ale` (incomplete)
- [ ] Test completely wrong: `/venues/xyz-123-abc`
- [ ] Test redirect loop prevention
- [ ] Test performance (<500ms response time)
- [ ] Test with query parameters: `/venues/test?foo=bar`

---

## 🚀 Implementation Plan

### Phase 1: Foundation (Week 1)

**Tasks**:
- [ ] Create `VenueMatcher` module with basic fuzzy matching
- [ ] Implement slug normalization functions
- [ ] Add confidence scoring algorithm
- [ ] Write unit tests for matching logic

**Deliverables**:
- Working fuzzy matcher with 90%+ test coverage
- Confidence scoring validated against sample data

---

### Phase 2: Integration (Week 2)

**Tasks**:
- [ ] Create `FallbackController` for venue 404s
- [ ] Integrate `VenueMatcher` with router
- [ ] Implement 301 redirect logic
- [ ] Add redirect tracking/logging

**Deliverables**:
- High-confidence matches auto-redirect
- Analytics logging in place

---

### Phase 3: UI (Week 3)

**Tasks**:
- [ ] Create `VenueSuggestionsLive` page
- [ ] Design and implement UI mockup
- [ ] Add Tailwind styling
- [ ] Implement standard 404 fallback

**Deliverables**:
- Polished "Did you mean?" page
- Standard 404 for no matches

---

### Phase 4: Testing & Optimization (Week 4)

**Tasks**:
- [ ] Run integration tests
- [ ] Test against real V1 missing URLs
- [ ] Performance optimization (caching, query tuning)
- [ ] A/B test confidence thresholds

**Deliverables**:
- <500ms response times
- Optimal confidence thresholds
- Production-ready feature

---

## 📊 Success Metrics

### Primary Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| **404 Recovery Rate** | 0% | 60%+ | Track redirects + suggestion clicks |
| **Bounce Rate** | 100% | <40% | Google Analytics |
| **Avg Response Time** | N/A | <500ms | APM monitoring |

### Secondary Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Auto-redirect accuracy | >95% | Manual review of logs |
| Suggestion click-through | >50% | Analytics events |
| User satisfaction | >80% positive | Optional feedback survey |

### Analytics Events to Track

```elixir
# Events to log
- venue_404_redirect (original_slug, matched_slug, confidence)
- venue_404_suggestions_shown (original_slug, suggestion_count)
- venue_404_suggestion_clicked (original_slug, clicked_slug, position)
- venue_404_no_match (original_slug)
```

---

## 🔒 Edge Cases & Considerations

### 1. Infinite Redirect Loops

**Problem**: Venue A redirects to Venue B, which redirects to Venue A

**Solution**:
```elixir
# Track redirect chain in session
defp prevent_redirect_loop(conn, target_slug) do
  redirect_chain = get_session(conn, :redirect_chain, [])
  
  if target_slug in redirect_chain do
    # Loop detected, show 404 instead
    render_standard_404(conn)
  else
    conn
    |> put_session(:redirect_chain, [target_slug | redirect_chain])
    |> redirect(to: ~p"/venues/#{target_slug}")
  end
end
```

---

### 2. Geographic Disambiguation

**Problem**: Multiple venues with same name in different cities

**Example**: 
- `/venues/royal-george` could be in London OR Manchester

**Solution**:
```elixir
# Extract geographic context from referer or session
defp add_geographic_bonus(candidates, context) do
  case extract_city_from_context(context) do
    nil -> candidates
    city -> 
      # Boost venues in same city by +15%
      Enum.map(candidates, fn {venue, confidence} ->
        bonus = if venue.city_id == city.id, do: 0.15, else: 0.0
        {venue, min(confidence + bonus, 1.0)}
      end)
  end
end
```

---

### 3. Performance at Scale

**Problem**: Fuzzy matching is CPU-intensive

**Solutions**:
1. **Limit candidate set**: Query max 50 venues, not entire database
2. **Cache results**: ETS cache for common 404s (1-hour TTL)
3. **Database indexes**: Add trigram index for similarity search
4. **Async processing**: Run matching in background Task

```elixir
# Add pg_trgm extension for fast similarity search
defp setup_similarity_index do
  execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
  execute "CREATE INDEX venues_slug_trgm_idx ON venues USING gin (slug gin_trgm_ops)"
end
```

---

### 4. SEO Considerations

**301 vs 302 vs 404**:
- **301 (Permanent)**: Use for high-confidence redirects (≥90%)
- **404 with suggestions**: Use for medium confidence
- **404 plain**: Use for no matches

**Robots.txt**: Don't block 404 pages, search engines need to see them

**Canonical tags**: Redirected pages should have canonical pointing to new URL

---

### 5. A/B Testing Thresholds

**Test different confidence thresholds**:

| Threshold | Expected Behavior | Risk |
|-----------|------------------|------|
| 85% | More redirects | Higher false positive rate |
| 90% | Balanced | Recommended starting point |
| 95% | Fewer redirects | More 404s, safer |

**Recommendation**: Start at 90%, adjust based on manual review of logs

---

## 🔍 Alternative Approaches Considered

### Option 1: Pre-compute Redirect Map

**Approach**: Build static redirect map from V1→V2 slugs at deployment time

**Pros**:
- Instant lookups (O(1))
- No fuzzy matching overhead
- 100% deterministic

**Cons**:
- Requires manual mapping effort
- Doesn't handle typos or variations
- Doesn't scale to unknown slugs

**Decision**: ❌ Not flexible enough, doesn't handle all cases

---

### Option 2: External Search Service (Algolia, Elasticsearch)

**Approach**: Use external search API for fuzzy matching

**Pros**:
- Highly optimized for fuzzy search
- Better typo tolerance
- Scales to millions of records

**Cons**:
- Additional cost ($$$)
- External dependency
- Slower (network latency)
- Overkill for 4,558 venues

**Decision**: ❌ Too complex for current scale

---

### Option 3: Machine Learning Model

**Approach**: Train ML model to predict correct venue from slug

**Pros**:
- Could learn patterns over time
- Potentially higher accuracy

**Cons**:
- Requires training data
- Complex infrastructure
- Overkill for problem size
- Hard to maintain

**Decision**: ❌ Not worth the complexity

---

## 📚 References

### Phoenix Documentation
- [Custom Error Pages](https://hexdocs.pm/phoenix/custom_error_pages.html)
- [Action Fallback](https://hexdocs.pm/phoenix/controllers.html#action-fallback)
- [Plug.Exception Protocol](https://hexdocs.pm/plug/Plug.Exception.html)

### Fuzzy Matching Libraries
- **String.jaro_distance/2**: Built-in Elixir (Jaro-Winkler)
- **String.levenshtein/2**: Elixir 1.13+
- **pg_trgm**: PostgreSQL trigram extension for similarity search

### Related Issues
- Issue #37: V1 to V2 Sitemap Compatibility Analysis

---

## 💬 Open Questions

1. **Should we track redirect success rate?**
   - Log every redirect for first month
   - Manually review sample to validate confidence scoring
   - Adjust thresholds based on data

2. **Should we allow users to report incorrect redirects?**
   - Add "Not what you're looking for?" link on redirected pages
   - Collect feedback to improve matching

3. **Should we cache fuzzy matching results?**
   - Recommendation: Yes, 1-hour TTL in ETS
   - Clear cache on venue updates

4. **Should we pre-redirect at sitemap generation time?**
   - Recommendation: No, keep dynamic for flexibility
   - Can add static redirects for top 50 later

---

## ✅ Definition of Done

- [ ] `VenueMatcher` module implemented with tests
- [ ] Fallback controller handles venue 404s
- [ ] 301 redirects work for high-confidence matches
- [ ] "Did you mean?" page implemented and styled
- [ ] Standard 404 shows for no matches
- [ ] Analytics logging in place
- [ ] Performance <500ms average
- [ ] Integration tests passing
- [ ] Manual testing completed against V1 URLs
- [ ] Documentation updated
- [ ] Deployed to staging for review

---

**Estimated Effort**: 3-4 weeks (1 developer)
**Priority**: High (blocks 15% of V1 URLs)
**Dependencies**: Issue #37 analysis complete
**Target Release**: V2.1.0

---

**Created**: 2025-11-16
**Author**: Sequential Thinking + Context7 Analysis
**Related**: Issue #37 (Sitemap Analysis)
