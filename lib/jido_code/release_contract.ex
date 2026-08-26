defmodule JidoCode.ReleaseContract do
  @moduledoc "Exact compatibility manifest for startup, migration, and release acceptance."

  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Metadata
  alias JidoCode.Knowledge.Native
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.Reasoning.Profiles
  alias JidoCode.Knowledge.Validation.ShapeCatalog
  alias JidoCode.ManagedCodingRelease

  @application_version "0.1.0"
  @migration_contract "1.0.0"

  @spec manifest() :: map()
  def manifest do
    %{
      application: @application_version,
      ontology: Release.current_version(),
      shapes: ShapeCatalog.version(),
      query_catalog: QueryCatalog.knowledge_version(),
      query_digest: QueryCatalog.digest(QueryCatalog.knowledge_version()),
      reasoning_digest: reasoning_digest(),
      graph_registry: GraphRegistry.revision(),
      store_schema: Config.supported_schema_version(),
      backend_schema: Metadata.backend_schema_version(),
      runtime_contract: JidoCode.Runtime.Version.current(),
      managed_coding: ManagedCodingRelease.digest(),
      migration_contract: @migration_contract
    }
  end

  @spec digest() :: String.t()
  def digest do
    manifest()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec verify() :: :ok | {:error, Error.t()}
  def verify do
    with :ok <- Native.verify(),
         :ok <- GraphRegistry.verify(),
         {:ok, ontology} <- Release.verify(),
         true <- ontology.version == manifest().ontology,
         true <- ShapeCatalog.known_versions?(manifest().ontology, manifest().shapes),
         :ok <- QueryCatalog.verify(),
         :ok <- verify_reasoning_profiles(),
         :ok <- ManagedCodingRelease.verify(),
         true <- byte_size(digest()) == 64 do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:incompatible, :release_contract)}
    end
  end

  @spec migration_order() :: [atom()]
  def migration_order do
    [
      :application,
      :ontology,
      :shapes,
      :query_catalog,
      :reasoning,
      :backend_schema,
      :store_schema,
      :graphs,
      :derived_rebuild,
      :managed_coding,
      :acceptance
    ]
  end

  defp verify_reasoning_profiles do
    if Enum.all?(Profiles.names(), &match?({:ok, [_ | _]}, Profiles.rules(&1))),
      do: :ok,
      else: {:error, Error.new(:incompatible, :release_reasoning_profiles)}
  end

  defp reasoning_digest do
    Profiles.names()
    |> Enum.map(fn name ->
      {:ok, rules} = Profiles.rule_names(name)
      {name, rules}
    end)
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
