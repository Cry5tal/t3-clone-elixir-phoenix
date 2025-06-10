defmodule T3CloneElixirWeb.ErrorJSONTest do
  use T3CloneElixirWeb.ConnCase, async: true

  test "renders 404" do
    assert T3CloneElixirWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert T3CloneElixirWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
