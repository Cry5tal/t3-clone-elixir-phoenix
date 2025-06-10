defmodule T3CloneElixirWeb.ModelLive.Show do
  use T3CloneElixirWeb, :live_view

  alias T3CloneElixir.Models

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:model, Models.get_model!(id))}
  end

  defp page_title(:show), do: "Show Model"
  defp page_title(:edit), do: "Edit Model"
end
