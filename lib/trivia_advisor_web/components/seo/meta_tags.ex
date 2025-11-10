defmodule TriviaAdvisorWeb.Components.SEO.MetaTags do
  @moduledoc """
  SEO meta tag components for OpenGraph, Twitter Cards, and standard HTML meta.
  """
  use Phoenix.Component

  @doc """
  Renders complete meta tag set for a page.

  Required assigns:
  - title: Page title
  - description: Meta description
  - url: Canonical URL

  Optional assigns:
  - image: OpenGraph/Twitter image URL
  - type: OpenGraph type (default: "website")
  - twitter_card: Twitter card type (default: "summary_large_image")
  """
  def meta_tags(assigns) do
    assigns =
      assigns
      |> assign_new(:type, fn -> "website" end)
      |> assign_new(:twitter_card, fn -> "summary_large_image" end)
      |> assign_new(:image, fn -> nil end)

    ~H"""
    <!-- Standard HTML Meta -->
    <title><%= @title %></title>
    <meta name="description" content={@description} />
    <link rel="canonical" href={@url} />

    <!-- OpenGraph Meta -->
    <meta property="og:title" content={@title} />
    <meta property="og:description" content={@description} />
    <meta property="og:url" content={@url} />
    <meta property="og:type" content={@type} />
    <meta property="og:site_name" content="Trivia Advisor" />
    <meta :if={@image} property="og:image" content={@image} />

    <!-- Twitter Card Meta -->
    <meta name="twitter:card" content={@twitter_card} />
    <meta name="twitter:title" content={@title} />
    <meta name="twitter:description" content={@description} />
    <meta :if={@image} name="twitter:image" content={@image} />

    <!-- Geo Tags (if coordinates provided) -->
    <meta :if={Map.get(assigns, :latitude)} name="geo.position" content={"#{@latitude};#{@longitude}"} />
    <meta :if={Map.get(assigns, :latitude)} name="ICBM" content={"#{@latitude}, #{@longitude}"} />
    """
  end

  @doc """
  Generates meta tags for home page.
  """
  def home_meta_tags(base_url) do
    %{
      title: "Trivia Advisor - Find Trivia Nights Near You",
      description: "Discover the best trivia nights, pub quizzes, and quiz events in your city. Find venues, schedules, and join the trivia community.",
      url: base_url,
      type: "website"
    }
  end

  @doc """
  Generates meta tags for country page.
  """
  def country_meta_tags(country, base_url) do
    %{
      title: "Trivia Nights in #{country.name} - Trivia Advisor",
      description: "Find the best trivia nights and pub quizzes in #{country.name}. Discover venues, schedules, and trivia events across the country.",
      url: "#{base_url}/#{country.slug}",
      type: "website"
    }
  end

  @doc """
  Generates meta tags for city page.
  """
  def city_meta_tags(city, country, base_url) do
    %{
      title: "Trivia Nights in #{city.name}, #{country.name} - Trivia Advisor",
      description: "Discover trivia nights and pub quizzes in #{city.name}. Find the best venues, schedules, and events for quiz enthusiasts.",
      url: "#{base_url}/#{country.slug}/#{city.slug}",
      type: "website",
      latitude: if(city.latitude, do: Decimal.to_float(city.latitude), else: nil),
      longitude: if(city.longitude, do: Decimal.to_float(city.longitude), else: nil)
    }
  end

  @doc """
  Generates meta tags for venue page.
  """
  def venue_meta_tags(venue, city, country, base_url) do
    image_url =
      case TriviaAdvisor.Locations.Venue.primary_image(venue) do
        %{"url" => url} -> url
        _ -> nil
      end

    %{
      title: "#{venue.name} - Trivia in #{city.name}, #{country.name}",
      description: "Trivia nights at #{venue.name} in #{city.name}. Find schedules, event details, and join the trivia community at this venue.",
      url: "#{base_url}/#{country.slug}/#{city.slug}/#{venue.slug}",
      type: "place",
      latitude: venue.latitude,
      longitude: venue.longitude,
      image: image_url
    }
  end
end
