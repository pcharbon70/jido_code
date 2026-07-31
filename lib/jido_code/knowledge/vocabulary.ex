defmodule JidoCode.Knowledge.Vocabulary do
  @moduledoc """
  Fixed identifiers for substrate metadata that precedes the product ontology.
  """

  @system_graph "urn:jido-code:graph:system"
  @dataset "urn:jido-code:dataset"
  @dataset_class "urn:jido-code:vocab:SystemDataset"
  @base "urn:jido-code:vocab:"

  @spec system_graph() :: String.t()
  def system_graph, do: @system_graph

  @spec dataset() :: String.t()
  def dataset, do: @dataset

  @spec dataset_class() :: String.t()
  def dataset_class, do: @dataset_class

  @spec predicate(atom()) :: String.t()
  def predicate(:store_schema_version), do: @base <> "storeSchemaVersion"
  def predicate(:backend_schema_version), do: @base <> "backendSchemaVersion"
  def predicate(:lineage), do: @base <> "lineage"
  def predicate(:dataset_revision), do: @base <> "datasetRevision"
  def predicate(:graph_revision), do: @base <> "graphRevision"
end
