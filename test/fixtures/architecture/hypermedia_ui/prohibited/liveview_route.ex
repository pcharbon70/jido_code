defmodule JidoCodeWeb.ArchitectureFixture.Router do
  use JidoCodeWeb, :router

  def routes do
    live "/new-product", NewProductLive
  end
end
