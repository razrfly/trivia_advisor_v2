# Smart 404 Handler - Quick Reference

**GitHub Issue**: #39
**Priority**: High
**Estimated Effort**: 3-4 weeks

---

## 🎯 Problem

15% of V1 venue URLs (790 venues) will return 404 in V2, including:
- 385 merged duplicates with numeric ID suffixes
- 813 temporary event-specific venues
- 200-400 closed/removed venues

**Current Behavior**: All 790 URLs → Generic 404 → User bounces

---

## 💡 Solution

Intelligent 404 handling using fuzzy matching:

### Decision Flow

```
Missing venue slug
    ↓
Fuzzy match against database
    ↓
┌─────────────────────────────────────┐
│ Confidence ≥90% + Single Match      │
│         ↓                            │
│  301 Redirect (SEO-friendly)        │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Confidence 70-89% + Multiple Matches│
│         ↓                            │
│  "Did you mean?" page               │
│  (Custom 404 with suggestions)      │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Confidence <70% or No Matches       │
│         ↓                            │
│  Standard 404 page                  │
└─────────────────────────────────────┘
```

---

## 🔧 Technical Approach

### 1. Slug Normalization

**Remove numeric IDs**:
- `albion-hotel-1759813035` → `albion-hotel`

**Extract venue from events**:
- `00s-quiz-vol-1-at-border-city-ale-house` → `border-city-ale-house`

### 2. Fuzzy Matching Algorithm

**Confidence Scoring** (0.0 - 1.0):
- Exact match after normalization: +40%
- Jaro-Winkler similarity: +30% (weighted)
- Levenshtein distance: +20% (weighted)
- Common prefix ratio: +10%

### 3. Components

**VenueMatcher Module**:
- Slug normalization
- Database candidate queries
- Confidence scoring
- Decision logic

**FallbackController**:
- Detect venue 404s
- Call VenueMatcher
- Handle redirects/suggestions

**VenueSuggestionsLive**:
- Custom 404 page
- List similar venues
- Show confidence scores

---

## 📊 Expected Impact

### Recovery Rate by Category

| Category | Count | Expected Outcome |
|----------|-------|------------------|
| Numeric ID duplicates | 385 | 95% auto-redirect (366 saved) |
| Event venues | 813 | 20% via suggestions (163 saved) |
| Closed venues | 200-400 | 10% via suggestions (20-40 saved) |
| **TOTAL** | **790** | **~61% recovery (485 users saved)** |

### Benefits

**SEO**:
- 301 redirects preserve link equity
- Reduced bounce rates
- Better crawl budget usage

**User Experience**:
- Automatic redirects feel seamless
- Helpful suggestions reduce frustration
- Better than generic 404

**Analytics**:
- Learn which old URLs get traffic
- Track redirect success rates
- Data-driven optimization

---

## 🚀 Implementation Phases

### Phase 1: Foundation (Week 1)
- Create VenueMatcher module
- Implement fuzzy matching logic
- Add confidence scoring
- Write unit tests

### Phase 2: Integration (Week 2)
- Create FallbackController
- Integrate with router
- Implement 301 redirects
- Add analytics logging

### Phase 3: UI (Week 3)
- Build VenueSuggestionsLive page
- Design "Did you mean?" interface
- Add Tailwind styling
- Standard 404 fallback

### Phase 4: Testing (Week 4)
- Integration tests
- Performance optimization
- Test against real V1 URLs
- A/B test confidence thresholds

---

## 🎯 Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| 404 Recovery Rate | 60%+ | Redirects + suggestion clicks |
| Bounce Rate | <40% | Google Analytics |
| Response Time | <500ms | APM monitoring |
| Redirect Accuracy | >95% | Manual log review |
| Suggestion CTR | >50% | Analytics events |

---

## 🔍 Example Scenarios

### Scenario 1: Numeric ID Match (High Confidence)

**User visits**: `/venues/albion-hotel-1759813035`

**Process**:
1. Venue not found in database
2. Normalize: `albion-hotel-1759813035` → `albion-hotel`
3. Find exact match: `albion-hotel` (confidence: 95%)
4. Auto-redirect with 301

**Result**: User seamlessly lands on `/venues/albion-hotel`

---

### Scenario 2: Event Venue (Medium Confidence)

**User visits**: `/venues/00s-quiz-vol-1-at-border-city-ale-house`

**Process**:
1. Venue not found
2. Extract: `border-city-ale-house`
3. Find match: `border-city-ale-house` (confidence: 85%)
4. Show suggestions page

**Result**: User sees "Did you mean?" with suggestion

---

### Scenario 3: Typo (Medium Confidence)

**User visits**: `/venues/distric-hotel`

**Process**:
1. Venue not found
2. Fuzzy match finds: `district-hotel` (confidence: 88%)
3. Show suggestions page

**Result**: User clicks suggestion and reaches correct venue

---

### Scenario 4: No Match (Low Confidence)

**User visits**: `/venues/completely-nonexistent-xyz-123`

**Process**:
1. Venue not found
2. No similar venues found (confidence: 20%)
3. Show standard 404

**Result**: User sees clean 404 with search option

---

## 🛡️ Edge Cases Handled

1. **Infinite redirect loops**: Session tracking prevents A→B→A
2. **Geographic disambiguation**: Boost venues in same city
3. **Performance**: Database indexes + caching for <500ms
4. **Multiple same names**: Consider location context
5. **Query parameters**: Preserved in redirects

---

## 📚 Technical Details

### Database Requirements

**PostgreSQL Extensions**:
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

**Indexes**:
```sql
CREATE INDEX venues_slug_trgm_idx
ON venues USING gin (slug gin_trgm_ops);
```

### Elixir String Functions Used

- `String.jaro_distance/2` - Built-in Jaro-Winkler
- `String.levenshtein/2` - Edit distance (Elixir 1.13+)
- PostgreSQL `similarity()` - Trigram similarity

### Performance Optimizations

1. Limit candidate queries to 50 venues max
2. ETS cache for common 404s (1-hour TTL)
3. Database trigram index for fast similarity
4. Async matching with Task for heavy queries

---

## 🔗 Related Documentation

- **Full Specification**: `SMART_404_HANDLER_ISSUE_39.md`
- **Sitemap Analysis**: `SITEMAP_V1_V2_COMPARISON.md`
- **GitHub Issue**: https://github.com/razrfly/trivia_advisor_v2/issues/39
- **Related Issue**: #37 (V1 to V2 Sitemap Compatibility)

---

## ✅ Quick Start Checklist

When implementing:

- [ ] Review full issue #39 for complete specification
- [ ] Set up pg_trgm extension in database
- [ ] Create VenueMatcher module first
- [ ] Test with sample V1 URLs from `/tmp/v1-venue-slugs.txt`
- [ ] Validate confidence scoring with manual review
- [ ] Add analytics logging for all redirects
- [ ] Monitor performance (<500ms requirement)
- [ ] A/B test confidence thresholds (start at 90%)

---

**Last Updated**: 2025-11-16
**Status**: Ready for Implementation
**Owner**: TBD
**Target Release**: V2.1.0
