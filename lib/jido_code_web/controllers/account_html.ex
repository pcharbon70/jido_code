defmodule JidoCodeWeb.AccountHTML do
  use JidoCodeWeb, :html

  import JidoCodeWeb.Components.ProductPage

  def humanize(:unavailable), do: "Unavailable"
  def humanize(:configured), do: "Configured"

  embed_templates "account_html/*"
end
