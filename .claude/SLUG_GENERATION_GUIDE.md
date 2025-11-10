# Slug Generation Guide - V1 to V2 Migration

**Critical**: Slug generation must be 100% identical to V1 to preserve SEO and prevent 404 errors.

---

## Base Slug Algorithm

All slugs use the same base algorithm from `TriviaAdvisor.Utils.Slug.slugify/1`:

```elixir
def slugify(str) when is_binary(str) do
  str
  |> String.downcase()              # "Hello World" -> "hello world"
  |> String.replace(~r/[^a-z0-9\s-]/, "")  # Remove special chars
  |> String.replace(~r/[\s-]+/, "-")       # Multiple spaces/hyphens -> single hyphen
  |> String.trim("-")                       # Remove leading/trailing hyphens
end
```

**Examples**:
- `"Hello World!"` → `"hello-world"`
- `"The Crown & Anchor"` → `"the-crown-anchor"`
- `"Newport-on-Tay"` → `"newport-on-tay"`

---

## City Slug Generation

**File**: `lib/trivia_advisor/locations/city.ex`
**Function**: `generate_slug/1` (private)

### Algorithm

1. **Base slug**: `Slug.slugify(city.name)`
2. **Check conflict**: Does another city in a DIFFERENT country have this slug?
3. **If conflict exists**: Append country code → `"#{base_slug}-#{country_code}"`
4. **If no conflict**: Use base slug

### Code

```elixir
defp generate_slug(%Ecto.Changeset{valid?: true, changes: %{name: name}} = changeset) do
  base_slug = Slug.slugify(name)

  case check_slug_conflict(base_slug, get_field(changeset, :country_id)) do
    true ->
      # Conflict exists, append country code
      country_code = Repo.get(Country, get_field(changeset, :country_id)).code
      put_change(changeset, :slug, "#{base_slug}-#{String.downcase(country_code)}")
    false ->
      # No conflict, use base slug
      put_change(changeset, :slug, base_slug)
  end
end

defp check_slug_conflict(slug, country_id) do
  query = from c in City,
          where: c.slug == ^slug and c.country_id != ^country_id
  Repo.exists?(query)
end
```

### Examples

**No conflict** (simple slug):
- `"London"` (UK) → `"london"` (no other "London" in different country)
- `"Reading"` (UK) → `"reading"` (no conflict)
- `"Berkeley"` (US) → `"berkeley"` (assuming no Berkeley in another country)

**Conflict exists** (country code appended):
- `"Newport"` (UK) + `"Newport"` (US) → `"newport-gb"` / `"newport-us"`
- `"Cambridge"` (UK) + `"Cambridge"` (US) → `"cambridge-gb"` / `"cambridge-us"`

**From sitemap** (all simple slugs = no conflicts):
- `argenton`
- `bexley`
- `berkeley`
- `reading`
- `farnham`
- `newport-on-tay` (unique name, no conflict)
- `newport-beach` (unique name, different from "Newport")

### Migration Requirements for V2

1. **Copy `Slug.slugify/1` utility** to V2
2. **Copy `City.generate_slug/1` logic** exactly
3. **Database must have `countries` table** with `code` field
4. **Ensure country codes are lowercase** (GB → gb)
5. **Test slug uniqueness constraint** in database

---

## Venue Slug Generation

**File**: `lib/trivia_advisor/locations/venue.ex`
**Function**: `put_slug/1` (private)

### Algorithm (Progressive Fallback)

Venue slugs try multiple strategies in order until one produces a unique slug:

1. **Name only**: `Slug.slugify(name)`
2. **Name + City**: `Slug.slugify("#{name} #{city_name}")`
3. **Name + City + Postcode**: `Slug.slugify("#{name} #{city_name} #{postcode}")`
4. **Name + Timestamp**: `Slug.slugify("#{name} #{System.system_time(:second)}")`

### Code

