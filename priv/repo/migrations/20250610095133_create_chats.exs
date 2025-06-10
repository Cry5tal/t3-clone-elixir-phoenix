defmodule T3CloneElixir.Repo.Migrations.CreateChats do
  use Ecto.Migration

  def change do
    create table(:chats, primary_key: false) do
  add :id, :uuid, primary_key: true
  add :name, :string
  add :user_id, references(:users, on_delete: :delete_all), null: false

  timestamps(type: :utc_datetime)
end

    alter table(:users) do
      add :role, :string, default: "user"
    end

    create table(:messages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :content, :text, null: false
      add :who, :string, null: false
      add :generated_by, :string
      add :slot_id, :uuid, null: false
      add :chat_id, references(:chats, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end


    create unique_index(:chats, [:id])
    create index(:chats, [:user_id])
    create index(:messages, [:chat_id])
    create index(:messages, [:slot_id])
    create index(:messages, [:user_id])
  end
end
