# Map Implementation Research: TriviaAdvisor V2 vs Eventasaurus

## PART 1: TriviaAdvisor V2 - Google Maps Usage

### Current Implementation

**Location**: `/lib/trivia_advisor_web/live/venue_show_live.ex` (lines 180-216)

**What's Used**:
1. **Google Maps Embed API** - Static iframe embed showing venue location
   - Lines 182-192: `<iframe>` with Google Maps Embed v1 API
   - API Key: `AIzaSyBFw0Qbyq9zTFTd-tUY6dZWTgaQzuU17R8`
   - Endpoint: `https://www.google.com/maps/embed/v1/place`
   - Parameters: `key`, `q` (coordinates), `zoom` (15)

2. **Google Maps Directions Link** - "Get Directions" button
   - Lines 193-214: Standard link to Google Maps directions
   - Endpoint: `https://www.google.com/maps/dir/?api=1&destination=`
   - Parameters: latitude, longitude

### Current Code Example
```heex
<%= if @venue.latitude && @venue.longitude do %>
  <div class="mt-4">
    <iframe
      width="100%"
      height="300"
      frameborder="0"
      style="border:0"
      referrerpolicy="no-referrer-when-downgrade"
      src={"https://www.google.com/maps/embed/v1/place?key=AIzaSyBFw0Qbyq9zTFTd-tUY6dZWTgaQzuU17R8&q=#{@venue.latitude},#{@venue.longitude}&zoom=15"}
      allowfullscreen
      class="rounded-lg shadow-md"
    >
    </iframe>
    <a
      href={"https://www.google.com/maps/dir/?api=1&destination=#{@venue.latitude},#{@venue.longitude}"}
      target="_blank"
      rel="noopener noreferrer"
      class="inline-flex items-center mt-3 text-blue-600 hover:text-blue-800 font-medium"
    >
      Get Directions
    </a>
  </div>
<% end %>
```

### Critical Issues

**API Key Exposure** ⚠️ **CRITICAL SECURITY ISSUE**
- The Google Maps API key is **hardcoded in the source code**: `AIzaSyBFw0Qbyq9zTFTd-tUY6dZWTgaQzuU17R8`
- This key is **publicly visible** in:
  - GitHub repository (if public)
  - Browser network requests
  - Cached/archived pages
- Anyone with this key can:
  - Use it on any website
  - Generate charges on the associated billing account
  - Exhaust the quota
  - Perform unauthorized requests

**Functionality Assessment**:
- ✅ Maps work and display venue location
- ✅ Directions link functional
- ❌ No interactive features (panning, zooming limited)
- ❌ No search functionality
- ❌ No clustering or multiple venue views
- ✅ Simple, minimal bandwidth usage

**No Configuration**:
- Maps are hardcoded, no environment variables
- No ability to disable or change provider
- Not configurable per deployment environment

### Search Results Summary
- Only **2 files** reference maps in TriviaAdvisor V2:
  - `venue_show_live.ex` (the only active usage)
  - Node modules documentation (not active code)

---

## PART 2: Eventasaurus - Mapbox Implementation

### Sophisticated Multi-Purpose Map System

Eventasaurus uses **Mapbox** extensively with three distinct implementations:

#### 1. Interactive Venue Map Display (Frontend)

**File**: `/assets/js/hooks/mapbox-venues-map.js` (276 lines)
**Component**: `/lib/eventasaurus_web/components/mapbox_venues_map_component.ex` (135 lines)

**Features**:
- Interactive Mapbox GL JS map with full panning/zooming
- **Smart Clustering**: Groups 10+ venues together
- **Responsive Design**: 600px height, mobile-friendly
- **Venue Markers**: Customizable popup with event count
- **Navigation Controls**: Zoom, pan, fullscreen controls
- **Smooth Animations**: Cluster expansion with ease-to animation
- **Dark Mode Support**: CSS classes for dark mode variants