```elixir
defp put_slug(changeset) do
  case get_change(changeset, :name) do
    nil -> changeset
    name ->
      # Get city and postcode from changeset if available
      city_name = get_in(get_change(changeset, :metadata) || %{}, ["city", "name"])
      postcode = get_change(changeset, :postcode)

      # Try different slug combinations
      slug = cond do
        # Try name only
        !slug_exists?(Slug.slugify(name)) ->
          Slug.slugify(name)

        # Try name + city
        city_name && !slug_exists?(Slug.slugify("#{name} #{city_name}")) ->
          Slug.slugify("#{name} #{city_name}")

        # Try name + city + postcode
        city_name && postcode && !slug_exists?(Slug.slugify("#{name} #{city_name} #{postcode}")) ->
          Slug.slugify("#{name} #{city_name} #{postcode}")

        # Fallback: name + timestamp
        true ->
          Slug.slugify("#{name} #{System.system_time(:second)}")
      end

      put_change(changeset, :slug, slug)
  end
end

defp slug_exists?(slug) do
  from(v in Venue,
    where: v.slug == ^slug and is_nil(v.deleted_at)
  )
  |> Repo.one()
  |> case do
    nil -> false
    _ -> true
  end
end
```

### Examples from Sitemap

**Strategy 1: Name only** (unique venue name)
- `"Hop Pole"` → `"hop-pole"`
- `"Gaia"` → `"gaia"`
- `"Moorings"` → `"moorings"`
- `"One Handsome Bastard"` → `"one-handsome-bastard"`

**Strategy 2: Name + City** (name conflicts, city disambiguates)
- `"The Crown" + "Horsham"` → `"the-crown-horsham"`
- `"The Royal George" + "London"` → `"the-royal-george-london"` (hypothetical)
- `"Lucky Voice" + "Liverpool Street"` → `"lucky-voice-liverpool-street"`

**Strategy 3: Name + City + Postcode** (still conflicts)
- Not seen in sitemap sample, but would look like:
- `"The Crown" + "London" + "W1"` → `"the-crown-london-w1"`

**Strategy 4: Name + Timestamp** (last resort for duplicates)
- `"The Catman Cafe"` → `"the-catman-cafe-1750339808"`
- Timestamp: `1750339808` (Unix timestamp in seconds)

**Event-specific slugs** (appear to be venue names that include event details):
- `"What's On Tap Highland Village (starts on June 9)"` → `"whats-on-tap-highland-village-starts-on-june-9"`
- `"The Press Room @ Alamo Drafthouse Seaport (starts on June 9)"` → `"the-press-room-alamo-drafthouse-seaport-starts-on-june-9"`
- `"Pride Music Bingo Night at Ponysaurus Brewing Co. (Wilmington)"` → `"pride-music-bingo-night-at-ponysaurus-brewing-co-wilmington"`

**Note**: These long event-specific slugs suggest that some "venues" in the database may actually be temporary events or event series.

### Key Observations

1. **Metadata dependency**: City name comes from `metadata["city"]["name"]`, NOT from the `city_id` association
2. **Soft delete handling**: `slug_exists?/1` explicitly ignores deleted venues (`is_nil(v.deleted_at)`)
3. **Uniqueness check**: Runs BEFORE database constraint, preventing race conditions
4. **Timestamp format**: Uses `System.system_time(:second)` (Unix timestamp)

### Migration Requirements for V2

1. **Copy `put_slug/1` logic** exactly (all 4 strategies)
2. **Preserve metadata structure** - city name must be in `metadata["city"]["name"]`
3. **Handle soft deletes** - ensure deleted venues don't block slug generation
4. **Test all slug strategies** with real venue data
5. **Understand event-specific slugs** - clarify if these are venues or events

---

## Migration Validation Checklist

### Pre-Migration
- [ ] Query V1 database for all city slugs and country codes
- [ ] Query V1 database for all venue slugs and their generation strategy
- [ ] Identify any cities with country code suffixes (conflicts)
- [ ] Identify venue slug distribution:
  - [ ] Count: name only
  - [ ] Count: name + city
  - [ ] Count: name + city + postcode
  - [ ] Count: name + timestamp

