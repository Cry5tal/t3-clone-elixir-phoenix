defmodule T3CloneElixir.Repo do
  use Ecto.Repo,
    otp_app: :t3_clone_elixir,
    adapter: Ecto.Adapters.Postgres
end
