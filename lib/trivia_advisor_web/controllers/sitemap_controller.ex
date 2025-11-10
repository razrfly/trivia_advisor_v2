defmodule TriviaAdvisorWeb.SitemapController do
  use TriviaAdvisorWeb, :controller

  @moduledoc """
  Controller for serving sitemap.xml and robots.txt.
  """

  @doc """
  Serves the sitemap.xml file.
  """
  def sitemap(conn, _params) do
    sitemap_xml = TriviaAdvisor.Sitemap.to_xml()

    conn
    |> put_resp_content_type("application/xml")
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
