# Sitemap Baseline Analysis
**Generated**: 2025-11-08
**Source**: https://cdn.quizadvisor.com/sitemaps/sitemap-00001.xml.gz

---

## 📊 URL Inventory

### Total URLs: **7,118**

| Category | Count | Percentage | Route Pattern | Priority | Changefreq |
|----------|-------|------------|---------------|----------|------------|
| **Static Pages** | 2 | 0.03% | `/`, `/cities` | 1.0, 0.9 | weekly |
| **City Pages** | 1,768 | 24.8% | `/cities/:slug` | 0.8 | daily |
| **Venue Pages** | 5,348 | 75.2% | `/venues/:slug` | 0.7 | daily |

---

## 🔍 Slug Format Analysis

### City Slugs
**Format**: Simple slugs (NOT with country codes as initially expected)

**Examples**:
- `reading`
- `berkeley`
- `newport-on-tay`
- `newport-beach`
- `argenton`
- `bexley`
- `farnham`
- `mansfield`

**Pattern**: Kebab-case city names, with hyphens for multi-word cities.

**Disambiguation**: Not immediately clear how cities with the same name in different countries are handled. May use different spellings or additional qualifiers.

### Venue Slugs
**Format**: Simple slugs OR slugs with numeric IDs

**Examples**:
- `the-crown-horsham` (simple)
- `hop-pole` (simple)
- `the-royal-george` (simple)
- `the-catman-cafe-1750339808` (with numeric ID)
- `lucky-voice-liverpool-street` (with location qualifier)
- `the-press-room-alamo-drafthouse-seaport-starts-on-june-9` (with event details)

**Pattern**: Kebab-case venue names, sometimes including:
- City name for disambiguation (`the-crown-horsham`)
- Location qualifier (`liverpool-street`)
- Numeric ID for uniqueness (`1750339808`)
- Event-specific details (for temporary events)

**Notes**: Some venue slugs are very long and include event-specific information. This suggests:
1. Some "venues" may actually be events at venues
2. Slug generation logic is complex and needs careful migration
3. Need to handle both simple and complex slug formats

---

## 📈 Progress Tracking Template

### Migration Progress by Category

| Category | Expected | Migrated | Validated | % Complete |
|----------|----------|----------|-----------|------------|
| Static Pages | 2 | 0 | 0 | 0% |
| City Pages | 1,768 | 0 | 0 | 0% |
| Venue Pages | 5,348 | 0 | 0 | 0% |
| **TOTAL** | **7,118** | **0** | **0** | **0%** |

**Update this table as routes are implemented and validated**

### Validation Checklist

For each URL category, validate:
- [ ] Route returns 200 OK (not 404)
- [ ] Page renders correctly
- [ ] JSON-LD schema present and valid
- [ ] Meta tags match V1
- [ ] Open Graph tags present
- [ ] Images load correctly
- [ ] Links functional
- [ ] Mobile responsive

---

## 🎯 Migration Priorities

### Phase 1: Static Pages (2 URLs)
**Priority**: CRITICAL - Foundation for all other pages
**Timeline**: Week 1

- [ ] `/` - Homepage with featured venues, popular cities, search
- [ ] `/cities` - Cities index (if this page exists beyond sitemap reference)

### Phase 2: City Pages (1,768 URLs)
**Priority**: HIGH - Important for local SEO
**Timeline**: Week 2-3

**Sample cities to test**:
- [ ] `/cities/reading` - Simple slug
- [ ] `/cities/newport-on-tay` - Multi-word slug
- [ ] `/cities/berkeley` - Common name (verify no conflicts)
- [ ] `/cities/newport-beach` - Another "Newport" (verify disambiguation)

**Validation**:
- Ensure slug generation matches V1 exactly
- Test spatial queries (venues near city)
- Verify filtering (radius, day-of-week, suburbs)

### Phase 3: Venue Pages (5,348 URLs)
**Priority**: CRITICAL - Core SEO value
**Timeline**: Week 3-5

**Sample venues to test**:
- [ ] `/venues/the-crown-horsham` - Simple slug with city
- [ ] `/venues/hop-pole` - Shortest slug format
- [ ] `/venues/the-catman-cafe-1750339808` - Numeric ID slug
- [ ] `/venues/lucky-voice-liverpool-street` - Location qualifier
- [ ] `/venues/the-press-room-alamo-drafthouse-seaport-starts-on-june-9` - Event-specific long slug

**Validation**:
- Test all slug format variations
- Verify merge redirects work
- Validate JSON-LD Event schema
- Check image loading
- Test event display and sorting

---

## 🔧 Slug Generation Requirements

