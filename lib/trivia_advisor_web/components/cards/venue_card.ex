defmodule TriviaAdvisorWeb.Components.Cards.VenueCard do
  @moduledoc """
  Venue card component for displaying venue information.
  """
  use Phoenix.Component
  alias TriviaAdvisor.Locations.Venue

  @doc """
  Renders a venue card with link to venue page.

  ## Examples

      <VenueCard.venue_card venue={venue} country_slug={@country.slug} city_slug={@city.slug} base_url={@base_url} />
  """
  attr :venue, :map, required: true
  attr :country_slug, :string, required: true
  attr :city_slug, :string, required: true
  attr :base_url, :string, required: true
  attr :show_city, :boolean, default: false

  def venue_card(assigns) do
    ~H"""
    <.link
      navigate={"#{@base_url}/#{@country_slug}/#{@city_slug}/#{@venue.slug}"}
      class="block group"
    >
      <div class="p-6 bg-white rounded-lg shadow-md hover:shadow-xl transition-shadow duration-200">
        <!-- Venue Image (if available) -->
        <%= if primary_image = Venue.primary_image(@venue) do %>
          <div class="mb-4 -mt-6 -mx-6">
            <img
              src={primary_image["url"]}
              alt={primary_image["alt"] || @venue.name}
              class="w-full h-48 object-cover rounded-t-lg"
            />
          </div>
        <% end %>

        <!-- Venue Name -->
        <h2 class="text-2xl font-semibold text-gray-900 mb-2 group-hover:text-blue-600 transition-colors">
          <%= @venue.name %>
        </h2>

        <!-- City (if show_city is true) -->
        <%= if @show_city && Map.has_key?(@venue, :city) && @venue.city do %>
          <p class="text-gray-600 mb-2">
            <%= @venue.city.name %>, <%= @venue.city.country.name %>
          </p>
        <% end %>

        <!-- Address -->
        <%= if @venue.address do %>
          <div class="flex items-start text-gray-600 mb-2">
            <svg
              class="w-5 h-5 mr-2 mt-0.5 flex-shrink-0"
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
            <span><%= @venue.address %></span>
          </div>
        <% end %>

        <!-- Venue Type Badge -->
        <%= if @venue.venue_type do %>
          <div class="mt-3">
            <span class="inline-block px-3 py-1 bg-blue-100 text-blue-800 text-sm font-medium rounded-full">
              <%= @venue.venue_type %>
            </span>
          </div>
        <% end %>

        <!-- Metadata indicators -->
        <div class="mt-4 flex items-center space-x-3 text-xs text-gray-500">
          <%= if @venue.metadata && map_size(@venue.metadata) > 0 do %>
            <span class="flex items-center">
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
              Details available
            </span>
          <% end %>
        </div>
      </div>
    </.link>
    """
  end
end
