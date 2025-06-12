defmodule T3CloneElixirWeb.ChatLive.Home do
  use T3CloneElixirWeb, :live_view

  alias T3CloneElixir.Chats
  alias T3CloneElixir.ChatServer
  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    if connected?(socket) do
      Phoenix.PubSub.subscribe(T3CloneElixir.PubSub, "chats:list")
    end
    chats = Chats.get_chats_by_user_id(user_id)
    {:ok, assign(socket, 
      chats: chats, 
      selected_chat_id: nil,
      show_rename_modal: false,
      show_delete_modal: false,
      modal_chat_id: nil,
      modal_chat_name: nil
    )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    selected_chat_id = Map.get(params, "uuid")
    messages =
      if selected_chat_id do
        Chats.get_chat_messages(selected_chat_id, 10, 0)
      else
        []
      end

    if selected_chat_id do
      Phoenix.PubSub.subscribe(T3CloneElixir.PubSub, "chat:#{selected_chat_id}")
    end

    # Fetch buffer from ChatServer for resumable stream
    ai_buffer =
      if selected_chat_id do
        T3CloneElixir.ChatServer.get_buffer(selected_chat_id)
      else
        ""
      end

    socket = assign(socket, selected_chat_id: selected_chat_id, messages: messages)
    # Push buffer to JS if present
    socket = if ai_buffer != "" do
      push_event(socket, "ai_buffer_init", %{buffer: ai_buffer})
    else
      socket
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    user_id = socket.assigns.current_user.id
    selected_chat_id = socket.assigns.selected_chat_id

    cond do
      # If no chat is selected, create a new chat
      is_nil(selected_chat_id) or selected_chat_id == "" ->
        # No chat open, create new chat and message
        case Chats.create_chat_with_message(user_id, content) do
          {:ok, %{chat: chat, message: message}} ->
            # Start AI response streaming for the new chat
            ChatServer.generate_response(chat.id, [message])
            # Redirect user to /chats/:uuid
            {:noreply,
             socket
             |> push_navigate(to: "/chats/#{chat.id}")}
          {:error, reason} ->
            {:noreply, socket |> put_flash(:error, "Failed to create chat: #{inspect(reason)}")}
        end
      # If a chat is selected, add the message to the chat
      true ->
        case Chats.create_message(selected_chat_id, user_id, content, "user") do
          {:ok, _message} ->
            IO.inspect(:user_message_created, label: "[LiveView] User message created, updating UI")
            # Get all messages for the chat
            messages = Chats.get_all_chat_messages(selected_chat_id)
            
            # Convert messages to the format expected by ChatServer/Completion
            chat_history = Enum.map(messages, fn msg ->
              %{"role" => msg.who, "content" => msg.content}
            end)
            
            # Start the AI response generation
            ChatServer.generate_response(selected_chat_id, chat_history)
            
            # Update the socket with the actual message structs for display
            {:noreply, assign(socket, messages: messages)}
          {:error, reason} ->
            IO.inspect(reason, label: "[LiveView] Failed to send message")
            {:noreply, socket |> put_flash(:error, "Failed to send message: #{inspect(reason)}")}
        end
    end
  end


  # Modal open/close handlers
  def handle_event("open_rename_modal", %{"id" => id, "name" => name}, socket) do
    {:noreply, assign(socket, show_rename_modal: true, show_delete_modal: false, modal_chat_id: id, modal_chat_name: name)}
  end

  def handle_event("open_delete_modal", %{"id" => id, "name" => name}, socket) do
    {:noreply, assign(socket, show_delete_modal: true, show_rename_modal: false, modal_chat_id: id, modal_chat_name: name)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_rename_modal: false, show_delete_modal: false, modal_chat_id: nil, modal_chat_name: nil)}
  end

  def handle_event("rename_chat", %{"name" => name}, socket) do
    chat_id = socket.assigns.modal_chat_id
    chat = Chats.get_chat!(chat_id)
    case Chats.update_chat(chat, %{name: name}) do
      {:ok, _chat} ->
        {:noreply,
         socket
         |> put_flash(:info, "Chat renamed successfully")
         |> assign(show_rename_modal: false, modal_chat_id: nil, modal_chat_name: nil)}
      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to rename chat: #{inspect(reason)}")}
    end
  end

  def handle_event("delete_chat", %{"id" => id}, socket) do
    chat = Chats.get_chat!(id)
    case Chats.delete_chat(chat) do
      {:ok, _chat} ->
        {:noreply, socket |> assign(show_delete_modal: false, modal_chat_id: nil, modal_chat_name: nil) |> put_flash(:info, "Chat deleted successfully")}
      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to delete chat: #{inspect(reason)}")}
    end
  end
  # Fetch the chat struct before deleting, as delete_chat/1 expects %Chat{} not ID


  # Handle PubSub updates for chat list
  @impl true
  def handle_info({:new_chat, chat}, socket) do
    {:noreply, update(socket, :chats, fn chats -> [chat | chats] end)}
  end

  @impl true
  def handle_info({:updated_chat, chat}, socket) do
    {:noreply, update(socket, :chats, fn chats ->
      Enum.map(chats, fn c -> if c.id == chat.id, do: chat, else: c end)
    end)}
  end

  @impl true
  def handle_info({:deleted_chat, chat}, socket) do
    {:noreply, update(socket, :chats, fn chats ->
      Enum.reject(chats, fn c -> c.id == chat.id end)
    end)}
  end

  # Handle incoming AI token stream
  @impl true
  def handle_info({:ai_token, token}, socket) do
    # Push each token to JS for incremental rendering
    {:noreply, push_event(socket, "ai_token", %{token: token})}
  end

  @impl true
  def handle_info(:done, socket) do
    # Fetch the current buffer from ChatServer
    chat_id = socket.assigns.selected_chat_id
    ai_buffer = T3CloneElixir.ChatServer.get_buffer(chat_id)
    user_id = socket.assigns.current_user.id

    # Save the AI message to the DB as 'assistant'
    if ai_buffer != "" do
      {:ok, _msg} = T3CloneElixir.Chats.create_message(chat_id, user_id, ai_buffer, "ai")
    end

    # Clear the buffer after saving
    T3CloneElixir.ChatServer.clear_buffer(chat_id)

    # Update messages list
    messages = T3CloneElixir.Chats.get_chat_messages(chat_id, 10, 0)

    # Notify JS that streaming is done and update assigns
    {:noreply,
      socket
      |> assign(messages: messages)
      |> push_event("stream_done", %{})
    }
  end
end
