defmodule T3CloneElixir.Chats do
  @moduledoc """
  The Chats context.
  """

  import Ecto.Query, warn: false
  alias T3CloneElixir.Repo

  alias T3CloneElixir.Chats.Chat
  alias T3CloneElixir.Messages.Message

  @doc """
  Returns the list of chats.

  ## Examples

      iex> list_chats()
      [%Chat{}, ...]

  """
  def list_chats do
    Repo.all(Chat)
  end

  @doc """
  Gets a single chat.

  Raises `Ecto.NoResultsError` if the Chat does not exist.

  ## Examples

      iex> get_chat!(123)
      %Chat{}

      iex> get_chat!(456)
      ** (Ecto.NoResultsError)

  """
  def get_chat!(id), do: Repo.get!(Chat, id)

  @doc """
  Creates a chat.

  ## Examples

      iex> create_chat(%{field: value})
      {:ok, %Chat{}}

      iex> create_chat(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_chat(attrs \\ %{}) do
    %Chat{}
    |> Chat.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a chat.

  ## Examples

      iex> update_chat(chat, %{field: new_value})
      {:ok, %Chat{}}

      iex> update_chat(chat, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_chat(%Chat{} = chat, attrs) do
    result =
      chat
      |> Chat.changeset(attrs)
      |> Repo.update()
    case result do
      {:ok, updated_chat} ->
        Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, "chats:list", {:updated_chat, updated_chat})
        {:ok, updated_chat}
      error ->
        error
    end
  end

  @doc """
  Deletes a chat.

  ## Examples

      iex> delete_chat(chat)
      {:ok, %Chat{}}

      iex> delete_chat(chat)
      {:error, %Ecto.Changeset{}}

  """
  def delete_chat(%Chat{} = chat) do
    result = Repo.delete(chat)
    case result do
      {:ok, deleted_chat} ->
        Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, "chats:list", {:deleted_chat, deleted_chat})
        {:ok, deleted_chat}
      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking chat changes.

  ## Examples

      iex> change_chat(chat)
      %Ecto.Changeset{data: %Chat{}}

  """
  def change_chat(%Chat{} = chat, attrs \\ %{}) do
    Chat.changeset(chat, attrs)
  end

  @doc """
  Returns all chats for the given user ID, ordered by most recently updated.

  ## Examples

      iex> get_chats_by_user_id("user-123")
      [%Chat{}, ...]

      iex> get_chats_by_user_id(nil)
      []

  """
  def get_chats_by_user_id(user_id) do
    if is_nil(user_id) do
      []
    else
      Repo.all(from c in Chat, where: c.user_id == ^user_id, order_by: [desc: c.updated_at])
    end
  end

  @doc """
  Returns messages for a given chat, with pagination support.

  ## Parameters

    * `chat_id` - The ID of the chat.
    * `limit` - The maximum number of messages to return (default: 10).
    * `offset` - The number of messages to skip (default: 0).

  ## Examples

      iex> get_chat_messages("chat-uuid")
      [%Message{}, ...]

      iex> get_chat_messages("chat-uuid", 5, 10)
      [%Message{}, ...]

  """
  def get_chat_messages(chat_id, limit \\ 10, offset \\ 0) do
    from(m in T3CloneElixir.Messages.Message,
      where: m.chat_id == ^chat_id,
      order_by: [asc: m.inserted_at],
      limit: ^limit,
      offset: ^offset
    )
    |> T3CloneElixir.Repo.all()
  end



  @doc """
  Returns all messages for a given chat.

  ## Parameters

    * `chat_id` - The ID of the chat.

  ## Examples

      iex> get_all_chat_messages("chat-uuid")
      [%Message{}, ...]

  """
  def get_all_chat_messages(chat_id) do
    Repo.all(from m in T3CloneElixir.Messages.Message, where: m.chat_id == ^chat_id, order_by: [asc: m.inserted_at])
  end



  @doc """
  Creates a new chat with an initial message and broadcasts the new chat to PubSub.

  ## Parameters
    * user_id - The ID of the user creating the chat
    * message_content - The content of the first message

  ## Returns
    * {:ok, %{chat: chat, message: message}}
    * {:error, reason}
  """
  def create_chat_with_message(user_id, message_content) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:chat, Chat.changeset(%Chat{}, %{user_id: user_id, name: "new chat"}))
    |> Ecto.Multi.run(:message, fn _repo, %{chat: chat} ->
      message_attrs = %{
        chat_id: chat.id,
        user_id: user_id,
        content: message_content,
        who: "user",
        slot_id: Ecto.UUID.generate()
      }
      Message.changeset(%Message{}, message_attrs)
      |> Repo.insert()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, result = %{chat: chat}} ->
        Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, "chats:list", {:new_chat, chat})
        {:ok, result}
      error ->
        error
    end
  end



  @doc """
Inserts a new message into an existing chat.

## Parameters
  * chat_id - The ID of the chat
  * user_id - The ID of the user sending the message
  * content - The message content

## Returns
  * {:ok, %Message{}}
  * {:error, reason}
"""
def create_message(chat_id, user_id, content, who) do
  message_attrs = %{
    chat_id: chat_id,
    user_id: user_id,
    content: content,
    who: who,
    slot_id: Ecto.UUID.generate()
  }
  %T3CloneElixir.Messages.Message{}
  |> T3CloneElixir.Messages.Message.changeset(message_attrs)
  |> T3CloneElixir.Repo.insert()
end
end
