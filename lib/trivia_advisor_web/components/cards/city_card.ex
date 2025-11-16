defmodule TriviaAdvisorWeb.Components.Cards.CityCard do
  @moduledoc """
  City card component for displaying city information.
  """
  use Phoenix.Component
  alias TriviaAdvisor.Locations
  alias TriviaAdvisorWeb.Helpers.ImageHelpers
  alias TriviaAdvisorWeb.Components.UI.{Icons, Badge}

  @doc """
  Renders a city card with link to city page.

  ## Examples

      <CityCard.city_card city={city} base_url={@base_url} />
  """
  attr :city, :map, required: true
  attr :base_url, :string, required: true
  attr :show_country, :boolean, default: true

  def city_card(assigns) do
    # Generate the appropriate city URL slug (handles disambiguation)
    assigns =
      assigns
      |> assign(:city_url_slug, Locations.city_url_slug(assigns.city))
      |> assign(:city_image, ImageHelpers.get_city_card_image(assigns.city))

    ~H"""
    <div class="bg-white rounded-lg shadow-md hover:shadow-xl transition-shadow duration-200">
      <div class="relative overflow-hidden">
        <.link
          navigate={"/cities/#{@city_url_slug}"}
          class="block group"
        >
          <%= if @city_image do %>
            <img
              src={@city_image.url}
              alt={@city_image.alt}
              loading="lazy"
              class="w-full h-48 object-cover rounded-t-lg"
            />
          <% end %>

          <div class="p-6">
            <!-- City Name -->
            <h3 class="text-xl font-semibold text-gray-900 mb-2 group-hover:text-blue-600 transition-colors">
              <%= @city.name %>
            </h3>

            <!-- Country Name -->
            <%= if @show_country do %>
              <p class="text-gray-600 mb-3">
                <%= @city.country.name %>
              </p>
            <% end %>

            <!-- Venue Count Badge -->
            <%= if Map.get(@city, :venue_count) do %>
              <div class="mb-3">
                <Badge.badge variant="indigo" icon="building">
                  <%= @city.venue_count %> <%= if @city.venue_count == 1,
                    do: "Venue",
                    else: "Venues" %>
                </Badge.badge>
              </div>
            <% end %>

            <!-- Coordinates (if available) -->
            <%= if @city.latitude && @city.longitude do %>
              <div class="flex items-center text-xs text-gray-500">
                <Icons.icon name="location" class="w-4 h-4 mr-1" />
                <span>
                  <%= Float.round(Decimal.to_float(@city.latitude), 2) %>,
                  <%= Float.round(Decimal.to_float(@city.longitude), 2) %>
                </span>
              </div>
            <% end %>

            <!-- Alternate Names (if available) -->
            <%= if @city.alternate_names && length(@city.alternate_names) > 0 do %>
              <div class="mt-2 text-xs text-gray-400">
                Also known as: <%= Enum.take(@city.alternate_names, 2) |> Enum.join(", ") %>
              </div>
            <% end %>
          </div>
        </.link>

        <%= if @city_image && @city_image[:photographer] && @city_image[:photographer_url] do %>
          <a
            href={@city_image.photographer_url}
            target="_blank"
            rel="noopener noreferrer"
            class="absolute bottom-0 right-0 bg-black bg-opacity-60 text-white text-xs px-2 py-1 rounded-tl z-10 pointer-events-auto hover:bg-opacity-80"
          >
            Photo by
            <span class="underline hover:text-gray-200">
              <%= @city_image.photographer %>
            </span>
          </a>
        <% end %>
      </div>
    </div>
    """
  end

end
