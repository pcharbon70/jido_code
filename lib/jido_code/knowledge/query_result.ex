defmodule JidoCode.Knowledge.QueryResult do
  @moduledoc """
  Bounded, attributable result returned by the catalog read boundary.
  """

  @derive {Inspect,
           only: [
             :query_name,
             :query_version,
             :scope_iri,
             :dataset_revision,
             :graph_revisions,
             :ontology_version,
             :completeness,
             :freshness,
             :truncated?,
             :cursor,
             :warnings,
             :execution_class,
             :consistency,
             :data
           ]}
  @enforce_keys [
    :query_name,
    :query_version,
    :dataset_revision,
    :graph_revisions,
    :ontology_version,
    :completeness,
    :freshness,
    :truncated?,
    :cursor,
    :warnings,
    :execution_class,
    :consistency,
    :evaluated_at,
    :data
  ]
  defstruct @enforce_keys ++ [:scope_iri]

  @type t :: %__MODULE__{}
end
