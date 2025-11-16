defmodule TriviaAdvisorWeb.Components.UI.Badge do
  @moduledoc """
  Reusable badge component for displaying labels, counts, and status indicators.

  Supports different color variants and optional icons.
  """
  use Phoenix.Component
  alias TriviaAdvisorWeb.Components.UI.Icons

  @doc """
  Renders a badge component.

  ## Attributes
  - `variant` - Color variant: blue, indigo, purple, green (default: blue)
  - `icon` - Optional icon name from Icons component
  - `class` - Additional CSS classes (optional)

  ## Slots
  - `inner_block` - Badge content (required)

  ## Examples

      <Badge.badge variant="blue">2.5 km</Badge.badge>
      <Badge.badge variant="indigo" icon="building">5 Venues</Badge.badge>
      <Badge.badge variant="purple">Source Name</Badge.badge>
  """
  attr :variant, :string, default: "blue"
  attr :icon, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def badge(assigns) do
    # Determine badge styles based on variant
    assigns = assign(assigns, :badge_classes, get_badge_classes(assigns.variant, assigns.class))

    ~H"""
    <span class={@badge_classes}>
      <%= if @icon do %>
        <Icons.icon name={@icon} class="w-4 h-4 mr-1.5" />
      <% end %>
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  # Get badge color classes based on variant
  defp get_badge_classes("blue", custom_class) do
    base_classes = "inline-flex items-center px-2 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded-full"
    merge_classes(base_classes, custom_class)
  end

  defp get_badge_classes("indigo", custom_class) do
    base_classes = "inline-flex items-center px-3 py-1 bg-indigo-100 text-indigo-800 text-sm font-medium rounded-full"
    merge_classes(base_classes, custom_class)
  end

  defp get_badge_classes("purple", custom_class) do
    base_classes = "inline-block px-3 py-1 bg-purple-100 text-purple-800 text-sm font-medium rounded-full"
    merge_classes(base_classes, custom_class)
  end

  defp get_badge_classes("green", custom_class) do
    base_classes = "inline-flex items-center px-3 py-1 bg-green-100 text-green-800 text-sm font-medium rounded-full"
    merge_classes(base_classes, custom_class)
  end

  # Default to blue for unknown variants
  defp get_badge_classes(_variant, custom_class) do
    get_badge_classes("blue", custom_class)
  end

  # Merge custom classes with base classes
  defp merge_classes(base, ""), do: base
  defp merge_classes(base, custom), do: "#{base} #{custom}"
end
