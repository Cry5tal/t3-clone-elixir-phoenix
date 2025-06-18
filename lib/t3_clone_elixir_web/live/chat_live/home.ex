defmodule T3CloneElixirWeb.ChatLive.Home do
  use T3CloneElixirWeb, :live_view

  alias T3CloneElixir.Chats
  alias T3CloneElixir.Models
  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    if connected?(socket) do
      Phoenix.PubSub.subscribe(T3CloneElixir.PubSub, "chats:list")
    end
    chats = Chats.get_chats_by_user_id(user_id)
    models = Models.list_models()
    default_model = List.first(models)
    {:ok, assign(socket,
      chats: chats,
      models: models,
      selected_model: default_model,
      show_model_dropdown: false,
      selected_chat_id: nil,
      show_rename_modal: false,
      show_delete_modal: false,
      modal_chat_id: nil,
      modal_chat_name: nil
    )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    selected_chat_id = Map.get(params, "uuid")
    socket = assign(socket,
      selected_chat_id: selected_chat_id
    )
    {:noreply, socket}
  end
  # Modal open/close handlers
  @impl true
  def handle_event("open_rename_modal", %{"id" => id, "name" => name}, socket) do
    {:noreply, assign(socket, show_rename_modal: true, show_delete_modal: false, modal_chat_id: id, modal_chat_name: name)}
  end

  @impl true
  def handle_event("open_delete_modal", %{"id" => id, "name" => name}, socket) do
    {:noreply, assign(socket, show_delete_modal: true, show_rename_modal: false, modal_chat_id: id, modal_chat_name: name)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_rename_modal: false, show_delete_modal: false, modal_chat_id: nil, modal_chat_name: nil)}
  end


  @impl true
  def handle_event("rename_chat", %{"name" => name}, socket) do
    chat_id = socket.assigns.modal_chat_id
    chat = Chats.get_chat!(chat_id)
    case Chats.update_chat(chat, %{name: name}) do
      {:ok, _chat} ->
        {:noreply,
         socket
         |> put_flash(:info, "Chat renamed successfully")
         |> assign(show_rename_modal: false, modal_chat_id: nil, modal_chat_name: nil)}
      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to rename chat: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_chat", %{"id" => id}, socket) do
    chat = Chats.get_chat!(id)
    case Chats.delete_chat(chat) do
      {:ok, _chat} ->
        # If the deleted chat is currently open, redirect to /chats
        if to_string(socket.assigns.selected_chat_id) == to_string(id) do
          {:noreply,
            socket
            |> assign(show_delete_modal: false, modal_chat_id: nil, modal_chat_name: nil)
            |> put_flash(:info, "Chat deleted successfully")
            |> push_navigate(to: "/chats")}
        else
          {:noreply,
            socket
            |> assign(show_delete_modal: false, modal_chat_id: nil, modal_chat_name: nil)
            |> put_flash(:info, "Chat deleted successfully")}
        end
      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to delete chat: #{inspect(reason)}")}
    end
  end

  # Handle PubSub updates for chat list
  @impl true
  def handle_info({:new_chat, chat}, socket) do
    {:noreply, update(socket, :chats, fn chats -> [chat | chats] end)}
  end

  @impl true
  def handle_info({:updated_chat, chat}, socket) do
    {:noreply, update(socket, :chats, fn chats ->
      chats
      |> Enum.map(fn c -> if c.id == chat.id, do: chat, else: c end)
      |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
    end)}
  end

  @impl true
  def handle_info({:deleted_chat, chat}, socket) do
    {:noreply, update(socket, :chats, fn chats ->
      Enum.reject(chats, fn c -> c.id == chat.id end)
    end)}
  end

  # Handle chat_renamed PubSub event for automatic renaming
  @impl true
  def handle_info({:chat_renamed, chat_id, new_name}, socket) do
    IO.inspect({:chat_renamed_event, chat_id, new_name}, label: "[DEBUG] Received chat_renamed event")
    # Update the chat name in the @chats assign
    chats = Enum.map(socket.assigns.chats, fn c ->
      if to_string(c.id) == to_string(chat_id), do: %{c | name: new_name}, else: c
    end)
    # If the currently selected chat is renamed, update modal_chat_name as well
    socket =
      if to_string(socket.assigns.selected_chat_id) == to_string(chat_id) do
        assign(socket, chats: chats, modal_chat_name: new_name)
      else
        assign(socket, chats: chats)
      end
    IO.inspect(socket.assigns.chats, label: "[DEBUG] Updated chats after rename")
    {:noreply, socket}
  end

  # Catch-all for unexpected PubSub or streaming messages to prevent crashes
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

end
