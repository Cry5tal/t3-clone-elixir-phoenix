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
  def generate_response(chat_id, chat_history) do
    IO.inspect({chat_id, chat_history}, label: "[ChatServer] generate_response/2 called")
    # Ensure the per-chat server is started
    case Registry.lookup(T3CloneElixir.ChatRegistry, chat_id) do
      [{pid, _}] ->
        # Already started
        GenServer.cast(pid, {:generate_response, chat_history})
      [] ->
        case T3CloneElixir.ChatSupervisor.start_chat_server(chat_id) do
          {:ok, pid} ->
            GenServer.cast(pid, {:generate_response, chat_history})
          {:error, {:already_started, pid}} ->
            GenServer.cast(pid, {:generate_response, chat_history})
          other ->
            IO.inspect(other, label: "[ChatServer] Error starting chat server")
        end
    end
  end

  # Handle cast for generating AI response
  def handle_cast({:generate_response, chat_history}, state = %{chat_id: chat_id, buffer: _buffer}) do
    IO.inspect({chat_id, chat_history}, label: "[ChatServer] handle_cast :generate_response")
    # Mock AI reply (for demo, just echo a canned string)
    mock_reply = "This is a mock AI response streaming token by token.This is a mock AI response streaming token by token.This is a mock AI response streaming token by token.This is a mock AI response streaming token by token.This is a mock AI response streaming token by token.This is a mock AI response streaming token by token.This is a mock AI response streaming token by token.This is a mock AI response streaming token by token."
    tokens = String.split(mock_reply, " ")
    topic = "chat:#{chat_id}"
    IO.inspect(topic, label: "[ChatServer] PubSub topic for streaming")

    # Spawn a task to simulate streaming
    Task.start(fn ->
      Enum.each(tokens, fn token ->
        GenServer.cast(via_tuple(chat_id), {:buffer_token, token})
        Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, topic, {:ai_token, token})
        Process.sleep(50)
      end)
      # DO NOT clear buffer here; let LiveView clear after DB save
      Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, topic, :done)
    end)

    {:noreply, %{state | buffer: ""}}
  end

  # Handle appending tokens to buffer
  def handle_cast({:buffer_token, token}, state) do
    new_buffer =
      if state.buffer == "" do
        token
      else
        state.buffer <> " " <> token
      end
    {:noreply, %{state | buffer: new_buffer}}
  end

  def handle_cast(:clear_buffer, state) do
    {:noreply, %{state | buffer: ""}}
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
