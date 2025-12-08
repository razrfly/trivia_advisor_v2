defmodule TriviaAdvisorWeb.SitemapController do
  use TriviaAdvisorWeb, :controller

  @moduledoc """
  Controller for serving sitemap.xml and robots.txt.
  """

  @doc """
  Serves the sitemap.xml file.
  Uses ConCache to serve cached XML (6-hour TTL).
  """
  def sitemap(conn, _params) do
    sitemap_xml = TriviaAdvisor.Sitemap.get_cached_xml()

    conn
    |> put_resp_content_type("application/xml")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, sitemap_xml)
  end

  @doc """
  Serves the robots.txt file.
  """
  def robots(conn, _params) do
    base_url = Application.get_env(:trivia_advisor, :base_url)

    robots_txt = """
    User-agent: *
    Allow: /

    Sitemap: #{base_url}/sitemap.xml
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, robots_txt)
  end
end
