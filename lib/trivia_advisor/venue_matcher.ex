defmodule TriviaAdvisor.VenueMatcher do
  @moduledoc """
  Intelligent fuzzy matching for venue slugs.

  Handles common patterns from V1 URLs that no longer exist in V2:
  - Numeric ID suffixes (e.g., "albion-hotel-1759813035")
  - Event-specific patterns (e.g., "00s-quiz-at-border-city-ale-house")
  - Typos and close matches

  Returns one of:
  - {:redirect, venue, confidence} - High confidence single match (≥90%)
  - {:suggestions, [{venue, confidence}, ...]} - Medium confidence matches (≥70%)
  - :no_match - No suitable matches found
  """

  alias TriviaAdvisor.{Repo, Locations.Venue}
  import Ecto.Query
  require Logger

  # Confidence thresholds
  @redirect_threshold 0.90
  @suggestion_threshold 0.70
  @max_suggestions 5

  @doc """
  Find similar venues for a missing slug.

  Returns:
  - {:redirect, venue, confidence} for high-confidence single match
  - {:suggestions, [{venue, confidence}, ...]} for medium-confidence matches
  - :no_match when no suitable venues found

  ## Examples

      iex> VenueMatcher.find_similar("albion-hotel-1759813035")
      {:redirect, %Venue{slug: "albion-hotel"}, 0.95}

      iex> VenueMatcher.find_similar("city-ale")
      {:suggestions, [{%Venue{slug: "city-ale-house"}, 0.85}, ...]}

      iex> VenueMatcher.find_similar("xyz-completely-random-123")
      :no_match
  """
  def find_similar(missing_slug) when is_binary(missing_slug) do
    cache_key = "venue_match_#{missing_slug}"

    ConCache.get_or_store(:city_cache, cache_key, fn ->
      do_find_similar(missing_slug)
    end)
  end

  defp do_find_similar(missing_slug) do
    normalized = normalize_slug(missing_slug)

    Logger.debug("VenueMatcher: Looking for '#{missing_slug}', normalized to '#{normalized}'")

    # Strategy 1: Try exact match on normalized slug first
    case get_venue_by_slug(normalized) do
      %Venue{} = venue ->
        Logger.info("VenueMatcher: Exact normalized match for '#{missing_slug}' -> '#{venue.slug}'")
        {:redirect, venue, 1.0}

      nil ->
        # Strategy 2: Query candidates and score them
        candidates = query_candidates(normalized, missing_slug)
        scored = score_candidates(candidates, missing_slug, normalized)
        decide_action(scored, missing_slug)
    end
  end

  @doc """
  Normalizes a slug by removing common V1 patterns.

  Patterns handled:
  - Numeric ID suffix: "venue-name-1234567890" → "venue-name"
  - Event prefix: "event-name-at-venue-name" → "venue-name"
  - Special characters cleanup
  """
  def normalize_slug(slug) when is_binary(slug) do
    slug
    |> String.downcase()
    |> String.trim()
    |> strip_numeric_suffix()
    |> extract_venue_from_event_pattern()
    |> clean_special_chars()
  end

  @doc """
  Strips numeric ID suffix from slug.

  V1 sometimes added numeric IDs to disambiguate venues:
  "albion-hotel-1759813035" → "albion-hotel"

  Only strips if the numeric part is 7+ digits (to avoid stripping valid numbers like years).
  """
  def strip_numeric_suffix(slug) do
    # Pattern: ends with hyphen followed by 7+ digits
    String.replace(slug, ~r/-\d{7,}$/, "")
  end

  @doc """
  Extracts venue name from event-specific patterns.

  V1 had event-specific URLs like:
  "00s-quiz-vol-1-at-border-city-ale-house" → "border-city-ale-house"
  "trivia-night-at-the-phoenix" → "the-phoenix"
  """
  def extract_venue_from_event_pattern(slug) do
    # Pattern: "...-at-{venue-name}" - extract everything after "-at-"
    case Regex.run(~r/-at-(.+)$/, slug) do
      [_, venue_name] -> venue_name
      nil -> slug
    end
  end

  @doc """
  Cleans special characters and normalizes hyphens.
  """
  def clean_special_chars(slug) do
    slug
    |> String.replace(~r/[^a-z0-9-]/, "-")  # Replace non-alphanumeric with hyphen
    |> String.replace(~r/-+/, "-")           # Collapse multiple hyphens
    |> String.trim("-")                       # Remove leading/trailing hyphens
  end

  # Query candidates from database using multiple strategies
  defp query_candidates(normalized, original) do
    # Strategy 1: LIKE match on normalized slug
    like_matches = query_like_matches(normalized)

    # Strategy 2: LIKE match on original (in case normalization was too aggressive)
    original_matches = query_like_matches(original)

    # Strategy 3: Get all venues starting with first word
    first_word = normalized |> String.split("-") |> List.first()
    prefix_matches = if first_word && String.length(first_word) >= 3 do
      query_prefix_matches(first_word)
    else
      []
    end

    # Combine and deduplicate
    (like_matches ++ original_matches ++ prefix_matches)
    |> Enum.uniq_by(& &1.id)
    |> Enum.take(50)  # Limit candidates for scoring
  end

  defp query_like_matches(pattern) when byte_size(pattern) < 3, do: []
  defp query_like_matches(pattern) do
    search_pattern = "%#{pattern}%"

    Repo.all(
      from v in Venue,
        where: ilike(v.slug, ^search_pattern),
        limit: 20,
        preload: [city: :country]
    )
  end

  defp query_prefix_matches(prefix) do
    search_pattern = "#{prefix}%"

    Repo.all(
      from v in Venue,
        where: ilike(v.slug, ^search_pattern),
        limit: 20,
        preload: [city: :country]
    )
  end

  defp get_venue_by_slug(slug) do
    Repo.one(
      from v in Venue,
        where: v.slug == ^slug,
        preload: [city: :country]
    )
  end

  # Score each candidate venue against the original and normalized slugs
  defp score_candidates(candidates, original_slug, normalized_slug) do
    candidates
    |> Enum.map(fn venue ->
      confidence = calculate_confidence(venue.slug, original_slug, normalized_slug)
      {venue, confidence}
    end)
    |> Enum.filter(fn {_venue, confidence} -> confidence >= @suggestion_threshold end)
    |> Enum.sort_by(fn {_venue, confidence} -> confidence end, :desc)
  end

  @doc """
  Calculates confidence score for a venue match.

  Scoring components:
  - Exact normalized match: +40%
  - Venue starts with search term: +25% (strong signal for partial matches)
  - Jaro-Winkler distance (weighted): +20%
  - Common prefix ratio: +15%
  - Containment bonus: +10%

  Returns a float between 0.0 and 1.0.
  """
  def calculate_confidence(venue_slug, original_slug, normalized_slug) do
    # Normalize the venue slug for comparison
    venue_normalized = normalize_slug(venue_slug)

    score = 0.0

    # 1. Exact normalized match (+40%)
    score = if venue_normalized == normalized_slug or venue_slug == normalized_slug do
      score + 0.40
    else
      score
    end

    # 2. Venue slug starts with the search term (+25%)
    # This is a strong signal that we found the right venue with a suffix
    score = if String.starts_with?(venue_slug, normalized_slug <> "-") or
               String.starts_with?(venue_normalized, normalized_slug <> "-") or
               String.starts_with?(venue_slug, normalized_slug) and venue_slug != normalized_slug do
      score + 0.25
    else
      score
    end

    # 3. Jaro-Winkler distance against normalized (+20% weighted)
    jaro_score = String.jaro_distance(venue_slug, normalized_slug)
    score = score + (jaro_score * 0.20)

    # 4. Also check Jaro against original (take best)
    jaro_original = String.jaro_distance(venue_slug, original_slug)
    jaro_bonus = max(jaro_score, jaro_original) * 0.05
    score = score + jaro_bonus

    # 5. Common prefix ratio (+15% weighted)
    prefix_ratio = common_prefix_ratio(venue_slug, normalized_slug)
    score = score + (prefix_ratio * 0.15)

    # 6. Containment bonus (+10% if one contains the other)
    score = if String.contains?(venue_slug, normalized_slug) or
               String.contains?(normalized_slug, venue_slug) do
      score + 0.10
    else
      score
    end

    # Cap at 1.0
    min(score, 1.0)
  end

  @doc """
  Calculates the ratio of common prefix length to minimum string length.
  """
  def common_prefix_ratio(str1, str2) do
    prefix_len = common_prefix_length(str1, str2)
    min_len = min(String.length(str1), String.length(str2))

    if min_len > 0 do
      prefix_len / min_len
    else
      0.0
    end
  end

  defp common_prefix_length(str1, str2) do
    str1_chars = String.graphemes(str1)
    str2_chars = String.graphemes(str2)

    Enum.zip(str1_chars, str2_chars)
    |> Enum.take_while(fn {a, b} -> a == b end)
    |> length()
  end

  # Decide what action to take based on scored candidates
  defp decide_action([], missing_slug) do
    Logger.info("VenueMatcher: No matches found for '#{missing_slug}'")
    :no_match
  end

  defp decide_action([{venue, confidence}], missing_slug) when confidence >= @redirect_threshold do
    Logger.info("VenueMatcher: High confidence redirect for '#{missing_slug}' -> '#{venue.slug}' (#{Float.round(confidence * 100, 1)}%)")
    {:redirect, venue, confidence}
  end

  defp decide_action([{venue, confidence} | _rest] = _candidates, missing_slug) when confidence >= @redirect_threshold do
    # Even if we have multiple, if the top one is very high confidence, redirect to it
    Logger.info("VenueMatcher: High confidence redirect for '#{missing_slug}' -> '#{venue.slug}' (#{Float.round(confidence * 100, 1)}%)")
    {:redirect, venue, confidence}
  end

  defp decide_action(candidates, missing_slug) do
    suggestions = Enum.take(candidates, @max_suggestions)
    Logger.info("VenueMatcher: Showing #{length(suggestions)} suggestions for '#{missing_slug}'")
    {:suggestions, suggestions}
  end
end
