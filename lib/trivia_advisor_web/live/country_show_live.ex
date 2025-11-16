defmodule TriviaAdvisorWeb.CountryShowLive do
  @moduledoc """
  Country page LiveView - displays all cities in a country.
  Matches V1 route pattern: /{country-slug}/
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisor.Locations
  alias TriviaAdvisorWeb.Helpers.ImageHelpers
  alias TriviaAdvisorWeb.Components.SEO.{MetaTags, Breadcrumbs}
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer, Hero}
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
        base_url = get_base_url()

        socket =
          socket
          |> assign(:page_title, "Trivia Nights in #{country.name}")
          |> assign(:country, country)
          |> assign(:base_url, base_url)
          |> assign(:page, 1)
          |> assign(:per_page, 50)

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = normalize_page(params["page"])
    per_page = socket.assigns.per_page
    country_id = socket.assigns.country.id

    cities = Locations.list_cities_for_country(country_id, page: page, per_page: per_page)
    total_count = Locations.count_cities_for_country(country_id)
    total_pages = ceil(total_count / per_page)

    {:noreply,
     socket
     |> assign(:cities, cities)
     |> assign(:page, page)
     |> assign(:total_count, total_count)
     |> assign(:total_pages, total_pages)}
  end

  @impl true
  def render(assigns) do
    meta = MetaTags.country_meta_tags(assigns.country, assigns.base_url)
    breadcrumbs = Breadcrumbs.country_breadcrumbs(assigns.country, assigns.base_url)

    hero_image = case assigns.cities do
      [] -> nil
      [first_city | _] -> ImageHelpers.get_city_card_image(first_city)
    end

    assigns =
      assigns
      |> assign(:meta, meta)
      |> assign(:breadcrumbs, breadcrumbs)
      |> assign(:hero_image, hero_image)

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

        <!-- Hero Banner with Country Image -->
        <Hero.hero_banner
          image_url={@hero_image && @hero_image.url}
          alt={@hero_image && @hero_image.alt}
          height="h-64 md:h-96"
          layout="center"
          gradient="from-transparent via-transparent to-black"
          gradient_opacity="opacity-60"
          photographer={@hero_image && @hero_image[:photographer]}
          photographer_url={@hero_image && @hero_image[:photographer_url]}
          fallback_title={"Trivia Nights in #{@country.name}"}
          fallback_subtitle={"Explore #{length(@cities)} #{if length(@cities) == 1, do: "city", else: "cities"} with trivia events"}
        >
          <:title>Trivia Nights in <%= @country.name %></:title>
          <:subtitle>
            Explore <%= length(@cities) %> <%= if length(@cities) == 1,
              do: "city",
              else: "cities" %> with trivia events
          </:subtitle>
        </Hero.hero_banner>

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
            <!-- Results Summary -->
            <div class="mb-6 text-gray-600">
              Showing <%= (@page - 1) * @per_page + 1 %>-<%= min(
                @page * @per_page,
                @total_count
              ) %> of <%= @total_count %> <%= if @total_count == 1,
                do: "city",
                else: "cities" %>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              <%= for city <- @cities do %>
                <CityCard.city_card city={city} base_url={@base_url} show_country={false} />
              <% end %>
            </div>

            <!-- Pagination Controls -->
            <%= if @total_pages > 1 do %>
              <div class="mt-12 flex justify-center items-center gap-2">
                <!-- Previous Button -->
                <%= if @page > 1 do %>
                  <.link
                    patch={"?page=#{@page - 1}"}
                    class="px-4 py-2 bg-white border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors"
                  >
                    ← Previous
                  </.link>
                <% else %>
                  <span class="px-4 py-2 bg-gray-100 border border-gray-200 rounded-md text-gray-400 cursor-not-allowed">
                    ← Previous
                  </span>
                <% end %>
                <!-- Page Numbers -->
                <div class="flex gap-1">
                  <%= for page_num <- pagination_range(@page, @total_pages) do %>
                    <%= if page_num == @page do %>
                      <span class="px-4 py-2 bg-indigo-600 text-white rounded-md font-medium">
                        <%= page_num %>
                      </span>
                    <% else %>
                      <%= if page_num == :ellipsis do %>
                        <span class="px-2 py-2 text-gray-500">...</span>
                      <% else %>
                        <.link
                          patch={"?page=#{page_num}"}
                          class="px-4 py-2 bg-white border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors"
                        >
                          <%= page_num %>
                        </.link>
                      <% end %>
                    <% end %>
                  <% end %>
                </div>
                <!-- Next Button -->
                <%= if @page < @total_pages do %>
                  <.link
                    patch={"?page=#{@page + 1}"}
                    class="px-4 py-2 bg-white border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors"
                  >
                    Next →
                  </.link>
                <% else %>
                  <span class="px-4 py-2 bg-gray-100 border border-gray-200 rounded-md text-gray-400 cursor-not-allowed">
                    Next →
                  </span>
                <% end %>
              </div>
            <% end %>
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

  # Generates a smart pagination range with ellipsis for large page counts.
  # Shows: [1] ... [current-1] [current] [current+1] ... [total]
  defp pagination_range(_current, total) when total <= 7 do
    1..total |> Enum.to_list()
  end

  defp pagination_range(current, total) do
    cond do
      # Near start: 1 2 3 4 5 ... total
      current <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total]

      # Near end: 1 ... total-4 total-3 total-2 total-1 total
      current >= total - 3 ->
        [1, :ellipsis, total - 4, total - 3, total - 2, total - 1, total]

      # Middle: 1 ... current-1 current current+1 ... total
      true ->
        [1, :ellipsis, current - 1, current, current + 1, :ellipsis, total]
    end
  end

  defp normalize_page(nil), do: 1

  defp normalize_page(param) when is_binary(param) do
    param
    |> String.trim()
    |> Integer.parse()
    |> case do
      {value, ""} when value > 0 -> value
      _ -> 1
    end
  end

  defp normalize_page(_), do: 1
end
