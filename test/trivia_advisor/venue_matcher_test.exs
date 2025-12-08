defmodule TriviaAdvisor.VenueMatcherTest do
  use ExUnit.Case, async: true

  alias TriviaAdvisor.VenueMatcher

  describe "normalize_slug/1" do
    test "strips numeric ID suffix (7+ digits)" do
      # Standard numeric suffix pattern from V1
      assert VenueMatcher.normalize_slug("albion-hotel-1759813035") == "albion-hotel"
      assert VenueMatcher.normalize_slug("the-phoenix-9876543210") == "the-phoenix"
    end

    test "does not strip short numeric suffixes" do
      # Should NOT strip years or short numbers
      assert VenueMatcher.normalize_slug("venue-2024") == "venue-2024"
      assert VenueMatcher.normalize_slug("pub-123") == "pub-123"
    end

    test "extracts venue from event pattern (at-)" do
      # V1 event-specific URLs
      assert VenueMatcher.normalize_slug("00s-quiz-vol-1-at-border-city-ale-house") == "border-city-ale-house"
      assert VenueMatcher.normalize_slug("trivia-night-at-the-phoenix") == "the-phoenix"
      assert VenueMatcher.normalize_slug("pub-quiz-at-o-neills") == "o-neills"
    end

    test "cleans special characters" do
      assert VenueMatcher.normalize_slug("the--phoenix") == "the-phoenix"
      assert VenueMatcher.normalize_slug("-the-phoenix-") == "the-phoenix"
      assert VenueMatcher.normalize_slug("the_phoenix") == "the-phoenix"
    end

    test "handles combined patterns" do
      # Numeric suffix + special chars
      assert VenueMatcher.normalize_slug("albion-hotel--1759813035") == "albion-hotel"

      # Event pattern + numeric suffix
      assert VenueMatcher.normalize_slug("quiz-at-the-phoenix-1234567890") == "the-phoenix"
    end

    test "lowercases input" do
      assert VenueMatcher.normalize_slug("THE-PHOENIX") == "the-phoenix"
      assert VenueMatcher.normalize_slug("Albion-Hotel") == "albion-hotel"
    end
  end

  describe "strip_numeric_suffix/1" do
    test "strips 7+ digit suffix" do
      assert VenueMatcher.strip_numeric_suffix("venue-1234567") == "venue"
      assert VenueMatcher.strip_numeric_suffix("venue-12345678") == "venue"
      assert VenueMatcher.strip_numeric_suffix("venue-1759813035") == "venue"
    end

    test "preserves short numeric suffixes" do
      assert VenueMatcher.strip_numeric_suffix("venue-123456") == "venue-123456"
      assert VenueMatcher.strip_numeric_suffix("venue-2024") == "venue-2024"
    end

    test "preserves slugs without numeric suffix" do
      assert VenueMatcher.strip_numeric_suffix("the-phoenix") == "the-phoenix"
      assert VenueMatcher.strip_numeric_suffix("o-neills-pub") == "o-neills-pub"
    end
  end

  describe "extract_venue_from_event_pattern/1" do
    test "extracts venue after '-at-'" do
      assert VenueMatcher.extract_venue_from_event_pattern("quiz-at-the-phoenix") == "the-phoenix"
      assert VenueMatcher.extract_venue_from_event_pattern("trivia-night-at-bar-name") == "bar-name"
    end

    test "returns original if no '-at-' pattern" do
      assert VenueMatcher.extract_venue_from_event_pattern("the-phoenix") == "the-phoenix"
      assert VenueMatcher.extract_venue_from_event_pattern("atlantic-hotel") == "atlantic-hotel"
    end
  end

  describe "calculate_confidence/3" do
    test "returns high confidence for exact match" do
      # Exact match should score very high
      # New scoring: exact match (+40%) + jaro (1.0 * 0.20 = +20%) + jaro_bonus (1.0 * 0.05 = +5%)
      #              + prefix ratio (1.0 * 0.15 = +15%) + containment (+10%) = 90%
      confidence = VenueMatcher.calculate_confidence("the-phoenix", "the-phoenix", "the-phoenix")
      assert confidence >= 0.90
    end

    test "returns high confidence when venue contains normalized slug" do
      # Venue slug contains the normalized search - containment bonus applies
      confidence = VenueMatcher.calculate_confidence("phoenix", "the-phoenix", "phoenix")
      # Contains match + jaro + prefix should give decent score
      assert confidence >= 0.50
    end

    test "returns medium confidence for similar slugs" do
      # Typo in search - Jaro-Winkler handles typos well
      confidence = VenueMatcher.calculate_confidence("the-phoenix", "the-phenix", "the-phenix")
      # Similar strings get moderate Jaro score (~0.33) - below suggestion threshold
      # This is expected: typos alone don't give high confidence
      assert confidence >= 0.30 && confidence < 0.70
    end

    test "returns low confidence for different slugs" do
      # Completely different
      confidence = VenueMatcher.calculate_confidence("the-phoenix", "xyz-restaurant", "xyz-restaurant")
      assert confidence < 0.70
    end

    test "returns high confidence when venue starts with search term" do
      # Venue slug starts with search term (e.g., "pasibus-19-642" starts with "pasibus")
      # This is the key scenario for V1 URLs with numeric suffixes
      confidence = VenueMatcher.calculate_confidence("pasibus-19-642", "pasibus", "pasibus")
      # Should get: starts_with bonus (+25%) + jaro + prefix ratio + containment (+10%)
      assert confidence >= 0.70
    end
  end

  describe "common_prefix_ratio/2" do
    test "returns 1.0 for identical strings" do
      assert VenueMatcher.common_prefix_ratio("phoenix", "phoenix") == 1.0
    end

    test "returns ratio for partial match" do
      # "phoen" matches in "phoenix" (5 chars) vs "phoen" (5 chars) = 1.0
      assert VenueMatcher.common_prefix_ratio("phoen", "phoenix") == 1.0

      # "the-p" matches in "the-phoenix" vs "the-pub" (5 chars / 7 chars = 0.714...)
      ratio = VenueMatcher.common_prefix_ratio("the-phoenix", "the-pub")
      assert ratio > 0.5 && ratio < 1.0
    end

    test "returns 0 for no common prefix" do
      assert VenueMatcher.common_prefix_ratio("abc", "xyz") == 0.0
    end
  end
end
