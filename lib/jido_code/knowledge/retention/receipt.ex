defmodule JidoCode.Knowledge.Retention.Receipt do
  @moduledoc "Bounded result of a checkpointed, validated retention activity."

  @enforce_keys [
    :plan_id,
    :activity_iri,
    :checksum,
    :affected_graph_count,
    :archived_resource_count,
    :erased_resource_count,
    :removal_count,
    :dataset_revision,
    :checkpoint_artifact_id,
    :integrity_status,
    :rebuild_graphs
  ]
  defstruct @enforce_keys
end
