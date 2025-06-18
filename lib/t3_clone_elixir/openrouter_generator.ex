defmodule T3CloneElixir.OpenrouterGenerator do
  @moduledoc """
  Handles streaming chat completions from OpenRouter API with cancellation support.
  """

  require Logger

  @openrouter_url "https://openrouter.ai/api/v1/chat/completions"
  @default_model "openai/gpt-4o"

  # Streams chat completion from OpenRouter, sending each chunk to the `receiver` PID.
  # Returns the PID of the spawned process, which can be sent :cancel to stop streaming.
  # Most of this is a recreation of the OpenRouter python api, with some modifications for elixir
  # Usage:
  #   pid = OpenrouterGenerator.stream_chat_completion(prompt, model, self())
  #   send(pid, :cancel) # to cancel
  # Accepts a list of messages (role/content), for flexibility
  def stream_chat_completion(messages, model \\ @default_model, receiver, is_stream \\ true) do
    api_key = Application.get_env(:t3_clone_elixir, :openrouter_api_key)
    IO.inspect(api_key, label: "[OpenrouterGenerator] api_key")
    spawn(fn ->
      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"},
        {"Accept", if(is_stream, do: "text/event-stream", else: "application/json")}
      ]
      body = %{
        "model" => model,
        "messages" => messages,
        "stream" => is_stream
      }
      |> Jason.encode!()

      request = Finch.build(:post, @openrouter_url, headers, body)
      # Support receiver as {pid, context} or just pid
      {send_pid, context} = case receiver do
        {pid, ctx} -> {pid, ctx}
        pid when is_pid(pid) -> {pid, nil}
      end

      if is_stream do
        # Streaming SSE mode (default)
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
                  if context do
                    send(send_pid, {:openrouter_stream_done, context})
                  else
                    send(send_pid, :openrouter_stream_done)
                  end

                # Handle regular data chunks
                String.starts_with?(line, "data: ") ->
                  data = String.trim_leading(line, "data: ")

                  # Parse the JSON and extract just the content delta
                  case Jason.decode(data) do
                    {:ok, parsed} ->
                      # Extract content from the delta if it exists
                      with %{"choices" => [%{"delta" => %{"content" => content}} | _]} <- parsed,
                           true <- is_binary(content) and content != "" do
                        if context do
                          send(send_pid, {:openrouter_token, context, content})
                        else
                          send(send_pid, {:openrouter_token, content})
                        end
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
            if context do
              send(send_pid, {:openrouter_stream_done, context})
            else
              send(send_pid, :openrouter_stream_done)
            end
            :ok
        end) do
          {:ok, _finch_pid} ->
            :ok
          {:error, reason} ->
            Logger.error("[Openrouter] Stream error: #{inspect(reason)}")
            if context do
              send(send_pid, {:openrouter_error, context, reason})
            else
              send(send_pid, {:openrouter_error, reason})
            end
        end
      else
        # Non-stream: get full JSON response, extract summary, send as a single token
        case Finch.request(request, T3CloneElixir.Finch) do
          {:ok, %Finch.Response{status: status, body: body}} ->
            IO.inspect({:summary_response_status, status, body}, label: "[DEBUG] Openrouter non-stream response")
            case Jason.decode(body) do
              {:ok, %{"choices" => [%{"message" => %{"content" => summary}} | _]}} ->
                IO.inspect(summary, label: "[DEBUG] Extracted summary from Openrouter response")
                if context do
                  send(send_pid, {:openrouter_token, context, summary})
                  send(send_pid, {:openrouter_stream_done, context})
                else
                  send(send_pid, {:openrouter_token, summary})
                  send(send_pid, :openrouter_stream_done)
                end
              other ->
                Logger.error("[Openrouter] Unexpected summary response: #{inspect(other)}")
                if context do
                  send(send_pid, {:openrouter_error, context, :invalid_summary_response})
                else
                  send(send_pid, {:openrouter_error, :invalid_summary_response})
                end
            end
          {:ok, %Finch.Response{status: status, body: body}} ->
            Logger.error("[Openrouter] Non-stream request failed: status #{status}, body: #{body}")
            if context do
              send(send_pid, {:openrouter_error, context, :http_error})
            else
              send(send_pid, {:openrouter_error, :http_error})
            end
          {:error, reason} ->
            Logger.error("[Openrouter] Non-stream request error: #{inspect(reason)}")
            if context do
              send(send_pid, {:openrouter_error, context, reason})
            else
              send(send_pid, {:openrouter_error, reason})
            end
        end
      end
    end)
  end


end
