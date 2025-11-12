defmodule TriviaAdvisorWeb.Components.SEO.JsonLD do
  @moduledoc """
  JSON-LD structured data components for SEO.
  Implements schema.org markup for events, breadcrumbs, and local businesses.
  """
  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]

  @doc """
  Renders JSON-LD structured data script tag.
  """
  def json_ld(assigns) do
    ~H"""
    <script type="application/ld+json">
      <%= raw(@data |> Jason.encode!() |> Phoenix.HTML.Safe.to_iodata()) %>
    </script>
    """
  end

  @doc """
  Generates BreadcrumbList schema for navigation.

  ## Examples

      iex> breadcrumb_list([
        %{name: "Home", url: "https://example.com"},
        %{name: "United States", url: "https://example.com/united-states"}
      ])
  """
  def breadcrumb_list(items) when is_list(items) do
    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" =>
        items
        |> Enum.with_index(1)
        |> Enum.map(fn {item, position} ->
          %{
            "@type" => "ListItem",
            "position" => position,
            "name" => item.name,
            "item" => item.url
          }
        end)
    }
  end

  @doc """
  Generates Event schema for trivia events.
  """
  def event_schema(event, venue, city, country, base_url) do
    %{
      "@context" => "https://schema.org",
      "@type" => "Event",
      "name" => event.name,
      "description" => "Trivia night at #{event.venue_name || venue.name}",
      "eventStatus" => "https://schema.org/EventScheduled",
      "eventAttendanceMode" => "https://schema.org/OfflineEventAttendanceMode",
      "location" => place_schema(venue, city, country),
      "organizer" => organizer_schema(base_url),
      "startDate" => get_next_occurrence_date(event)
    }
    |> maybe_add_image(venue)
  end

  defp get_next_occurrence_date(event) do
    case TriviaAdvisor.Events.get_next_occurrence(event) do
      %{"date" => date, "start_time" => start_time} ->
        "#{date}T#{start_time}:00"
      _ ->
        nil
    end
  end

  defp place_schema(venue, city, country) do
    %{
      "@type" => "Place",
      "name" => venue.name,
      "address" => %{
        "@type" => "PostalAddress",
        "streetAddress" => venue.address,
        "addressLocality" => city.name,
        "addressCountry" => country.code
      }
    }
    |> maybe_add_geo(venue)
  end

  defp maybe_add_geo(place, %{latitude: lat, longitude: lon}) when not is_nil(lat) and not is_nil(lon) do
    Map.put(place, "geo", %{
      "@type" => "GeoCoordinates",
      "latitude" => lat,
      "longitude" => lon
    })
  end

  defp maybe_add_geo(place, _), do: place

  defp organizer_schema(base_url) do
    %{
      "@type" => "Organization",
      "name" => "Trivia Advisor",
      "url" => base_url
    }
  end

  defp offers_schema(%{price_info: price_info, booking_url: booking_url}) when not is_nil(price_info) do
    %{
      "@type" => "Offer",
      "description" => price_info,
      "url" => booking_url,
      "availability" => "https://schema.org/InStock"
    }
  end

  defp offers_schema(_), do: nil

  defp maybe_add_image(schema, venue) do
    case TriviaAdvisor.Locations.Venue.primary_image(venue) do
      %{"url" => url} -> Map.put(schema, "image", url)
      _ -> schema
    end
  end

  defp maybe_add_performers(schema, %{public_event_performers: performers}) when is_list(performers) and length(performers) > 0 do
    performer_schemas =
      Enum.map(performers, fn performer ->
        %{
          "@type" => "Person",
          "name" => performer.name,
          "description" => performer.bio
        }
      end)

    Map.put(schema, "performer", performer_schemas)
  end

  defp maybe_add_performers(schema, _), do: schema

  @doc """
  Generates LocalBusiness schema for venues.
  """
  def local_business_schema(venue, city, country) do
    %{
      "@context" => "https://schema.org",
      "@type" => "LocalBusiness",
      "name" => venue.name,
      "address" => %{
        "@type" => "PostalAddress",
        "streetAddress" => venue.address,
        "addressLocality" => city.name,
        "addressCountry" => country.code
      }
    }
    |> maybe_add_geo(venue)
    |> maybe_add_venue_image(venue)
  end

  defp maybe_add_venue_image(schema, venue) do
    case TriviaAdvisor.Locations.Venue.primary_image(venue) do
      %{"url" => url} -> Map.put(schema, "image", url)
      _ -> schema
    end
  end
end
