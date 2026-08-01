defmodule JidoCode.Knowledge.ConsistencyReceipt do
  @moduledoc false

  @derive {Inspect,
           only: [
             :mode,
             :status,
             :dataset_revision,
             :graph_revisions,
             :ontology_version,
             :complete_graphs,
             :valid_at,
             :valid_interval,
             :derived_rule_set_revision,
             :gaps,
             :constraint_digest
           ]}
  @enforce_keys [
    :mode,
    :status,
    :dataset_revision,
    :graph_revisions,
    :ontology_version,
    :complete_graphs,
    :valid_at,
    :valid_interval,
    :derived_rule_set_revision,
    :gaps,
    :constraint_digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
end
