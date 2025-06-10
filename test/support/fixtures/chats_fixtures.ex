defmodule T3CloneElixir.ChatsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `T3CloneElixir.Chats` context.
  """

  @doc """
  Generate a unique chat id.
  """
  def unique_chat_id do
    raise "implement the logic to generate a unique chat id"
  end

  @doc """
  Generate a chat.
  """
  def chat_fixture(attrs \\ %{}) do
    {:ok, chat} =
      attrs
      |> Enum.into(%{
        id: unique_chat_id(),
        name: "some name",
        user_id: "some user_id"
      })
      |> T3CloneElixir.Chats.create_chat()

    chat
  end
end
