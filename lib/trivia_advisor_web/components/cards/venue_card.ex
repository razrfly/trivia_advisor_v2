defmodule TriviaAdvisorWeb.Components.Cards.VenueCard do
  @moduledoc """
  Venue card component for displaying venue information with event details.
  """
  use Phoenix.Component
  alias TriviaAdvisor.Events.PublicEvent

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
    ~H"""
    <div class="bg-white rounded-lg shadow-md hover:shadow-xl transition-shadow duration-200">
      <.link
        navigate={"/venues/#{@venue.slug}"}
        class="block group"
      >
        <!-- Venue Image (if available) -->
        <%= if @venue[:venue_images] && is_list(@venue.venue_images) && length(@venue.venue_images) > 0 do %>
          <% primary_image = List.first(@venue.venue_images) %>
          <div class="mb-4">
            <img
              src={primary_image["url"]}
              alt={primary_image["alt"] || @venue.venue_name}
              class="w-full h-48 object-cover rounded-t-lg"
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
              <span><%= PublicEvent.format_time(@venue.start_time, @venue.country_code) %></span>
              <span class="mx-2">•</span>
              <span><%= PublicEvent.format_entry_fee(@venue.entry_fee_cents) %></span>
            </div>
          <% end %>

          <!-- Event Description -->
          <%= if @venue[:description] && String.length(@venue.description || "") > 0 do %>
            <p class="mb-4 text-sm text-gray-600 line-clamp-3"><%= @venue.description %></p>
          <% end %>
        </div>
      </.link>

      <!-- Source Attribution: Last Seen + Source Name (outside main link to avoid nesting) -->
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
              Source:
              <%= if @venue[:source_url] do %>
                <a
                  href={@venue.source_url}
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

  # Time ago helper (simplified version, similar to production)
  defp time_ago(datetime) when is_struct(datetime, NaiveDateTime) do
    # Convert to DateTime for comparison
    {:ok, dt} = DateTime.from_naive(datetime, "Etc/UTC")
    time_ago(dt)
  end

  defp time_ago(datetime) when is_struct(datetime, DateTime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} minutes ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)} hours ago"
      diff_seconds < 604_800 -> "#{div(diff_seconds, 86400)} days ago"
      diff_seconds < 2_592_000 -> "#{div(diff_seconds, 604_800)} weeks ago"
      diff_seconds < 31_536_000 -> "#{div(diff_seconds, 2_592_000)} months ago"
      true -> "#{div(diff_seconds, 31_536_000)} years ago"
    end
  end

  defp time_ago(_), do: "recently"
end
