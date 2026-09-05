defmodule JidoCode.Identity.Authenticator do
  @moduledoc "A public authenticator description; verifier material is never exposed."

  @derive {Inspect,
           only: [
             :authenticator_ref,
             :subject_ref,
             :kind,
             :phishing_resistant,
             :status,
             :revision
           ]}
  @enforce_keys [
    :authenticator_ref,
    :subject_ref,
    :kind,
    :phishing_resistant,
    :enrolled_at,
    :verified_at,
    :revoked_at,
    :status,
    :revision
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          authenticator_ref: String.t(),
          subject_ref: String.t(),
          kind: :local_password,
          phishing_resistant: boolean(),
          enrolled_at: DateTime.t(),
          verified_at: DateTime.t(),
          revoked_at: DateTime.t() | nil,
          status: :active | :revoked,
          revision: pos_integer()
        }
end
