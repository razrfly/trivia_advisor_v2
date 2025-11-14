defmodule TriviaAdvisorWeb.Components.Cards.EventCard do
  @moduledoc """
  Event card component for displaying trivia event information.
  """
  use Phoenix.Component
  alias TriviaAdvisor.Events
  alias TriviaAdvisor.Events.PublicEvent

  @doc """
  Renders an event card with upcoming occurrences.

  ## Examples

      <EventCard.event_card event={event} />
      <EventCard.event_card event={event} country={country} />
  """
  attr :event, :map, required: true
  attr :show_venue, :boolean, default: false
  attr :country, :map, default: nil

  def event_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-md p-6">
      <!-- Event Header -->
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <h3 class="text-2xl font-semibold text-gray-900 mb-2">
            <%= @event.name %>
          </h3>

          <!-- Venue (if show_venue is true) -->
          <%= if @show_venue && @event.venue_name do %>
            <p class="text-gray-600 mb-2">
              <span class="inline-block mr-1">📍</span>
              <%= @event.venue_name %>
            </p>
          <% end %>

          <!-- Source Badge -->
          <%= if @event.source_name do %>
            <span class="inline-block px-3 py-1 bg-purple-100 text-purple-800 text-sm font-medium rounded-full">
              <%= @event.source_name %>
            </span>
          <% end %>
        </div>

        <!-- Active Status Indicator -->
        <span class="flex items-center text-green-600 text-sm font-medium">
          <span class="w-2 h-2 bg-green-600 rounded-full mr-2"></span>
          Active
        </span>
      </div>

      <!-- Event Details Card -->
      <div class="grid grid-cols-4 gap-4 my-6 p-4 bg-gray-50 rounded-lg">
        <!-- Quiz Day -->
        <div class="text-center">
          <div class="flex items-center justify-center mb-2">
            <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
            </svg>
          </div>
          <div class="text-sm text-gray-500 mb-1">Quiz Day</div>
          <div class="font-semibold text-gray-900">
            <%= if @event.day_of_week do %>
              <%= PublicEvent.format_day_name(@event.day_of_week) %>
            <% else %>
              TBD
            <% end %>
          </div>
        </div>

        <!-- Start Time -->
        <div class="text-center">
          <div class="flex items-center justify-center mb-2">
            <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
          </div>
          <div class="text-sm text-gray-500 mb-1">Start Time</div>
          <div class="font-semibold text-gray-900">
            <%= if @event.start_time && @country do %>
              <%= PublicEvent.format_time(@event.start_time, @country) %>
            <% else %>
              <%= if @event.start_time do %>
                <%= PublicEvent.format_time(@event.start_time, %{code: "US"}) %>
              <% else %>
                TBD
              <% end %>
            <% end %>
          </div>
        </div>

        <!-- Entry Fee -->
        <div class="text-center">
          <div class="flex items-center justify-center mb-2">
            <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
          </div>
          <div class="text-sm text-gray-500 mb-1">Entry Fee</div>
          <div class="font-semibold text-gray-900">
            <%= if @event.entry_fee_cents != nil do %>
              <%= PublicEvent.format_entry_fee(@event.entry_fee_cents, get_currency_code(@event, @country)) %>
            <% else %>
              Check website
            <% end %>
          </div>
        </div>

        <!-- Frequency -->
        <div class="text-center">
          <div class="flex items-center justify-center mb-2">
            <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
            </svg>
          </div>
          <div class="text-sm text-gray-500 mb-1">Frequency</div>
          <div class="font-semibold text-gray-900 capitalize">
            <%= if @event.frequency do %>
              <%= @event.frequency %>
            <% else %>
              TBD
            <% end %>
          </div>
        </div>
      </div>

      <!-- Event Description -->
      <%= if @event.description && String.trim(@event.description) != "" do %>
        <div class="mt-6 pt-6 border-t border-gray-200">
          <h3 class="text-xl font-semibold text-gray-900 mb-3 flex items-center">
            <svg
              class="w-5 h-5 mr-2 text-blue-600"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              >
              </path>
            </svg>
            About This Trivia Night
          </h3>
          <p class="text-gray-700 leading-relaxed mb-4">
            <%= @event.description %>
          </p>

          <!-- Source Attribution -->
          <div class="flex flex-wrap items-center gap-2 text-sm text-gray-500">
            <%= if @event.last_seen_at do %>
              <span>
                <svg class="w-4 h-4 inline mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                  >
                  </path>
                </svg>
                Updated <%= PublicEvent.time_ago(@event.last_seen_at) %>
              </span>
            <% end %>

            <%= if @event.inserted_at do %>
              <span class="mx-2">•</span>
              <span>
                <svg class="w-4 h-4 inline mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                  >
                  </path>
                </svg>
                Active since <%= PublicEvent.format_active_since(@event.inserted_at) %>
              </span>
            <% end %>

            <%= if @event.source_name do %>
              <span class="mx-2">•</span>
              <span>
                <svg class="w-4 h-4 inline mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
                  >
                  </path>
                </svg>
                Source:
                <a
                  href={if @event.activity_slug, do: "https://wombie.com/activities/#{@event.activity_slug}", else: "https://wombie.com"}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-blue-600 hover:text-blue-800 hover:underline"
                >
                  <%= @event.source_name %>
                </a>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Upcoming Occurrences -->
      <%= case Events.get_upcoming_occurrences(@event) do %>
        <% upcoming when is_list(upcoming) and upcoming != [] -> %>
          <div class="mt-4 pt-4 border-t border-gray-200">
            <h4 class="font-semibold text-gray-900 mb-2 flex items-center">
              <svg
                class="w-5 h-5 mr-2 text-blue-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                >
                </path>
              </svg>
              Upcoming Dates:
            </h4>
            <ul class="space-y-2">
              <%= for occ <- Enum.take(upcoming, 5) do %>
                <li class="flex items-center text-gray-700">
                  <span class="w-2 h-2 bg-blue-600 rounded-full mr-3"></span>
                  <span class="font-medium"><%= occ["date"] %></span>
                  <%= if occ["start_time"] do %>
                    <span class="ml-2 text-gray-500">at <%= occ["start_time"] %></span>
                  <% end %>
                </li>
              <% end %>
              <%= if Enum.count(upcoming) > 5 do %>
                <li class="text-sm text-gray-500 italic">
                  +<%= Enum.count(upcoming) - 5 %> more upcoming <%= if Enum.count(upcoming) - 5 ==
                                                                         1,
                                                                       do: "date",
                                                                       else: "dates" %>
                </li>
              <% end %>
            </ul>
          </div>
        <% _ -> %>
          <!-- No upcoming occurrences -->
      <% end %>

      <!-- Event Details Footer -->
      <%= if @event.source_url do %>
        <div class="mt-4 pt-4 border-t border-gray-200 flex items-center justify-end">
          <!-- Source Link -->
          <a
            href={@event.source_url}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center px-4 py-2 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors"
          >
            View Details
            <svg
              class="w-4 h-4 ml-2"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M14 5l7 7m0 0l-7 7m7-7H3"
              >
              </path>
            </svg>
          </a>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper to get currency code from event's country
  defp get_currency_code(_event, country) when is_map(country) and not is_nil(country) do
    case Countries.get(country.code) do
      %{currency_code: currency_code} when is_binary(currency_code) ->
        currency_code

      _ ->
        "USD"
    end
  end

  defp get_currency_code(event, _) do
    # Fallback: try to get from event's country_code if available
    if Map.has_key?(event, :country_code) && event.country_code do
      case Countries.get(event.country_code) do
        %{currency_code: currency_code} when is_binary(currency_code) ->
          currency_code

        _ ->
          "USD"
      end
    else
      "USD"
    end
  end
end
