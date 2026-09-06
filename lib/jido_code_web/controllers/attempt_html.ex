defmodule JidoCodeWeb.AttemptHTML do
  use JidoCodeWeb, :html

  import JidoCodeWeb.Components.ProductPage

  alias JidoCodeWeb.Components.Projection
  alias JidoCodeWeb.Components.ReadWorkspace
  alias JidoCodeWeb.ReadProjectionView

  embed_templates "attempt_html/*"
end
