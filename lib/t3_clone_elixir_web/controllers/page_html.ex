defmodule T3CloneElixirWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use T3CloneElixirWeb, :html

  embed_templates "page_html/*"
end
