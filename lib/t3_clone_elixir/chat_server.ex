defmodule T3CloneElixir.ChatServer do
  use GenServer

  # Starts a per-chat GenServer registered via Registry
  def start_link(chat_id) do
    GenServer.start_link(__MODULE__, chat_id, name: via_tuple(chat_id))
  end

  defp via_tuple(chat_id), do: {:via, Registry, {T3CloneElixir.ChatRegistry, chat_id}}

  def init(chat_id) do
    # Initialize buffer as empty string
    {:ok, %{chat_id: chat_id, buffer: ""}}
  end

  # Public API to trigger AI response generation for a chat
  # New: generate_response/3 with model_name
  def generate_response(chat_id, chat_history, model_name) do
    IO.inspect({chat_id, chat_history, model_name}, label: "[ChatServer] generate_response/3 called")
    case Registry.lookup(T3CloneElixir.ChatRegistry, chat_id) do
      [{pid, _}] ->
        GenServer.cast(pid, {:generate_response, chat_history, model_name})
      [] ->
        case T3CloneElixir.ChatSupervisor.start_chat_server(chat_id) do
          {:ok, pid} ->
            GenServer.cast(pid, {:generate_response, chat_history, model_name})
          {:error, {:already_started, pid}} ->
            GenServer.cast(pid, {:generate_response, chat_history, model_name})
          other ->
            IO.inspect(other, label: "[ChatServer] Error starting chat server")
        end
    end
  end

  # Backwards compatibility
  def generate_response(chat_id, chat_history) do
    generate_response(chat_id, chat_history, "openai/gpt-4o")
  end

  # Handle cast for generating AI response (with model_name)
  def handle_cast({:generate_response, chat_history, model_name}, state = %{chat_id: chat_id, buffer: _buffer}) do
    IO.inspect({chat_id, chat_history, model_name}, label: "[ChatServer] handle_cast :generate_response/3")
    T3CloneElixir.Completion.generate(chat_id, chat_history, self(), model_name)
    {:noreply, %{state | buffer: ""}}
  end

  # Backwards compatibility for old calls
  def handle_cast({:generate_response, chat_history}, state = %{chat_id: chat_id, buffer: _buffer}) do
    IO.inspect({chat_id, chat_history}, label: "[ChatServer] handle_cast :generate_response")
    T3CloneElixir.Completion.generate(chat_id, chat_history, self(), "openai/gpt-4o")
    {:noreply, %{state | buffer: ""}}
  end

  # Handle appending tokens to buffer
  def handle_cast({:buffer_token, token}, state) do
    new_buffer =
      if state.buffer == "" do
        token
      else
        state.buffer <> "" <> token
      end
    {:noreply, %{state | buffer: new_buffer}}
  end
  def handle_cast(:clear_buffer, state) do
    {:noreply, %{state | buffer: ""}}
  end
  # Handle incoming OpenRouter streaming tokens and events
  def handle_info({:openrouter_token, content}, state = %{chat_id: chat_id}) do
    topic = "chat:#{chat_id}"
    # Content is already extracted from JSON by OpenrouterGenerator
    GenServer.cast(self(), {:buffer_token, content})
    Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, topic, {:ai_token, content})
    {:noreply, state}
  end

  # Handles the end of the AI completion stream. If this is the first AI completion (chat still has default name),
  # trigger summary generation for automatic chat renaming.
  def handle_info(:openrouter_stream_done, state = %{chat_id: chat_id}) do
    IO.inspect({:openrouter_stream_done, chat_id}, label: "[DEBUG] handle_info(:openrouter_stream_done) entry")
    topic = "chat:#{chat_id}"
    Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, topic, :done)

    # Fetch chat from DB to check if it still has the default name
    chat = T3CloneElixir.Chats.get_chat!(chat_id)
    IO.inspect(chat, label: "[DEBUG] chat fetched in :openrouter_stream_done")
    if chat.name == "new chat" do
      # Fetch all messages for summarization
      chat_history = T3CloneElixir.Chats.get_all_chat_messages(chat_id)
      IO.inspect(chat_history, label: "[DEBUG] chat_history for summarization (before buffer)")
      # Append the current AI response (buffer) as an 'ai' message so summary sees both user and AI response
      chat_history_with_ai =
        if String.trim(state.buffer) != "" do
          chat_history ++ [%{"role" => "assistant", "content" => String.trim(state.buffer)}]
        else
          chat_history
        end
      IO.inspect(chat_history_with_ai, label: "[DEBUG] chat_history for summarization (with buffer)")
      # Call summary generation in non-stream mode; will receive a single token
      res = T3CloneElixir.Completion.generate_summary(chat_id, chat_history_with_ai, self())
      IO.inspect(res, label: "[DEBUG] generate_summary result")
      {:noreply, state}
    else
      IO.inspect(:skip_summarization, label: "[DEBUG] chat already renamed, skip summarization")
      {:noreply, state}
    end
  end

  # Handles summary response (single token) from Completion.generate_summary (tagged)
  def handle_info({:openrouter_token, :summary, summary}, state = %{chat_id: chat_id}) do
    IO.inspect({:openrouter_token_summary, chat_id, summary}, label: "[DEBUG] handle_info({:openrouter_token, :summary, ...}) entry")
    # Update chat name in DB
    chat = T3CloneElixir.Chats.get_chat!(chat_id)
    IO.inspect(chat, label: "[DEBUG] chat before update in :summary handler")
    {:ok, _updated_chat} = T3CloneElixir.Chats.update_chat(chat, %{name: String.trim(summary)})
    IO.inspect(:updated_chat, label: "[DEBUG] chat updated in DB")
    # Broadcast to chat topic and chats:list (handled in update_chat)
    topic = "chat:#{chat_id}"
    Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, topic, {:chat_renamed, chat_id, String.trim(summary)})
    IO.inspect({:broadcasted_rename, chat_id, summary}, label: "[DEBUG] broadcasted chat_renamed")
    {:noreply, state}
  end

  # Optionally handle :openrouter_stream_done, :summary (not strictly needed for non-stream)
  def handle_info({:openrouter_stream_done, :summary}, state), do: {:noreply, state}

  def handle_info({:openrouter_error, reason}, state = %{chat_id: chat_id}) do
    topic = "chat:#{chat_id}"
    Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, topic, {:ai_error, reason})
    {:noreply, state}
  end



  # Public API to clear buffer
  def clear_buffer(chat_id) do
    case Registry.lookup(T3CloneElixir.ChatRegistry, chat_id) do
      [{pid, _}] ->
        GenServer.cast(pid, :clear_buffer)
      [] ->
        :ok
    end
  end

  # Public API to get current buffer
  def get_buffer(chat_id) do
    case Registry.lookup(T3CloneElixir.ChatRegistry, chat_id) do
      [{pid, _}] ->
        GenServer.call(pid, :get_buffer)
      [] ->
        ""
    end
  end

  def handle_call(:get_buffer, _from, state) do
    {:reply, state.buffer, state}
  end
end
