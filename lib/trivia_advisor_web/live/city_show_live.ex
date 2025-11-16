defmodule TriviaAdvisorWeb.CityShowLive do
  @moduledoc """
  City page LiveView - displays all venues in a city.
  Supports both flat (/cities/{slug}) and hierarchical patterns for backward compatibility.
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisor.Locations
  alias TriviaAdvisorWeb.Helpers.{SEOHelpers, ImageHelpers}
  alias TriviaAdvisorWeb.JsonLd.{CitySchema, BreadcrumbListSchema}
  alias TriviaAdvisorWeb.Components.SEO.Breadcrumbs
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer, Hero}
  alias TriviaAdvisorWeb.Components.Cards.VenueCard
  alias TriviaAdvisorWeb.Components.UI.EmptyState

  @impl true
  # Flat URL pattern: /cities/{city-slug} or /cities/{city-slug-country-slug}
  def mount(%{"city_slug" => city_slug} = params, _session, socket)
      when not is_map_key(params, "country_slug") do
    case Locations.get_city_by_url_slug(city_slug) do
      %{country: country} = city when not is_nil(country) ->
        # City found with country preloaded
        load_city_page(city, country, socket)

      _ ->
        # City not found or missing country association
        {:ok,
         socket
         |> put_flash(:error, "City not found")
         |> redirect(to: "/")}
    end
  end

  # Hierarchical URL pattern: /{country-slug}/{city-slug}
  def mount(%{"country_slug" => country_slug, "city_slug" => city_slug}, _session, socket) do
    with country when not is_nil(country) <- Locations.get_country_by_slug(country_slug),
         city when not is_nil(city) <- Locations.get_city_by_slug(city_slug),
         true <- city.country_id == country.id do
      # Use common helper to load city page
      load_city_page(city, country, socket)
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "City not found")
         |> redirect(to: "/")}
    end
  end

  # Common helper to load city page data (used by both flat and hierarchical routes)
  defp load_city_page(city, country, socket) do
    base_url = get_base_url()

    # Load venues to get count for SEO
    venues = Locations.list_venues_for_city(city.id, [])
    venue_count = length(venues)

    # Get day counts and suburbs for filter UI
    day_counts = Locations.get_day_counts_for_city(city.id)
    suburbs = Locations.get_suburbs_for_city(city.id)

    # Generate JSON-LD structured data
    city_json_ld = CitySchema.generate(city, %{venue_count: venue_count})
    breadcrumbs = BreadcrumbListSchema.build_city_breadcrumbs(city, base_url)
    breadcrumbs_json_ld = BreadcrumbListSchema.generate(breadcrumbs)
    combined_json_ld = "[#{city_json_ld},#{breadcrumbs_json_ld}]"

    # Build meta description
    description =
      if venue_count > 0 do
        "Discover #{venue_count} trivia venues in #{city.name}, #{country.name}. Find trivia nights, pub quizzes, and quiz events."
      else
        "Find trivia nights, pub quizzes, and quiz events in #{city.name}, #{country.name}."
      end

    # Get hero image
    hero_image_url = ImageHelpers.get_city_hero_image_url(city)

    # Generate flat URL slug for canonical path
    city_url_slug = Locations.city_url_slug(city)

    socket =
      socket
      |> assign(:country, country)
      |> assign(:city, city)
      |> assign(:base_url, base_url)
      |> assign(:selected_weekday, nil)
      |> assign(:selected_suburb, nil)
      |> assign(:selected_radius, nil)
      |> assign(:venues, venues)
      |> assign(:total_venue_count, venue_count)
      |> assign(:day_counts, day_counts)
      |> assign(:suburbs, suburbs)
      |> assign(:hero_image_url, hero_image_url)
      |> assign(:city_url_slug, city_url_slug)
      |> SEOHelpers.assign_meta_tags(
        title: "Trivia Nights in #{city.name}, #{country.name}",
        description: description,
        image: hero_image_url,
        type: "website",
        canonical_path: "/cities/#{city_url_slug}",
        json_ld: combined_json_ld
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    weekday = parse_weekday(params["day"])
    suburb = params["suburb"]

    socket =
      socket
      |> assign(:selected_weekday, weekday)
      |> assign(:selected_suburb, suburb)
      |> load_venues()

    {:noreply, socket}
  end

  defp load_venues(socket) do
    city_id = socket.assigns.city.id
    weekday = socket.assigns[:selected_weekday]
    suburb = socket.assigns[:selected_suburb]

    opts =
      []
      |> maybe_add_opt(:weekday, weekday)
      |> maybe_add_opt(:suburb, suburb)

    venues = Locations.list_venues_for_city(city_id, opts)

    assign(socket, :venues, venues)
  end

  defp maybe_add_opt(opts, _key, nil), do: opts
  defp maybe_add_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_weekday(nil), do: nil
  defp parse_weekday("monday"), do: 1
  defp parse_weekday("tuesday"), do: 2
  defp parse_weekday("wednesday"), do: 3
  defp parse_weekday("thursday"), do: 4
  defp parse_weekday("friday"), do: 5
  defp parse_weekday("saturday"), do: 6
  defp parse_weekday("sunday"), do: 7
  defp parse_weekday(_), do: nil

  @impl true
  def render(assigns) do
    breadcrumbs = Breadcrumbs.city_breadcrumbs(assigns.city, assigns.country, assigns.base_url)
    assigns = assign(assigns, :breadcrumbs, breadcrumbs)

    ~H"""
    <div class="flex flex-col min-h-screen bg-gray-50">
      <!-- Header -->
      <Header.site_header current_path={"/cities/#{@city_url_slug}"} />

      <!-- Main Content -->
      <main class="flex-1">
        <!-- Hero Image Section -->
        <Hero.hero_banner
          image_url={@hero_image_url}
          alt={ImageHelpers.get_city_hero_image_alt(@city, @country)}
          height="h-64 md:h-80 lg:h-96"
          layout="bottom"
          gradient="from-gray-900/80 to-transparent"
        >
          <:title>Trivia Nights in <%= @city.name %></:title>
          <:subtitle>
            <%= if @selected_weekday || @selected_suburb do %>
              <%= @country.name %> • <%= length(@venues) %> of <%= @total_venue_count %> <%= if @total_venue_count == 1,
                do: "venue",
                else: "venues" %>
            <% else %>
              <%= @country.name %> • <%= @total_venue_count %> <%= if @total_venue_count == 1,
                do: "venue",
                else: "venues" %>
            <% end %>
          </:subtitle>
        </Hero.hero_banner>
        <!-- Breadcrumbs -->
        <div class="container mx-auto px-4 py-4 bg-white border-b">
          <Breadcrumbs.breadcrumbs items={@breadcrumbs} />
        </div>

        <!-- Filters Section -->
        <div class="bg-white border-b">
          <div class="container mx-auto px-4 py-6">
            <!-- Day Filter -->
            <h3 class="text-sm font-semibold text-gray-700 mb-3">Filter by Day:</h3>
            <div class="flex flex-wrap gap-2">
              <.link
                patch={"/cities/#{@city_url_slug}"}
                class={[
                  "px-4 py-2 rounded-lg font-medium transition-colors",
                  if(@selected_weekday == nil,
                    do: "bg-blue-600 text-white",
                    else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
                  )
                ]}
              >
                Any Day
              </.link>

              <%= for {day_name, day_num} <- [
                {"Monday", 1},
                {"Tuesday", 2},
                {"Wednesday", 3},
                {"Thursday", 4},
                {"Friday", 5},
                {"Saturday", 6},
                {"Sunday", 7}
              ] do %>
                <% count = Map.get(@day_counts, day_num, 0) %>
                <%= if count > 0 do %>
                  <.link
                    patch={"/cities/#{@city_url_slug}?day=#{String.downcase(day_name)}"}
                    class={[
                      "px-4 py-2 rounded-lg font-medium transition-colors",
                      if(@selected_weekday == day_num,
                        do: "bg-blue-600 text-white",
                        else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
                      )
                    ]}
                  >
                    <%= day_name %> (<%= count %>)
                  </.link>
                <% end %>
              <% end %>
            </div>

            <!-- Suburb Filter -->
            <%= if length(@suburbs) > 1 do %>
              <div class="mt-6">
                <h3 class="text-sm font-semibold text-gray-700 mb-3">Filter by Suburb:</h3>
                <div class="flex flex-wrap gap-2">
                  <.link
                    patch={"/cities/#{@city_url_slug}"}
                    class={[
                      "px-4 py-2 rounded-lg font-medium transition-colors",
                      if(@selected_suburb == nil,
                        do: "bg-indigo-600 text-white",
                        else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
                      )
                    ]}
                  >
                    All Suburbs
                  </.link>

                  <%= for suburb_data <- Enum.take(@suburbs, 15) do %>
                    <.link
                      patch={"/cities/#{@city_url_slug}?suburb=#{URI.encode(suburb_data.suburb)}"}
                      class={[
                        "px-4 py-2 rounded-lg font-medium transition-colors",
                        if(@selected_suburb == suburb_data.suburb,
                          do: "bg-indigo-600 text-white",
                          else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
                        )
                      ]}
                    >
                      <%= suburb_data.suburb %> (<%= suburb_data.count %>)
                    </.link>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Venues List -->
        <div class="container mx-auto px-4 py-12">
          <%= if Enum.empty?(@venues) do %>
            <EmptyState.empty_state
              icon="🏢"
              title={"No venues found in #{@city.name}"}
              description="Check back soon as we add more venues to this city."
              action_text={"← Back to #{@country.name}"}
              action_path={"#{@base_url}/#{@country.slug}"}
            />
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for venue <- @venues do %>
                <VenueCard.venue_card venue={venue} />
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
