defmodule JidoCode.Identity.Resource do
  @moduledoc "Server-owned opaque reference to one exact product resource scope."

  @enforce_keys [
    :resource_ref,
    :kind,
    :iri,
    :tenant_ref,
    :project_ref,
    :parent_ref,
    :graph_scope_iri,
    :classification,
    :environment,
    :lifecycle,
    :registry_revision
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end
