defmodule TriviaAdvisorWeb.Components.Cards.VenueCard do
  @moduledoc """
  Venue card component for displaying venue information with event details.
  """
  use Phoenix.Component
  alias TriviaAdvisor.Events.PublicEvent
  alias TriviaAdvisorWeb.Helpers.{CurrencyHelpers, ImageHelpers}
  alias TriviaAdvisorWeb.Components.UI.{Icons, Badge}

  @doc """
  Renders a venue card with event details and link to venue page (flat URL structure).

  Since V2 uses flat event data from trivia_events_export view, the venue map
  contains both venue and event fields at the top level (no nested objects).

  ## Examples

      <VenueCard.venue_card venue={venue} />
      <VenueCard.venue_card venue={venue} show_city={true} />
      <VenueCard.venue_card venue={venue} show_city={true} show_distance={true} />
  """
  attr :venue, :map, required: true
  attr :show_city, :boolean, default: false
  attr :show_distance, :boolean, default: false

  def venue_card(assigns) do
    # Convert struct to map for easier field access (if it's a struct)
    venue = if is_struct(assigns.venue), do: Map.from_struct(assigns.venue), else: assigns.venue

    # Handle both :slug (from get_latest_venues) and :venue_slug (from list_venues_for_city)
    slug = Map.get(venue, :venue_slug) || Map.get(venue, :slug)
    venue = Map.put(venue, :slug, slug)

    assigns = assign(assigns, :venue, venue)

    ~H"""
    <div class="bg-white rounded-lg shadow-md hover:shadow-xl transition-shadow duration-200">
      <.link
        navigate={"/venues/#{@venue.slug}"}
        class="block group"
      >
        <!-- Venue Image with 3-level fallback (cached_images → video_images → city_images) -->
        <% image = ImageHelpers.get_venue_card_image(@venue) %>
        <%= if image do %>
          <div class="mb-4">
            <img
              src={image.url}
              alt={image.alt}
              class="w-full h-40 object-cover rounded-t-lg"
            />
          </div>
        <% end %>

        <div class="p-6">
          <!-- Venue Name with Optional Distance Badge -->
          <div class="flex items-start justify-between mb-2">
            <h2 class="text-2xl font-semibold text-gray-900 flex-1 group-hover:text-blue-600 transition-colors">
              <%= @venue.venue_name %>
            </h2>
            <%= if @show_distance && @venue[:distance_km] do %>
              <Badge.badge variant="blue" class="ml-3 flex-shrink-0">
                <%= format_distance(@venue.distance_km) %> km
              </Badge.badge>
            <% end %>
          </div>

          <!-- City (if show_city is true) -->
          <%= if @show_city && @venue[:city_name] do %>
            <p class="text-gray-600 mb-2">
              <%= @venue.city_name %>, <%= @venue.country_name %>
            </p>
          <% end %>

          <!-- Address -->
          <%= if @venue[:venue_address] do %>
            <div class="flex items-start text-gray-600 mb-2">
              <Icons.icon name="location" class="w-5 h-5 mr-2 mt-0.5 flex-shrink-0" />
              <span><%= @venue.venue_address %></span>
            </div>
          <% end %>

          <!-- Event Details: Day / Time / Price -->
          <%= if @venue[:day_of_week] && @venue[:start_time] do %>
            <div class="mb-3 flex items-center text-sm text-gray-600">
              <span class="font-medium text-indigo-600">
                <%= PublicEvent.format_day_name(@venue.day_of_week) %>s
              </span>
              <span class="mx-2">•</span>
              <span><%= PublicEvent.format_time(@venue.start_time, get_country(@venue)) %></span>
              <span class="mx-2">•</span>
              <span><%= PublicEvent.format_entry_fee(@venue.entry_fee_cents, get_currency_code(@venue)) %></span>
            </div>
          <% end %>

          <!-- Event Description -->
          <%= if @venue[:description] && String.length(@venue.description || "") > 0 do %>
            <p class="mb-4 text-sm text-gray-600 line-clamp-3"><%= @venue.description %></p>
          <% end %>
        </div>
      </.link>

      <!-- Source Attribution: Last Seen + Source Name + Website (outside main link to avoid nesting) -->
      <%= if @venue[:last_seen_at] do %>
        <div class="px-6 pb-4 flex items-center text-xs text-gray-500">
          <Icons.icon name="time" class="w-4 h-4 mr-1" />
          <span>Updated <%= PublicEvent.time_ago(@venue.last_seen_at) %></span>
          <%= if @venue[:source_name] do %>
            <span class="mx-1">•</span>
            <span>
              Source: <%= if @venue[:activity_slug] do %>
                <a
                  href={"https://wombie.com/activities/#{@venue.activity_slug}"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-indigo-600 hover:text-indigo-800"
                  onclick="event.stopPropagation()"
                >
                  <%= @venue.source_name %>
                </a>
              <% else %>
                <%= @venue.source_name %>
              <% end %>
            </span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Delegate to CurrencyHelpers for country extraction
  defp get_country(venue), do: CurrencyHelpers.get_country(venue)

  # Delegate to CurrencyHelpers for currency code extraction
  defp get_currency_code(venue), do: CurrencyHelpers.get_country_currency(venue)

  # Format distance for display, handling both Decimal and float types
  defp format_distance(distance) when is_struct(distance, Decimal) do
    Decimal.to_string(distance)
  end

  defp format_distance(distance) when is_float(distance) do
    Float.to_string(distance)
  end

  defp format_distance(distance) when is_integer(distance) do
    Integer.to_string(distance)
  end

  defp format_distance(_), do: "N/A"
end
