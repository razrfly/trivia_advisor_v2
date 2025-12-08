defmodule TriviaAdvisorWeb.LatestEventsLive do
  @moduledoc """
  Latest Events LiveView - displays the most recently added/updated trivia venues.
  Shows a paginated grid of venue cards ordered by last_seen_at date.
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisor.Locations
  alias TriviaAdvisorWeb.Components.SEO.{MetaTags, Breadcrumbs}
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer}
  alias TriviaAdvisorWeb.Components.Cards.VenueCard

  @default_limit 24

  @impl true
  def mount(_params, _session, socket) do
    base_url = get_base_url()

    # Fetch latest venues (more than homepage shows)
    latest_venues = Locations.get_latest_venues(@default_limit)

    socket =
      socket
      |> assign(:page_title, "Latest Trivia Events")
      |> assign(:latest_venues, latest_venues)
      |> assign(:base_url, base_url)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    meta = %{
      title: "Latest Trivia Events | Trivia Advisor",
      description: "Discover the newest trivia nights, pub quizzes, and quiz events added to Trivia Advisor. Find recently added venues hosting trivia near you.",
      url: "#{assigns.base_url}/events/latest",
      type: "website",
      image: nil,
      twitter_card: "summary_large_image"
    }

    breadcrumbs = [
      %{name: "Home", url: assigns.base_url},
      %{name: "Latest Events", url: nil}
    ]

    assigns =
      assigns
      |> assign(:meta, meta)
      |> assign(:breadcrumbs, breadcrumbs)

    ~H"""
    <div class="flex flex-col min-h-screen bg-gray-50">
      <!-- SEO Meta Tags -->
      <MetaTags.meta_tags {Map.to_list(@meta)} />

      <!-- Header -->
      <Header.site_header current_path="/events/latest" />

      <!-- Main Content -->
      <main class="flex-1">
        <!-- Breadcrumbs -->
        <div class="container mx-auto px-4 py-4">
          <Breadcrumbs.breadcrumbs items={@breadcrumbs} />
        </div>

        <!-- Page Header -->
        <div class="bg-white border-b">
          <div class="container mx-auto px-4 py-8">
            <h1 class="text-4xl font-bold text-gray-900 mb-2">
              Latest Trivia Events
            </h1>
            <p class="text-lg text-gray-600">
              Discover the newest trivia nights and pub quizzes added to Trivia Advisor
            </p>
          </div>
        </div>

        <!-- Venues Grid -->
        <div class="container mx-auto px-4 py-12">
          <%= if Enum.empty?(@latest_venues) do %>
            <!-- Empty State -->
            <div class="text-center py-12">
              <svg
                class="w-24 h-24 mx-auto text-gray-400 mb-4"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                />
              </svg>
              <h2 class="text-2xl font-semibold text-gray-900 mb-2">No events found</h2>
              <p class="text-gray-600 mb-6">
                Check back soon for new trivia events!
              </p>
              <.link
                navigate="/"
                class="inline-block px-6 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors"
              >
                Back to Home
              </.link>
            </div>
          <% else %>
            <!-- Venue Cards Grid -->
            <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
              <%= for venue <- @latest_venues do %>
                <VenueCard.venue_card venue={venue} show_city={true} />
              <% end %>
            </div>
          <% end %>
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
