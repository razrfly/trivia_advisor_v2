defmodule TriviaAdvisorWeb.Components.UI.CityAutocomplete do
  @moduledoc """
  LiveView component for city autocomplete search.
  Provides real-time search suggestions with direct navigation.
  """
  use TriviaAdvisorWeb, :live_component

  alias TriviaAdvisor.Locations

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:suggestions, [])
     |> assign(:show_dropdown, false)
     |> assign(:selected_index, -1)}
  end

  @impl true
  def handle_event("search_input", %{"city_search" => query}, socket) do
    suggestions =
      if String.length(query) >= 2 do
        Locations.search_cities(query)
        |> Enum.take(5)  # Limit to 5 suggestions
      else
        []
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:suggestions, suggestions)
     |> assign(:show_dropdown, !Enum.empty?(suggestions))
     |> assign(:selected_index, -1)}
  end

  @impl true
  def handle_event("select_city", %{"slug" => slug}, socket) do
    {:noreply, push_navigate(socket, to: "/cities/#{slug}")}
  end

  @impl true
  def handle_event("submit_search", %{"city_search" => query}, socket) do
    # Fallback: navigate to cities index with search parameter
    {:noreply, push_navigate(socket, to: "/cities?search=#{query}")}
  end

  @impl true
  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative" id={@id} phx-click-away="close_dropdown" phx-target={@myself}>
      <form phx-submit="submit_search" phx-target={@myself} class="flex gap-2">
        <input
          type="text"
          name="city_search"
          value={@search_query}
          placeholder="Search for a city..."
          phx-change="search_input"
          phx-debounce="300"
          phx-target={@myself}
          class="flex-1 px-4 py-3 rounded-lg bg-white border border-gray-300 text-gray-900 placeholder:text-gray-500 shadow-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          autocomplete="off"
        />
        <button
          type="submit"
          class="px-6 py-3 bg-white text-blue-600 font-semibold rounded-lg hover:bg-gray-100 transition-colors"
        >
          Search
        </button>
      </form>

      <!-- Dropdown Suggestions -->
      <%= if @show_dropdown do %>
        <div class="absolute z-50 w-full mt-2 bg-white rounded-lg shadow-xl border border-gray-200 max-h-96 overflow-y-auto">
          <%= for {city, index} <- Enum.with_index(@suggestions) do %>
            <button
              type="button"
              phx-click="select_city"
              phx-value-slug={Locations.city_url_slug(city)}
              phx-target={@myself}
              class={"px-4 py-3 w-full text-left hover:bg-blue-50 transition-colors border-b border-gray-100 last:border-b-0 #{if index == @selected_index, do: "bg-blue-50", else: ""}"}
            >
              <p class="font-semibold text-gray-900"><%= city.name %></p>
              <p class="text-sm text-gray-600"><%= city.country.name %></p>
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
