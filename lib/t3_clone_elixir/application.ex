defmodule T3CloneElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      T3CloneElixirWeb.Telemetry,
      T3CloneElixir.Repo,
      {DNSCluster, query: Application.get_env(:t3_clone_elixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: T3CloneElixir.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: T3CloneElixir.Finch},
      # Start a worker by calling: T3CloneElixir.Worker.start_link(arg)
      # {T3CloneElixir.Worker, arg},
      # Start the Registry for per-chat servers
      {Registry, keys: :unique, name: T3CloneElixir.ChatRegistry},
      # Start the DynamicSupervisor for chat servers
      T3CloneElixir.ChatSupervisor,
      # Start to serve requests, typically the last entry
      T3CloneElixirWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: T3CloneElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    T3CloneElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
