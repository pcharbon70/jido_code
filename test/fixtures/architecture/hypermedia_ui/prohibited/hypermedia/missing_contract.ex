defmodule JidoCodeWeb.Hypermedia.MissingContractController do
  use JidoCodeWeb, :controller

  @hypermedia_contract %{
    kind: :command,
    interface: "hui.command_adapter.v1"
  }

  def contract, do: @hypermedia_contract
end
