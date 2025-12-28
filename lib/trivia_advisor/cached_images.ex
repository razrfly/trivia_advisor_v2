defmodule TriviaAdvisor.CachedImages do
  @moduledoc """
  Helper module for retrieving cached R2 image URLs.

  Uses SQL functions to fetch images from the cached_images table,
  which stores R2/CDN URLs for venue images.

  SQL Functions available:
  - get_entity_image_url(entity_type TEXT, entity_id INTEGER, position INTEGER)
  - get_venue_image_url(venue_slug TEXT, position INTEGER)

  These functions return COALESCE(cdn_url, original_url) from cached_images
  where status = 'cached', or NULL if no cached image exists.
  """

  alias TriviaAdvisor.Repo

  @doc """
  Gets the cached R2 image URL for a venue by slug.
  Returns the CDN URL if cached, nil otherwise.

  ## Examples

      iex> get_venue_image_url("beer-merchants-tap", 0)
      "https://cdn.quizadvisor.com/venues/beer-merchants-tap/image-0.jpg"

      iex> get_venue_image_url("nonexistent-venue", 0)
      nil
  """
  def get_venue_image_url(venue_slug, position \\ 0) when is_binary(venue_slug) do
    case Repo.query("SELECT get_venue_image_url($1, $2)", [venue_slug, position]) do
      {:ok, %{rows: [[url]]}} when is_binary(url) -> url
      _ -> nil
    end
  end

  @doc """
  Gets the cached R2 image URL for any entity type.
  Returns the CDN URL if cached, nil otherwise.

  ## Examples

      iex> get_entity_image_url("venue", 123, 0)
      "https://cdn.quizadvisor.com/venues/123/image-0.jpg"

      iex> get_entity_image_url("city", 456, 0)
      "https://cdn.quizadvisor.com/cities/456/image-0.jpg"
  """
  def get_entity_image_url(entity_type, entity_id, position \\ 0)
      when is_binary(entity_type) and is_integer(entity_id) do
    case Repo.query("SELECT get_entity_image_url($1, $2, $3)", [entity_type, entity_id, position]) do
      {:ok, %{rows: [[url]]}} when is_binary(url) -> url
      _ -> nil
    end
  end

  @doc """
  Gets a venue image URL from the cached_images table.
  This is the primary function to use for displaying venue images.

  ## Examples

      iex> get_venue_image_with_fallback("beer-merchants-tap", 0)
      "https://cdn.quizadvisor.com/venues/beer-merchants-tap/image-0.jpg"

  ## Parameters
    - venue_slug: The venue's URL slug
    - position: The image position/index (default 0 for primary image)
  """
  def get_venue_image_with_fallback(venue_slug, _venue_images \\ nil, position \\ 0) do
    get_venue_image_url(venue_slug, position)
  end

  @doc """
  Gets a venue image map (url + alt) from cached_images.
  Returns a map with :url and :alt keys, or nil if no image available.

  ## Examples

      iex> get_venue_image_map_with_fallback("beer-merchants-tap", nil, "Beer Merchants Tap")
      %{url: "https://...", alt: "Beer Merchants Tap"}
  """
  def get_venue_image_map_with_fallback(venue_slug, _venue_images \\ nil, venue_name, position \\ 0) do
    case get_venue_image_url(venue_slug, position) do
      nil ->
        nil

      url ->
        %{url: url, alt: venue_name || "Venue photo"}
    end
  end
end
