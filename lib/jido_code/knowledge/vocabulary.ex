defmodule JidoCode.Knowledge.Vocabulary do
  @moduledoc """
  Fixed identifiers for substrate metadata that precedes the product ontology.
  """

  @system_graph "urn:jido-code:graph:system"
  @dataset "urn:jido-code:dataset"
  @dataset_class "urn:jido-code:vocab:SystemDataset"
  @commit_class "urn:jido-code:vocab:Commit"
  @graph_change_class "urn:jido-code:vocab:GraphChange"
  @restore_activity_class "urn:jido-code:vocab:RestoreActivity"
  @committed "urn:jido-code:vocab:Committed"
  @restored "urn:jido-code:vocab:Restored"
  @sync_durability "urn:jido-code:vocab:SyncDurability"
  @base "urn:jido-code:vocab:"

  @spec system_graph() :: String.t()
  def system_graph, do: @system_graph

  @spec dataset() :: String.t()
  def dataset, do: @dataset

  @spec dataset_class() :: String.t()
  def dataset_class, do: @dataset_class

  def commit_class, do: @commit_class
  def graph_change_class, do: @graph_change_class
  def restore_activity_class, do: @restore_activity_class
  def committed, do: @committed
  def restored, do: @restored
  def sync_durability, do: @sync_durability

  @spec predicate(atom()) :: String.t()
  def predicate(:store_schema_version), do: @base <> "storeSchemaVersion"
  def predicate(:backend_schema_version), do: @base <> "backendSchemaVersion"
  def predicate(:lineage), do: @base <> "lineage"
  def predicate(:dataset_revision), do: @base <> "datasetRevision"
  def predicate(:graph_revision), do: @base <> "graphRevision"
  def predicate(:status), do: @base <> "status"
  def predicate(:batch_digest), do: @base <> "batchDigest"
  def predicate(:prior_dataset_revision), do: @base <> "priorDatasetRevision"
  def predicate(:additions_count), do: @base <> "additionsCount"
  def predicate(:removals_count), do: @base <> "removalsCount"
  def predicate(:durability), do: @base <> "durability"
  def predicate(:graph_change), do: @base <> "graphChange"
  def predicate(:changed_graph), do: @base <> "changedGraph"
  def predicate(:prior_graph_revision), do: @base <> "priorGraphRevision"
  def predicate(:source_digest), do: @base <> "sourceDigest"
  def predicate(:request_fingerprint), do: @base <> "requestFingerprint"
  def predicate(:command_iri), do: @base <> "commandIri"
end
