defmodule T3CloneElixirWeb.ChatLive.Home do
  use T3CloneElixirWeb, :live_view

  alias T3CloneElixir.Chats
  alias T3CloneElixir.ChatServer
  alias T3CloneElixir.Models
  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    if connected?(socket) do
      Phoenix.PubSub.subscribe(T3CloneElixir.PubSub, "chats:list")
    end
    chats = Chats.get_chats_by_user_id(user_id)
    models = Models.list_models()
    default_model = List.first(models)
    {:ok, assign(socket,
      chats: chats,
      models: models,
      selected_model: default_model,
      show_model_dropdown: false,
      selected_chat_id: nil,
      show_rename_modal: false,
      show_delete_modal: false,
      modal_chat_id: nil,
      modal_chat_name: nil,
      ai_streaming_message: nil,
      is_waiting_for_stream: false, # Add new assign
      input_content: "",
      models: models
    )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    selected_chat_id = Map.get(params, "uuid")
    # Fetch messages and the chat struct if a chat is selected
    {messages, selected_model} =
      if selected_chat_id do
        chat = Chats.get_chat!(selected_chat_id)
        # Preload model association for messages
        messages =
          Chats.get_chat_messages(selected_chat_id, 10, 0)
          |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})
        models = socket.assigns.models
        selected_model = Enum.find(models, fn m -> to_string(m.id) == to_string(chat.selected_model_id) end) || List.first(models)
        {messages, selected_model}
      else
        {[], List.first(socket.assigns.models)}
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

    socket = assign(socket,
      selected_chat_id: selected_chat_id,
      messages: messages,
      selected_model: selected_model,
      ai_streaming_message: (if ai_buffer != "", do: ai_buffer, else: nil),
      input_content: "",
      messages_offset: length(messages), # Track offset for pagination
      all_messages_loaded: messages == [] # True if no messages (all loaded)
      # models is already assigned in mount and should remain a list of model structs
    )
    {:noreply, socket}
  end

  @impl true
  # Handle model selection from dropdown
  def handle_event("select_model", %{"id" => model_id}, socket) do
    models = socket.assigns.models
    selected = Enum.find(models, fn m -> to_string(m.id) == to_string(model_id) end) || List.first(models)
    if socket.assigns.selected_chat_id do
      # Update the existing chat's selected model in the DB
      chat = Chats.get_chat!(socket.assigns.selected_chat_id)
      case Chats.update_chat(chat, %{selected_model_id: model_id}) do
        {:ok, _chat} ->
          {:noreply, assign(socket, selected_model: selected)}
        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, "Failed to update chat: #{inspect(reason)}")}
      end
    else
      # No chat selected: just update the assign so it will be used for the next chat creation
      {:noreply, assign(socket, selected_model: selected)}
    end
  end

  # Handle chat message send, with model selection
  def handle_event("send_message", %{"content" => content, "model_id" => model_id}, socket) do
    # Prevent sending empty or whitespace-only messages
    if !content || String.trim(content) == "" do
      {:noreply, socket}
    else
      user_id = socket.assigns.current_user.id
      selected_chat_id = socket.assigns.selected_chat_id
      models = socket.assigns.models
      model = Enum.find(models, fn m -> to_string(m.id) == to_string(model_id) end) || List.first(models)
      socket = assign(socket, selected_model: model)
      model_name = model.openrouter_name || "openai/gpt-4o"
      selected_model_id = model.id
      cond do
        is_nil(selected_chat_id) or selected_chat_id == "" ->
          case Chats.create_chat_with_message(user_id, content, selected_model_id) do
            {:ok, %{chat: chat, message: message}} ->
              ChatServer.generate_response(chat.id, [message], model_name)
              {:noreply, socket |> push_event("stream_start", %{}) |> push_navigate(to: "/chats/#{chat.id}")}
            {:error, reason} ->
              {:noreply, socket |> put_flash(:error, "Failed to create chat: #{inspect(reason)}")}
          end
        true ->
          case Chats.create_message(selected_chat_id, user_id, content, "user") do
            {:ok, _message} ->
              messages = Chats.get_all_chat_messages(selected_chat_id)
              chat_history = Enum.map(messages, fn msg -> %{"role" => msg.who, "content" => msg.content} end)
              ChatServer.generate_response(selected_chat_id, chat_history, model_name)
              new_socket = assign(socket, messages: messages, ai_streaming_message: "", is_waiting_for_stream: true)
              IO.inspect(new_socket.assigns.ai_streaming_message, label: "[DEBUG] ai_streaming_message after assign (send_message)")
              {:noreply, new_socket |> push_event("stream_start", %{})}
            {:error, reason} ->
              {:noreply, socket |> put_flash(:error, "Failed to send message: #{inspect(reason)}")}
          end
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
        # If the deleted chat is currently open, redirect to /chats
        if to_string(socket.assigns.selected_chat_id) == to_string(id) do
          {:noreply,
            socket
            |> assign(show_delete_modal: false, modal_chat_id: nil, modal_chat_name: nil)
            |> put_flash(:info, "Chat deleted successfully")
            |> push_navigate(to: "/chats")}
        else
          {:noreply,
            socket
            |> assign(show_delete_modal: false, modal_chat_id: nil, modal_chat_name: nil)
            |> put_flash(:info, "Chat deleted successfully")}
        end
      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to delete chat: #{inspect(reason)}")}
    end
  end


  # Handle event to cancel/stop the AI stream
  # This simply sends :done to self, which triggers the existing handle_info logic
  def handle_event("cancel_stream", _params, socket) do
    # Call the ChatServer to cancel the AI stream for the selected chat
    T3CloneElixir.ChatServer.cancel_stream(socket.assigns.selected_chat_id)
    {:noreply, socket}
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
      chats
      |> Enum.map(fn c -> if c.id == chat.id, do: chat, else: c end)
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
    end)}
  end

  @impl true
  def handle_info({:deleted_chat, chat}, socket) do
    {:noreply, update(socket, :chats, fn chats ->
      Enum.reject(chats, fn c -> c.id == chat.id end)
    end)}
  end

  # Handle chat_renamed PubSub event for automatic renaming
  @impl true
  def handle_info({:chat_renamed, chat_id, new_name}, socket) do
    IO.inspect({:chat_renamed_event, chat_id, new_name}, label: "[DEBUG] Received chat_renamed event")
    # Update the chat name in the @chats assign
    chats = Enum.map(socket.assigns.chats, fn c ->
      if to_string(c.id) == to_string(chat_id), do: %{c | name: new_name}, else: c
    end)
    # If the currently selected chat is renamed, update modal_chat_name as well
    socket =
      if to_string(socket.assigns.selected_chat_id) == to_string(chat_id) do
        assign(socket, chats: chats, modal_chat_name: new_name)
      else
        assign(socket, chats: chats)
      end
    IO.inspect(socket.assigns.chats, label: "[DEBUG] Updated chats after rename")
    {:noreply, socket}
  end

  # Handle incoming AI token stream
  @impl true
  def handle_info({:ai_token, token}, socket) do
    # Append token to the streaming message buffer
      current = socket.assigns.ai_streaming_message || ""
      {:noreply, assign(socket, ai_streaming_message: current <> token)}
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

    # Update messages list and clear streaming buffer
    messages =
      T3CloneElixir.Chats.get_chat_messages(chat_id, 10, 0)
      |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})
    {:noreply,
      socket
      |> assign(messages: messages, ai_streaming_message: nil, is_waiting_for_stream: false)
      |> push_event("stream_done", %{})
    }
  end

  # Handle loading more messages for pagination (infinite scroll)
  @impl true
  def handle_event("load_more_messages", _params, socket) do
    chat_id = socket.assigns.selected_chat_id
    offset = socket.assigns[:messages_offset] || 0
    # Fetch next batch (older messages)
    new_messages =
      if chat_id do
        T3CloneElixir.Chats.get_chat_messages(chat_id, 10, offset)
        |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})
      else
        []
      end
    # Merge and deduplicate by id
    all_messages =
      (new_messages ++ (socket.assigns[:messages] || []))
      |> Enum.uniq_by(& &1.id)
    all_loaded = new_messages == [] or length(new_messages) < 10
    {:noreply,
      socket
      |> assign(messages: all_messages, messages_offset: offset + length(new_messages), all_messages_loaded: all_loaded)
    }
  end

end
