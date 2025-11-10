defmodule TriviaAdvisorWeb.HealthController do
  use TriviaAdvisorWeb, :controller

  alias TriviaAdvisor.Repo

  @doc """
  Health check endpoint for load balancers and monitoring systems.

  Returns:
  - 200 OK with JSON body when healthy (database connected)
  - 503 Service Unavailable when unhealthy (database disconnected)

  Example response:
  ```json
  {
    "status": "healthy",
    "database": "connected",
    "timestamp": "2025-01-08T12:34:56Z"
  }
  ```
  """
  def check(conn, _params) do
    case Repo.query("SELECT 1 AS health_check") do
      {:ok, _result} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "healthy",
          database: "connected",
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "unhealthy",
          database: "disconnected",
          error: inspect(reason),
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end
end
