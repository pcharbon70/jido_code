defmodule JidoCode.Identity.Membership do
  @moduledoc "Current named-human tenant/project membership and explanatory role record."

  @enforce_keys [
    :membership_ref,
    :subject_ref,
    :tenant_ref,
    :project_ref,
    :roles,
    :route_groups,
    :clearance,
    :valid_from,
    :valid_to,
    :revision,
    :status
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end
