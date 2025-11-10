defmodule TriviaAdvisorWeb.Components.Cards.EventCard do
  @moduledoc """
  Event card component for displaying trivia event information.
  """
  use Phoenix.Component
  alias TriviaAdvisor.Events

  @doc """
  Renders an event card with upcoming occurrences.

  ## Examples

      <EventCard.event_card event={event} />
  """
  attr :event, :map, required: true
  attr :show_venue, :boolean, default: false

  def event_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-md p-6">
      <!-- Event Header -->
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <h3 class="text-2xl font-semibold text-gray-900 mb-2">
            <%= @event.title %>
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

      <!-- Upcoming Occurrences -->
      <%= if upcoming = Events.get_upcoming_occurrences(@event) do %>
        <%= if !Enum.empty?(upcoming) do %>
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
              <%= if length(upcoming) > 5 do %>
                <li class="text-sm text-gray-500 italic">
                  +<%= length(upcoming) - 5 %> more upcoming <%= if length(upcoming) - 5 ==
                                                                     1,
                                                                   do: "date",
                                                                   else: "dates" %>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
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
end