**Implementation Details**:
```javascript
// Clustering with custom styling
mapboxgl.Map with:
  - Style: mapbox://styles/mapbox/streets-v12
  - Clustering enabled for 10+ venues
  - Custom circle colors (blue gradients)
  - Point count aggregation
  - Popup on marker click
```

#### 2. Geocoding Service (Backend)

**File**: `/lib/eventasaurus_discovery/geocoding/providers/mapbox.ex` (281 lines)

**Features**:
- **Free Tier**: 100,000 requests/month
- **Rate Limit**: 600 requests/minute
- **Forward Geocoding**: Address → Coordinates + City + Country
- **Reverse Geocoding**: Coordinates → Address information
- **Error Handling**: Timeout, rate-limiting, authentication failures
- **Comprehensive Logging**: Detailed debug/error logs for monitoring

**API Used**:
```
Forward: https://api.mapbox.com/geocoding/v5/mapbox.places/{address}.json
Reverse: https://api.mapbox.com/geocoding/v5/mapbox.places/{lng},{lat}.json
```

**Response Parsing**:
- Extracts: latitude, longitude, city, country, place_name
- Handles: Decimal coordinates, place_type detection, context hierarchy
- Returns: Standardized geocode result with place_id for tracking

#### 3. Client-Side Geocoding (Form Search)

**File**: `/assets/js/hooks/places-search/providers/mapbox-provider.js` (389 lines)

**Features**:
- **SearchBox Core API**: Mapbox's modern search interface
- **Autocomplete Search**: Real-time suggestions while typing
- **Session Tokens**: Cost-effective session management
- **Place Selection**: Seamless place picker for forms
- **Error Recovery**: Graceful fallbacks if Mapbox unavailable

**Script Loading**:
```javascript
https://api.mapbox.com/search-js/v1.0.0-beta.22/core.js
```

### Configuration

**Environment Variables** (`config/runtime.exs`):
```elixir
config :eventasaurus, :mapbox, 
  access_token: System.get_env("MAPBOX_ACCESS_TOKEN")
```

**Example .env**:
```
MAPBOX_ACCESS_TOKEN=your_mapbox_access_token
MAPBOX_DEFAULT_STYLE_ID=mapbox/streets-v12  # Optional
```

**Security Best Practices**:
- Token stored in `.env` (not in code)
- Documented as **PUBLIC token** with minimal scopes
- URL restrictions recommended
- Environment-based configuration

### File Locations
| Purpose | File | Lines |
|---------|------|-------|
| Interactive Map Hook | `assets/js/hooks/mapbox-venues-map.js` | 276 |
| Map Component | `lib/eventasaurus_web/components/mapbox_venues_map_component.ex` | 135 |
| Geocoding Provider | `lib/eventasaurus_discovery/geocoding/providers/mapbox.ex` | 281 |
| Search Provider | `assets/js/hooks/places-search/providers/mapbox-provider.js` | 389 |

---

## PART 3: Comparative Analysis

### Implementation Quality

| Feature | TriviaAdvisor V2 | Eventasaurus |
|---------|-----------------|--------------|
| **Interactivity** | Static iframe | Full interactive (pan, zoom, cluster) |
| **Number of Maps** | Single view only | Multiple views (venue map, search) |
| **Configuration** | Hardcoded | Environment-based (.env) |
| **Security** | ⚠️ KEY EXPOSED | ✅ Secure (token in .env) |
| **Feature Scope** | Display only | Display + Geocoding + Search |
| **Clustering** | N/A | Intelligent (10+ venues) |
| **API Keys** | 1 (Google) | 1 (Mapbox) |
| **Code Organization** | In view template | Separated (hooks, components, providers) |
| **Error Handling** | None | Comprehensive (timeout, rate-limit, auth) |
| **Dark Mode** | N/A | Supported |

### Cost Comparison

**Google Maps Embed API**:
- Free: Up to 25,000 requests/day
- No monthly limit
- Billing if exceeded
- ⚠️ Currently exposed key has no protection

