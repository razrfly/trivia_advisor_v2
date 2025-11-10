defmodule TriviaAdvisorWeb.HomeLive do
  @moduledoc """
  Home page LiveView - landing page for Trivia Advisor.
  Displays popular cities and welcome content.
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisor.Locations
  alias TriviaAdvisorWeb.Components.SEO.{MetaTags, Breadcrumbs}
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer}
  alias TriviaAdvisorWeb.Components.Cards.{CityCard, VenueCard}

  @impl true
  def mount(_params, _session, socket) do
    # Fetch popular cities for display
    cities = Locations.get_popular_cities(12)
    latest_venues = Locations.get_latest_venues(10)

    # Get stats
    venue_count = Locations.count_venues_with_trivia()
    city_count = Locations.count_cities_with_trivia()
    country_count = Locations.count_countries_with_trivia()

    socket =
      socket
      |> assign(:page_title, "Find Trivia Nights Near You")
      |> assign(:cities, cities)
      |> assign(:latest_venues, latest_venues)
      |> assign(:venue_count, venue_count)
      |> assign(:city_count, city_count)
      |> assign(:country_count, country_count)
      |> assign(:base_url, get_base_url())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    meta = MetaTags.home_meta_tags(assigns.base_url)
    breadcrumbs = Breadcrumbs.home_breadcrumbs(assigns.base_url)

    assigns =
      assigns
      |> assign(:meta, meta)
      |> assign(:breadcrumbs, breadcrumbs)

    ~H"""
    <div class="flex flex-col min-h-screen bg-gray-50">
      <!-- SEO Meta Tags -->
      <MetaTags.meta_tags {Map.to_list(@meta)} />

      <!-- Header -->
      <Header.site_header current_path="/" />

      <!-- Main Content -->
      <main class="flex-1">
        <!-- Breadcrumbs -->
        <div class="container mx-auto px-4 py-4">
          <Breadcrumbs.breadcrumbs items={@breadcrumbs} />
        </div>

        <!-- Hero Section -->
        <div class="bg-gradient-to-r from-blue-600 to-purple-600 text-white">
          <div class="container mx-auto px-4 py-16 text-center">
            <h1 class="text-5xl font-bold mb-4">
              Trivia Advisor
            </h1>
            <p class="text-xl mb-8">
              Discover the best trivia nights, pub quizzes, and quiz events near you
            </p>

            <!-- Stats -->
            <div class="flex justify-center gap-8 mt-8">
              <div class="text-center">
                <div class="text-4xl font-bold"><%= @venue_count %></div>
                <div class="text-blue-100 mt-1">Venues</div>
              </div>
              <div class="text-center">
                <div class="text-4xl font-bold"><%= @city_count %></div>
                <div class="text-blue-100 mt-1">Cities</div>
              </div>
              <div class="text-center">
                <div class="text-4xl font-bold"><%= @country_count %></div>
                <div class="text-blue-100 mt-1">Countries</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Latest Venues Section -->
        <div class="container mx-auto px-4 py-12">
          <h2 class="text-3xl font-bold mb-2 text-gray-900">
            Latest Trivia Venues
          </h2>
          <p class="text-gray-600 mb-8">
            Recently added venues hosting trivia nights
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-6">
            <%= for venue <- @latest_venues do %>
              <VenueCard.venue_card
                venue={venue}
                country_slug={venue.city.country.slug}
                city_slug={venue.city.slug}
                base_url={@base_url}
              />
            <% end %>
          </div>
        </div>

        <!-- Popular Cities Grid -->
        <div class="bg-white py-12">
          <div class="container mx-auto px-4">
            <h2 class="text-3xl font-bold mb-8 text-gray-900">
              Explore Trivia by City
            </h2>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              <%= for city <- @cities do %>
                <CityCard.city_card city={city} base_url={@base_url} />
              <% end %>
            </div>
          </div>
        </div>

        <!-- About Section -->
        <div class="bg-gray-50 py-12">
          <div class="container mx-auto px-4">
            <div class="max-w-3xl mx-auto text-center">
              <h2 class="text-3xl font-bold mb-4 text-gray-900">
                Welcome to Trivia Advisor
              </h2>
              <p class="text-lg text-gray-700 mb-6">
                Find the perfect trivia night, pub quiz, or quiz event in your area.
                We help you discover venues, check schedules, and connect with the trivia community.
              </p>
              <.link
                navigate="/about"
                class="inline-block px-6 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors"
              >
                Learn More
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

  defp get_base_url do
    Application.get_env(:trivia_advisor, :base_url, "https://quizadvisor.com")
  end
end
