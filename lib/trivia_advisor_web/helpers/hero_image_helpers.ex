defmodule TriviaAdvisorWeb.Helpers.HeroImageHelpers do
  @moduledoc """
  Helpers for generating hero image URLs for cities and other entities.

  Provides fallback logic using the city's unsplash_gallery from the database.
  """

  @doc """
  Gets the hero image URL for a city.

  Returns a random image from the city's Unsplash gallery if available,
  otherwise returns a fallback placeholder.

  ## Parameters
    - city: City struct with unsplash_gallery field

  ## Examples

      iex> HeroImageHelpers.city_hero_image(city_with_gallery)
      "https://images.unsplash.com/photo-xyz..."

      iex> HeroImageHelpers.city_hero_image(city_without_gallery)
      "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=1200&h=400&fit=crop&q=80"
  """
  def city_hero_image(city) do
    # Try to get image from city's unsplash_gallery
    case get_random_city_image(city.id, city.unsplash_gallery) do
      nil -> city_fallback_image()
      url -> url
    end
  end

  @doc """
  Gets the absolute URL for a city hero image.

  ## Parameters
    - city: City struct

  ## Examples

      iex> HeroImageHelpers.city_hero_image_url(city)
      "https://images.unsplash.com/photo-xyz..."
  """
  def city_hero_image_url(city) do
    # city_hero_image already returns absolute URLs from Unsplash
    city_hero_image(city)
  end

  @doc """
  Gets the fallback hero image for cities.

  This is used when a city doesn't have an unsplash_gallery.
  Uses a pleasant bar/pub image from Unsplash.
  """
  def city_fallback_image do
    # Use a nice bar/pub image as fallback
    "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=1200&h=400&fit=crop&q=80"
  end

  @doc """
  Gets a themed placeholder image for a city.

  Uses the city name to generate a unique placeholder.

  ## Parameters
    - city: City struct

  ## Examples

      iex> HeroImageHelpers.city_placeholder_image(city)
      "https://placehold.co/1200x400/4F46E5/FFFFFF?text=Austin"
  """
  def city_placeholder_image(city) do
    # Use a nice blue gradient color scheme
    city_name = URI.encode(city.name)
    "https://placehold.co/1200x400/4F46E5/FFFFFF?text=#{city_name}"
  end

  @doc """
  Gets the hero image alt text for a city.

  ## Parameters
    - city: City struct

  ## Examples

      iex> HeroImageHelpers.city_hero_image_alt(city)
      "Trivia nights in Austin, Texas"
  """
  def city_hero_image_alt(city, country \\ nil) do
    if country do
      "Trivia nights in #{city.name}, #{country.name}"
    else
      "Trivia nights in #{city.name}"
    end
  end

  # Private functions

  @doc false
  @spec get_random_city_image(integer(), map() | nil) :: String.t() | nil
  defp get_random_city_image(_city_id, nil), do: nil

  defp get_random_city_image(city_id, gallery) when is_map(gallery) do
    # Get images from the gallery
    images = gallery["images"] || []

    if Enum.empty?(images) do
      nil
    else
      # Use city ID as seed for consistent random selection
      # Same city always gets the same image
      index = rem(city_id, length(images))
      image = Enum.at(images, index)

      # Return the main URL (not thumb_url)
      image["url"]
    end
  end

  defp get_random_city_image(_city_id, _gallery), do: nil
end
