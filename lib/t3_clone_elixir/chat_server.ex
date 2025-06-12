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
    #topic = "chat:#{chat_id}"

    # Start streaming completion using the abstraction module
    # Tokens will be received as :openrouter_token messages in handle_info
    T3CloneElixir.Completion.generate(chat_id, chat_history, self())

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
  # Handle incoming OpenRouter streaming tokens and events
  def handle_info({:openrouter_token, content}, state = %{chat_id: chat_id, buffer: buffer}) do
    topic = "chat:#{chat_id}"
    # Content is already extracted from JSON by OpenrouterGenerator
    GenServer.cast(self(), {:buffer_token, content})
    Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, topic, {:ai_token, content})
    {:noreply, state}
  end

  def handle_info(:openrouter_stream_done, state = %{chat_id: chat_id}) do
    topic = "chat:#{chat_id}"
    Phoenix.PubSub.broadcast(T3CloneElixir.PubSub, topic, :done)
    {:noreply, state}
  end

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
