defmodule JidoCode.Factory.Fleet.Result do
  @moduledoc "Transient, explainable result of one graph-derived fleet admission cycle."

  @enforce_keys [:selected, :deferred, :policy_revision]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          selected: [map()],
          deferred: [map()],
          policy_revision: non_neg_integer() | nil
        }
end
