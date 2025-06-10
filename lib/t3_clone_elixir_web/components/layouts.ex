defmodule T3CloneElixirWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use T3CloneElixirWeb, :controller` and
  `use T3CloneElixirWeb, :live_view`.
  """
  use T3CloneElixirWeb, :html

  embed_templates "layouts/*"
end
