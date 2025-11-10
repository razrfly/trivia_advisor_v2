defmodule TriviaAdvisorWeb.Components.SEO.Breadcrumbs do
  @moduledoc """
  Breadcrumb navigation component with structured data support.
  """
  use Phoenix.Component
  alias TriviaAdvisorWeb.Components.SEO.JsonLD

  @doc """
  Renders breadcrumb navigation with JSON-LD structured data.

  ## Examples

      <.breadcrumbs items={[
        %{name: "Home", url: "/"},
        %{name: "United States", url: "/united-states"},
        %{name: "New York", url: "/united-states/new-york"}
      ]} />
  """
  attr :items, :list, required: true, doc: "List of breadcrumb items with :name and :url"

  def breadcrumbs(assigns) do
    ~H"""
    <nav aria-label="Breadcrumb" class="mb-4">
      <ol class="flex items-center space-x-2 text-sm text-gray-600">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <li class="flex items-center">
            <%= if index > 0 do %>
              <span class="mx-2 text-gray-400">/</span>
            <% end %>
            <%= if index == length(@items) - 1 do %>
              <span class="font-semibold text-gray-900" aria-current="page">
                <%= item.name %>
              </span>
            <% else %>
              <a href={item.url} class="hover:text-gray-900 hover:underline">
                <%= item.name %>
              </a>
            <% end %>
          </li>
        <% end %>
      </ol>

      <!-- JSON-LD Structured Data -->
      <JsonLD.json_ld data={JsonLD.breadcrumb_list(@items)} />
    </nav>
    """
  end

  @doc """
  Builds breadcrumb items for home page.
  """
  def home_breadcrumbs(base_url) do
    [
      %{name: "Home", url: base_url}
    ]
  end

  @doc """
  Builds breadcrumb items for country page.
  """
  def country_breadcrumbs(country, base_url) do
    [
      %{name: "Home", url: base_url},
      %{name: country.name, url: "#{base_url}/#{country.slug}"}
    ]
  end

  @doc """
  Builds breadcrumb items for city page.
  """
  def city_breadcrumbs(city, country, base_url) do
    [
      %{name: "Home", url: base_url},
      %{name: country.name, url: "#{base_url}/#{country.slug}"},
      %{name: city.name, url: "#{base_url}/#{country.slug}/#{city.slug}"}
    ]
  end

  @doc """
  Builds breadcrumb items for venue page.
  """
  def venue_breadcrumbs(venue, city, country, base_url) do
    [
      %{name: "Home", url: base_url},
      %{name: country.name, url: "#{base_url}/#{country.slug}"},
      %{name: city.name, url: "#{base_url}/#{country.slug}/#{city.slug}"},
      %{name: venue.name, url: "#{base_url}/#{country.slug}/#{city.slug}/#{venue.slug}"}
    ]
  end
end
