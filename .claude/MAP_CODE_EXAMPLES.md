# Map Implementation Code Examples

## Current Implementation in TriviaAdvisor V2

### File: `lib/trivia_advisor_web/live/venue_show_live.ex`

**Lines 180-216 (Current Code - To Be Evaluated)**

```heex
<%= if @venue.latitude && @venue.longitude do %>
  <div class="mt-4">
    <iframe
      width="100%"
      height="300"
      frameborder="0"
      style="border:0"
      referrerpolicy="no-referrer-when-downgrade"
      src={"https://www.google.com/maps/embed/v1/place?key=YOUR_GOOGLE_MAPS_KEY&q=#{@venue.latitude},#{@venue.longitude}&zoom=15"}
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
      <svg
        class="w-4 h-4 mr-1"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"
        >
        </path>
      </svg>
      Get Directions
    </a>
  </div>
<% end %>
```

**Issues with Current Code**:
- ⚠️ Hardcoded API key (REDACTED - was exposed in old code, now removed)
- No configuration management
- Static iframe (no interactivity)
- No error handling
- No fallback for disabled venue coordinates

---

## Option A: Simplified Version (Recommended)

### Code to Keep: Lines 174-178

```heex
<%= if @venue.address do %>
  <p class="text-gray-700 mb-2"><%= @venue.address %></p>
<% end %>

<p class="text-gray-600 mb-4"><%= @city.name %>, <%= @country.name %></p>
```

**Benefits**:
- ✓ Removes security vulnerability
- ✓ Simpler code
- ✓ Faster page loads
- ✓ No API key management
- ✓ No external dependencies

**What Users Lose**:
- Interactive map display (minimal impact - users can open in native maps app)

---

## Option B: Mapbox Implementation (Future Option)

### Component: `lib/trivia_advisor_web/components/mapbox_venues_map_component.ex`

```elixir
defmodule TriviaAdvisorWeb.MapboxVenuesMapComponent do
  @moduledoc """
  Interactive map component for displaying venue location using Mapbox.
  """
  use TriviaAdvisorWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="relative w-full h-[400px] rounded-lg overflow-hidden shadow-lg border border-gray-200">
      <div
        id={"mapbox-venue-map-#{@id}"}
        phx-hook="MapboxVenueMap"
        data-venue={Jason.encode!(prepare_venue_data(@venue))}
        class="w-full h-full"
      >
        <!-- Loading state -->
        <div class="flex items-center justify-center h-full bg-gray-100">
          <div class="text-center">
            <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <p class="text-gray-600 text-sm">Loading map...</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(socket), do: {:ok, socket}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  defp prepare_venue_data(venue) do
    %{
      id: venue.id,
      name: venue.name,
      address: venue.address,
      latitude: venue.latitude,
      longitude: venue.longitude,
      url: "/venues/#{venue.slug}"
    }
  end
end
```

### Hook: `assets/js/hooks/mapbox-venue-map.js`

```javascript
const MapboxVenueMap = {
  mounted() {
    this.initMap();
  },

  initMap() {
    if (!window.mapboxgl) {
      console.warn("Mapbox GL JS not loaded, retrying...");
      setTimeout(() => this.initMap(), 100);
      return;
    }

    if (!window.MAPBOX_ACCESS_TOKEN) {
      console.error("Mapbox access token not configured");
      return;
    }

    try {
      const venueData = JSON.parse(this.el.dataset.venue);
      
      mapboxgl.accessToken = window.MAPBOX_ACCESS_TOKEN;
      
      this.map = new mapboxgl.Map({
        container: this.el,
        style: 'mapbox://styles/mapbox/streets-v12',
        center: [venueData.longitude, venueData.latitude],
        zoom: 15
      });

      this.map.on('load', () => {
        new mapboxgl.Marker()
          .setLngLat([venueData.longitude, venueData.latitude])
          .setPopup(new mapboxgl.Popup({ offset: 25 })
            .setHTML(`<div class="p-2"><h3 class="font-semibold">${venueData.name}</h3></div>`))
          .addTo(this.map);
      });
    } catch (error) {
      console.error("Error initializing Mapbox:", error);
    }
  },

  destroyed() {
    if (this.map) {
      this.map.remove();
    }
  }
};

export default MapboxVenueMap;
```

### Template Usage in `venue_show_live.ex`

```heex
<.live_component
  module={TriviaAdvisorWeb.MapboxVenuesMapComponent}
  id="venue-map"
  venue={@venue}
/>
```

### Configuration

**File: `config/runtime.exs`**

```elixir
# Configure Mapbox for interactive maps
config :trivia_advisor, :mapbox,
  access_token: System.get_env("MAPBOX_ACCESS_TOKEN")
```

**File: `.env.example`**

```bash
# Maps (optional - only needed if using Mapbox)
# Get token from: https://account.mapbox.com/
MAPBOX_ACCESS_TOKEN=your_mapbox_token_here
```

**File: `assets/js/app.js`**

```javascript
import MapboxVenueMap from "./hooks/mapbox-venue-map";

let Hooks = {
  MapboxVenueMap: MapboxVenueMap,
  // ... other hooks
};

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});
```

---

## Option C: Secure Google Maps (Not Recommended)

### Configuration Approach

**File: `config/runtime.exs`**

```elixir
config :trivia_advisor, :google_maps,
  api_key: System.get_env("GOOGLE_MAPS_EMBED_KEY")
```

**File: `.env.example`**

```bash
GOOGLE_MAPS_EMBED_KEY=your_google_maps_embed_key_here
```

### Template Update

```heex
<%= if @venue.latitude && @venue.longitude do %>
  <div class="mt-4">
    <iframe
      width="100%"
      height="300"
      frameborder="0"
      style="border:0"
      referrerpolicy="no-referrer-when-downgrade"
      src={"https://www.google.com/maps/embed/v1/place?key=#{@google_maps_key}&q=#{@venue.latitude},#{@venue.longitude}&zoom=15"}
      allowfullscreen
      class="rounded-lg shadow-md"
    >
    </iframe>
  </div>
<% end %>
```

### Pass Configuration to Template

```elixir
# In render/1 function
render(assigns) do
  google_maps_key = Application.get_env(:trivia_advisor, :google_maps)[:api_key]
  
  assigns =
    assigns
    |> assign(:google_maps_key, google_maps_key)
```

**Issues with this approach**:
- Still requires API key management
- Limited features
- No configuration per environment

---

## Comparison Table

| Aspect | Option A (Remove) | Option B (Mapbox) | Option C (Google) |
|--------|-------------------|-------------------|-------------------|
| **Implementation** | Delete 37 lines | Copy 2 files + hook | Move to .env + update |
| **Security** | ✓ Removes key | ✓ Env-based | ✓ Env-based |
| **Interactivity** | None (keep address) | Full interactive | Static iframe |
| **Configuration** | N/A | Simple (.env) | Simple (.env) |
| **Time Estimate** | 5 min | 2 hours | 1 hour |
| **Maintenance** | None | Low | Medium |
| **Recommended** | ✓ YES | If needed later | Not recommended |

---

## Verification Checklist

After implementing any option:

- [ ] Address display works
- [ ] Mobile responsive
- [ ] No console errors
- [ ] API key not exposed (if applicable)
- [ ] Configuration in .env (if applicable)
- [ ] No hardcoded credentials
- [ ] Tests pass
- [ ] Page loads quickly
- [ ] Fallback works if coordinates missing
- [ ] Documentation updated

