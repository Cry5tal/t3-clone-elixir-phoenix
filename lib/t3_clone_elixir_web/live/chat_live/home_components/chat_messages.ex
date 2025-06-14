defmodule T3CloneElixirWeb.Live.ChatLive.HomeComponents.ChatMessages do
  use T3CloneElixirWeb, :live_component

  @doc """
  Renders chat messages. Assigns:
    - :messages (list of message maps/structs)
    - :streaming_message (string, optional)
  """
  def render(assigns) do
    ~H"""
    <div>
      <%= if @messages == [] and is_nil(@streaming_message) do %>
        <div class="text-center text-text-300">No messages yet.</div>
      <% else %>
        <%= for msg <- @messages do %>
          <div class={if msg.who == "user", do: "flex justify-end", else: "flex"}>
            <%= if msg.who in ["ai", "assistant"] do %>
              <div id={"ai-msg-#{msg.id || @index}"} class="ai-message rounded-xl px-6 py-4 bg-bg-100 text-text-100 max-w-2xl w-full">
                <%= for block <- parse_code_blocks(msg.content) do %>
                  <%= if is_map(block) and block.type == :code do %>
                    <div class="code-card bg-bg-200 border border-bg-300 rounded-xl mb-4 mt-4 overflow-hidden">
                      <div class="flex items-center justify-between px-4 py-2 bg-bg-300 border-b border-bg-300">
                        <span class="text-xs uppercase tracking-wide text-text-200 font-semibold">
                          <%= block.language %>
                        </span>
                        <button id={"copy-btn-#{msg.id || @index}"} class="copy-btn text-xs px-2 py-1 rounded bg-bg-100 hover:bg-accent-100 transition ml-2" phx-hook="CopyCode" type="button">
                          Copy
                        </button>
                      </div>
                      <%= if block.language == "mermaid" do %>
                        <pre class="m-0 p-0 rounded-none"><code class="language-mermaid"><%= block.code %></code></pre>
                      <% else %>
                        <%= Phoenix.HTML.raw(format_markdown("```" <> block.language <> "\n" <> block.code <> "```")) %>
                      <% end %>
                    </div>
                  <% else %>
                    <%= Phoenix.HTML.raw(format_markdown(block)) %>
                  <% end %>
                <% end %>
              </div>
            <% else %>
              <div class="rounded-xl px-5 py-3 bg-bg-300 text-text-100 max-w-xl ml-8">
                <%= msg.content %>
              </div>
            <% end %>
          </div>
        <% end %>
        <%= if @streaming_message do %>
          <div class="flex">
            <div id="ai-msg-streaming" class="ai-message rounded-xl px-6 py-4 bg-bg-100 text-text-100 max-w-2xl w-full animate-pulse">
              <%= for block <- parse_code_blocks(@streaming_message) do %>
                <%= if is_map(block) and block.type == :code do %>
                  <div class="code-card bg-bg-200 border border-bg-300 rounded-xl mb-4 overflow-hidden">
                    <div class="flex items-center justify-between px-4 py-2 bg-bg-300 border-b border-bg-300">
                      <span class="text-xs uppercase tracking-wide text-accent-100 font-semibold">
                        <%= block.language %>
                      </span>
                      <button id="copy-btn-streaming" class="copy-btn text-xs px-2 py-1 rounded bg-bg-100 hover:bg-accent-100 transition ml-2" phx-hook="CopyCode" type="button">
                        Copy
                      </button>
                    </div>
                    <%= if block.language == "mermaid" do %>
                      <pre class="m-0 p-0 rounded-none"><code class="language-mermaid"><%= block.code %></code></pre>
                    <% else %>
                      <%= Phoenix.HTML.raw(format_markdown("```" <> block.language <> "\n" <> block.code <> "```")) %>
                    <% end %>
                  </div>
                <% else %>
                  <%= Phoenix.HTML.raw(format_markdown(block)) %>
                <% end %>
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # Helper: Parse markdown content into text and code blocks
  # Returns a list of either strings (markdown text) or maps (%{type: :code, language: lang, code: code})
  defp parse_code_blocks(nil), do: []
  defp parse_code_blocks(text) when is_binary(text) do
    # Regex to match code blocks: ```lang\n...code...\n```
    regex = ~r/```([a-zA-Z0-9_+-]*)\n([\s\S]*?)```/m
    do_parse_code_blocks(text, regex, [])
  end

  defp do_parse_code_blocks(<<>>, _regex, acc), do: Enum.reverse(acc)
  defp do_parse_code_blocks(text, regex, acc) do
    case Regex.run(regex, text, capture: :all_but_first) do
      [lang, code] ->
        {before, rest} = Regex.split(regex, text, parts: 2) |> List.to_tuple()
        acc =
          (if before != "", do: [before | acc], else: acc)
          |> List.insert_at(0, %{type: :code, language: lang == "" && "text" || lang, code: code})
        do_parse_code_blocks(rest || "", regex, acc)
      nil ->
        [text | acc] |> Enum.reverse()
    end
  end

  # Formats markdown to GitHub-style HTML using mdex
  # Only used for assistant/AI messages
  defp format_markdown(nil), do: ""
  defp format_markdown(text) when is_binary(text) do
    MDEx.to_html!(
      text,
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        shortcodes: true
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true,
        relaxed_autolinks: true
      ],
      render: [
        unsafe_: true
      ],
      syntax_highlight: [
        formatter: {:html_inline, theme: "github_dark"}
      ]
    )
  end

end
