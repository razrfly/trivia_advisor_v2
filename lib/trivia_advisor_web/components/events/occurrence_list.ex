defmodule TriviaAdvisorWeb.Components.Events.OccurrenceList do
  @moduledoc """
  Component for displaying event occurrences list.
  """
  use Phoenix.Component

  @doc """
  Renders a list of event occurrences.

  ## Examples

      <OccurrenceList.occurrence_list occurrences={upcoming_occurrences} limit={5} />
  """
  attr :occurrences, :list, required: true
  attr :limit, :integer, default: nil
  attr :show_header, :boolean, default: true

  def occurrence_list(assigns) do
    # Apply limit if specified
    occurrences =
      if assigns.limit do
        Enum.take(assigns.occurrences, assigns.limit)
      else
        assigns.occurrences
      end

    remaining =
      if assigns.limit && length(assigns.occurrences) > assigns.limit do
        length(assigns.occurrences) - assigns.limit
      else
        0
      end

    assigns =
      assigns
      |> assign(:limited_occurrences, occurrences)
      |> assign(:remaining, remaining)

    ~H"""
    <div class="occurrence-list">
      <%= if @show_header do %>
        <h4 class="font-semibold text-gray-900 mb-3 flex items-center">
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
          Upcoming Dates
        </h4>
      <% end %>

      <%= if Enum.empty?(@limited_occurrences) do %>
        <p class="text-gray-500 italic">No upcoming occurrences</p>
      <% else %>
        <ul class="space-y-2">
          <%= for occ <- @limited_occurrences do %>
            <li class="flex items-center text-gray-700">
              <span class="w-2 h-2 bg-blue-600 rounded-full mr-3 flex-shrink-0"></span>
              <div class="flex-1">
                <span class="font-medium"><%= occ["date"] %></span>
                <%= if occ["start_time"] do %>
                  <span class="ml-2 text-gray-600">
                    <%= format_time(occ["start_time"]) %>
                  </span>
                <% end %>
                <%= if occ["end_time"] do %>
                  <span class="text-gray-500">
                    - <%= format_time(occ["end_time"]) %>
                  </span>
                <% end %>
                <%= if occ["status"] && occ["status"] != "scheduled" do %>
                  <span class="ml-2 text-xs px-2 py-0.5 bg-yellow-100 text-yellow-800 rounded">
                    <%= occ["status"] %>
                  </span>
                <% end %>
              </div>
            </li>
          <% end %>

          <%= if @remaining > 0 do %>
            <li class="text-sm text-gray-500 italic">
              +<%= @remaining %> more upcoming <%= if @remaining == 1, do: "date", else: "dates" %>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  defp format_time(time_string) when is_binary(time_string) do
    case Time.from_iso8601(time_string <> ":00") do
      {:ok, time} ->
        time
        |> Time.to_string()
        |> String.slice(0..4)

      _ ->
        time_string
    end
  end

  defp format_time(_), do: ""
end
