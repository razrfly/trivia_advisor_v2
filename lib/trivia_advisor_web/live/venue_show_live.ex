defmodule TriviaAdvisorWeb.VenueShowLive do
  @moduledoc """
  Venue page LiveView - displays venue details and trivia events.
  Matches V1 route pattern: /{country-slug}/{city-slug}/{venue-slug}/
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisor.{Locations, Events}
  alias TriviaAdvisorWeb.Helpers.SEOHelpers
  alias TriviaAdvisorWeb.JsonLd.{VenueSchema, BreadcrumbListSchema}
  alias TriviaAdvisorWeb.Components.SEO.{MetaTags, Breadcrumbs}
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer}
  alias TriviaAdvisorWeb.Components.Cards.EventCard
  alias TriviaAdvisorWeb.Components.UI.EmptyState

  @impl true
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
      events = Events.get_events_for_venue(venue.id)
      nearby_venues = Locations.find_venues_near_venue(venue, 5)
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
          canonical_path: "/#{country.slug}/#{city.slug}/#{venue.slug}",
          json_ld: combined_json_ld
        )

      {:ok, socket}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Venue not found")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
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
      <Header.site_header current_path={
        "#{@base_url}/#{@country.slug}/#{@city.slug}/#{@venue.slug}"
      } />

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
            <!-- Left Column: Venue Details -->
            <div class="lg:col-span-2">
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
                  <p class="text-blue-800">
                    <%= next_quiz["date"] %>
                    <%= if next_quiz["start_time"] do %>
                      at <%= next_quiz["start_time"] %>
                    <% end %>
                  </p>
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

            <!-- Right Column: Image & Contact -->
            <div>
              <!-- Venue Image -->
              <%= if primary_image = Locations.Venue.primary_image(@venue) do %>
                <div class="mb-6">
                  <img
                    src={primary_image["url"]}
                    alt={primary_image["alt"] || @venue.name}
                    class="w-full h-64 object-cover rounded-lg shadow-md"
                  />
                </div>
              <% end %>

              <!-- Venue Type Badge -->
              <%= if @venue.venue_type do %>
                <div class="mb-6">
                  <span class="inline-block px-3 py-1 bg-blue-100 text-blue-800 text-sm font-medium rounded-full">
                    <%= @venue.venue_type %>
                  </span>
                </div>
              <% end %>
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
            action_path={"#{@base_url}/#{@country.slug}/#{@city.slug}"}
          />
        <% else %>
          <div class="space-y-6">
            <%= for event <- @events do %>
              <EventCard.event_card event={event} />
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
                <a
                  href={"#{@base_url}/#{nearby_venue.city.country.slug}/#{nearby_venue.city.slug}/#{nearby_venue.slug}"}
                  class="block bg-gray-50 rounded-lg p-6 hover:bg-gray-100 transition-colors border border-gray-200 hover:border-blue-500"
                >
                  <div class="flex items-start justify-between mb-3">
                    <h3 class="text-lg font-semibold text-gray-900 flex-1">
                      <%= nearby_venue.name %>
                    </h3>
                    <%= if distance = Locations.distance_between_venues(@venue, nearby_venue) do %>
                      <span class="ml-3 px-2 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded-full flex-shrink-0">
                        <%= distance %> km
                      </span>
                    <% end %>
                  </div>

                  <%= if nearby_venue.address do %>
                    <p class="text-sm text-gray-600 mb-2">
                      <%= nearby_venue.address %>
                    </p>
                  <% end %>

                  <p class="text-sm text-gray-500">
                    <%= nearby_venue.city.name %><%= if nearby_venue.city.name != @city.name do %>, <%= nearby_venue.city.country.name %><% end %>
                  </p>

                  <%= if nearby_venue.venue_type do %>
                    <div class="mt-3">
                      <span class="inline-block px-2 py-1 bg-gray-200 text-gray-700 text-xs font-medium rounded">
                        <%= nearby_venue.venue_type %>
                      </span>
                    </div>
                  <% end %>
                </a>
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
    events
    |> Enum.map(&Events.get_next_occurrence/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1["date"])
    |> List.first()
  end
end
