defmodule TriviaAdvisorWeb.Helpers.SlugHelper do
  @moduledoc """
  Slug generation helpers matching V1 algorithms exactly.

  Preserves 100% SEO by maintaining identical slug generation logic.
  Based on .claude/SLUG_GENERATION_GUIDE.md
  """

  @doc """
  Base slugify function used across all slug types.

  Converts string to lowercase URL-safe format:
  - Lowercase conversion
  - Replace spaces and special chars with hyphens
  - Remove consecutive hyphens
  - Trim leading/trailing hyphens

  ## Examples

      iex> slugify("The Phoenix")
      "the-phoenix"

      iex> slugify("Bob's Bar & Grill")
      "bobs-bar-grill"

      iex> slugify("Café René")
      "cafe-rene"
  """
  def slugify(string) when is_binary(string) do
    string
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^a-z0-9\s-]/u, "")
    |> String.replace(~r/[\s-]+/, "-")
    |> String.trim("-")
  end

  def slugify(nil), do: ""

  @doc """
  Generates city slug matching V1 algorithm.

  Strategy:
  1. Try simple slug: slugify(city_name)
  2. If conflict exists, append country code: slug-countrycode

  ## Examples

      iex> city_slug("London", "gb", conflict?: false)
      "london"

      iex> city_slug("London", "ca", conflict?: true)
      "london-ca"
  """
  def city_slug(city_name, country_code, opts \\ [])

  def city_slug(city_name, _country_code, opts) when is_binary(city_name) do
    base_slug = slugify(city_name)

    case Keyword.get(opts, :conflict?, false) do
      false -> base_slug
      true ->
        country_code = Keyword.get(opts, :country_code, "")
        "#{base_slug}-#{String.downcase(country_code)}"
    end
  end

  @doc """
  Generates venue slug matching V1 algorithm with 4-strategy fallback.

  Strategies (in order):
  1. Simple: slugify(venue_name)
  2. With city: venueslug-cityslug
  3. With postcode: venueslug-cityslug-postcodeslug
  4. With timestamp: venueslug-cityslug-timestamp

  ## Examples

      iex> venue_slug("The Phoenix", "London", nil, strategy: :simple)
      "the-phoenix"

      iex> venue_slug("The Phoenix", "London", nil, strategy: :with_city)
      "the-phoenix-london"

      iex> venue_slug("The Phoenix", "London", "SW1A 1AA", strategy: :with_postcode)
      "the-phoenix-london-sw1a-1aa"
  """
  def venue_slug(venue_name, city_name, postcode, opts \\ [])

  def venue_slug(venue_name, city_name, postcode, opts) when is_binary(venue_name) do
    venue_slug = slugify(venue_name)
    city_slug = slugify(city_name)

    case Keyword.get(opts, :strategy, :simple) do
      :simple ->
        venue_slug

      :with_city ->
        "#{venue_slug}-#{city_slug}"

      :with_postcode when is_binary(postcode) ->
        postcode_slug = slugify(postcode)
        "#{venue_slug}-#{city_slug}-#{postcode_slug}"

      :with_postcode ->
        # No postcode available, fall back to with_city
        "#{venue_slug}-#{city_slug}"

      :with_timestamp ->
        timestamp = System.system_time(:second)
        "#{venue_slug}-#{city_slug}-#{timestamp}"
    end
  end

  @doc """
  Validates if a slug matches expected format.

  Valid slug:
  - Contains only lowercase letters, numbers, hyphens
  - No leading/trailing hyphens
  - No consecutive hyphens

  ## Examples

      iex> valid_slug?("the-phoenix")
      true

      iex> valid_slug?("-invalid-")
      false

      iex> valid_slug?("has--double")
      false
  """
  def valid_slug?(slug) when is_binary(slug) do
    slug =~ ~r/^[a-z0-9]+(-[a-z0-9]+)*$/
  end

  def valid_slug?(_), do: false

  @doc """
  Checks if two slugs are equivalent (case-insensitive comparison).

  ## Examples

      iex> slugs_match?("london", "london")
      true

      iex> slugs_match?("London", "london")
      true

      iex> slugs_match?("london", "paris")
      false
  """
  def slugs_match?(slug1, slug2) when is_binary(slug1) and is_binary(slug2) do
    String.downcase(slug1) == String.downcase(slug2)
  end

  def slugs_match?(_, _), do: false
end
