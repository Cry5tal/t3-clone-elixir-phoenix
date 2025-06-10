defmodule T3CloneElixir.ChatsTest do
  use T3CloneElixir.DataCase

  alias T3CloneElixir.Chats

  describe "chats" do
    alias T3CloneElixir.Chats.Chat

    import T3CloneElixir.ChatsFixtures

    @invalid_attrs %{id: nil, name: nil, user_id: nil}

    test "list_chats/0 returns all chats" do
      chat = chat_fixture()
      assert Chats.list_chats() == [chat]
    end

    test "get_chat!/1 returns the chat with given id" do
      chat = chat_fixture()
      assert Chats.get_chat!(chat.id) == chat
    end

    test "create_chat/1 with valid data creates a chat" do
      valid_attrs = %{id: "7488a646-e31f-11e4-aace-600308960662", name: "some name", user_id: "some user_id"}

      assert {:ok, %Chat{} = chat} = Chats.create_chat(valid_attrs)
      assert chat.id == "7488a646-e31f-11e4-aace-600308960662"
      assert chat.name == "some name"
      assert chat.user_id == "some user_id"
    end

    test "create_chat/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chats.create_chat(@invalid_attrs)
    end

    test "update_chat/2 with valid data updates the chat" do
      chat = chat_fixture()
      update_attrs = %{id: "7488a646-e31f-11e4-aace-600308960668", name: "some updated name", user_id: "some updated user_id"}

      assert {:ok, %Chat{} = chat} = Chats.update_chat(chat, update_attrs)
      assert chat.id == "7488a646-e31f-11e4-aace-600308960668"
      assert chat.name == "some updated name"
      assert chat.user_id == "some updated user_id"
    end

    test "update_chat/2 with invalid data returns error changeset" do
      chat = chat_fixture()
      assert {:error, %Ecto.Changeset{}} = Chats.update_chat(chat, @invalid_attrs)
      assert chat == Chats.get_chat!(chat.id)
    end

    test "delete_chat/1 deletes the chat" do
      chat = chat_fixture()
      assert {:ok, %Chat{}} = Chats.delete_chat(chat)
      assert_raise Ecto.NoResultsError, fn -> Chats.get_chat!(chat.id) end
    end

    test "change_chat/1 returns a chat changeset" do
      chat = chat_fixture()
      assert %Ecto.Changeset{} = Chats.change_chat(chat)
    end
  end
end
