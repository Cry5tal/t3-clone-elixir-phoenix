defmodule T3CloneElixir.ModelsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `T3CloneElixir.Models` context.
  """

  @doc """
  Generate a model.
  """
  def model_fixture(attrs \\ %{}) do
    {:ok, model} =
      attrs
      |> Enum.into(%{
        allow_files: true,
        allow_images: true,
        name: "some name",
        openrouter_name: "some openrouter_name"
      })
      |> T3CloneElixir.Models.create_model()

    model
  end
end
