defmodule TriviaAdvisorWeb.VenueShowLive do
  @moduledoc """
  Venue page LiveView - displays venue details and trivia events.
  Supports both flat (/venues/{slug}) and hierarchical patterns for backward compatibility.

  Also handles smart 404s with fuzzy matching:
  - High confidence match (≥90%): 301 redirect to correct venue
  - Medium confidence matches (≥70%): Show "Did you mean?" suggestions
  - No matches: Show standard 404 page
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisor.{Locations, Events, VenueMatcher}
  alias TriviaAdvisorWeb.Helpers.{SEOHelpers, ImageHelpers}
  alias TriviaAdvisorWeb.JsonLd.{VenueSchema, BreadcrumbListSchema}
  alias TriviaAdvisorWeb.Components.SEO.{MetaTags, Breadcrumbs}
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer}
  alias TriviaAdvisorWeb.Components.Cards.{EventCard, VenueCard}
  alias TriviaAdvisorWeb.Components.UI.EmptyState

  @impl true
  # Flat URL pattern: /venues/{venue-slug}
  def mount(%{"venue_slug" => venue_slug} = params, _session, socket)
      when not is_map_key(params, "country_slug") and not is_map_key(params, "city_slug") do
    case Locations.get_venue_by_slug(venue_slug) do
      %{city: %{country: country} = city} = venue ->
        # Venue found with city and country preloaded
        load_venue_page(venue, city, country, socket)

      _ ->
        # Venue not found - try smart matching
        handle_missing_venue(venue_slug, socket)
    end
  end

  # Hierarchical URL pattern: /{country-slug}/{city-slug}/{venue-slug}
  def mount(
        %{"country_slug" => country_slug, "city_slug" => city_slug, "venue_slug" => venue_slug},
        _session,
        socket
      ) do
    with country when not is_nil(country) <- Locations.get_country_by_slug(country_slug),
         city when not is_nil(city) <- Locations.get_city_by_slug(city_slug),
         true <- city.country_id == country.id,
         venue when not is_nil(venue) <- Locations.get_venue_by_slug(venue_slug),
         true <- venue.city_id == city.id do
      # Use common helper to load venue page
      load_venue_page(venue, city, country, socket)
    else
      _ ->
        # Any failure (invalid country/city/venue or mismatched IDs) - try smart matching
        # This provides a helpful user experience regardless of which part of the URL was wrong
        handle_missing_venue(venue_slug, socket)
    end
  end

  # Handle missing venue with smart fuzzy matching
  defp handle_missing_venue(missing_slug, socket) do
    case VenueMatcher.find_similar(missing_slug) do
      {:redirect, venue, _confidence} ->
        # High confidence match - redirect to correct venue
        # Note: LiveView redirect is client-side; for SEO 301, would need Plug-level handling
        {:ok,
         socket
         |> redirect(to: "/venues/#{venue.slug}")}

      {:suggestions, suggestions} ->
        # Medium confidence - show suggestions page
        load_suggestions_page(missing_slug, suggestions, socket)

      :no_match ->
        # No matches - show 404 page
        load_not_found_page(missing_slug, socket)
    end
  end

  # Load suggestions page when multiple possible matches found
  defp load_suggestions_page(missing_slug, suggestions, socket) do
    base_url = get_base_url()

    socket =
      socket
      |> assign(:page_mode, :suggestions)
      |> assign(:missing_slug, missing_slug)
      |> assign(:suggestions, suggestions)
      |> assign(:base_url, base_url)
      |> SEOHelpers.assign_meta_tags(
        title: "Venue Not Found - Did You Mean?",
        description: "The venue '#{missing_slug}' was not found. Here are similar venues you might be looking for.",
        type: "website",
        canonical_path: "/venues/#{missing_slug}"
      )

    {:ok, socket}
  end

  # Load 404 page when no matches found
  defp load_not_found_page(missing_slug, socket) do
    base_url = get_base_url()

    socket =
      socket
      |> assign(:page_mode, :not_found)
      |> assign(:missing_slug, missing_slug)
      |> assign(:base_url, base_url)
      |> SEOHelpers.assign_meta_tags(
        title: "Venue Not Found",
        description: "The venue '#{missing_slug}' could not be found. This venue may have closed or been removed.",
        type: "website",
        canonical_path: "/venues/#{missing_slug}"
      )

    {:ok, socket}
  end

  # Common helper to load venue page data (used by both flat and hierarchical routes)
  defp load_venue_page(venue, city, country, socket) do
    events = Events.get_events_for_venue(venue.id)
    nearby_venues = Events.get_nearby_trivia_venues(venue, 5)
    base_url = get_base_url()

    # Generate JSON-LD structured data for venue and breadcrumbs
    venue_json_ld = VenueSchema.generate(venue)
    breadcrumbs = BreadcrumbListSchema.build_venue_breadcrumbs(venue, base_url)
    breadcrumbs_json_ld = BreadcrumbListSchema.generate(breadcrumbs)

    # Combine JSON-LD schemas
    combined_json_ld = "[#{venue_json_ld},#{breadcrumbs_json_ld}]"

    # Build meta description
    event_count = length(events)

    description =
      if event_count > 0 do
        "#{venue.name} in #{city.name}, #{country.name} - #{event_count} trivia events. Find trivia nights, pub quizzes, and quiz events."
      else
        "#{venue.name} in #{city.name}, #{country.name} - Trivia venue information and events."
      end

    socket =
      socket
      |> assign(:page_mode, :venue)
      |> assign(:country, country)
      |> assign(:city, city)
      |> assign(:venue, venue)
      |> assign(:events, events)
      |> assign(:nearby_venues, nearby_venues)
      |> assign(:base_url, base_url)
      |> SEOHelpers.assign_meta_tags(
        title: "#{venue.name} - Trivia in #{city.name}, #{country.name}",
        description: description,
        type: "website",
        canonical_path: "/venues/#{venue.slug}",
        json_ld: combined_json_ld
      )

    {:ok, socket}
  end

  @impl true
  def render(%{page_mode: :suggestions} = assigns) do
    render_suggestions_page(assigns)
  end

  def render(%{page_mode: :not_found} = assigns) do
    render_not_found_page(assigns)
  end

  def render(%{page_mode: :venue} = assigns) do
    render_venue_page(assigns)
  end

  # Fallback for backwards compatibility
  def render(assigns) do
    render_venue_page(assigns)
  end

  # Render the suggestions page ("Did you mean?")
  defp render_suggestions_page(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen bg-gray-50">
      <!-- Header -->
      <Header.site_header current_path={"/venues/#{@missing_slug}"} />

      <!-- Main Content -->
      <main class="flex-1">
        <div class="max-w-4xl mx-auto px-4 py-16">
          <div class="text-center mb-12">
            <div class="text-6xl mb-6">🔍</div>
            <h1 class="text-4xl font-bold text-gray-900 mb-4">
              Venue Not Found
            </h1>
            <p class="text-xl text-gray-600">
              We couldn't find "<span class="font-mono bg-gray-100 px-2 py-1 rounded"><%= @missing_slug %></span>", but we found similar venues:
            </p>
          </div>

          <div class="space-y-4 mb-12">
            <%= for {venue, confidence} <- @suggestions do %>
              <.link navigate={~p"/venues/#{venue.slug}"}
                    class="block p-6 bg-white rounded-lg shadow hover:shadow-lg transition border border-gray-200 hover:border-blue-300">
                <div class="flex items-center justify-between">
                  <div>
                    <h3 class="text-xl font-semibold text-gray-900">
                      <%= venue.name %>
                    </h3>
                    <p class="text-gray-600 mt-1">
                      <%= if venue.city do %>
                        <%= venue.city.name %><%= if venue.city.country do %>, <%= venue.city.country.name %><% end %>
                      <% end %>
                    </p>
                    <p class="text-sm text-gray-500 mt-2 font-mono">
                      /venues/<%= venue.slug %>
                    </p>
                  </div>
                  <div class="text-right flex-shrink-0 ml-4">
                    <span class={"inline-flex items-center px-3 py-1 rounded-full text-sm font-medium #{confidence_badge_class(confidence)}"}>
                      <%= Float.round(confidence * 100, 0) |> trunc() %>% match
                    </span>
                  </div>
                </div>
              </.link>
            <% end %>
          </div>

          <div class="text-center">
            <p class="text-gray-600 mb-4">
              Can't find what you're looking for?
            </p>
            <div class="flex flex-wrap justify-center gap-4">
              <.link navigate={~p"/search"}
                    class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                Search All Venues
              </.link>
              <.link navigate={~p"/"}
                    class="inline-flex items-center px-6 py-3 border border-gray-300 text-base font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
                Go Home
              </.link>
            </div>
          </div>
        </div>
      </main>

      <!-- Footer -->
      <Footer.site_footer />
    </div>
    """
  end

  # Render the 404 page (no matches found)
  defp render_not_found_page(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen bg-gray-50">
      <!-- Header -->
      <Header.site_header current_path={"/venues/#{@missing_slug}"} />

      <!-- Main Content -->
      <main class="flex-1">
        <div class="max-w-4xl mx-auto px-4 py-16">
          <div class="text-center">
            <div class="text-6xl mb-6">🎯</div>
            <h1 class="text-4xl font-bold text-gray-900 mb-4">
              Venue Not Found
            </h1>
            <p class="text-xl text-gray-600 mb-8">
              The venue "<span class="font-mono bg-gray-100 px-2 py-1 rounded"><%= @missing_slug %></span>" could not be found.
            </p>
            <p class="text-gray-500 mb-8">
              This venue may have closed, been removed, or the URL may be incorrect.
            </p>

            <div class="flex flex-wrap justify-center gap-4">
              <.link navigate={~p"/search"}
                    class="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                Search Venues
              </.link>
              <.link navigate={~p"/cities"}
                    class="inline-flex items-center px-6 py-3 border border-gray-300 text-base font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                </svg>
                Browse Cities
              </.link>
              <.link navigate={~p"/"}
                    class="inline-flex items-center px-6 py-3 border border-gray-300 text-base font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
                Go Home
              </.link>
            </div>
          </div>
        </div>
      </main>

      <!-- Footer -->
      <Footer.site_footer />
    </div>
    """
  end

  # Helper for confidence badge styling
  defp confidence_badge_class(confidence) when confidence >= 0.90, do: "bg-green-100 text-green-800"
  defp confidence_badge_class(confidence) when confidence >= 0.80, do: "bg-blue-100 text-blue-800"
  defp confidence_badge_class(_confidence), do: "bg-yellow-100 text-yellow-800"

  # Render the regular venue page
  defp render_venue_page(assigns) do
    meta = MetaTags.venue_meta_tags(assigns.venue, assigns.city, assigns.country, assigns.base_url)

    breadcrumbs =
      Breadcrumbs.venue_breadcrumbs(
        assigns.venue,
        assigns.city,
        assigns.country,
        assigns.base_url
      )

    assigns =
      assigns
      |> assign(:meta, meta)
      |> assign(:breadcrumbs, breadcrumbs)

    ~H"""
    <div class="flex flex-col min-h-screen bg-gray-50">
      <!-- SEO Meta Tags -->
      <MetaTags.meta_tags {Map.to_list(@meta)} />

      <!-- Header -->
      <Header.site_header current_path={"/venues/#{@venue.slug}"} />

      <!-- Main Content -->
      <main class="flex-1">
        <!-- Breadcrumbs -->
        <div class="container mx-auto px-4 py-4">
          <Breadcrumbs.breadcrumbs items={@breadcrumbs} />
        </div>

      <!-- Venue Header -->
      <div class="bg-white border-b">
        <div class="container mx-auto px-4 py-8">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">
            <%= @venue.name %>
          </h1>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <!-- Left Column: Images & Contact -->
            <div class="lg:col-span-2">
              <!-- Venue Images Gallery -->
              <%= case ImageHelpers.get_venue_gallery_images(@venue, @city) do %>
                <% [single_image] -> %>
                  <!-- Single image layout -->
                  <div class="mb-6">
                    <img
                      src={single_image["url"]}
                      alt={single_image["alt"] || @venue.name}
                      class="w-full h-48 object-cover rounded-lg shadow-md"
                    />
                  </div>
                <% [main_image | [_ | _] = rest_images] -> %>
                  <!-- Multiple images grid: 1 large + 2 smaller thumbnails -->
                  <div class="mb-6">
                    <div class="grid grid-cols-2 gap-2">
                      <!-- Main large image -->
                      <div class="col-span-2">
                        <img
                          src={main_image["url"]}
                          alt={main_image["alt"] || @venue.name}
                          class="w-full h-48 object-cover rounded-lg shadow-md"
                        />
                      </div>

                      <!-- Thumbnail images (limited to 2) -->
                      <%= for image <- Enum.take(rest_images, 2) do %>
                        <div class="aspect-square">
                          <img
                            src={image["url"]}
                            alt={image["alt"] || @venue.name}
                            class="w-full h-full object-cover rounded-lg shadow-md"
                          />
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% _ -> %>
                  <!-- No images available -->
              <% end %>

              <!-- Venue Type Badge -->
              <%= if @venue.venue_type do %>
                <div class="mb-6">
                  <span class="inline-block px-3 py-1 bg-blue-100 text-blue-800 text-sm font-medium rounded-full">
                    <%= @venue.venue_type %>
                  </span>
                </div>
              <% end %>

              <!-- Contact Information -->
              <%= if (@venue.metadata && @venue.metadata["phone"]) || (@venue.metadata && @venue.metadata["website"]) do %>
                <div class="bg-gray-50 rounded-lg p-6">
                  <h3 class="text-xl font-semibold text-gray-900 mb-4 flex items-center">
                    <svg
                      class="w-5 h-5 mr-2 text-blue-600"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                      >
                      </path>
                    </svg>
                    Contact
                  </h3>

                  <div class="space-y-3">
                    <%= if @venue.metadata["phone"] do %>
                      <a
                        href={"tel:#{@venue.metadata["phone"]}"}
                        class="flex items-center text-gray-700 hover:text-blue-600 transition-colors"
                      >
                        <svg
                          class="w-5 h-5 mr-3 text-blue-600"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"
                          >
                          </path>
                        </svg>
                        <span><%= @venue.metadata["phone"] %></span>
                      </a>
                    <% end %>

                    <%= if @venue.metadata["website"] do %>
                      <a
                        href={@venue.metadata["website"]}
                        target="_blank"
                        rel="noopener noreferrer"
                        class="flex items-center text-gray-700 hover:text-blue-600 transition-colors"
                      >
                        <svg
                          class="w-5 h-5 mr-3 text-blue-600"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"
                          >
                          </path>
                        </svg>
                        <span>Visit website</span>
                      </a>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Right Column: Location & Map -->
            <div>
              <!-- Next Quiz Night -->
              <%= if next_quiz = get_next_quiz_night(@events) do %>
                <div class="mb-6 p-4 bg-blue-50 border-l-4 border-blue-600 rounded-r-lg">
                  <h2 class="text-lg font-semibold text-blue-900 mb-2 flex items-center">
                    <svg
                      class="w-5 h-5 mr-2"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                      >
                      </path>
                    </svg>
                    Next Quiz Night
                  </h2>
                  <p class="text-blue-800 mb-3">
                    <%= next_quiz["date"] %>
                    <%= if next_quiz["start_time"] do %>
                      at <%= next_quiz["start_time"] %>
                    <% end %>
                  </p>

                  <%= if first_event = List.first(@events) do %>
                    <!-- Source Attribution -->
                    <div class="flex flex-wrap items-center gap-2 text-xs text-blue-700 border-t border-blue-200 pt-3">
                      <%= if first_event.last_seen_at do %>
                        <span class="flex items-center">
                          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                            >
                            </path>
                          </svg>
                          Updated <%= TriviaAdvisor.Events.PublicEvent.time_ago(first_event.last_seen_at) %>
                        </span>
                      <% end %>

                      <%= if first_event.source_name do %>
                        <span class="mx-1">•</span>
                        <span class="flex items-center">
                          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              stroke-width="2"
                              d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
                            >
                            </path>
                          </svg>
                          Source:
                          <a
                            href={if first_event.activity_slug, do: "https://wombie.com/activities/#{first_event.activity_slug}", else: "https://wombie.com"}
                            target="_blank"
                            rel="noopener noreferrer"
                            class="text-blue-600 hover:text-blue-800 hover:underline ml-1"
                          >
                            <%= first_event.source_name %>
                          </a>
                        </span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <!-- Location Section -->
              <div class="mb-6">
                <h2 class="text-2xl font-semibold text-gray-900 mb-3 flex items-center">
                  <svg
                    class="w-6 h-6 mr-2 text-gray-700"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
                    >
                    </path>
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
                    >
                    </path>
                  </svg>
                  Location
                </h2>

                <%= if @venue.address do %>
                  <p class="text-gray-700 mb-2"><%= @venue.address %></p>
                <% end %>

                <p class="text-gray-600 mb-4"><%= @city.name %>, <%= @country.name %></p>

                <%= if @venue.latitude && @venue.longitude do %>
                  <div class="mt-4">
                    <div
                      id="venue-map"
                      phx-hook="MapboxVenueMap"
                      data-lat={@venue.latitude}
                      data-lng={@venue.longitude}
                      data-name={@venue.name}
                      class="w-full h-[300px] rounded-lg shadow-md"
                    >
                      <!-- Loading state -->
                      <div class="flex items-center justify-center h-full bg-gray-100">
                        <p class="text-gray-600 text-sm">Loading map...</p>
                      </div>
                    </div>
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
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Events Section -->
      <div class="container mx-auto px-4 py-12">
        <h2 class="text-3xl font-bold text-gray-900 mb-6">
          Trivia Events at <%= @venue.name %>
        </h2>

        <%= if Enum.empty?(@events) do %>
          <EmptyState.empty_state
            icon="🎤"
            title="No trivia events currently listed"
            description={"Check back soon or explore other venues in #{@city.name}."}
            action_text={"← Back to #{@city.name}"}
            action_path={"/#{@country.slug}/#{@city.slug}"}
          />
        <% else %>
          <div class="space-y-6">
            <%= for event <- @events do %>
              <EventCard.event_card event={event} country={@country} />
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Nearby Venues Section -->
      <%= if !Enum.empty?(@nearby_venues) do %>
        <div class="bg-white border-t">
          <div class="container mx-auto px-4 py-12">
            <h2 class="text-3xl font-bold text-gray-900 mb-6 flex items-center">
              <svg
                class="w-8 h-8 mr-3 text-blue-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
                >
                </path>
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
                >
                </path>
              </svg>
              Nearby Trivia Venues
            </h2>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for nearby_venue <- @nearby_venues do %>
                <VenueCard.venue_card
                  venue={nearby_venue}
                  show_city={nearby_venue.city_name != @city.name}
                  show_distance={true}
                />
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </main>

      <!-- Footer -->
      <Footer.site_footer />
    </div>
    """
  end

  defp get_base_url do
    Application.get_env(:trivia_advisor, :base_url, "https://quizadvisor.com")
  end

  defp get_next_quiz_night([]), do: nil

  defp get_next_quiz_night(events) do
    # Optimized: use reduce to find minimum in single pass instead of map + sort
    events
    |> Enum.reduce(nil, fn event, acc ->
      case Events.get_next_occurrence(event) do
        nil -> acc
        occurrence ->
          case acc do
            nil -> occurrence
            existing ->
              if Date.compare(occurrence["date_value"], existing["date_value"]) == :lt do
                occurrence
              else
                existing
              end
          end
      end
    end)
  end
end
