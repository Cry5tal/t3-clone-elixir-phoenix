defmodule T3CloneElixir.Completion do
  @moduledoc """
  Abstraction for LLM completions. Handles prompt construction and provider dispatch.
  """

  alias T3CloneElixir.OpenrouterGenerator

  @default_model "openai/gpt-4o"

  # Public API: starts streaming completion for a chat history.
  # Receives chat_id, chat_history (list of Message structs), and receiver PID (usually the ChatServer).
  # New: generate/4 with model_name
  def generate(chat_id, chat_history, receiver, model_name) do
    IO.inspect({chat_id, chat_history, model_name}, label: "[Completion] generate/4 called")
    system_prompt = "You are a helpful assistant."
    messages =
      [%{"role" => "system", "content" => system_prompt}]
      ++ to_openrouter_messages(chat_history)
    OpenrouterGenerator.stream_chat_completion(messages, model_name, receiver, true)
  end

  # Backwards compatibility
  def generate(chat_id, chat_history, receiver \\ self()) do
    generate(chat_id, chat_history, receiver, @default_model)
  end

  # Helper: Convert messages to OpenRouter API format
  # Handles both Ecto structs and maps
  defp to_openrouter_messages(chat_history) do
    Enum.map(chat_history, fn msg ->
      cond do
        # Handle Ecto structs (Message structs)
        is_struct(msg) and Map.has_key?(msg, :who) ->
          role = case msg.who do
            "user" -> "user"
            "ai" -> "assistant"
            other -> to_string(other)
          end
          %{"role" => role, "content" => msg.content}

        # Handle maps with string keys
        is_map(msg) and Map.has_key?(msg, "role") ->
          role = if msg["role"] == "ai", do: "assistant", else: msg["role"]
          %{"role" => role, "content" => msg["content"]}

        # Handle any other unexpected format
        true ->
          raise "Invalid message format: #{inspect(msg)}"
      end
    end)
  end

  @doc """
  Generates a short summary/title for a chat using the LLM.
  Used for automatic chat renaming after the first completion.
  chat_id: chat id (for context/logging if needed)
  chat_history: list of Message structs or maps (same as generate/4)
  receiver: PID to send the streaming result to (usually the ChatServer)
  """
  def generate_summary(_chat_id, chat_history, receiver \\ self()) do
    system_prompt = "You are an assistant that summarizes conversations. Given the following messages, generate a very short, descriptive chat title (3-8 words, no quotes, no punctuation at the end)."
    messages =
      [%{"role" => "system", "content" => system_prompt}]
      ++ to_openrouter_messages(chat_history)
    # Use a fast/small model for summarization if desired, fallback to default
    model = @default_model
    # Pass a context tag :summary to distinguish summary completions
    OpenrouterGenerator.stream_chat_completion(messages, model, {receiver, :summary}, false)
  end

end
