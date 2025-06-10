defmodule T3CloneElixir.Repo.Migrations.CreateModels do
  use Ecto.Migration

  def change do
    create table(:models) do
      add :name, :string
      add :openrouter_name, :string
      add :allow_images, :boolean, default: false, null: false
      add :allow_files, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    alter table(:messages) do
      add :model_id, references(:models, on_delete: :nilify_all)
      remove(:generated_by)
    end


  end
end
