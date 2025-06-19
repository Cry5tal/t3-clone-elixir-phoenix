import Config

# config/runtime.exs executed at startup for all environments.
# Used to load runtime configuration from environment variables.

if config_env() == :prod do
  # Multi-region database configuration
  primary_region = System.get_env("PRIMARY_REGION")
  fly_region     = System.get_env("FLY_REGION")
  database_url   = System.get_env("DATABASE_URL") ||
    raise "environment variable DATABASE_URL is missing."

  # Adjust connection URL: use read-replica port in non-primary regions
  conn_url =
    if primary_region && fly_region && fly_region != primary_region do
      database_url
      |> URI.parse()
      |> Map.put(:port, 5433)
      |> URI.to_string()
    else
      database_url
    end

  # Configure Ecto Repo
  config :t3_clone_elixir, T3CloneElixir.Repo,
    url: conn_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),
    socket_options: if(System.get_env("ECTO_IPV6") in ["true", "1"], do: [:inet6], else: [])

  # Configure Endpoint at runtime
  endpoint_config = [
    url: [host: System.get_env("PHX_HOST") || "", port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "8080")
    ],
    secret_key_base: System.get_env("SECRET_KEY_BASE") || raise("SECRET_KEY_BASE missing")
  ]

  # Conditionally include LiveView signing salt
  endpoint_config =
    case System.get_env("LIVE_VIEW_SALT") do
      nil -> endpoint_config
      salt -> Keyword.put(endpoint_config, :live_view, [signing_salt: salt])
    end

  config :t3_clone_elixir, T3CloneElixirWeb.Endpoint, endpoint_config

  # Enable Phoenix server if requested by environment
  if System.get_env("PHX_SERVER") do
    config :t3_clone_elixir, T3CloneElixirWeb.Endpoint, server: true
  end
end
