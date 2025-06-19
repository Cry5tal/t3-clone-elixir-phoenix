defmodule T3CloneElixir.Release do
  @moduledoc """
  Tasks to run before the application starts in production.
  """

  @app :t3_clone_elixir

  @doc """
  Creates the database (if it doesn't exist) and runs all migrations,
  but only in the primary region.
  """
  def create_and_migrate do
    primary = System.get_env("PRIMARY_REGION")
    region  = System.get_env("FLY_REGION")

    if region == primary do
      IO.puts("🚀 Running migrations in primary region: #{region}")

      # Load the application config (Repo, endpoint, etc.)
      Application.load(@app)

      # Get list of repositories from config
      repos = Application.fetch_env!(@app, :ecto_repos)

      Enum.each(repos, fn repo ->
        config = repo.config()

        # 1. Create the database if it doesn't exist
        case repo.__adapter__.storage_up(config) do
          :ok ->
            IO.puts("✅ Database created or already exists")

          {:error, :already_up} ->
            IO.puts("🔄 Database already up, skipping create")

          {:error, term} ->
            IO.warn("⚠️ Could not create database: #{inspect(term)}")
        end

        # 2. Run all migrations
        Ecto.Migrator.with_repo(repo, fn _repo_pid ->
          Ecto.Migrator.run(repo, :up, all: true)
        end)
      end)
    else
      IO.puts("⏭ Skipping migrations in region=#{region} (primary=#{primary})")
    end
  end
end
