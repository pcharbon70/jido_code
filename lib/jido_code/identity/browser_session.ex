defmodule JidoCode.Identity.BrowserSession do
  @moduledoc "Server-side browser session state; cookies contain only its opaque reference."

  @derive {Inspect,
           only: [
             :session_ref,
             :subject_ref,
             :issued_at,
             :last_seen_at,
             :last_authenticated_at,
             :assurance,
             :session_generation,
             :account_generation,
             :policy_revision,
             :hard_expires_at,
             :idle_expires_at,
             :status
           ]}
  @enforce_keys [
    :session_ref,
    :subject_ref,
    :issued_at,
    :last_seen_at,
    :last_authenticated_at,
    :assurance,
    :nonce,
    :session_generation,
    :account_generation,
    :policy_revision,
    :hard_expires_at,
    :idle_expires_at,
    :status,
    :revoked_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          session_ref: String.t(),
          subject_ref: String.t(),
          issued_at: DateTime.t(),
          last_seen_at: DateTime.t(),
          last_authenticated_at: DateTime.t(),
          assurance: :baseline | :phishing_resistant | :action_bound_step_up,
          nonce: String.t(),
          session_generation: pos_integer(),
          account_generation: pos_integer(),
          policy_revision: String.t(),
          hard_expires_at: DateTime.t(),
          idle_expires_at: DateTime.t(),
          status: :active | :revoked | :expired,
          revoked_at: DateTime.t() | nil
        }
end
