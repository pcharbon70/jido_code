defmodule JidoCode.Identity.RecoveryEvent do
  @moduledoc "Privacy-safe immutable account recovery evidence."

  @derive {Inspect,
           only: [
             :recovery_event_ref,
             :initiator_ref,
             :subject_ref,
             :method_class,
             :approval_refs,
             :outcome,
             :generation_before,
             :generation_after,
             :occurred_at
           ]}
  @enforce_keys [
    :recovery_event_ref,
    :initiator_ref,
    :subject_ref,
    :method_class,
    :approval_refs,
    :outcome,
    :generation_before,
    :generation_after,
    :occurred_at
  ]
  defstruct @enforce_keys
end
