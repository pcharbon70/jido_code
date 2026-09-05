defmodule JidoCode.Identity.AuthenticationEvent do
  @moduledoc "Privacy-safe immutable authentication evidence."

  @derive {Inspect,
           only: [
             :authentication_event_ref,
             :subject_ref,
             :method_class,
             :assurance,
             :outcome,
             :occurred_at,
             :correlation_ref,
             :policy_revision
           ]}
  @enforce_keys [
    :authentication_event_ref,
    :subject_ref,
    :method_class,
    :assurance,
    :outcome,
    :occurred_at,
    :correlation_ref,
    :policy_revision
  ]
  defstruct @enforce_keys
end
