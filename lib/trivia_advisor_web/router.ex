defmodule TriviaAdvisorWeb.Router do
  use TriviaAdvisorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TriviaAdvisorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TriviaAdvisorWeb do
    pipe_through :browser

    # Home page
    live "/", HomeLive, :index

    # About page (static)
    live "/about", AboutLive, :index

    # Cities index
    live "/cities", CitiesIndexLive, :index

    # Search
    live "/search", SearchLive, :index

    # SEO files (sitemap and robots.txt)
    get "/sitemap.xml", SitemapController, :sitemap
    get "/robots.txt", SitemapController, :robots

    # Dynamic routes matching V1 patterns for SEO preservation
    # Pattern: /{country-slug}/{city-slug}/{venue-slug}/
    live "/:country_slug/:city_slug/:venue_slug", VenueShowLive, :show

    # Pattern: /{country-slug}/{city-slug}/
    live "/:country_slug/:city_slug", CityShowLive, :show

    # Pattern: /{country-slug}/
    live "/:country_slug", CountryShowLive, :show
  end

  # Health check endpoint (no authentication required for load balancers)
  scope "/", TriviaAdvisorWeb do
    pipe_through :api

    get "/health", HealthController, :check
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:trivia_advisor, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TriviaAdvisorWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