### During Migration
- [ ] Copy `Slug.slugify/1` to V2 (exact copy)
- [ ] Copy `City.generate_slug/1` to V2 (exact copy)
- [ ] Copy `Venue.put_slug/1` to V2 (exact copy)
- [ ] Ensure `countries` table has `code` field
- [ ] Ensure `venues` table has `metadata` JSONB field
- [ ] Ensure soft delete logic preserved (`deleted_at` field)

### Post-Migration Validation
- [ ] Generate sample slugs in V2, compare to V1 database
- [ ] Test city slug conflict detection (simulate duplicate city names)
- [ ] Test venue slug generation with all 4 strategies
- [ ] Verify deleted venues don't block slug generation
- [ ] Test slug uniqueness constraints in database
- [ ] Compare V2 generated slugs to sitemap URLs (100% match required)

---

## Edge Cases to Test

### City Slugs
1. **Duplicate city names in same country** - Should error (unique constraint)
2. **Duplicate city names in different countries** - Should append country code
3. **Special characters in city name** - `"Newport-on-Tay"` → `"newport-on-tay"`
4. **City name with apostrophe** - `"L'Aquila"` → `"laquila"`
5. **City name with ampersand** - `"Trinidad & Tobago"` → `"trinidad-tobago"`

### Venue Slugs
1. **Unique venue name** - Should use name only
2. **Duplicate venue names in same city** - Should add city, postcode, or timestamp
3. **Duplicate venue names in different cities** - Should add city name
4. **Venue with no city metadata** - Should fall back to timestamp
5. **Venue with very long name** - Slug should not be truncated
6. **Deleted venue with same name** - New venue should reuse slug
7. **Venue created at exact same second** - Timestamp may collide (rare edge case)

---

## Database Schema Requirements

