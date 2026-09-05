defmodule JidoCode.Identity.HumanDelegation do
  @moduledoc "Attenuated, non-transitive named-human delegation record."

  @enforce_keys [
    :delegation_ref,
    :issuer_subject_ref,
    :delegate_subject_ref,
    :resource_refs,
    :actions,
    :graph_families,
    :environment,
    :valid_from,
    :valid_to,
    :policy_revision,
    :delegation_revision,
    :attenuation_parent_ref,
    :revocation_generation,
    :minimum_assurance,
    :maximum_classification,
    :obligations,
    :status
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end
