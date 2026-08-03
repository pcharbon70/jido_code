defmodule JidoCode.Knowledge.QueryCatalog do
  @moduledoc """
  Closed registry of reviewed product and operational graph questions.

  A source digest is part of each versioned definition, so changing query text
  without advancing or explicitly reviewing its version fails verification.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryDefinition
  alias JidoCode.Knowledge.QuerySource

  @version "1.0.0"
  @repository_version "1.1.0"
  @default_limits %{
    timeout_ms: 5_000,
    row_limit: 200,
    triple_limit: 500,
    byte_limit: 256_000,
    traversal_depth: 2,
    graph_limit: 20,
    parameter_collection_limit: 100
  }

  @spec version() :: String.t()
  def version, do: @version

  @spec repository_version() :: String.t()
  def repository_version, do: @repository_version

  @spec names() :: [atom()]
  def names, do: names(@version)

  @spec names(String.t()) :: [atom()]
  def names(version) when version in [@version, @repository_version],
    do: version |> definitions() |> Map.keys() |> Enum.sort()

  def names(_version), do: []

  @spec fetch(atom(), String.t()) :: {:ok, QueryDefinition.t()} | {:error, Error.t()}
  def fetch(name, version)
      when is_atom(name) and version in [@version, @repository_version] do
    case Map.fetch(definitions(version), name) do
      {:ok, definition} -> {:ok, definition}
      :error -> invalid()
    end
  end

  def fetch(_name, _version), do: invalid()

  @spec verify() :: :ok | {:error, Error.t()}
  def verify do
    definitions =
      [@version, @repository_version]
      |> Enum.flat_map(&(definitions(&1) |> Map.values()))

    if Enum.all?(definitions, &valid?/1),
      do: :ok,
      else: {:error, Error.new(:incompatible, :verify_query_catalog)}
  end

  @spec digest() :: String.t()
  def digest, do: digest(@version)

  @spec digest(String.t()) :: String.t()
  def digest(version) when version in [@version, @repository_version] do
    definitions(version)
    |> Enum.sort_by(fn {name, _definition} -> name end)
    |> Enum.map_join("\n", fn {name, definition} ->
      "#{name}:#{definition.version}:#{definition.source_digest}"
    end)
    |> QueryDefinition.source_digest()
  end

  defp definitions(version) do
    Map.new(specifications(version), fn specification ->
      source = QuerySource.fetch(specification.name)

      definition =
        struct!(QueryDefinition, %{
          name: specification.name,
          version: version,
          purpose: specification.purpose,
          form: specification.form,
          parameters: specification.parameters,
          capability: specification.capability,
          graph_families: specification.graph_families,
          completeness: specification.completeness,
          limits: Map.merge(@default_limits, Map.get(specification, :limits, %{})),
          decoder: specification.decoder,
          source: source,
          source_digest: QueryDefinition.source_digest(source),
          execution_class: specification.execution_class,
          compatibility_notes: specification.compatibility_notes,
          allow_graph_variable?: false
        })

      {definition.name, definition}
    end)
  end

  defp specifications(version) do
    graph = %{graph: %{type: :graph_iri, required: true}}
    resource = Map.put(graph, :resource, %{type: :resource_iri, required: true})

    base = [
      spec(
        :dataset_revision,
        :select,
        %{},
        :administrative,
        [:system],
        :scalar,
        "Read the authoritative substrate revision.",
        :diagnostic,
        :substrate
      ),
      spec(
        :graph_metadata,
        :select,
        graph,
        :administrative,
        GraphRegistry.families(),
        :table,
        "Describe registered graph lifecycle metadata.",
        :diagnostic,
        :declared
      ),
      spec(
        :ontology_compatibility,
        :select,
        graph,
        :ontology,
        [:ontology],
        :table,
        "Read ontology release compatibility facts.",
        :product,
        :declared
      ),
      spec(
        :command_receipt,
        :select,
        resource,
        :administrative,
        [:security_audit],
        :table,
        "Read a bounded command receipt projection.",
        :diagnostic,
        :declared
      ),
      spec(
        :audit_reference,
        :select,
        resource,
        :security,
        [:security_audit],
        :table,
        "Locate bounded audit references for a command.",
        :diagnostic,
        :declared
      ),
      spec(
        :graph_health,
        :ask,
        graph,
        :administrative,
        GraphRegistry.families(),
        :boolean,
        "Check that graph metadata is present.",
        :diagnostic,
        :declared
      ),
      spec(
        :resource_description,
        :construct,
        resource,
        :observation,
        GraphRegistry.families(),
        :subgraph,
        "Describe one resource in one authorized graph.",
        :product,
        :open_world
      ),
      spec(
        :semantic_neighborhood,
        :construct,
        resource,
        :observation,
        GraphRegistry.families(),
        :subgraph,
        "Read one bounded incoming and outgoing neighborhood.",
        :product,
        :open_world
      ),
      spec(
        :provenance_chain,
        :construct,
        resource,
        :evidence,
        GraphRegistry.families(),
        :subgraph,
        "Read a bounded provenance neighborhood.",
        :product,
        :open_world
      ),
      spec(
        :supporting_claims,
        :select,
        resource,
        :evidence,
        [:evidence, :memory],
        :table,
        "Read claims that support a resource.",
        :product,
        :open_world
      ),
      spec(
        :contradicting_claims,
        :select,
        resource,
        :evidence,
        [:evidence, :memory],
        :table,
        "Read claims that contradict a resource.",
        :product,
        :open_world
      ),
      spec(
        :supersession,
        :select,
        resource,
        :observation,
        GraphRegistry.families(),
        :table,
        "Read explicit supersession relationships.",
        :product,
        :open_world
      ),
      spec(
        :transition_endpoint,
        :select,
        resource,
        :control,
        [:repository_control, :run_attempt],
        :table,
        "Read the accepted transition-chain endpoint.",
        :product,
        :declared
      ),
      spec(
        :transition_history,
        :select,
        resource,
        :control,
        [:repository_control, :run_attempt],
        :timeline,
        "Read bounded accepted transition history.",
        :product,
        :declared
      ),
      spec(
        :temporal_as_of,
        :select,
        Map.put(resource, :instant, %{type: :datetime, required: true}),
        :observation,
        GraphRegistry.families(),
        :timeline,
        "Read assertions recorded by a transaction-time instant.",
        :product,
        :open_world
      ),
      spec(
        :graph_completeness,
        :select,
        resource,
        :observation,
        GraphRegistry.families(),
        :table,
        "Read declared closed-world coverage.",
        :product,
        :declared
      ),
      spec(
        :derived_graph_freshness,
        :select,
        graph,
        :observation,
        [:derived],
        :table,
        "Read derivation source-revision metadata.",
        :product,
        :declared
      )
    ]

    if version == @repository_version,
      do: base ++ repository_specifications(resource) ++ source_specifications(graph),
      else: base
  end

  defp repository_specifications(resource) do
    [
      spec(
        :repository_description,
        :construct,
        resource,
        :observation,
        [:factory_catalog],
        :subgraph,
        "Describe one conceptual repository in the factory catalog.",
        :product,
        :open_world
      ),
      spec(
        :locator_resolution,
        :select,
        resource,
        :observation,
        [:factory_catalog],
        :table,
        "Resolve conceptual repositories explicitly related to one locator.",
        :product,
        :open_world
      ),
      spec(
        :active_enrollment,
        :select,
        resource,
        :observation,
        [:factory_catalog],
        :table,
        "Read enrollment candidates for current-state resolution.",
        :product,
        :declared
      ),
      spec(
        :enrollment_history,
        :select,
        resource,
        :observation,
        [:factory_catalog],
        :timeline,
        "Read accepted enrollment transition history.",
        :product,
        :declared
      ),
      spec(
        :factory_repository_cohort,
        :select,
        resource,
        :observation,
        [:factory_catalog],
        :table,
        "Read bounded enrollment and repository members for one factory.",
        :product,
        :declared
      ),
      spec(
        :latest_complete_observation,
        :select,
        resource,
        :observation,
        [:observation_batch],
        :timeline,
        "Read a complete observation candidate at an enrollment scope.",
        :product,
        :declared
      ),
      spec(
        :observation_claim_history,
        :select,
        resource,
        :observation,
        [:observation_batch],
        :timeline,
        "Read sourced claim history about one repository resource.",
        :product,
        :open_world
      ),
      spec(
        :observation_contradictions,
        :select,
        resource,
        :observation,
        [:observation_batch],
        :table,
        "Read explicit contradiction relationships for one claim.",
        :product,
        :open_world
      ),
      spec(
        :provider_freshness,
        :select,
        resource,
        :observation,
        [:observation_batch],
        :timeline,
        "Read provider source and retrieval times at an enrollment scope.",
        :product,
        :declared
      ),
      spec(
        :repository_snapshot_description,
        :construct,
        resource,
        :observation,
        [:observation_batch],
        :subgraph,
        "Describe one exact repository snapshot anchor.",
        :product,
        :declared
      )
    ]
  end

  defp source_specifications(graph) do
    snapshot = Map.put(graph, :snapshot, %{type: :resource_iri, required: true})
    entity = Map.put(snapshot, :resource, %{type: :resource_iri, required: true})

    [
      spec(
        :snapshot_readiness_freshness,
        :select,
        snapshot,
        :observation,
        [:observation_batch],
        :timeline,
        "Read analyzer readiness and observation freshness for one exact snapshot.",
        :product,
        :declared
      ),
      spec(
        :source_modules,
        :select,
        snapshot,
        :source,
        [:source_revision],
        :table,
        "Read modules for one exact repository snapshot.",
        :product,
        :declared
      ),
      spec(
        :source_functions,
        :select,
        snapshot,
        :source,
        [:source_revision],
        :table,
        "Read functions for one exact repository snapshot.",
        :product,
        :declared
      ),
      spec(
        :source_otp_patterns,
        :select,
        snapshot,
        :source,
        [:source_revision],
        :table,
        "Read bounded OTP/runtime patterns for one exact repository snapshot.",
        :product,
        :declared
      ),
      spec(
        :source_dependencies,
        :select,
        snapshot,
        :source,
        [:source_revision],
        :table,
        "Read dependency relationships for one exact repository snapshot.",
        :product,
        :declared
      ),
      spec(
        :source_entity_neighborhood,
        :select,
        entity,
        :source,
        [:source_revision],
        :table,
        "Read a bounded incoming and outgoing neighborhood in one exact snapshot.",
        :product,
        :open_world
      ),
      spec(
        :source_impact,
        :select,
        entity,
        :source,
        [:source_revision],
        :table,
        "Read bounded code-relation impact around one exact source entity.",
        :product,
        :open_world
      )
    ]
  end

  defp spec(
         name,
         form,
         parameters,
         capability,
         graph_families,
         decoder,
         purpose,
         class,
         completeness
       ) do
    %{
      name: name,
      form: form,
      parameters: parameters,
      capability: capability,
      graph_families: graph_families,
      decoder: decoder,
      purpose: purpose,
      execution_class: class,
      completeness: completeness,
      compatibility_notes: "Initial Phase 5 contract; decoder fixtures are version-bound."
    }
  end

  defp valid?(definition) do
    definition.source_digest == QueryDefinition.source_digest(definition.source) and
      definition.version in [@version, @repository_version] and
      definition.form in [:select, :ask, :construct] and
      definition.compatibility_notes != "" and
      bounded_source?(definition)
  end

  defp bounded_source?(definition) do
    source = String.upcase(definition.source)

    not Regex.match?(~r/\b(INSERT|DELETE|LOAD|CLEAR|CREATE|DROP|COPY|MOVE|ADD|SERVICE)\b/, source) and
      (definition.form == :ask or String.contains?(source, "LIMIT")) and
      (definition.allow_graph_variable? or not Regex.match?(~r/GRAPH\s+\?/, source))
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :query_catalog)}
end
