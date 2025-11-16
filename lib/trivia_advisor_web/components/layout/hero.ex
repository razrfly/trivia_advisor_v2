defmodule TriviaAdvisorWeb.Components.Layout.Hero do
  @moduledoc """
  Hero banner component for city and country pages.

  Provides flexible hero sections with:
  - Background images with overlay gradients
  - Customizable layouts (centered vs bottom-aligned)
  - Optional photographer attribution
  - Fallback to text-only header when no image
  """
  use Phoenix.Component

  @doc """
  Renders a hero banner with image and content overlay.

  ## Examples

      <!-- City hero (bottom-aligned) -->
      <Hero.hero_banner
        image_url={@hero_image_url}
        alt={@hero_image_alt}
        height="h-64 md:h-80 lg:h-96"
        layout="bottom"
        gradient="from-gray-900/80 to-transparent"
      >
        <:title>Trivia Nights in <%= @city.name %></:title>
        <:subtitle><%= @country.name %> • <%= @venue_count %> venues</:subtitle>
      </Hero.hero_banner>

      <!-- Country hero (centered with attribution) -->
      <Hero.hero_banner
        image_url={@hero_image.url}
        alt={@hero_image.alt}
        height="h-64 md:h-96"
        layout="center"
        gradient="from-transparent via-transparent to-black"
        gradient_opacity="opacity-60"
        photographer={@hero_image[:photographer]}
        photographer_url={@hero_image[:photographer_url]}
      >
        <:title>Trivia Nights in <%= @country.name %></:title>
        <:subtitle>Explore <%= @city_count %> cities with trivia events</:subtitle>
      </Hero.hero_banner>
  """
  attr :image_url, :string, default: nil, doc: "Hero image URL"
  attr :alt, :string, default: "", doc: "Image alt text"
  attr :height, :string, default: "h-64 md:h-80 lg:h-96", doc: "Height classes"
  attr :layout, :string, default: "bottom", doc: "Layout: 'center' or 'bottom'"
  attr :gradient, :string, default: "from-gray-900/80 to-transparent", doc: "Gradient direction and colors"
  attr :gradient_opacity, :string, default: nil, doc: "Optional gradient opacity class"
  attr :photographer, :string, default: nil, doc: "Photographer name for attribution"
  attr :photographer_url, :string, default: nil, doc: "Photographer profile URL"
  attr :fallback_title, :string, default: nil, doc: "Title for text-only fallback"
  attr :fallback_subtitle, :string, default: nil, doc: "Subtitle for text-only fallback"

  slot :title, required: true, doc: "Hero title content"
  slot :subtitle, required: true, doc: "Hero subtitle content"

  def hero_banner(assigns) do
    # Determine layout classes
    assigns = assign(assigns, :layout_classes, get_layout_classes(assigns.layout))
    assigns = assign(assigns, :title_classes, get_title_classes(assigns.layout))
    assigns = assign(assigns, :has_image, assigns.image_url != nil)

    ~H"""
    <%= if @has_image do %>
      <!-- Hero with Image -->
      <div class={"relative #{@height} bg-gray-900"}>
        <img
          src={@image_url}
          alt={@alt}
          class="w-full h-full object-cover opacity-70"
        />
        <div class={"absolute inset-0 bg-gradient-to-t #{@gradient} #{@gradient_opacity}"}>
        </div>
        <div class={"absolute inset-0 #{@layout_classes}"}>
          <div class={@title_classes}>
            <h1 class="text-4xl md:text-5xl lg:text-6xl font-bold text-white mb-2 drop-shadow-lg">
              <%= render_slot(@title) %>
            </h1>
            <p class="text-xl md:text-2xl text-gray-200 drop-shadow-lg">
              <%= render_slot(@subtitle) %>
            </p>
          </div>
        </div>

        <!-- Photographer Attribution -->
        <%= if @photographer && @photographer_url do %>
          <div class="absolute bottom-2 right-2 bg-black bg-opacity-60 text-white text-xs px-3 py-1 rounded">
            Photo by
            <a
              href={@photographer_url}
              target="_blank"
              rel="noopener noreferrer"
              class="underline hover:text-gray-200"
            >
              <%= @photographer %>
            </a>
          </div>
        <% end %>
      </div>
    <% else %>
      <!-- Fallback: Text-only Header -->
      <div class="bg-white border-b">
        <div class="container mx-auto px-4 py-8">
          <h1 class="text-4xl font-bold text-gray-900 mb-2">
            <%= if @fallback_title, do: @fallback_title, else: render_slot(@title) %>
          </h1>
          <p class="text-lg text-gray-600">
            <%= if @fallback_subtitle, do: @fallback_subtitle, else: render_slot(@subtitle) %>
          </p>
        </div>
      </div>
    <% end %>
    """
  end

  # Get layout container classes based on layout type
  defp get_layout_classes("center"), do: "flex items-center justify-center"
  defp get_layout_classes("bottom"), do: "container mx-auto px-4 h-full flex flex-col justify-end pb-8"
  defp get_layout_classes(_), do: "container mx-auto px-4 h-full flex flex-col justify-end pb-8"

  # Get title container classes based on layout type
  defp get_title_classes("center"), do: "text-center text-white px-4"
  defp get_title_classes("bottom"), do: ""
  defp get_title_classes(_), do: ""
end
