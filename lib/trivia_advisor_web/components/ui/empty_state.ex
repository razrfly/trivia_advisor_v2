defmodule TriviaAdvisorWeb.Components.UI.EmptyState do
  @moduledoc """
  Empty state component for displaying when no content is available.
  """
  use Phoenix.Component

  @doc """
  Renders an empty state message with optional action.

  ## Examples

      <EmptyState.empty_state
        icon="🔍"
        title="No venues found"
        description="There are no venues in this city yet."
        action_text="Back to Cities"
        action_path="/cities"
      />
  """
  attr :icon, :string, default: "📭"
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :action_text, :string, default: nil
  attr :action_path, :string, default: nil

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-12 px-4">
      <!-- Icon -->
      <div class="text-6xl mb-4">
        <%= @icon %>
      </div>

      <!-- Title -->
      <h3 class="text-xl font-semibold text-gray-900 mb-2">
        <%= @title %>
      </h3>

      <!-- Description -->
      <%= if @description do %>
        <p class="text-gray-600 mb-6 max-w-md mx-auto">
          <%= @description %>
        </p>
      <% end %>

      <!-- Action Button -->
      <%= if @action_text && @action_path do %>
        <.link
          navigate={@action_path}
          class="inline-flex items-center px-6 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors"
        >
          <svg
            class="w-5 h-5 mr-2"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M10 19l-7-7m0 0l7-7m-7 7h18"
            >
            </path>
          </svg>
          <%= @action_text %>
        </.link>
      <% end %>
    </div>
    """
  end
end