### cities table
```sql
CREATE TABLE cities (
  id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  slug VARCHAR NOT NULL UNIQUE,  -- Generated, unique across all cities
  country_id INTEGER NOT NULL REFERENCES countries(id),
  latitude DECIMAL,
  longitude DECIMAL,
  unsplash_gallery JSONB,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### venues table
```sql
CREATE TABLE venues (
  id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  slug VARCHAR NOT NULL UNIQUE,  -- Generated, unique across non-deleted venues
  address VARCHAR NOT NULL,
  postcode VARCHAR,
  latitude DECIMAL,
  longitude DECIMAL,
  city_id INTEGER NOT NULL REFERENCES cities(id),
  metadata JSONB,  -- Must contain metadata.city.name for slug generation
  deleted_at TIMESTAMP,  -- Soft delete
  deleted_by VARCHAR,
  merged_into_id INTEGER REFERENCES venues(id),
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### countries table
```sql
CREATE TABLE countries (
  id SERIAL PRIMARY KEY,
  name VARCHAR NOT NULL,
  code VARCHAR NOT NULL UNIQUE,  -- ISO code (lowercase: "gb", "us", "fr")
  slug VARCHAR NOT NULL UNIQUE,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

---

## Testing Strategy

### Unit Tests

**Test: `Slug.slugify/1`**
```elixir
test "removes special characters" do
  assert Slug.slugify("Hello World!") == "hello-world"
  assert Slug.slugify("The Crown & Anchor") == "the-crown-anchor"
end

test "handles multiple spaces and hyphens" do
  assert Slug.slugify("Newport  -  on - Tay") == "newport-on-tay"
end

test "trims leading/trailing hyphens" do
  assert Slug.slugify("-Hello-") == "hello"
end
```

**Test: `City.generate_slug/1`**
```elixir
test "uses simple slug when no conflict" do
  city = insert(:city, name: "London", country: build(:country, code: "GB"))
  assert city.slug == "london"
end

test "appends country code when conflict exists" do
  # Create "Newport" in UK
  insert(:city, name: "Newport", country: build(:country, code: "GB"))
  # Create "Newport" in US - should get country code
  city = insert(:city, name: "Newport", country: build(:country, code: "US"))
  assert city.slug == "newport-us"
end
```

**Test: `Venue.put_slug/1`**
```elixir
test "uses name only when unique" do
  venue = insert(:venue, name: "Hop Pole")
  assert venue.slug == "hop-pole"
end

test "adds city when name conflicts" do
  insert(:venue, name: "The Crown", metadata: %{"city" => %{"name" => "London"}})
  venue = insert(:venue, name: "The Crown", metadata: %{"city" => %{"name" => "Horsham"}})
  assert venue.slug == "the-crown-horsham"
end

test "uses timestamp when all else fails" do
  # Create venue with same name and city
  insert(:venue, name: "The Crown", metadata: %{"city" => %{"name" => "London"}})
  # Create duplicate
  venue = insert(:venue, name: "The Crown", metadata: %{"city" => %{"name" => "London"}})
  assert String.starts_with?(venue.slug, "the-crown-")
  assert String.length(venue.slug) > length("the-crown-")
end

test "ignores deleted venues when checking uniqueness" do
  deleted = insert(:venue, name: "Hop Pole", deleted_at: DateTime.utc_now())
  new_venue = insert(:venue, name: "Hop Pole")
  assert new_venue.slug == "hop-pole"  # Reuses slug
  refute new_venue.id == deleted.id
end
```

### Integration Tests

**Test: Sitemap URL validation**
```elixir
test "all sitemap URLs resolve correctly" do
  # Generate sitemap
  {:ok, sitemap} = Sitemap.generate()

  # Extract all URLs
  urls = extract_urls(sitemap)

  # Test each URL returns 200
  for url <- urls do
    assert_http_status(url, 200)
  end
end

test "generated slugs match sitemap URLs" do
  # Get all slugs from sitemap
  sitemap_slugs = get_sitemap_slugs("https://cdn.quizadvisor.com/sitemaps/sitemap-00001.xml.gz")

  # Get all slugs from V2 database
  city_slugs = Repo.all(from c in City, select: c.slug)
  venue_slugs = Repo.all(from v in Venue, where: is_nil(v.deleted_at), select: v.slug)
  db_slugs = city_slugs ++ venue_slugs

  # Compare
  assert MapSet.equal?(MapSet.new(sitemap_slugs), MapSet.new(db_slugs))
end
```

---

## Performance Considerations

### City Slug Generation
- **Query on every city insert**: Checks for slug conflicts
- **Index required**: `CREATE INDEX idx_cities_slug_country ON cities(slug, country_id);`
- **Optimization**: Consider caching country codes to avoid repeated `Repo.get(Country, ...)`

### Venue Slug Generation
- **Multiple queries on insert**: Checks up to 4 slug variations
- **Index required**: `CREATE INDEX idx_venues_slug_deleted ON venues(slug) WHERE deleted_at IS NULL;`
- **Optimization**: Could batch-check all slug candidates in one query
- **Soft delete impact**: Query must filter `deleted_at IS NULL` every time

---

## Read-Only Migration Implications

Since V2 is read-only and consumes the Eventasaurus database:

1. **Slugs are pre-generated** - V1 already created all slugs, V2 just reads them
2. **No slug generation on insert** - V2 won't create new cities or venues
3. **Migration task**: Copy slug generation logic for reference/documentation only
4. **Primary use case**: Understanding how existing slugs were created
5. **Testing focus**: Validate that V2 can read and use existing slugs correctly

**Recommendation**:
- Copy slug generation code to V2 for reference
- Add comprehensive tests to validate slug format understanding
- Do NOT implement slug generation in V2 (read-only database)
- Focus on correct slug parsing and URL routing

---

## Next Steps

1. **Phase 0.3**: Extract slug generation code from V1
2. **Phase 0.4**: Validate all sitemap slugs against expected format
3. **Phase 1**: Copy slug utility to V2 (for reference/testing)
4. **Phase 2**: Implement routing that correctly handles all slug formats
5. **Phase 6**: Test 100% of sitemap URLs resolve correctly
