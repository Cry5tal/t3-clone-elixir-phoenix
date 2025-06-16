defmodule T3CloneElixir.InputDraftServer do
  @moduledoc """
  GenServer for storing per-chat input drafts in memory (no DB persistence).
  Key: chat_id (string or integer)
  Value: input draft (string)
  """
  use GenServer

  # Client API

  @doc "Start the server."
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Get draft for chat_id."
  def get_draft(chat_id) do
    GenServer.call(__MODULE__, {:get, chat_id})
  end

  @doc "Set draft for chat_id."
  def set_draft(chat_id, draft) do
    GenServer.cast(__MODULE__, {:set, chat_id, draft})
  end

  @doc "Delete draft for chat_id."
  def delete_draft(chat_id) do
    GenServer.cast(__MODULE__, {:delete, chat_id})
  end

  # Server Callbacks
  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:get, chat_id}, _from, state) do
    {:reply, Map.get(state, chat_id, ""), state}
  end

  @impl true
  def handle_cast({:set, chat_id, draft}, state) do
    {:noreply, Map.put(state, chat_id, draft)}
  end

  @impl true
  def handle_cast({:delete, chat_id}, state) do
    {:noreply, Map.delete(state, chat_id)}
  end
end
