defmodule T3CloneElixir.OpenrouterGenerator do
  @moduledoc """
  Handles streaming chat completions from OpenRouter API with cancellation support.
  """

  require Logger

  @openrouter_url "https://openrouter.ai/api/v1/chat/completions"
  @default_model "openai/gpt-4o"

  # Streams chat completion from OpenRouter, sending each chunk to the `receiver` PID.
  # Returns the PID of the spawned process, which can be sent :cancel to stop streaming.
  #
  # Usage:
  #   pid = OpenrouterGenerator.stream_chat_completion(prompt, model, self())
  #   send(pid, :cancel) # to cancel
  # Accepts a list of messages (role/content), for flexibility
  def stream_chat_completion(messages, model \\ @default_model, receiver) do
    api_key = Application.get_env(:t3_clone_elixir, :openrouter_api_key)
    IO.inspect(api_key, label: "[OpenrouterGenerator] api_key")
    spawn_link(fn ->
      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"},
        {"Accept", "text/event-stream"}
      ]
      body = %{
        "model" => model,
        "messages" => messages,
        "stream" => true
      }
      |> Jason.encode!()

      request = Finch.build(:post, @openrouter_url, headers, body)
      case Finch.stream(request, T3CloneElixir.Finch, nil, fn
        {:status, status}, _acc ->
          Logger.debug("[Openrouter] Status: #{status}")
          :ok
        {:headers, headers}, _acc ->
          Logger.debug("[Openrouter] Headers: #{inspect(headers)}")
          :ok
        {:data, chunk}, _acc ->
          for line <- String.split(chunk, "\n"), line != "" do
            cond do
              # Handle [DONE] marker
              String.trim(line) == "data: [DONE]" ->
                send(receiver, :openrouter_stream_done)
              
              # Handle regular data chunks
              String.starts_with?(line, "data: ") ->
                data = String.trim_leading(line, "data: ")
                
                # Parse the JSON and extract just the content delta
                case Jason.decode(data) do
                  {:ok, parsed} ->
                    # Extract content from the delta if it exists
                    with %{"choices" => [%{"delta" => %{"content" => content}} | _]} <- parsed,
                         true <- is_binary(content) and content != "" do
                      send(receiver, {:openrouter_token, content})
                    else
                      # Skip empty content or non-content deltas (like role changes)
                      _ -> :ok
                    end
                  
                  {:error, error} ->
                    Logger.error("[Openrouter] Failed to parse JSON: #{inspect(error)} for data: #{data}")
                end
              
              true -> :ok
            end
          end
          :ok
        {:done, _}, _acc ->
          send(receiver, :openrouter_stream_done)
          :ok
      end) do
        {:ok, _finch_pid} ->
          :ok
        {:error, reason} ->
          Logger.error("[Openrouter] Stream error: #{inspect(reason)}")
          send(receiver, {:openrouter_error, reason})
      end
    end)
  end

  # Backwards compatibility: single prompt string
  def stream_chat_completion(prompt, model, receiver) when is_binary(prompt) do
    messages = [%{"role" => "user", "content" => prompt}]
    stream_chat_completion(messages, model, receiver)
  end

end
