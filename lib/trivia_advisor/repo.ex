defmodule TriviaAdvisor.Repo do
  use Ecto.Repo,
    otp_app: :trivia_advisor,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Dynamically loads the repository url from the
  SUPABASE_DATABASE_URL environment variable.
  """
  def init(_type, config) do
    case System.get_env("SUPABASE_DATABASE_URL") do
      nil ->
        raise "SUPABASE_DATABASE_URL environment variable is not set!"

      url ->
        config = Keyword.put(config, :url, url)
        {:ok, config}
    end
  end
end
