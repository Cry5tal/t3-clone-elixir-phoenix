defmodule T3CloneElixirWeb.FallbackController do
  @moduledoc """
  Handles fallback for routes not matched (404).
  """
  use T3CloneElixirWeb, :controller

  # Renders the custom 404 page
  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_view(T3CloneElixirWeb.ErrorHTML)
    |> render("404.html", assigns: %{})
  end
end
