defmodule T3CloneElixir.Repo.Migrations.SelectedModelChat do
  use Ecto.Migration

  def change do
    alter table(:chats) do
      add :selected_model_id, references(:models, on_delete: :nilify_all)
    end
  end
end
