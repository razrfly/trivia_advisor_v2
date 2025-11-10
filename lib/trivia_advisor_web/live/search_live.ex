defmodule TriviaAdvisorWeb.SearchLive do
  @moduledoc """
  Search page LiveView - search for venues and cities.
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisor.Locations
  alias TriviaAdvisorWeb.Components.SEO.{MetaTags, Breadcrumbs}
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Search Trivia Venues and Cities")
      |> assign(:query, "")
      |> assign(:venues, [])
      |> assign(:cities, [])
      |> assign(:searched, false)
      |> assign(:base_url, get_base_url())

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)

    if String.length(query) >= 2 do
      venues = Locations.search_venues(query, 20)

      # Search cities
      cities =
        Locations.get_popular_cities(100)
        |> Enum.filter(fn city ->
          String.contains?(String.downcase(city.name), String.downcase(query))
        end)
        |> Enum.take(20)

      socket =
        socket
        |> assign(:query, query)
        |> assign(:venues, venues)
        |> assign(:cities, cities)
        |> assign(:searched, true)

      {:noreply, socket}
    else
      socket =
        socket
        |> assign(:query, query)
        |> assign(:venues, [])
        |> assign(:cities, [])
        |> assign(:searched, false)

      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    meta = %{
      title: "Search Trivia Venues and Cities | Trivia Advisor",
      description: "Search for trivia venues and cities worldwide. Find your next trivia night.",
      url: "#{assigns.base_url}/search",
      type: "website",
      image: nil,
      twitter_card: "summary_large_image"
    }

    breadcrumbs = [
      %{name: "Home", url: assigns.base_url},
      %{name: "Search", url: nil}
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
      <Header.site_header current_path={@base_url <> "/search"} />

      <!-- Main Content -->
      <main class="flex-1">
        <!-- Breadcrumbs -->
        <div class="container mx-auto px-4 py-4">
          <Breadcrumbs.breadcrumbs items={@breadcrumbs} />
        </div>

        <!-- Search Section -->
        <div class="bg-white border-b">
          <div class="container mx-auto px-4 py-12">
            <h1 class="text-4xl font-bold text-gray-900 mb-2">
              Search Trivia Venues
            </h1>
            <p class="text-lg text-gray-600 mb-8">
              Find trivia nights in your area
            </p>

            <!-- Search Form -->
            <form phx-submit="search" class="max-w-2xl">
              <div class="flex gap-2">
                <input
                  type="text"
                  name="query"
                  value={@query}
                  placeholder="Search by venue or city name..."
                  class="flex-1 px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  autofocus
                />
                <button
                  type="submit"
                  class="px-6 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors"
                >
                  <svg
                    class="w-5 h-5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                    >
                    </path>
                  </svg>
                </button>
              </div>
            </form>
          </div>
        </div>

        <!-- Results Section -->
        <%= if @searched do %>
          <div class="container mx-auto px-4 py-12">
            <%= if Enum.empty?(@venues) && Enum.empty?(@cities) do %>
              <div class="text-center py-12">
                <div class="text-6xl mb-4">🔍</div>
                <h2 class="text-2xl font-bold text-gray-900 mb-2">No results found</h2>
                <p class="text-gray-600">
                  Try searching with a different term
                </p>
              </div>
            <% else %>
              <!-- Venues Results -->
              <%= if !Enum.empty?(@venues) do %>
                <div class="mb-12">
                  <h2 class="text-2xl font-bold text-gray-900 mb-6">
                    Venues (<%= length(@venues) %>)
                  </h2>
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    <%= for venue <- @venues do %>
                      <.link
                        navigate={"/venues/#{venue.slug}"}
                        class="block p-6 bg-white rounded-lg border border-gray-200 hover:border-blue-500 hover:shadow-md transition-all"
                      >
                        <h3 class="text-lg font-semibold text-gray-900 mb-2">
                          <%= venue.name %>
                        </h3>
                        <%= if venue.address do %>
                          <p class="text-sm text-gray-600 mb-2">
                            <%= venue.address %>
                          </p>
                        <% end %>
                        <p class="text-sm text-gray-500">
                          <%= venue.city.name %>, <%= venue.city.country.name %>
                        </p>
                        <%= if venue.venue_type do %>
                          <div class="mt-3">
                            <span class="inline-block px-2 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded">
                              <%= venue.venue_type %>
                            </span>
                          </div>
                        <% end %>
                      </.link>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <!-- Cities Results -->
              <%= if !Enum.empty?(@cities) do %>
                <div>
                  <h2 class="text-2xl font-bold text-gray-900 mb-6">
                    Cities (<%= length(@cities) %>)
                  </h2>
                  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    <%= for city <- @cities do %>
                      <.link
                        navigate={"/cities/#{Locations.city_url_slug(city)}"}
                        class="block p-4 bg-white rounded-lg border border-gray-200 hover:border-blue-500 hover:shadow-md transition-all"
                      >
                        <h3 class="text-lg font-semibold text-gray-900 mb-1">
                          <%= city.name %>
                        </h3>
                        <p class="text-sm text-gray-500">
                          <%= city.country.name %>
                        </p>
                      </.link>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
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
end