**Mapbox**:
- Free: 100,000 geocoding requests/month
- Free: Unlimited map views (after initial load)
- $5/100k requests after free tier
- Session tokens reduce costs (5 requests per session free)

---

## PART 4: Recommendations

### Option A: Remove Maps Entirely ✅ RECOMMENDED FOR V2

**Rationale**:
- Maps are "nice-to-have" not critical
- Simple venue information (address, coordinates) already displayed
- Directions link to Google Maps available
- No user queries for map features in V2
- Removes security vulnerability
- Simplifies deployment
- Zero ongoing maintenance

**Action Items**:
1. Delete lines 180-216 from `venue_show_live.ex`
2. Verify address still displays (lines 174-178)
3. Test: Venues without coordinates still show address
4. Remove any unused imports
5. Test mobile responsiveness

**Code Change**:
```heex
<!-- REMOVE: Lines 180-216 (iframe and directions) -->
<!-- KEEP: Address display lines 174-178 -->
<%= if @venue.address do %>
  <p class="text-gray-700 mb-2"><%= @venue.address %></p>
<% end %>
<p class="text-gray-600 mb-4"><%= @city.name %>, <%= @country.name %></p>
<!-- Users can still use native phone/map apps for directions -->
```

**Security Benefit**: Removes hardcoded API key from codebase

---

### Option B: Migrate to Mapbox (If Maps Needed Later)

**Only pursue if maps become business requirement**

**Steps**:
1. Set up Mapbox account (free tier: $0)
2. Create `.env` variable: `MAPBOX_ACCESS_TOKEN=...`
3. Port Eventasaurus Mapbox components:
   - Copy `mapbox-venues-map.js` hook
   - Copy `mapbox_venues_map_component.ex`
   - Register hook in `app.js`
4. Update `venue_show_live.ex`:
   ```heex
   <.live_component
     module={TriviaAdvisorWeb.MapboxVenuesMapComponent}
     id="venue-map"
     venues={[@venue]}
     city={@city}
   />
   ```

**Advantages of Mapbox**:
- ✅ No hardcoded keys
- ✅ Industry-standard interactive maps
- ✅ Better clustering support
- ✅ Geocoding API available
- ✅ Professional appearance

---

### Option C: Keep Current Google Maps (Not Recommended)

**Issues**:
- ⚠️ **Hardcoded API key must be rotated immediately**
- ❌ Limited interactivity
- ❌ No environment-based config
- ❌ Technical debt

**Only if choosing this**:
1. Move API key to environment variable
2. Configure in `config/runtime.exs`:
   ```elixir
   config :trivia_advisor, :google_maps,
     api_key: System.get_env("GOOGLE_MAPS_EMBED_KEY")
   ```
3. Update template:
   ```heex
   src={"https://www.google.com/maps/embed/v1/place?key=#{@google_maps_key}&q=#{@venue.latitude},#{@venue.longitude}&zoom=15"}
   ```
4. Pass to template: `assign(:google_maps_key, config(:google_maps)[:api_key])`

---

## Summary

| Aspect | Finding |
|--------|---------|
| **Current Status** | Google Maps embedded, hardcoded API key ⚠️ |
| **Functionality** | Works but minimal features, no user demand |
| **Security** | CRITICAL - API key exposed in public code |
| **Eventasaurus Example** | Sophisticated Mapbox setup with 4 components |
| **V2 Best Practice** | Remove maps (Option A) - not core feature |
| **If Maps Needed Later** | Use Mapbox (Option B) - proven implementation |
| **Migration Effort** | Trivial (delete 37 lines) for Option A |
| **Effort if Mapbox Later** | ~2 hours to port Eventasaurus components |

---

## Files Affected (Option A - Recommended)

**TriviaAdvisor V2**:
- `/lib/trivia_advisor_web/live/venue_show_live.ex` - Remove lines 180-216

**No other files require changes** (no configuration, no hooks, no components)

**Before**: Lines 91-344 (total)
**After**: Lines 91-307 (total) - 37 lines removed
