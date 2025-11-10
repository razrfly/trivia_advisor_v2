defmodule TriviaAdvisorWeb.CitiesIndexLive do
  @moduledoc """
  Cities index LiveView - displays all cities with trivia events grouped by country.
  Provides alphabetical browsing and search functionality.
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisor.Locations
  alias TriviaAdvisorWeb.Components.SEO.{MetaTags, Breadcrumbs}
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer}

  @impl true
  def mount(_params, _session, socket) do
    countries = Locations.list_countries()
    base_url = get_base_url()

    # Group cities by country
    cities_by_country =
      countries
      |> Enum.map(fn country ->
        cities = Locations.list_cities_for_country(country.id)
        {country, cities}
      end)
      |> Enum.filter(fn {_country, cities} -> !Enum.empty?(cities) end)
      |> Enum.sort_by(fn {country, _cities} -> country.name end)

    socket =
      socket
      |> assign(:page_title, "All Trivia Cities")
      |> assign(:cities_by_country, cities_by_country)
      |> assign(:base_url, base_url)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    meta = %{
      title: "All Trivia Cities | Trivia Advisor",
      description: "Browse all cities with trivia nights, pub quizzes, and quiz events worldwide. Find trivia venues in your area.",
      url: "#{assigns.base_url}/cities",
      type: "website",
      image: nil,
      twitter_card: "summary_large_image"
    }

    breadcrumbs = [
      %{name: "Home", url: assigns.base_url},
      %{name: "Cities", url: nil}
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
      <Header.site_header current_path="/cities" />

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
              All Trivia Cities
            </h1>
            <p class="text-lg text-gray-600">
              Browse <%= Enum.sum(Enum.map(@cities_by_country, fn {_, cities} -> length(cities) end)) %> cities
              across <%= length(@cities_by_country) %> countries hosting trivia events
            </p>
          </div>
        </div>

        <!-- Cities by Country -->
        <div class="container mx-auto px-4 py-12">
          <%= for {country, cities} <- @cities_by_country do %>
            <div class="mb-12">
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
                    d="M3 21v-4m0 0V5a2 2 0 012-2h6.5l1 1H21l-3 6 3 6h-8.5l-1-1H5a2 2 0 00-2 2zm9-13.5V9"
                  >
                  </path>
                </svg>
                <%= country.name %> (<%= length(cities) %>)
              </h2>

              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                <%= for city <- Enum.sort_by(cities, & &1.name) do %>
                  <.link
                    navigate={"/#{country.slug}/#{city.slug}"}
                    class="block p-4 bg-white rounded-lg border border-gray-200 hover:border-blue-500 hover:shadow-md transition-all"
                  >
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <h3 class="text-lg font-semibold text-gray-900 mb-1">
                          <%= city.name %>
                        </h3>
                        <%= if city.latitude && city.longitude do %>
                          <p class="text-sm text-gray-500 flex items-center">
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
                            <%= Float.round(Decimal.to_float(city.latitude), 2) %>, <%= Float.round(
                              Decimal.to_float(city.longitude),
                              2
                            ) %>
                          </p>
                        <% end %>
                      </div>
                      <svg
                        class="w-5 h-5 text-gray-400 flex-shrink-0 ml-2"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 5l7 7-7 7"
                        >
                        </path>
                      </svg>
                    </div>
                  </.link>
                <% end %>
              </div>
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