### City Slug Algorithm (to reverse-engineer from V1)
```elixir
# Expected format: kebab-case city name
# Unknown: How are duplicate city names handled?
# Examples suggest NO country code suffix

def generate_city_slug(city_name) do
  city_name
  |> String.downcase()
  |> String.replace(" ", "-")
  |> String.replace(~r/[^a-z0-9-]/, "")
end
```

**Open Questions**:
1. How are cities with the same name in different countries disambiguated?
   - Example: `berkeley` (US) vs potential `berkeley` (UK)
   - Example: `newport-on-tay` (Scotland) vs `newport-beach` (US) - different names, so no conflict
2. Are city slugs guaranteed unique in the database?
3. Is there a `slug` column in the `cities` table, or is it generated?

### Venue Slug Algorithm (to reverse-engineer from V1)
```elixir
# Multiple formats observed:
# 1. Simple: venue-name
# 2. With city: venue-name-city
# 3. With numeric ID: venue-name-1234567890
# 4. With event details: long-descriptive-name-with-event-info

# Need to find slug generation logic in V1 codebase
# Check for Slug helper module or venue schema slug generation
```

**Open Questions**:
1. When is numeric ID added to slug?
   - Hypothesis: When slug collision occurs
2. Are event-specific venues (long slugs) actually venues or events?
   - Example: `whats-on-tap-highland-village-starts-on-june-9`
   - This looks like an event, not a permanent venue
3. Is there a `slug` column in `venues` table?
4. How are merged venues handled in slugs?

---

## 🚨 Critical Findings

### 1. Slug Format Different Than Expected
**Initial Assumption**: City slugs would include country codes (e.g., `london-gb`)
**Reality**: City slugs are simple (e.g., `reading`, `berkeley`)

**Impact**: Need to verify slug generation logic in V1 codebase before migration.

**Action Required**:
- [ ] Find slug generation code in V1
- [ ] Understand disambiguation strategy
- [ ] Test edge cases (duplicate city names)

### 2. Venue Slug Complexity
**Observation**: Multiple venue slug formats exist
**Impact**: Migration must handle all slug format variations

**Action Required**:
- [ ] Categorize all venue slug types
- [ ] Find slug generation logic in V1
- [ ] Implement identical logic in V2
- [ ] Test all format variations

### 3. Potential Event-as-Venue Issue
**Observation**: Some venue slugs include event-specific details
**Impact**: Data model may be complex (venues vs events vs event-venues)

**Action Required**:
- [ ] Clarify Eventasaurus data model
- [ ] Understand how temporary events are handled
- [ ] Verify if these are actual venues or just events

---

## 📋 Next Steps

### Immediate (Phase 0 - Week 1)
1. **Find V1 slug generation logic**
   - [ ] Search V1 codebase for slug generation
   - [ ] Document exact algorithm
   - [ ] Test with sample data

2. **Validate database structure**
   - [ ] Query Eventasaurus database for `cities` table schema
   - [ ] Query `venues` table schema
   - [ ] Confirm `slug` columns exist
   - [ ] Test slug uniqueness

3. **Test sample URLs**
   - [ ] Pick 10 representative URLs from each category
   - [ ] Test in V1 production (ensure they work)
   - [ ] Document page structure and features
   - [ ] Screenshot for visual comparison

### Week 2-3 (Phase 1-2)
4. **Implement slug generation in V2**
   - [ ] Port V1 slug logic to V2
   - [ ] Write tests for all slug formats
   - [ ] Validate against sitemap URLs

5. **Set up progress tracking**
   - [ ] Create automated URL testing script
   - [ ] Track migration progress (0% → 100%)
   - [ ] Monitor for 404 errors

### Week 4+ (Phase 3+)
6. **Validate SEO preservation**
   - [ ] Compare V1 vs V2 JSON-LD schemas
   - [ ] Test Google Rich Results
   - [ ] Verify social sharing previews

---

## 🔗 Resources

- **V1 Sitemap**: https://cdn.quizadvisor.com/sitemaps/sitemap-00001.xml.gz
- **V1 Robots.txt**: https://quizadvisor.com/robots.txt
- **V1 Codebase**: `/Users/holdenthomas/Code/paid-projects-2024/trivia_advisor`
- **V2 Codebase**: `/Users/holdenthomas/Code/paid-projects-2025/trivia_advisor`
- **Database**: Eventasaurus (Supabase PostgreSQL)

---

## 📝 Notes

- Sitemap last updated: 2025-11-08
- All URLs use `https://quizadvisor.com` domain
- No `/countries/:slug` routes found in sitemap (despite being in V1 router)
- No `/venues/latest` route in sitemap (despite being in V1 router)
- This suggests sitemap may not include all public routes

**Recommendation**: Also audit V1 router to ensure ALL public routes are accounted for, not just sitemap URLs.
