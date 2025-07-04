defmodule T3CloneElixir.ChatSupervisor do
  use DynamicSupervisor

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_chat_server(chat_id) do
    child_spec = {T3CloneElixir.ChatServer, chat_id}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
