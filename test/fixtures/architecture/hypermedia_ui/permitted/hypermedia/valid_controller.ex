defmodule JidoCodeWeb.Hypermedia.ValidController do
  use JidoCodeWeb, :controller

  @hypermedia_contract %{
    kind: :command,
    interface: "hui.command_adapter.v1",
    authority_builder: "hui.identity_authority.v1",
    exact_resource_action: "project:refresh",
    query_catalog: "hui.product_projection.v1",
    concealment: :policy_outcome,
    redaction: :before_render,
    stable_dom: "project-status",
    csrf_origin: :required,
    command_gateway: "hui.command_adapter.v1",
    receipt: :durable,
    native_fallback: true,
    availability: :implementation_gated
  }

  def contract, do: @hypermedia_contract
end
