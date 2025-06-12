defmodule T3CloneElixir.Chats.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  schema "chats" do
    field :name, :string
    belongs_to :user, T3CloneElixir.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:user_id, :name])
    |> validate_required([:user_id, :name])
  end
end
