defmodule T3CloneElixirWeb.ChatLive.ChatArea do
  use T3CloneElixirWeb, :live_view

  alias T3CloneElixir.Chats
  alias T3CloneElixir.ChatServer
  alias T3CloneElixir.Models

  @impl true
  def mount(_params, session, socket) do
    chat_id = session["chat_id"]
    user_id = session["current_user_id"]
    models = session["models"] || []
    selected_model =
      case models do
        [first | _] -> first
        _ -> nil
      end

    # Load messages for the chat (if any)
    messages =
      if chat_id do
        Chats.get_chat_messages(chat_id, 10, 0)
        |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})
      else
        []
      end

    # Buffer for streaming/resumable stream
    ai_buffer =
      if chat_id do
        ChatServer.get_buffer(chat_id)
      else
        ""
      end

    # Fetch draft for this chat (if any) from InputDraftServer
    input_content =
      if chat_id do
        T3CloneElixir.InputDraftServer.get_draft(chat_id)
      else
        ""
      end

    if connected?(socket) and chat_id do
      Phoenix.PubSub.subscribe(T3CloneElixir.PubSub, "chat:#{chat_id}")
    end
    {:ok,
      socket
      |> assign(
        chat_id: chat_id,
        user_id: user_id,
        messages: messages,
        models: models,
        selected_model: selected_model,
        ai_streaming_message: (if ai_buffer != "", do: ai_buffer, else: nil),
        is_waiting_for_stream: false,
        input_content: input_content,
        messages_offset: length(messages),
        all_messages_loaded: messages == []
      )
    }
  end

  # Handle debounced draft updates from client
  @impl true
  def handle_event("draft_update", %{"content" => content}, socket) do
    chat_id = socket.assigns.chat_id
    # Only save draft if chat_id exists
    if chat_id do
      T3CloneElixir.InputDraftServer.set_draft(chat_id, content)
    end
    {:noreply, assign(socket, input_content: content)}
  end

  # Handle model selection from dropdown
  @impl true
  def handle_event("select_model", %{"id" => model_id}, socket) do
    models = socket.assigns.models
    selected = Enum.find(models, fn m -> to_string(m.id) == to_string(model_id) end) || List.first(models)
    if socket.assigns.chat_id do
      # Update the existing chat's selected model in the DB
      chat = Chats.get_chat!(socket.assigns.chat_id)
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
  @impl true
  def handle_event("send_message", %{"content" => content, "model_id" => model_id}, socket) do
    # Prevent sending empty or whitespace-only messages
    if !content || String.trim(content) == "" do
      {:noreply, socket}
    else
      # Clear the draft for this chat when sending a message
      if socket.assigns.chat_id do
        T3CloneElixir.InputDraftServer.delete_draft(socket.assigns.chat_id)
      end
      user_id = socket.assigns.user_id
      chat_id = socket.assigns.chat_id
      models = socket.assigns.models
      model = Enum.find(models, fn m -> to_string(m.id) == to_string(model_id) end) || List.first(models)
      socket = assign(socket, selected_model: model)
      model_name = model.openrouter_name || "openai/gpt-4o"
      selected_model_id = model.id
      cond do
        is_nil(chat_id) or chat_id == "" ->
          case Chats.create_chat_with_message(user_id, content, selected_model_id) do
            {:ok, %{chat: chat, message: message}} ->
              Phoenix.PubSub.subscribe(T3CloneElixir.PubSub, "chat:#{chat.id}")
              # Start streaming via ChatServer (use generate_response)
              chat_history = [message]
              ChatServer.generate_response(chat.id, chat_history, model_name)
              # Navigate to the new chat (remounts the chat area)
              messages = [message]
              socket = assign(socket,
                chat_id: chat.id,
                messages: messages,
                selected_model: model,
                ai_streaming_message: nil,
                is_waiting_for_stream: true,
                input_content: ""
              )
              {:noreply, socket |> push_event("stream_start", %{}) |> push_navigate(to: "/chats/#{chat.id}")}
            {:error, reason} ->
              {:noreply, socket |> put_flash(:error, "Failed to send message: #{inspect(reason)}")}
          end
        true ->
          # Existing chat: append message and start stream
          case Chats.create_message(chat_id, user_id, content, "user") do
            {:ok, message} ->
              # Fetch all messages as structs for state/UI
              messages = Chats.get_all_chat_messages(chat_id)
              # Map to LLM format only for the LLM call
              chat_history = Enum.map(messages, fn msg -> %{"role" => msg.who, "content" => msg.content} end)
              ChatServer.generate_response(chat_id, chat_history, model_name)
              # Assign messages as structs for everything else
              socket = assign(socket,
                messages: messages,
                selected_model: model,
                ai_streaming_message: nil,
                is_waiting_for_stream: true,
                input_content: ""
              )
              {:noreply, socket |> push_event("stream_start", %{})}
            {:error, reason} ->
              {:noreply, socket |> put_flash(:error, "Failed to send message: #{inspect(reason)}")}
          end
      end
    end
  end

  # Handle event to cancel/stop the AI stream
  @impl true
  def handle_event("cancel_stream", _params, socket) do
    ChatServer.cancel_stream(socket.assigns.chat_id)
    {:noreply, socket}
  end

  # Handle loading more messages for pagination (infinite scroll)
  @impl true
  def handle_event("load_more_messages", _params, socket) do
    chat_id = socket.assigns.chat_id
    offset = socket.assigns[:messages_offset] || 0
    new_messages =
      if chat_id do
        Chats.get_chat_messages(chat_id, 10, offset)
        |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})
      else
        []
      end
    all_messages =
      (new_messages ++ (socket.assigns[:messages] || []))
      |> Enum.uniq_by(& &1.id)
    all_loaded = new_messages == [] or length(new_messages) < 10
    {:noreply,
      socket
      |> assign(messages: all_messages, messages_offset: offset + length(new_messages), all_messages_loaded: all_loaded)
    }
  end

  # Handle incoming AI token stream
  @impl true
  def handle_info({:ai_token, token}, socket) do
    current = socket.assigns.ai_streaming_message || ""
    {:noreply, assign(socket, ai_streaming_message: current <> token)}
  end

  @impl true
  def handle_info(:done, socket) do
    chat_id = socket.assigns.chat_id
    ai_buffer = ChatServer.get_buffer(chat_id)
    user_id = socket.assigns.user_id
    if ai_buffer != "" do
      {:ok, _msg} = Chats.create_message(chat_id, user_id, ai_buffer, "ai")
    end
    ChatServer.clear_buffer(chat_id)
    messages =
      Chats.get_chat_messages(chat_id, 10, 0)
      |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})
    {:noreply,
      socket
      |> assign(messages: messages, ai_streaming_message: nil, is_waiting_for_stream: false)
      |> push_event("stream_done", %{})
    }
  end

end
