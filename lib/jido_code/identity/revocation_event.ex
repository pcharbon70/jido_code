defmodule JidoCode.Identity.RevocationEvent do
  @moduledoc "Privacy-safe monotonic invalidation notification."

  @enforce_keys [
    :event_ref,
    :dimension,
    :subject_ref,
    :resource_ref,
    :prior_generation,
    :next_generation,
    :policy_revision,
    :occurred_at
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end
