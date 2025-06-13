defmodule T3CloneElixir.Repo.Migrations.SelectedModelChatInteger do
  use Ecto.Migration

  def change do
    alter table(:chats) do
      remove :selected_model_id
      add :selected_model_id, references(:models, type: :integer)
    end
  end
end
