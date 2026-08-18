defmodule JidoCode.Factory.Approval.Outcome do
  @moduledoc "Bounded result of one approved invocation or redelivery."

  @enforce_keys [
    :approval_iri,
    :invocation_iri,
    :status,
    :terminal?,
    :effect_dispatched?,
    :consumption_receipt,
    :terminal_receipt,
    :reconciliation_receipt,
    :redelivery_allowed?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
end
