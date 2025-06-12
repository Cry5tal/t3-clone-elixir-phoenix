defmodule T3CloneElixir.Completion do
  @moduledoc """
  Abstraction for LLM completions. Handles prompt construction and provider dispatch.
  """

  alias T3CloneElixir.OpenrouterGenerator

  @default_model "openai/gpt-4o"

  # Public API: starts streaming completion for a chat history.
  # Receives chat_id, chat_history (list of Message structs), and receiver PID (usually the ChatServer).
  def generate(chat_id, chat_history, receiver \\ self()) do
    IO.inspect({chat_id, chat_history}, label: "[Completion] generate/3 called")
    system_prompt = "You are a helpful assistant."
    messages =
      [%{"role" => "system", "content" => system_prompt}]
      ++ to_openrouter_messages(chat_history)
    OpenrouterGenerator.stream_chat_completion(messages, @default_model, receiver)
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

end
