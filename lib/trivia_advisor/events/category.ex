defmodule TriviaAdvisor.Events.Category do
  @moduledoc """
  Ecto schema for the categories table in Eventasaurus database.
  Read-only schema for event categorization.
  """
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: false}
  schema "categories" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :icon, :string
    field :color, :string
    field :display_order, :integer
    field :translations, :map
    field :is_active, :boolean
    field :schema_type, :string

    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id

    timestamps(type: :naive_datetime)
  end

  @trivia_category_id 29

  @doc """
  Returns the ID of the trivia category.
  """
  def trivia_category_id, do: @trivia_category_id
end
