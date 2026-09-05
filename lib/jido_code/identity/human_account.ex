defmodule JidoCode.Identity.HumanAccount do
  @moduledoc "A durable named-human identity record without credentials or grants."

  @derive {Inspect,
           only: [
             :subject_ref,
             :display_name,
             :login,
             :status,
             :account_generation,
             :policy_revision
           ]}
  @enforce_keys [
    :subject_ref,
    :display_name,
    :login,
    :status,
    :account_generation,
    :policy_revision,
    :recovery_state,
    :authenticator_refs,
    :inserted_at,
    :updated_at
  ]
  defstruct @enforce_keys

  @type status :: :active | :disabled | :recovery_pending
  @type t :: %__MODULE__{
          subject_ref: String.t(),
          display_name: String.t(),
          login: String.t(),
          status: status(),
          account_generation: pos_integer(),
          policy_revision: String.t(),
          recovery_state: :not_configured | :ready | :pending,
          authenticator_refs: [String.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
end
