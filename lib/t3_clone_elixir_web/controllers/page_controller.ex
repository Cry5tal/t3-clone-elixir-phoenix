defmodule T3CloneElixirWeb.PageController do
  use T3CloneElixirWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    conn
      |>redirect(to: ~p"/chats")
      |> halt()
  end
end
