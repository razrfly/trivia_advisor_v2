defmodule TriviaAdvisorWeb.Components.Cards.VenueCard do
  @moduledoc """
  Venue card component for displaying venue information with event details.
  """
  use Phoenix.Component
  alias TriviaAdvisor.Events.PublicEvent
  alias TriviaAdvisorWeb.Helpers.CurrencyHelpers

  @doc """
  Renders a venue card with event details and link to venue page (flat URL structure).

  Since V2 uses flat event data from trivia_events_export view, the venue map
  contains both venue and event fields at the top level (no nested objects).

  ## Examples

      <VenueCard.venue_card venue={venue} />
      <VenueCard.venue_card venue={venue} show_city={true} />
  """
  attr :venue, :map, required: true
  attr :show_city, :boolean, default: false

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
        <!-- Venue Image with 3-level fallback (venue_images → video_images → city_images) -->
        <% image = get_venue_card_image(@venue) %>
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
          <!-- Venue Name -->
          <h2 class="text-2xl font-semibold text-gray-900 mb-2 group-hover:text-blue-600 transition-colors">
            <%= @venue.venue_name %>
          </h2>

          <!-- City (if show_city is true) -->
          <%= if @show_city && @venue[:city_name] do %>
            <p class="text-gray-600 mb-2">
              <%= @venue.city_name %>, <%= @venue.country_name %>
            </p>
          <% end %>

          <!-- Address -->
          <%= if @venue[:venue_address] do %>
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
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="w-4 h-4 mr-1"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
            />
          </svg>
          <span>Updated <%= time_ago(@venue.last_seen_at) %></span>
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

  @doc """
  Gets the best available image for a venue card with fallback chain.
  Returns a map with url and alt text, or nil if no images available.

  Fallback order:
  1. venue_images (uploaded venue photos)
  2. venue_metadata["video_images"] (video thumbnails)
  3. city_images (Unsplash city gallery)
  """
  def get_venue_card_image(venue) do
    cond do
      # Try venue_images first
      has_venue_images?(venue) ->
        image = List.first(venue.venue_images)
        %{
          url: image["url"],
          alt: image["alt"] || venue.venue_name
        }

      # Try video_images second
      has_video_images?(venue) ->
        image = venue.venue_metadata["video_images"] |> List.first()
        %{
          url: image["url"],
          alt: "#{venue.venue_name} video thumbnail"
        }

      # Fall back to city_images (Unsplash gallery - different image per venue)
      has_city_images?(venue) ->
        get_random_city_image(venue)

      # No images available
      true ->
        nil
    end
  end

  defp has_venue_images?(venue) do
    venue_images = Map.get(venue, :venue_images)
    is_list(venue_images) &&
      length(venue_images) > 0 &&
      get_in(venue_images, [Access.at(0), "url"])
  end

  defp has_video_images?(venue) do
    venue_metadata = Map.get(venue, :venue_metadata)
    is_map(venue_metadata) &&
      is_list(venue_metadata["video_images"]) &&
      length(venue_metadata["video_images"]) > 0 &&
      get_in(venue_metadata, ["video_images", Access.at(0), "url"])
  end

  defp has_city_images?(venue) do
    city_images = Map.get(venue, :city_images)

    # Handle Unsplash gallery structure: %{"active_category" => "general", "categories" => %{...}}
    if is_map(city_images) && Map.has_key?(city_images, "active_category") do
      active_cat = city_images["active_category"]
      categories = city_images["categories"]

      is_map(categories) &&
        is_map(categories[active_cat]) &&
        is_list(categories[active_cat]["images"]) &&
        length(categories[active_cat]["images"]) > 0 &&
        get_in(categories, [active_cat, "images", Access.at(0), "url"])
    else
      false
    end
  end

  # Get a random image from city's Unsplash gallery, consistent per venue ID.
  # Uses venue_id as seed to ensure the same venue always gets the same image
  # from the gallery, while different venues get different images for visual variety.
  defp get_random_city_image(venue) do
    city_images = venue.city_images
    active_cat = city_images["active_category"]
    images = city_images["categories"][active_cat]["images"]

    # Use venue_id modulo length to select a consistent image per venue
    venue_id = Map.get(venue, :venue_id) || Map.get(venue, :id) || 0
    index = rem(venue_id, length(images))
    image = Enum.at(images, index)

    %{
      url: image["url"],
      alt: "#{venue.city_name} cityscape"
    }
  end

  # Delegate to CurrencyHelpers for country extraction
  defp get_country(venue), do: CurrencyHelpers.get_country(venue)

  # Delegate to CurrencyHelpers for currency code extraction
  defp get_currency_code(venue), do: CurrencyHelpers.get_country_currency(venue)

  # Time ago helper using Timex for proper pluralization
  defp time_ago(datetime) when is_struct(datetime, NaiveDateTime) do
    # Convert to DateTime for Timex
    {:ok, dt} = DateTime.from_naive(datetime, "Etc/UTC")
    time_ago(dt)
  end

  defp time_ago(datetime) when is_struct(datetime, DateTime) do
    Timex.from_now(datetime)
  end

  defp time_ago(_), do: "recently"
end
