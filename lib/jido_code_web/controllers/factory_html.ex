defmodule JidoCodeWeb.FactoryHTML do
  use JidoCodeWeb, :html

  import JidoCodeWeb.Components.ProductPage

  alias JidoCodeWeb.Components.Projection
  alias JidoCodeWeb.ReadProjectionView

  embed_templates "factory_html/*"
end
