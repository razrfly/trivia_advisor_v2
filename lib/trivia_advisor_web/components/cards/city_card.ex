defmodule TriviaAdvisorWeb.Components.Cards.CityCard do
  @moduledoc """
  City card component for displaying city information.
  """
  use Phoenix.Component
  alias TriviaAdvisor.Locations

  @doc """
  Renders a city card with link to city page.

  ## Examples

      <CityCard.city_card city={city} base_url={@base_url} />
  """
  attr :city, :map, required: true
  attr :base_url, :string, required: true
  attr :show_country, :boolean, default: true

  def city_card(assigns) do
    # Generate the appropriate city URL slug (handles disambiguation)
    assigns =
      assigns
      |> assign(:city_url_slug, Locations.city_url_slug(assigns.city))
      |> assign(:city_image, get_city_card_image(assigns.city))

    ~H"""
    <div class="bg-white rounded-lg shadow-md hover:shadow-xl transition-shadow duration-200">
      <div class="relative overflow-hidden">
        <.link
          navigate={"/cities/#{@city_url_slug}"}
          class="block group"
        >
          <%= if @city_image do %>
            <img
              src={@city_image.url}
              alt={@city_image.alt}
              loading="lazy"
              class="w-full h-48 object-cover rounded-t-lg"
            />
          <% end %>

          <div class="p-6">
            <!-- City Name -->
            <h3 class="text-xl font-semibold text-gray-900 mb-2 group-hover:text-blue-600 transition-colors">
              <%= @city.name %>
            </h3>

            <!-- Country Name -->
            <%= if @show_country do %>
              <p class="text-gray-600 mb-3">
                <%= @city.country.name %>
              </p>
            <% end %>

            <!-- Venue Count Badge -->
            <%= if Map.get(@city, :venue_count) do %>
              <div class="mb-3">
                <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-indigo-100 text-indigo-800">
                  <svg
                    class="w-4 h-4 mr-1.5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"
                    >
                    </path>
                  </svg>
                  <%= @city.venue_count %> <%= if @city.venue_count == 1,
                    do: "Venue",
                    else: "Venues" %>
                </span>
              </div>
            <% end %>

            <!-- Coordinates (if available) -->
            <%= if @city.latitude && @city.longitude do %>
              <div class="flex items-center text-xs text-gray-500">
                <svg
                  class="w-4 h-4 mr-1"
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
                <span>
                  <%= Float.round(Decimal.to_float(@city.latitude), 2) %>,
                  <%= Float.round(Decimal.to_float(@city.longitude), 2) %>
                </span>
              </div>
            <% end %>

            <!-- Alternate Names (if available) -->
            <%= if @city.alternate_names && length(@city.alternate_names) > 0 do %>
              <div class="mt-2 text-xs text-gray-400">
                Also known as: <%= Enum.take(@city.alternate_names, 2) |> Enum.join(", ") %>
              </div>
            <% end %>
          </div>
        </.link>

        <%= if @city_image && @city_image[:photographer] && @city_image[:photographer_url] do %>
          <a
            href={@city_image.photographer_url}
            target="_blank"
            rel="noopener noreferrer"
            class="absolute bottom-0 right-0 bg-black bg-opacity-60 text-white text-xs px-2 py-1 rounded-tl z-10 pointer-events-auto hover:bg-opacity-80"
          >
            Photo by
            <span class="underline hover:text-gray-200">
              <%= @city_image.photographer %>
            </span>
          </a>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Gets the image for a city card from the unsplash_gallery field.
  Returns a map with url, alt, photographer, and photographer_url, or nil if no images available.
  """
  def get_city_card_image(city) do
    unsplash_gallery = Map.get(city, :unsplash_gallery)

    if has_unsplash_images?(unsplash_gallery) do
      extract_city_image(unsplash_gallery, city.name)
    else
      nil
    end
  end

  defp has_unsplash_images?(gallery) when is_map(gallery) do
    # Check for Unsplash gallery structure: %{"active_category" => "general", "categories" => %{...}}
    active_cat = gallery["active_category"]
    categories = gallery["categories"]

    is_binary(active_cat) &&
      is_map(categories) &&
      is_map(categories[active_cat]) &&
      is_list(categories[active_cat]["images"]) &&
      length(categories[active_cat]["images"]) > 0 &&
      get_in(categories, [active_cat, "images", Access.at(0), "url"])
  end

  defp has_unsplash_images?(_), do: false

  defp extract_city_image(gallery, city_name) do
    active_cat = gallery["active_category"]
    images = gallery["categories"][active_cat]["images"]

    # Get the first image from the gallery
    image = List.first(images)

    %{
      url: image["url"],
      alt: image["alt"] || "#{city_name} cityscape",
      photographer: image["photographer"],
      photographer_url: image["photographer_url"]
    }
  end
end
