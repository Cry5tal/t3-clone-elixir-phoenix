# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :t3_clone_elixir,
  ecto_repos: [T3CloneElixir.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :t3_clone_elixir, T3CloneElixirWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: T3CloneElixirWeb.ErrorHTML, json: T3CloneElixirWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: T3CloneElixir.PubSub,
  live_view: [signing_salt: "NNG9jQBI"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :t3_clone_elixir, T3CloneElixir.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  t3_clone_elixir: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  t3_clone_elixir: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]





config :t3_clone_elixir, :openrouter_api_key, System.get_env("OPENROUTER_API_KEY")
config :t3_clone_elixir, :admin_email, System.get_env("ADMIN_EMAIL")
config :t3_clone_elixir, :admin_password, System.get_env("ADMIN_PASSWORD")

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
