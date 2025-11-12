# Venue Card Image Fallback System

## Problem Statement

Venue cards currently only display images from `venue_images` field. When venues don't have uploaded images, cards appear without visuals even though we have fallback image sources available (video thumbnails and city Unsplash images).

## Current Behavior

```elixir
# VenueCard component (line 30-38)
<%= if @venue[:venue_images] && is_list(@venue.venue_images) && length(@venue.venue_images) > 0 do %>
  <% primary_image = List.first(@venue.venue_images) %>
  <img src={primary_image["url"]} alt={primary_image["alt"] || @venue.venue_name} />
<% end %>
```

**Result**: Many venue cards have no images, appearing as text-only cards.

## Expected Behavior

Implement a 3-level image fallback system:

1. **Primary**: `venue_images[0]` - Venue-specific photos
2. **Secondary**: `venue_metadata["video_images"][0]` - Video thumbnail frames
3. **Tertiary**: `city_images[0]` - City Unsplash gallery (fallback)

## Data Structures

### Available Fields (from trivia_events_export view)

```elixir
# From PublicEvent schema (public_event.ex)
field :venue_images, {:array, :map}       # [%{"url" => "...", "alt" => "..."}]
field :venue_metadata, :map               # %{"video_images" => [...], ...}
field :city_images, {:array, :map}        # [%{"urls" => %{"regular" => "..."}, "alt_description" => "..."}]
```

### Image Format Examples

**venue_images** (direct upload):
```elixir
[%{"url" => "https://cdn.example.com/venue.jpg", "alt" => "Venue interior"}]
```

**venue_metadata["video_images"]** (video frames):
```elixir
%{"video_images" => [%{"url" => "https://youtube.com/thumbnail.jpg"}]}
```

**city_images** (Unsplash gallery):
```elixir
[%{
  "urls" => %{"regular" => "https://images.unsplash.com/photo-123", "small" => "..."},
  "alt_description" => "City skyline at sunset"
}]
```

## Implementation Plan

### Step 1: Create Helper Function

**Location**: `lib/trivia_advisor_web/components/cards/venue_card.ex`

```elixir
defmodule TriviaAdvisorWeb.Components.Cards.VenueCard do
  # ... existing code ...

  @doc """
  Gets the best available image for a venue card with fallback chain.
  Returns a map with url and alt text, or nil if no images available.

  Fallback order:
  1. venue_images (uploaded venue photos)
  2. venue_metadata["video_images"] (video thumbnails)
  3. city_images (Unsplash city gallery)
  """
  def get_venue_card_image(venue) do
    cond do
      # Try venue_images first
      has_venue_images?(venue) ->
        image = List.first(venue.venue_images)
        %{
          url: image["url"],
          alt: image["alt"] || venue.venue_name
        }

      # Try video_images second
      has_video_images?(venue) ->
        image = venue.venue_metadata["video_images"] |> List.first()
        %{
          url: image["url"],
          alt: "#{venue.venue_name} video thumbnail"
        }

      # Fall back to city_images
      has_city_images?(venue) ->
        image = List.first(venue.city_images)
        %{
          url: image["urls"]["regular"],
          alt: image["alt_description"] || "#{venue.city_name} cityscape"
        }

      # No images available
      true ->
        nil
    end
  end

  defp has_venue_images?(venue) do
    is_list(venue[:venue_images]) &&
    length(venue.venue_images) > 0 &&
    get_in(venue.venue_images, [Access.at(0), "url"])
  end

  defp has_video_images?(venue) do
    is_map(venue[:venue_metadata]) &&
    is_list(venue.venue_metadata["video_images"]) &&
    length(venue.venue_metadata["video_images"]) > 0 &&
    get_in(venue.venue_metadata, ["video_images", Access.at(0), "url"])
  end

  defp has_city_images?(venue) do
    is_list(venue[:city_images]) &&
    length(venue.city_images) > 0 &&
    get_in(venue.city_images, [Access.at(0), "urls", "regular"])
  end
end
```

### Step 2: Update VenueCard Component

**Replace** lines 29-39 with:

```elixir
<!-- Venue Image with fallback -->
<% image = get_venue_card_image(@venue) %>
<%= if image do %>
  <div class="mb-4">
    <img
      src={image.url}
      alt={image.alt}
      class="w-full h-48 object-cover rounded-t-lg"
    />
  </div>
<% end %>
```

## Testing Strategy

### Test Data Scenarios

1. **Venue with venue_images** → Should use venue_images[0]
2. **Venue without venue_images but with video_images** → Should use video_images[0]
3. **Venue with only city_images** → Should use city_images[0]
4. **Venue with no images at all** → Should show no image (card without image)
5. **Venue with all three** → Should prioritize venue_images[0]

### Manual Testing

```bash
# Test with Kraków (likely has city_images but not venue_images)
open http://localhost:4003/cities/krakow

# Test with London (mix of venues with/without images)
open http://localhost:4003/cities/london
```

## Architectural Decision

### Why Helper Function (Not Database View)?

**Considered Options**:
- ❌ **Option A**: Add computed column to `trivia_events_export` view
- ✅ **Option B**: Helper function in presentation layer

**Decision: Option B** because:

1. **Read-Only Constraint**: We don't own Eventasaurus database, trivia_events_export is read-only
2. **Separation of Concerns**: Image selection is presentation logic, belongs in presentation layer
3. **Flexibility**: Easy to modify fallback order or add new sources without database changes
4. **Performance**: Negligible runtime overhead (just array checks in Elixir)
5. **Testability**: Pure functions are easy to test with different data scenarios

## Acceptance Criteria

- [ ] Helper function `get_venue_card_image/1` implemented with 3-level fallback
- [ ] VenueCard component updated to use helper
- [ ] All 3 fallback levels tested and working
- [ ] No broken images or missing alt text
- [ ] Kraków page shows city images for venues without venue images
- [ ] London page shows mix of venue/city images appropriately

## Related Files

- `lib/trivia_advisor_web/components/cards/venue_card.ex` - Component to update
- `lib/trivia_advisor/events/public_event.ex` - Schema with field definitions
- `lib/trivia_advisor/locations.ex` - Query that fetches all image fields

## Notes

- Ensure `venue_metadata` field is selected in the query (locations.ex)
- City images use Unsplash format with nested `urls` map
- Consider adding image loading states/placeholders in future enhancement
