defmodule TriviaAdvisorWeb.Helpers.ImageHelpers do
  @moduledoc """
  Centralized image helper functions for cards and components.

  Provides consistent image fallback logic across venue cards, city cards,
  and other components that display images with various sources.
  """

  @doc """
  Gets the best available image for a venue card with fallback chain.
  Returns a map with url and alt text, or nil if no images available.

  Fallback order:
  1. venue_images (uploaded venue photos)
  2. venue_metadata["video_images"] (video thumbnails)
  3. city_images (Unsplash city gallery)

  ## Examples

      iex> ImageHelpers.get_venue_card_image(venue)
      %{url: "https://...", alt: "Venue name"}
  """
  def get_venue_card_image(venue) do
    cond do
      # Try venue_images first
      has_venue_images?(venue) ->
        image = List.first(venue.venue_images)
        %{
          url: image["url"],
          alt: image["alt"] || Map.get(venue, :venue_name) || "Venue photo"
        }

      # Try video_images second
      has_video_images?(venue) ->
        image = venue.venue_metadata["video_images"] |> List.first()
        %{
          url: image["url"],
          alt: "#{Map.get(venue, :venue_name) || "Venue"} video thumbnail"
        }

      # Fall back to city_images (Unsplash gallery - different image per venue)
      has_city_images?(venue) ->
        get_random_city_image(venue)

      # No images available
      true ->
        nil
    end
  end

  @doc """
  Gets the image for a city card from the unsplash_gallery field.
  Returns a map with url, alt, photographer, and photographer_url, or nil if no images available.

  ## Examples

      iex> ImageHelpers.get_city_card_image(city)
      %{url: "https://...", alt: "London cityscape", photographer: "John Doe", photographer_url: "https://..."}
  """
  def get_city_card_image(city) do
    unsplash_gallery = Map.get(city, :unsplash_gallery)

    if has_unsplash_images?(unsplash_gallery) do
      extract_city_image(unsplash_gallery, Map.get(city, :name, "City"))
    else
      nil
    end
  end

  @doc """
  Gets the hero image URL for a city.
  Returns URL string from unsplash_gallery if available, otherwise returns fallback.
  Supports both new (categorized) and old (flat) gallery structures.

  ## Examples

      iex> ImageHelpers.get_city_hero_image_url(city)
      "https://images.unsplash.com/photo-xyz..."
  """
  def get_city_hero_image_url(city) do
    case get_random_city_hero_image(city) do
      nil -> city_fallback_image()
      url -> url
    end
  end

  @doc """
  Gets the hero image alt text for a city.

  ## Examples

      iex> ImageHelpers.get_city_hero_image_alt(city)
      "Trivia nights in Austin"

      iex> ImageHelpers.get_city_hero_image_alt(city, country)
      "Trivia nights in Austin, Texas"
  """
  def get_city_hero_image_alt(city, country \\ nil) do
    if country do
      "Trivia nights in #{city.name}, #{country.name}"
    else
      "Trivia nights in #{city.name}"
    end
  end

  @doc """
  Gets the fallback hero image for cities.
  Used when a city doesn't have an unsplash_gallery.
  """
  def city_fallback_image do
    "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=1200&h=400&fit=crop&q=80"
  end

  @doc """
  Gets venue images for gallery display with fallback logic.
  Returns a list of up to 5 images from venue_images, or falls back to city_images.

  Fallback order:
  1. venue_images (uploaded venue photos - up to 5)
  2. primary_image from Locations.Venue (single image)
  3. city_images from Unsplash gallery (up to 5)

  ## Examples

      iex> ImageHelpers.get_venue_gallery_images(venue, city)
      [%{"url" => "https://...", "alt" => "..."}]
  """
  def get_venue_gallery_images(venue, city) do
    cond do
      # Try venue_images first (JSONB array) with validation
      has_venue_images?(venue) ->
        venue.venue_images
        |> Enum.filter(&is_map/1)
        |> Enum.filter(&is_binary(Map.get(&1, "url")))
        |> Enum.take(5)

      # Fallback to primary_image from Locations.Venue
      primary_image = get_primary_image(venue) ->
        [primary_image]

      # Fallback to city images
      Map.get(city, :unsplash_gallery) && is_map(city.unsplash_gallery) ->
        get_city_gallery_images(city.unsplash_gallery)

      # No images available
      true ->
        []
    end
  end

  @doc """
  Extracts images from unsplash_gallery JSONB structure for gallery display.
  Returns a list of up to 5 images.

  ## Examples

      iex> ImageHelpers.get_city_gallery_images(unsplash_gallery)
      [%{"url" => "https://...", "alt" => "..."}]
  """
  def get_city_gallery_images(unsplash_gallery) when is_map(unsplash_gallery) do
    with active_cat when is_binary(active_cat) <- unsplash_gallery["active_category"],
         categories when is_map(categories) <- unsplash_gallery["categories"],
         category when is_map(category) <- categories[active_cat],
         images when is_list(images) <- category["images"] do
      images
      |> Enum.filter(&is_map/1)
      |> Enum.filter(&is_binary(Map.get(&1, "url")))
      |> Enum.take(5)
    else
      _ -> []
    end
  end

  def get_city_gallery_images(_), do: []

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  # Venue Images Validation

  defp has_venue_images?(venue) do
    venue_images = Map.get(venue, :venue_images)
    is_list(venue_images) &&
      length(venue_images) > 0 &&
      get_in(venue_images, [Access.at(0), "url"])
  end

  # Video Images Validation

  defp has_video_images?(venue) do
    venue_metadata = Map.get(venue, :venue_metadata)
    is_map(venue_metadata) &&
      is_list(venue_metadata["video_images"]) &&
      length(venue_metadata["video_images"]) > 0 &&
      get_in(venue_metadata, ["video_images", Access.at(0), "url"])
  end

  # City Images Validation (Unsplash Gallery Structure)

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
      alt: "#{Map.get(venue, :city_name, "City")} cityscape"
    }
  end

  # Get primary image from Locations.Venue if available
  defp get_primary_image(venue) do
    try do
      TriviaAdvisor.Locations.Venue.primary_image(venue)
    rescue
      _ -> nil
    end
  end

  # Get random city hero image - supports both old and new gallery structures
  # Uses city_id as seed for consistent random selection (same city always gets same image)
  defp get_random_city_hero_image(city) do
    gallery = Map.get(city, :unsplash_gallery)
    city_id = Map.get(city, :id) || 0

    cond do
      # New structure: categorized gallery
      is_map(gallery) && Map.has_key?(gallery, "active_category") ->
        active_cat = gallery["active_category"]
        images = get_in(gallery, ["categories", active_cat, "images"]) || []

        if Enum.empty?(images) do
          nil
        else
          index = rem(city_id, length(images))
          image = Enum.at(images, index)
          image["url"]
        end

      # Old structure: flat gallery with images array
      is_map(gallery) && Map.has_key?(gallery, "images") ->
        images = gallery["images"] || []

        if Enum.empty?(images) do
          nil
        else
          index = rem(city_id, length(images))
          image = Enum.at(images, index)
          image["url"]
        end

      # No gallery
      true ->
        nil
    end
  end

  # Check if unsplash_gallery has valid images (supports both structures)
  defp has_unsplash_images?(gallery) when is_map(gallery) do
    cond do
      # New structure: categorized gallery
      Map.has_key?(gallery, "active_category") ->
        active_cat = gallery["active_category"]
        categories = gallery["categories"]

        is_binary(active_cat) &&
          is_map(categories) &&
          is_map(categories[active_cat]) &&
          is_list(categories[active_cat]["images"]) &&
          length(categories[active_cat]["images"]) > 0 &&
          get_in(categories, [active_cat, "images", Access.at(0), "url"])

      # Old structure: flat gallery
      Map.has_key?(gallery, "images") ->
        images = gallery["images"]
        is_list(images) && length(images) > 0 && get_in(images, [Access.at(0), "url"])

      # Unknown structure
      true ->
        false
    end
  end

  defp has_unsplash_images?(_), do: false

  # Extract image data from unsplash gallery (supports both structures)
  defp extract_city_image(gallery, city_name) do
    image =
      cond do
        # New structure: categorized gallery
        Map.has_key?(gallery, "active_category") ->
          active_cat = gallery["active_category"]
          images = gallery["categories"][active_cat]["images"]
          List.first(images)

        # Old structure: flat gallery
        Map.has_key?(gallery, "images") ->
          List.first(gallery["images"])

        true ->
          nil
      end

    if image do
      %{
        url: image["url"],
        alt: image["alt"] || "#{city_name} cityscape",
        photographer: image["photographer"],
        photographer_url: image["photographer_url"]
      }
    else
      nil
    end
  end
end
