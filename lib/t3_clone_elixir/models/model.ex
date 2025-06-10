defmodule T3CloneElixir.Models.Model do
  use Ecto.Schema
  import Ecto.Changeset

  schema "models" do
    field :name, :string
    field :openrouter_name, :string
    field :allow_images, :boolean, default: false
    field :allow_files, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(model, attrs) do
    model
    |> cast(attrs, [:name, :openrouter_name, :allow_images, :allow_files])
    |> validate_required([:name, :openrouter_name, :allow_images, :allow_files])
  end
end
