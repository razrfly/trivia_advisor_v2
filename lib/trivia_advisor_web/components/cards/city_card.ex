defmodule TriviaAdvisorWeb.Components.Cards.CityCard do
  @moduledoc """
  City card component for displaying city information.
  """
  use Phoenix.Component
  alias TriviaAdvisor.Locations

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
    assigns = assign(assigns, :city_url_slug, Locations.city_url_slug(assigns.city))

    ~H"""
    <.link
      navigate={"/cities/#{@city_url_slug}"}
      class="block group"
    >
      <div class="p-6 bg-white rounded-lg shadow-md hover:shadow-xl transition-shadow duration-200">
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

        <!-- Coordinates (if available) -->
        <%= if @city.latitude && @city.longitude do %>
          <div class="flex items-center text-xs text-gray-500">
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
    """
  end
end
