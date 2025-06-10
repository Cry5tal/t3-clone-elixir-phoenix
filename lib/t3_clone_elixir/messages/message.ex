defmodule T3CloneElixir.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  schema "messages" do
    field :content, :string # Use :string, will map to :text in migration for large size
    field :who, :string # "user" or "ai"
    field :slot_id, :binary_id # Groups sibling messages for branching/comparison

    belongs_to :chat, T3CloneElixir.Chats.Chat, type: :binary_id
    belongs_to :user, T3CloneElixir.Accounts.User
    belongs_to :model, T3CloneElixir.Models.Model
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :who, :slot_id, :chat_id, :user_id, :model_id])
    |> validate_required([:content, :who, :slot_id, :chat_id])
    |> validate_inclusion(:who, ["user", "ai"])
  end
end
