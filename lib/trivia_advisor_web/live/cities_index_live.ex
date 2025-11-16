defmodule TriviaAdvisorWeb.CitiesIndexLive do
  @moduledoc """
  Cities index LiveView - displays top cities with trivia events grouped by country.
  Shows top 12 cities per country by venue count for optimal performance.
  Provides search functionality and links to explore all cities per country.
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisor.Locations
  alias TriviaAdvisorWeb.Components.SEO.{MetaTags, Breadcrumbs}
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer}
  alias TriviaAdvisorWeb.Components.Cards.CityCard

  @impl true
  def mount(params, _session, socket) do
    raw_query = Map.get(params, "search")

    # Normalize search query: trim whitespace, convert empty to nil for consistency
    search_query =
      case raw_query do
        nil ->
          nil

        q ->
          q = String.trim(q)
          if q == "", do: nil, else: q
      end

    base_url = get_base_url()

    # Get cities based on search parameter
    cities_by_country =
      if search_query do
        # Search mode: filter cities by name
        cities = Locations.search_cities(search_query)

        # Group filtered cities by country
        cities
        |> Enum.group_by(& &1.country)
        |> Enum.map(fn {country, cities} -> {country, cities} end)
        |> Enum.sort_by(fn {country, _cities} -> country.name end)
      else
        # Normal mode: show top 12 cities per country for performance
        # This reduces load from 1000+ cities to ~150-250 cities
        Locations.list_top_cities_by_country(12)
      end

    socket =
      socket
      |> assign(:page_title,
        if(search_query,
          do: "Search: #{search_query} | Trivia Cities",
          else: "Top Trivia Cities by Country"))
      |> assign(:cities_by_country, cities_by_country)
      |> assign(:search_query, search_query)
      |> assign(:base_url, base_url)
      |> assign(:show_see_more, is_nil(search_query))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    meta = %{
      title: "Top Trivia Cities Worldwide | Trivia Advisor",
      description: "Discover the top cities for trivia nights, pub quizzes, and quiz events worldwide. Browse cities by country and find trivia venues near you.",
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
            <%= if @search_query do %>
              <h1 class="text-4xl font-bold text-gray-900 mb-2">
                Search Results for "<%= @search_query %>"
              </h1>
              <p class="text-lg text-gray-600">
                Found <%= Enum.sum(Enum.map(@cities_by_country, fn {_, cities} -> length(cities) end)) %>
                <%= if Enum.sum(Enum.map(@cities_by_country, fn {_, cities} -> length(cities) end)) == 1, do: "city", else: "cities" %>
              </p>
            <% else %>
              <h1 class="text-4xl font-bold text-gray-900 mb-2">
                Top Trivia Cities by Country
              </h1>
              <p class="text-lg text-gray-600">
                Discover the top cities for trivia in <%= length(@cities_by_country) %> countries worldwide
              </p>
            <% end %>
          </div>
        </div>

        <!-- No Results Message -->
        <%= if @search_query && Enum.empty?(@cities_by_country) do %>
          <div class="container mx-auto px-4 py-12 text-center">
            <div class="max-w-md mx-auto">
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
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                >
                </path>
              </svg>
              <h2 class="text-2xl font-semibold text-gray-900 mb-2">No cities found</h2>
              <p class="text-gray-600 mb-6">
                We couldn't find any cities matching "<%= @search_query %>"
              </p>
              <.link
                navigate="/cities"
                class="inline-block px-6 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors"
              >
                View All Cities
              </.link>
            </div>
          </div>
        <% end %>

        <!-- Cities by Country -->
        <div class="container mx-auto px-4 py-12">
          <%= for {country, cities} <- @cities_by_country do %>
            <div class="mb-12">
              <!-- Country Header with "View All" Button -->
              <div class="flex items-center justify-between mb-6">
                <h2 class="text-3xl font-bold text-gray-900 flex items-center">
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
                  <%= country.name %>
                </h2>

                <%= if @show_see_more do %>
                  <.link
                    navigate={"#{country.slug}"}
                    class="inline-flex items-center px-4 py-2 text-sm font-medium text-blue-600 bg-blue-50 rounded-lg hover:bg-blue-100 transition-colors"
                  >
                    View All <%= country.name %> Cities
                    <svg
                      class="w-4 h-4 ml-2"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 5l7 7-7 7"
                      />
                    </svg>
                  </.link>
                <% end %>
              </div>

              <!-- City Cards Grid -->
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                <%= for city <- cities do %>
                  <CityCard.city_card city={city} base_url={@base_url} show_country={false} />
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
