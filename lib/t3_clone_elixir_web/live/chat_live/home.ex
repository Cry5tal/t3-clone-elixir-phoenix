defmodule T3CloneElixirWeb.ChatLive.Home do
  use T3CloneElixirWeb, :live_view

  alias T3CloneElixir.Chats
  alias T3CloneElixir.ChatServer
  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    chats = Chats.get_chats_by_user_id(user_id)
    {:ok, assign(socket, chats: chats, selected_chat_id: nil)}
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
      true ->
        case Chats.create_message(selected_chat_id, user_id, content, "user") do
          {:ok, _message} ->
            IO.inspect(:user_message_created, label: "[LiveView] User message created, updating UI")
            messages = Chats.get_chat_messages(selected_chat_id, 10, 0)
            ChatServer.generate_response(selected_chat_id, messages)
            {:noreply, assign(socket, messages: messages)}
          {:error, reason} ->
            IO.inspect(reason, label: "[LiveView] Failed to send message")
            {:noreply, socket |> put_flash(:error, "Failed to send message: #{inspect(reason)}")}
        end
    end
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
