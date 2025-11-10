defmodule TriviaAdvisorWeb.CountryShowLive do
  @moduledoc """
  Country page LiveView - displays all cities in a country.
  Matches V1 route pattern: /{country-slug}/
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisor.Locations
  alias TriviaAdvisorWeb.Components.SEO.{MetaTags, Breadcrumbs}
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer}
  alias TriviaAdvisorWeb.Components.Cards.CityCard
  alias TriviaAdvisorWeb.Components.UI.EmptyState

  @impl true
  def mount(%{"country_slug" => country_slug}, _session, socket) do
    case Locations.get_country_by_slug(country_slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Country not found")
         |> redirect(to: "/")}

      country ->
        cities = Locations.list_cities_for_country(country.id)
        base_url = get_base_url()

        socket =
          socket
          |> assign(:page_title, "Trivia Nights in #{country.name}")
          |> assign(:country, country)
          |> assign(:cities, cities)
          |> assign(:base_url, base_url)

        {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    meta = MetaTags.country_meta_tags(assigns.country, assigns.base_url)
    breadcrumbs = Breadcrumbs.country_breadcrumbs(assigns.country, assigns.base_url)

    assigns =
      assigns
      |> assign(:meta, meta)
      |> assign(:breadcrumbs, breadcrumbs)

    ~H"""
    <div class="flex flex-col min-h-screen bg-gray-50">
      <!-- SEO Meta Tags -->
      <MetaTags.meta_tags {Map.to_list(@meta)} />

      <!-- Header -->
      <Header.site_header current_path={"#{@base_url}/#{@country.slug}"} />

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
              Trivia Nights in <%= @country.name %>
            </h1>
            <p class="text-lg text-gray-600">
              Explore <%= length(@cities) %> <%= if length(@cities) == 1,
                do: "city",
                else: "cities" %> with trivia events
            </p>
          </div>
        </div>

        <!-- Cities Grid -->
        <div class="container mx-auto px-4 py-12">
          <%= if Enum.empty?(@cities) do %>
            <EmptyState.empty_state
              icon="🌆"
              title={"No cities found in #{@country.name}"}
              description="Check back soon as we add more cities to this country."
              action_text="← Back to Home"
              action_path={@base_url}
            />
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              <%= for city <- @cities do %>
                <CityCard.city_card city={city} base_url={@base_url} show_country={false} />
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
