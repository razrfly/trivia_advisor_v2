defmodule TriviaAdvisorWeb.Components.Layout.Header do
  @moduledoc """
  Site header component with navigation.
  """
  use Phoenix.Component

  @doc """
  Renders the site header with logo and navigation.

  ## Examples

      <Header.site_header current_path={@current_path} />
  """
  attr :current_path, :string, default: "/"

  def site_header(assigns) do
    ~H"""
    <header class="bg-white shadow-sm border-b border-gray-200">
      <div class="container mx-auto px-4">
        <div class="flex items-center justify-between h-16">
          <!-- Logo -->
          <.link navigate="/" class="flex items-center space-x-2">
            <span class="text-2xl font-bold text-blue-600">🎯</span>
            <span class="text-xl font-bold text-gray-900">Trivia Advisor</span>
          </.link>

          <!-- Navigation -->
          <nav class="hidden md:flex items-center space-x-6">
            <.nav_link href="/" current_path={@current_path}>
              Home
            </.nav_link>
            <.nav_link href="/cities" current_path={@current_path}>
              Cities
            </.nav_link>
            <.nav_link href="/search" current_path={@current_path}>
              Search
            </.nav_link>
            <.nav_link href="/about" current_path={@current_path}>
              About
            </.nav_link>
          </nav>

          <!-- Mobile menu button -->
          <button class="md:hidden p-2 rounded-md text-gray-600 hover:text-gray-900 hover:bg-gray-100">
            <svg
              class="w-6 h-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 6h16M4 12h16M4 18h16"
              >
              </path>
            </svg>
          </button>
        </div>
      </div>
    </header>
    """
  end

  @doc """
  Renders a navigation link with active state highlighting.
  """
  attr :href, :string, required: true
  attr :current_path, :string, default: "/"
  slot :inner_block, required: true

  def nav_link(assigns) do
    is_active = assigns.href == assigns.current_path
    assigns = assign(assigns, :is_active, is_active)

    ~H"""
    <.link
      navigate={@href}
      class={[
        "text-sm font-medium transition-colors",
        if(@is_active,
          do: "text-blue-600 border-b-2 border-blue-600",
          else: "text-gray-700 hover:text-blue-600"
        )
      ]}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end
end
