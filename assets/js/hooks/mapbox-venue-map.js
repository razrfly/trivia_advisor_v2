/**
 * MapboxVenueMap Hook
 *
 * Renders a simple Mapbox GL JS map showing a single venue marker.
 */

const MapboxVenueMap = {
  mounted() {
    this.initMap();
  },

  initMap() {
    // Wait for Mapbox GL to be loaded
    if (!window.mapboxgl) {
      console.warn("Mapbox GL JS not loaded, retrying...");
      setTimeout(() => this.initMap(), 100);
      return;
    }

    // Check for access token
    if (!window.MAPBOX_ACCESS_TOKEN) {
      console.error("Mapbox access token not configured");
      this.showError("Map configuration error");
      return;
    }

    try {
      const lat = parseFloat(this.el.dataset.lat);
      const lng = parseFloat(this.el.dataset.lng);
      const venueName = this.el.dataset.name;

      if (isNaN(lat) || isNaN(lng)) {
        console.error("Invalid coordinates");
        this.showError("Invalid venue location");
        return;
      }

      // Set access token
      mapboxgl.accessToken = window.MAPBOX_ACCESS_TOKEN;

      // Initialize map
      this.map = new mapboxgl.Map({
        container: this.el,
        style: 'mapbox://styles/mapbox/streets-v12',
        center: [lng, lat],
        zoom: 15
      });

      // Add navigation controls
      this.map.addControl(new mapboxgl.NavigationControl());

      // Add marker
      new mapboxgl.Marker({ color: '#2563eb' })
        .setLngLat([lng, lat])
        .setPopup(
          new mapboxgl.Popup({ offset: 25 })
            .setHTML(`
              <div class="p-2">
                <h3 class="font-semibold text-gray-900">${venueName}</h3>
              </div>
            `)
        )
        .addTo(this.map);

    } catch (error) {
      console.error("Error initializing Mapbox venue map:", error);
      this.showError("Failed to load map");
    }
  },

  showError(message) {
    this.el.innerHTML = `
      <div class="flex items-center justify-center h-full bg-red-50 rounded-lg">
        <div class="text-center">
          <svg class="w-8 h-8 text-red-600 mx-auto mb-2" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
          </svg>
          <p class="text-red-600">${message}</p>
        </div>
      </div>
    `;
  },

  destroyed() {
    if (this.map) {
      this.map.remove();
    }
  }
};

export default MapboxVenueMap;
