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
    hero_image = get_hero_image(assigns.cities)

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
        <%= if @hero_image do %>
          <div class="relative h-64 md:h-96 bg-gray-900">
            <img
              src={@hero_image.url}
              alt={@hero_image.alt}
              class="w-full h-full object-cover opacity-70"
            />
            <div class="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-black opacity-60">
            </div>
            <div class="absolute inset-0 flex items-center justify-center">
              <div class="text-center text-white px-4">
                <h1 class="text-4xl md:text-5xl lg:text-6xl font-bold mb-4 drop-shadow-lg">
                  Trivia Nights in <%= @country.name %>
                </h1>
                <p class="text-xl md:text-2xl drop-shadow-lg">
                  Explore <%= length(@cities) %> <%= if length(@cities) == 1,
                    do: "city",
                    else: "cities" %> with trivia events
                </p>
              </div>
            </div>
            <%= if @hero_image[:photographer] && @hero_image[:photographer_url] do %>
              <div class="absolute bottom-2 right-2 bg-black bg-opacity-60 text-white text-xs px-3 py-1 rounded">
                Photo by
                <a
                  href={@hero_image.photographer_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="underline hover:text-gray-200"
                >
                  <%= @hero_image.photographer %>
                </a>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- Fallback: Text-only header if no hero image -->
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
        <% end %>

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

  @doc """
  Gets hero image for the country page from the first city's unsplash_gallery.
  Uses the primary city (first in the sorted list) as the country representative image.
  """
  defp get_hero_image([]), do: nil

  defp get_hero_image([first_city | _rest]) do
    unsplash_gallery = Map.get(first_city, :unsplash_gallery)

    if has_unsplash_images?(unsplash_gallery) do
      extract_hero_image(unsplash_gallery, first_city.name)
    else
      nil
    end
  end

  defp has_unsplash_images?(gallery) when is_map(gallery) do
    active_cat = gallery["active_category"]
    categories = gallery["categories"]

    is_binary(active_cat) &&
      is_map(categories) &&
      is_map(categories[active_cat]) &&
      is_list(categories[active_cat]["images"]) &&
      length(categories[active_cat]["images"]) > 0 &&
      get_in(categories, [active_cat, "images", Access.at(0), "url"])
  end

  defp has_unsplash_images?(_), do: false

  defp extract_hero_image(gallery, city_name) do
    active_cat = gallery["active_category"]
    images = gallery["categories"][active_cat]["images"]
    image = List.first(images)

    %{
      url: image["url"],
      alt: image["alt"] || "#{city_name} cityscape",
      photographer: image["photographer"],
      photographer_url: image["photographer_url"]
    }
  end

  @doc """
  Generates a smart pagination range with ellipsis for large page counts.
  Shows: [1] ... [current-1] [current] [current+1] ... [total]
  """
  defp pagination_range(current, total) when total <= 7 do
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
