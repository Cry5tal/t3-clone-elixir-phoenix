defmodule T3CloneElixirWeb.ChatLive.Home do
  use T3CloneElixirWeb, :live_view


  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
