defmodule T3CloneElixirWeb.ChatLive.HomeComponents.Sidebar do
  use T3CloneElixirWeb, :live_component

  @moduledoc """
  Sidebar LiveComponent for chat navigation and actions.
  Renders the chat list, new chat button, and logout button.
  Receives :chats, :selected_chat_id, :show_rename_modal, :show_delete_modal, :modal_chat_id, :modal_chat_name as assigns.
  """

  @impl true
  # Render the sidebar with keyed chat list items for granular updates and scroll preservation
  def render(assigns) do
    ~H"""
    <aside
      id="logo-sidebar"
      class="fixed top-0 left-0 z-40 w-64 h-screen pt-20 transition-transform -translate-x-full bg-bg-200 border-r border-bg-300 sm:translate-x-0"
      aria-label="Sidebar"
    >
      <div class="h-full flex flex-col px-3 pb-4 overflow-y-auto bg-bg-200">
        <!-- New Chat Button -->
        <a
          href={~p"/chats"}
          class="w-full mb-4 py-2 px-4 flex items-center justify-center rounded-full bg-brand text-text-100 hover:bg-accent-100 transition"
        >
          <svg
            class="w-5 h-5 mr-2"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
          </svg>
          New Chat
        </a>
        <!-- Chat List with keyed function components for each chat item -->
        <div class="flex-1 overflow-y-auto">
          <ul class="space-y-1">
            <%= for chat <- @chats do %>
              <.chat_list_item
                key={chat.id}
                chat={chat}
                selected_chat_id={@selected_chat_id}
              />
            <% end %>
          </ul>
        </div>
        <!-- Log Out Button -->
        <.link
          href={~p"/users/log_out"}
          method="delete"
          class="w-full mt-4 py-2 px-4 flex items-center justify-center rounded-full bg-bg-300 text-text-100 hover:bg-accent-100 transition"
        >
          <svg
            class="w-5 h-5 mr-2"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a2 2 0 01-2 2H7a2 2 0 01-2-2V7a2 2 0 012-2h4a2 2 0 012 2v1"
            />
          </svg>
          Log out
        </.link>
      </div>
    </aside>
    """
  end

  # Stateless function component for a single chat list item, keyed by chat.id
  @doc """
  Renders a single chat item in the sidebar. Only rerenders when chat or selected_chat_id changes.
  """
  attr :chat, :map, required: true
  attr :selected_chat_id, :string, required: true
  def chat_list_item(assigns) do
    ~H"""
    <li class="relative">
      <div class="flex items-center">
        <.link
          patch={"/chats/#{@chat.id}"}
          class={[
            "flex-1 flex items-center px-3 py-2 rounded-lg transition relative overflow-hidden",
            if(@selected_chat_id == to_string(@chat.id),
              do: "bg-bg-300 text-text-100",
              else: "bg-bg-200 text-text-100 hover:bg-accent-100"
            )
          ]}
        >
          <span class="block max-w-[calc(100%-2.5rem)] whitespace-nowrap overflow-hidden fade-right pr-8">{@chat.name}</span>
          <!-- Three Dots Dropdown Trigger using Flowbite logic -->
          <button
            id={"dropdownDotsButton-#{@chat.id}"}
            phx-hook="DropdownMenuHook"
            data-dropdown-menu-id={"dropdownDots-#{@chat.id}"}
            type="button"
            class="absolute right-2 top-1/2 -translate-y-1/2 p-1 rounded-full hover:bg-bg-200 focus:outline-none focus:ring-2 focus:ring-brand flex items-center justify-center"
          >
            <svg
              class="w-5 h-5 text-text-300"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <circle cx="12" cy="5" r="1.5" />
              <circle cx="12" cy="12" r="1.5" />
              <circle cx="12" cy="19" r="1.5" />
            </svg>
          </button>
        </.link>
        <!-- Flowbite Dropdown Menu -->
        <div
          id={"dropdownDots-#{@chat.id}"}
          class="z-50 hidden bg-bg-200 divide-y divide-bg-300 border-[1px] border-bg-300 rounded-lg shadow-sm w-44 absolute left-40 top-10"
        >
          <ul class="py-2 text-sm text-text-100">
            <li>
              <button
                type="button"
                phx-click="open_rename_modal"
                phx-value-id={@chat.id}
                phx-value-name={@chat.name}
                class="w-full text-left flex items-center px-4 py-2 hover:bg-bg-300 rounded transition"
              >
                <!-- Pen Icon -->
                <svg
                  class="w-4 h-4 mr-2"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15.232 5.232l3.536 3.536M9 13l6.586-6.586a2 2 0 112.828 2.828L11.828 15.828a2 2 0 01-2.828 0L9 13z"
                  />
                </svg>
                Rename
              </button>
            </li>
            <li>
            <button
            type="button"
            phx-click="open_delete_modal"
            phx-value-id={@chat.id}
            phx-value-name={@chat.name}
            class="w-full text-left flex items-center px-4 py-2 hover:bg-bg-300 rounded transition text-sm font-medium"
          >
            <svg
              class="w-4 h-4 mr-2 text-red-500"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M3 6h18M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2m2 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6h14zm-8 4v6m4-6v6"
              />
            </svg>
            <span class="text-red-500">Delete</span>
          </button>
            </li>
          </ul>
        </div>
      </div>
    </li>
    """
  end

end
