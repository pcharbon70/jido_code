defmodule JidoCode.Knowledge.ProjectionEnvelope do
  @moduledoc """
  JSON-safe, attributable, bounded view over one exact catalog query result.
  """

  @derive {Inspect,
           only: [
             :projection_name,
             :projection_version,
             :shape,
             :actor_scope,
             :dataset_revision,
             :source_graph_revisions,
             :ontology_version,
             :query_name,
             :query_version,
             :generated_at,
             :completeness,
             :freshness,
             :truncated?,
             :warnings,
             :cursor,
             :consistency,
             :data
           ]}
  @enforce_keys [
    :projection_name,
    :projection_version,
    :shape,
    :actor_scope,
    :authorization_scope_digest,
    :dataset_revision,
    :source_graph_revisions,
    :ontology_version,
    :query_name,
    :query_version,
    :generated_at,
    :completeness,
    :freshness,
    :truncated?,
    :warnings,
    :cursor,
    :consistency,
    :parameters_digest,
    :data
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
end
