defmodule T3CloneElixir.Release do
  @app :t3_clone_elixir

  def create_and_migrate do
    primary = System.get_env("PRIMARY_REGION")
    region  = System.get_env("FLY_REGION")

    if region == primary do
      Application.load(@app)
      for repo <- Application.fetch_env!(@app, :ecto_repos) do
        config = repo.config()

        case repo.__adapter__.storage_up(config) do
          :ok -> IO.puts("✅ Database created or already exists")
          {:error, :already_up} -> IO.puts("🔄 DB exists, skip create")
          {:error, term} -> IO.puts("⚠️ Could not create DB: #{inspect(term)}")
        end

        Ecto.Migrator.with_repo(repo, fn _ ->
          Ecto.Migrator.run(repo, :up, all: true)
        end)
      end
    else
      IO.puts("⏭ Skipping migrations in non-primary region (#{region})")
    end
  end
end
