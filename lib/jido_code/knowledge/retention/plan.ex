defmodule JidoCode.Knowledge.Retention.Plan do
  @moduledoc "Immutable, transient execution plan for one bounded retention activity."

  @enforce_keys [
    :id,
    :activity_iri,
    :actor_iri,
    :audit_graph_iri,
    :dataset_revision,
    :graph_revisions,
    :retain,
    :archive,
    :remove,
    :erase,
    :rebuild_graphs,
    :removals,
    :audit_additions,
    :affected_graphs,
    :checksum,
    :rationale,
    :validation_report_iri
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          activity_iri: String.t(),
          actor_iri: String.t(),
          audit_graph_iri: String.t(),
          dataset_revision: non_neg_integer(),
          graph_revisions: %{String.t() => non_neg_integer()},
          retain: [String.t()],
          archive: [String.t()],
          remove: [String.t()],
          erase: [String.t()],
          rebuild_graphs: [String.t()],
          removals: [RDF.Quad.t()],
          audit_additions: [RDF.Quad.t()],
          affected_graphs: [String.t()],
          checksum: String.t(),
          rationale: String.t(),
          validation_report_iri: String.t()
        }
end
