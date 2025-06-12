# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     T3CloneElixir.Repo.insert!(%T3CloneElixir.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

defmodule T3CloneElixir.Seeds do
  alias T3CloneElixir.Repo
  alias T3CloneElixir.Accounts
  alias T3CloneElixir.Models.Model
  alias T3CloneElixir.Chats.Chat
  alias T3CloneElixir.Messages.Message
  import Ecto.UUID, only: [generate: 0]

  def make_me_admin do
    Accounts.make_admin("vasilenkoden14@gmail.com")
  end

  # Seeds chat models
  def seed_models do
    models = [
      %{name: "OpenAI GPT-4", openrouter_name: "openai/gpt-4", allow_images: true, allow_files: false},
      %{name: "Anthropic Claude-3", openrouter_name: "anthropic/claude-3", allow_images: false, allow_files: true}
    ]
    Enum.map(models, fn attrs -> Repo.insert!(Model.changeset(%Model{}, attrs)) end)
  end

  # Seeds chats for user_id 1
  def seed_chats(user_id) do
    chats = [
      %{name: "Elixir Q&A", user_id: user_id},
      %{name: "Markdown Playground", user_id: user_id},
      %{name: "General Coding", user_id: user_id}
    ]
    Enum.map(chats, fn attrs -> Repo.insert!(Chat.changeset(%Chat{}, attrs)) end)
  end

  # Seeds messages for each chat
  def seed_messages(chats, models, user_id) do
    IO.inspect(models, label: "Seeded models")
    if Enum.empty?(models), do: raise("No models found! Check your seeds or migration.")
    markdown_examples = [
      {"user", "Hello! This is a **markdown** message."},
      {"ai", "Here's some Elixir code:\n```elixir\nIO.puts(\"Hello, world!\")\n```"},
      {"user", "How about some math?\n\n`E = mc^2`"},
      {"ai", "A code block:\n```python\nprint('Hello from Python!')\n```"},
      {"user", "List example:\n- Item 1\n- Item 2\n- **Bold Item**"},
      {"ai", "Table example:\n\n| Syntax | Description |\n|--------|-------------|\n| Header | Title       |\n| Paragraph | Text    |"}
    ]

    for {chat, _idx} <- Enum.with_index(chats) do
      slot_id = generate()
      [model1, model2] = Enum.take_random(try, 2)
      for {who, content} <- Enum.take_random(markdown_examples, Enum.random(3..6)) do
        model_id = if who == "ai", do: model1.id, else: model2.id
        IO.inspect(model_id, label: "model_id for message")
        Repo.insert!(%Message{
          content: content,
          who: who,
          slot_id: slot_id,
          chat_id: chat.id,
          user_id: if(who == "user", do: user_id, else: nil),
          model_id: model_id
        })
      end
    end
  end
end

# Existing admin logic
#T3CloneElixir.Seeds.make_me_admin()

# SEED DATA
user_id = 1 # Assumes user with id 1 exists
models = T3CloneElixir.Seeds.seed_models()
chats = T3CloneElixir.Seeds.seed_chats(user_id)
T3CloneElixir.Seeds.seed_messages(chats, models, user_id)
