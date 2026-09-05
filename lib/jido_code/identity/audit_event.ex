defmodule JidoCode.Identity.AuditEvent do
  @moduledoc "Privacy-safe immutable identity audit evidence."

  @derive {Inspect,
           only: [
             :audit_event_ref,
             :actor_ref,
             :action_ref,
             :object_ref,
             :outcome,
             :policy_revision,
             :receipt_ref,
             :occurred_at
           ]}
  @enforce_keys [
    :audit_event_ref,
    :actor_ref,
    :action_ref,
    :object_ref,
    :outcome,
    :policy_revision,
    :receipt_ref,
    :occurred_at
  ]
  defstruct @enforce_keys
end
