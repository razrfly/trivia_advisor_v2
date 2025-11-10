defmodule TriviaAdvisorWeb.Components.Layout.Footer do
  @moduledoc """
  Site footer component with links and copyright.
  """
  use Phoenix.Component

  @doc """
  Renders the site footer.

  ## Examples

      <Footer.site_footer />
  """
  def site_footer(assigns) do
    current_year = Date.utc_today().year
    assigns = assign(assigns, :current_year, current_year)

    ~H"""
    <footer class="bg-gray-900 text-gray-300 mt-auto">
      <div class="container mx-auto px-4 py-8">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
          <!-- About Section -->
          <div>
            <h3 class="text-white font-semibold mb-4">Trivia Advisor</h3>
            <p class="text-sm text-gray-400">
              Your guide to finding the best trivia nights, pub quizzes, and quiz events worldwide.
            </p>
          </div>

          <!-- Quick Links -->
          <div>
            <h3 class="text-white font-semibold mb-4">Quick Links</h3>
            <ul class="space-y-2 text-sm">
              <li>
                <.link navigate="/" class="hover:text-white transition-colors">
                  Home
                </.link>
              </li>
              <li>
                <.link navigate="/about" class="hover:text-white transition-colors">
                  About
                </.link>
              </li>
            </ul>
          </div>

          <!-- Legal -->
          <div>
            <h3 class="text-white font-semibold mb-4">Legal</h3>
            <ul class="space-y-2 text-sm">
              <li>
                <a href="#" class="hover:text-white transition-colors">Privacy Policy</a>
              </li>
              <li>
                <a href="#" class="hover:text-white transition-colors">Terms of Service</a>
              </li>
            </ul>
          </div>
        </div>

        <!-- Copyright -->
        <div class="border-t border-gray-800 mt-8 pt-8 text-center text-sm text-gray-500">
          <p>© <%= @current_year %> Trivia Advisor. All rights reserved.</p>
        </div>
      </div>
    </footer>
    """
  end
end
