defmodule TriviaAdvisorWeb.AboutLive do
  @moduledoc """
  About page LiveView - static content about Trivia Advisor.
  """
  use TriviaAdvisorWeb, :live_view

  alias TriviaAdvisorWeb.Components.SEO.{MetaTags, Breadcrumbs}
  alias TriviaAdvisorWeb.Components.Layout.{Header, Footer}

  @impl true
  def mount(_params, _session, socket) do
    base_url = get_base_url()

    socket =
      socket
      |> assign(:page_title, "About Trivia Advisor")
      |> assign(:base_url, base_url)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    meta = %{
      title: "About Trivia Advisor - Find Trivia Nights & Pub Quizzes",
      description: "Learn about Trivia Advisor, your guide to finding the best trivia nights, pub quizzes, and quiz events worldwide.",
      url: "#{assigns.base_url}/about",
      type: "website"
    }

    breadcrumbs = [
      %{name: "Home", url: assigns.base_url},
      %{name: "About", url: "#{assigns.base_url}/about"}
    ]

    assigns =
      assigns
      |> assign(:meta, meta)
      |> assign(:breadcrumbs, breadcrumbs)

    ~H"""
    <div class="flex flex-col min-h-screen bg-gray-50">
      <!-- SEO Meta Tags -->
      <MetaTags.meta_tags {Map.to_list(@meta)} />

      <!-- Header -->
      <Header.site_header current_path="/about" />

      <!-- Main Content -->
      <main class="flex-1">
        <!-- Breadcrumbs -->
        <div class="container mx-auto px-4 py-4">
          <Breadcrumbs.breadcrumbs items={@breadcrumbs} />
        </div>

        <!-- Content -->
        <div class="container mx-auto px-4 py-12">
        <div class="max-w-4xl mx-auto bg-white rounded-lg shadow-md p-8">
          <h1 class="text-4xl font-bold mb-6 text-gray-900">
            About Trivia Advisor
          </h1>

          <div class="prose prose-lg max-w-none">
            <p class="text-gray-700 mb-4">
              Welcome to Trivia Advisor, your comprehensive guide to finding trivia nights,
              pub quizzes, and quiz events around the world.
            </p>

            <h2 class="text-2xl font-semibold mt-8 mb-4 text-gray-900">
              Our Mission
            </h2>
            <p class="text-gray-700 mb-4">
              We help trivia enthusiasts discover the best quiz nights in their area,
              connect with the trivia community, and never miss a great event.
            </p>

            <h2 class="text-2xl font-semibold mt-8 mb-4 text-gray-900">
              What We Offer
            </h2>
            <ul class="list-disc list-inside text-gray-700 mb-4 space-y-2">
              <li>Comprehensive venue listings with schedules and details</li>
              <li>Search by city and location to find events near you</li>
              <li>Regular updates on trivia nights and quiz events</li>
              <li>Community-driven content and recommendations</li>
            </ul>

            <div class="mt-8">
              <.link
                navigate={@base_url}
                class="inline-block px-6 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors"
              >
                Start Exploring Trivia Nights
              </.link>
            </div>
          </div>
        </div>
        </div>
      </main>

      <!-- Footer -->
      <Footer.site_footer />
    </div>
    """
  end

  defp get_base_url do
    Application.get_env(:trivia_advisor, :base_url, "https://quizadvisor.com")
  end
end
