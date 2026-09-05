defmodule JidoCode.Identity.AuthorizationResult do
  @moduledoc "Transient HUI identity/scope/authority decision; never persisted as a grant."

  @enforce_keys [
    :decision,
    :safe_reason,
    :current_scope,
    :product_identity,
    :authority_context,
    :membership_explanations,
    :exact_grant_ref,
    :delegation_ref,
    :obligations,
    :policy_revision,
    :graph_revisions,
    :audit_correlation_ref,
    :concealment,
    :redaction
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end
