defmodule TriviaAdvisorWeb.PageController do
  use TriviaAdvisorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
