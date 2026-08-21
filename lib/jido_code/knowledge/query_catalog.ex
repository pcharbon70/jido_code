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
  @control_loop_version "1.2.0"
  @governance_version "1.3.0"
  @reconciliation_version "1.4.0"
  @scheduling_version "1.5.0"
  @execution_version "1.6.0"
  @knowledge_version "1.7.0"
  @history_version "2.0.0"
  @experience_version "2.1.0"
  @procedure_version "2.2.0"
  @versions [
    @version,
    @repository_version,
    @control_loop_version,
    @governance_version,
    @reconciliation_version,
    @scheduling_version,
    @execution_version,
    @knowledge_version,
    @history_version,
    @experience_version,
    @procedure_version
  ]
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

  @spec control_loop_version() :: String.t()
  def control_loop_version, do: @control_loop_version

  @spec governance_version() :: String.t()
  def governance_version, do: @governance_version

  @spec reconciliation_version() :: String.t()
  def reconciliation_version, do: @reconciliation_version

  @spec scheduling_version() :: String.t()
  def scheduling_version, do: @scheduling_version

  @spec execution_version() :: String.t()
  def execution_version, do: @execution_version

  @spec knowledge_version() :: String.t()
  def knowledge_version, do: @knowledge_version

  @spec history_version() :: String.t()
  def history_version, do: @history_version

  @spec experience_version() :: String.t()
  def experience_version, do: @experience_version

  @spec procedure_version() :: String.t()
  def procedure_version, do: @procedure_version

  @spec names() :: [atom()]
  def names, do: names(@version)

  @spec names(String.t()) :: [atom()]
  def names(version) when version in @versions,
    do: version |> definitions() |> Map.keys() |> Enum.sort()

  def names(_version), do: []

  @spec fetch(atom(), String.t()) :: {:ok, QueryDefinition.t()} | {:error, Error.t()}
  def fetch(name, version) when is_atom(name) and version in @versions do
    case Map.fetch(definitions(version), name) do
      {:ok, definition} -> {:ok, definition}
      :error -> invalid()
    end
  end

  def fetch(_name, _version), do: invalid()

  @spec verify() :: :ok | {:error, Error.t()}
  def verify do
    definitions =
      @versions
      |> Enum.flat_map(&(definitions(&1) |> Map.values()))

    if Enum.all?(definitions, &valid?/1),
      do: :ok,
      else: {:error, Error.new(:incompatible, :verify_query_catalog)}
  end

  @spec digest() :: String.t()
  def digest, do: digest(@version)

  @spec digest(String.t()) :: String.t()
  def digest(version) when version in @versions do
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

    case version do
      @version ->
        base

      @repository_version ->
        base ++ repository_specifications(resource) ++ source_specifications(graph)

      @control_loop_version ->
        base ++
          repository_specifications(resource) ++
          source_specifications(graph) ++
          work_specifications(graph)

      @governance_version ->
        base ++
          repository_specifications(resource) ++
          source_specifications(graph) ++
          work_specifications(graph) ++
          governance_specifications(resource)

      @reconciliation_version ->
        base ++
          repository_specifications(resource) ++
          source_specifications(graph) ++
          work_specifications(graph) ++
          governance_specifications(resource) ++
          reconciliation_specifications(graph, resource)

      @scheduling_version ->
        base ++
          repository_specifications(resource) ++
          source_specifications(graph) ++
          work_specifications(graph) ++
          governance_specifications(resource) ++
          reconciliation_specifications(graph, resource) ++
          scheduling_specifications(graph, resource)

      @execution_version ->
        base ++
          repository_specifications(resource) ++
          source_specifications(graph) ++
          work_specifications(graph) ++
          governance_specifications(resource) ++
          reconciliation_specifications(graph, resource) ++
          scheduling_specifications(graph, resource) ++
          execution_boundary_specifications(resource)

      @knowledge_version ->
        base ++
          repository_specifications(resource) ++
          source_specifications(graph) ++
          work_specifications(graph) ++
          governance_specifications(resource) ++
          reconciliation_specifications(graph, resource) ++
          scheduling_specifications(graph, resource) ++
          execution_boundary_specifications(resource) ++
          evidence_specifications(resource) ++
          decision_specifications(resource) ++
          memory_specifications(resource) ++
          insight_specifications(resource)

      @history_version ->
        base ++
          repository_specifications(resource) ++
          source_specifications(graph) ++
          work_specifications(graph) ++
          governance_specifications(resource) ++
          reconciliation_specifications(graph, resource) ++
          scheduling_specifications(graph, resource) ++
          execution_boundary_specifications(resource) ++
          evidence_specifications(resource) ++
          decision_specifications(resource) ++
          memory_specifications(resource) ++
          insight_specifications(resource) ++
          history_specifications(resource)

      @experience_version ->
        base ++
          repository_specifications(resource) ++
          source_specifications(graph) ++
          work_specifications(graph) ++
          governance_specifications(resource) ++
          reconciliation_specifications(graph, resource) ++
          scheduling_specifications(graph, resource) ++
          execution_boundary_specifications(resource) ++
          evidence_specifications(resource) ++
          decision_specifications(resource) ++
          memory_specifications(resource) ++
          insight_specifications(resource) ++
          history_specifications(resource) ++
          experience_specifications(resource)

      @procedure_version ->
        base ++
          repository_specifications(resource) ++
          source_specifications(graph) ++
          work_specifications(graph) ++
          governance_specifications(resource) ++
          reconciliation_specifications(graph, resource) ++
          scheduling_specifications(graph, resource) ++
          execution_boundary_specifications(resource) ++
          evidence_specifications(resource) ++
          decision_specifications(resource) ++
          memory_specifications(resource) ++
          insight_specifications(resource) ++
          history_specifications(resource) ++
          experience_specifications(resource) ++
          artifact_claim_specifications(resource)
    end
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

  defp work_specifications(graph) do
    resource = Map.put(graph, :resource, %{type: :resource_iri, required: true})

    state =
      Map.put(graph, :state, %{
        type: :concept,
        required: true,
        values: %{
          proposed: "https://jido.run/ontology/concept/GoalProposed",
          active: "https://jido.run/ontology/concept/DesiredOutcomeActive",
          approved: "https://jido.run/ontology/concept/GoalApproved",
          eligible: "https://jido.run/ontology/concept/TaskEligible",
          blocked: "https://jido.run/ontology/concept/TaskBlocked",
          executing: "https://jido.run/ontology/concept/TaskExecuting",
          awaiting_decision: "https://jido.run/ontology/concept/TaskAwaitingDecision"
        }
      })

    [
      spec(
        :desired_outcome_description,
        :select,
        resource,
        :control,
        [:factory_policy],
        :table,
        "Read one desired proposition, constraints, policies, and validity.",
        :product,
        :declared
      ),
      spec(
        :goal_neighborhood,
        :select,
        resource,
        :control,
        [:repository_control],
        :table,
        "Read one bounded goal neighborhood with policy and addressed-resource edges.",
        :product,
        :open_world
      ),
      spec(
        :task_dag,
        :select,
        resource,
        :control,
        [:repository_control],
        :table,
        "Read tasks and dependency edges for one plan.",
        :product,
        :declared
      ),
      spec(
        :work_blockers,
        :select,
        resource,
        :control,
        [:repository_control],
        :table,
        "Read declared blockers and unsatisfied prerequisite edges for one task.",
        :product,
        :declared
      ),
      spec(
        :work_transition_history,
        :select,
        resource,
        :control,
        [:repository_control],
        :timeline,
        "Read the accepted transition history for one desired or work resource.",
        :product,
        :declared
      ),
      spec(
        :work_lens,
        :select,
        state,
        :control,
        [:repository_control],
        :table,
        "List bounded current transition endpoints for one controlled work state.",
        :product,
        :declared
      ),
      spec(
        :plan_context,
        :select,
        resource,
        :control,
        [:repository_control],
        :table,
        "Read exact source, policy, assumptions, effects, and planner context for one plan.",
        :product,
        :declared
      )
    ]
  end

  defp governance_specifications(resource) do
    [
      spec(
        :policy_description,
        :select,
        resource,
        :control,
        [:factory_policy],
        :table,
        "Read one versioned policy contract and evaluator binding.",
        :product,
        :declared
      ),
      spec(
        :governance_transition_history,
        :select,
        resource,
        :control,
        [:factory_policy, :repository_control],
        :timeline,
        "Read accepted policy, obligation, or capability lifecycle transitions.",
        :product,
        :declared
      ),
      spec(
        :cohort_definition,
        :select,
        resource,
        :control,
        [:factory_policy],
        :table,
        "Read one static or query-derived repository cohort definition.",
        :product,
        :declared
      ),
      spec(
        :cohort_membership,
        :select,
        resource,
        :control,
        [:derived],
        :table,
        "Read bounded derived membership and explanation paths for one cohort.",
        :product,
        :declared
      ),
      spec(
        :policy_applicability,
        :select,
        resource,
        :control,
        [:derived],
        :table,
        "Read applicability evidence bound to exact derived graph revisions.",
        :product,
        :declared
      ),
      spec(
        :obligation_description,
        :select,
        resource,
        :control,
        [:repository_control],
        :table,
        "Read one policy obligation, evidence, constraints, and source revisions.",
        :product,
        :declared
      ),
      spec(
        :capability_strict_view,
        :select,
        resource,
        :control,
        [:factory_policy],
        :table,
        "Read declared capability, availability, authorization, limits, and completeness.",
        :product,
        :declared
      ),
      spec(
        :capability_hierarchy,
        :select,
        resource,
        :control,
        [:derived],
        :table,
        "Read rebuildable capability classifications without granting authority.",
        :product,
        :declared
      )
    ]
  end

  defp reconciliation_specifications(graph, resource) do
    [
      spec(
        :active_reconciliation_scopes,
        :select,
        graph,
        :control,
        [:factory_catalog],
        :table,
        "Discover active enrollment scopes requiring reconciliation.",
        :product,
        :declared
      ),
      spec(
        :incomplete_reconciliations,
        :select,
        graph,
        :control,
        [:repository_control],
        :table,
        "Discover proposed or running reconciliation activities from graph state.",
        :product,
        :declared
      ),
      spec(
        :reconciliation_input,
        :select,
        resource,
        :control,
        [:repository_control],
        :table,
        "Read one exact reconciliation input package and its graph revisions.",
        :product,
        :declared
      ),
      spec(
        :reconciliation_explanation,
        :select,
        resource,
        :control,
        [:repository_control],
        :table,
        "Read bounded gaps, proposals, omissions, decisions, and explanation edges.",
        :product,
        :declared
      )
    ]
  end

  defp scheduling_specifications(graph, resource) do
    [
      spec(
        :eligible_work_candidates,
        :select,
        graph,
        :control,
        [:repository_control],
        :table,
        "Discover bounded task candidates whose accepted endpoint is eligible.",
        :product,
        :declared
      ),
      spec(
        :eligibility_context,
        :select,
        resource,
        :control,
        [:repository_control],
        :table,
        "Read one task's direct closed-world eligibility context for exact-revision evaluation.",
        :product,
        :declared
      ),
      spec(
        :lease_description,
        :select,
        resource,
        :control,
        [:repository_control],
        :table,
        "Read one execution lease, eligibility receipt, owner, capability, interval, and fence.",
        :product,
        :declared
      ),
      spec(
        :lease_transition_history,
        :select,
        resource,
        :control,
        [:repository_control],
        :timeline,
        "Read the accepted transition history for one execution lease.",
        :product,
        :declared
      )
    ]
  end

  defp execution_boundary_specifications(resource) do
    graph = Map.take(resource, [:graph])

    [
      spec(
        :execution_context_subject,
        :select,
        resource,
        :execution,
        [:factory_catalog, :factory_policy, :source_revision, :repository_control, :memory],
        :table,
        "Read one bounded subject used to assemble exact execution context.",
        :product,
        :declared
      ),
      spec(
        :interaction_session,
        :select,
        resource,
        :execution,
        [:repository_control, :run_attempt],
        :table,
        "Read one interaction session without runtime-private state.",
        :product,
        :declared
      ),
      spec(
        :interaction_timeline,
        :select,
        resource,
        :execution,
        [:repository_control, :run_attempt],
        :table,
        "Read a bounded chronological interaction timeline.",
        :product,
        :declared
      ),
      spec(
        :active_attempts,
        :select,
        graph,
        :execution,
        [:repository_control],
        :table,
        "Discover graph-visible execution attempts with direct lease-successor state.",
        :product,
        :declared
      ),
      spec(
        :attempt_by_task,
        :select,
        resource,
        :execution,
        [:repository_control],
        :table,
        "Read bounded attempt and lease lineage for one task.",
        :product,
        :declared
      ),
      spec(
        :attempt_status,
        :select,
        resource,
        :execution,
        [:run_attempt],
        :table,
        "Read bounded attempt identity, fence, runtime, snapshot, and context facts.",
        :product,
        :declared
      ),
      spec(
        :attempt_timeline,
        :select,
        resource,
        :execution,
        [:run_attempt],
        :timeline,
        "Read a bounded accepted attempt transition timeline.",
        :product,
        :declared
      ),
      spec(
        :tool_invocations,
        :select,
        resource,
        :execution,
        [:run_attempt],
        :timeline,
        "Read bounded tool invocation metadata and redacted output digests.",
        :product,
        :declared
      ),
      spec(
        :attempt_artifacts,
        :select,
        resource,
        :execution,
        [:run_attempt],
        :table,
        "Read content-addressed attempt artifact metadata without embedded content.",
        :product,
        :declared
      ),
      spec(
        :cancellation_retry_lineage,
        :select,
        resource,
        :execution,
        [:run_attempt],
        :table,
        "Read cancellation and retry lineage without provider-private state.",
        :product,
        :declared
      ),
      spec(
        :run_completeness,
        :select,
        resource,
        :execution,
        [:run_attempt],
        :table,
        "Read run graph lifecycle, provenance completeness, missing outputs, and limitations.",
        :product,
        :declared
      )
    ]
  end

  defp evidence_specifications(resource) do
    stale = Map.put(resource, :instant, %{type: :datetime, required: true})

    [
      spec(
        :evidence_by_goal,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read bounded evidence connected to one exact goal.",
        :product,
        :declared
      ),
      spec(
        :evidence_by_claim,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read bounded support and contradiction for one exact claim.",
        :product,
        :declared
      ),
      spec(
        :evidence_by_attempt,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read bounded evidence generated from one exact execution attempt.",
        :product,
        :declared
      ),
      spec(
        :evidence_by_artifact,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read bounded evidence that evaluated one content-addressed artifact.",
        :product,
        :declared
      ),
      spec(
        :verification_timeline,
        :select,
        resource,
        :evidence,
        [:evidence],
        :timeline,
        "Read verification activities and failed, skipped, or unknown checks.",
        :product,
        :declared
      ),
      spec(
        :evidence_support,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read supporting and contradictory evidence without collapsing either side.",
        :product,
        :declared
      ),
      spec(
        :evidence_sufficiency,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read exact evidence inputs for a pure sufficiency evaluation.",
        :product,
        :declared
      ),
      spec(
        :stale_evidence,
        :select,
        stale,
        :evidence,
        [:evidence],
        :timeline,
        "Read expired or superseded evidence candidates at one instant.",
        :product,
        :declared
      ),
      spec(
        :missing_evidence_requirements,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read recorded method and coverage facts used to explain missing requirements.",
        :product,
        :declared
      )
    ]
  end

  defp decision_specifications(resource) do
    [
      spec(
        :decision_by_goal,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read decisions that address one exact goal.",
        :product,
        :declared
      ),
      spec(
        :decision_by_claim,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read decisions that disposition one claim or its immutable successor.",
        :product,
        :declared
      ),
      spec(
        :decision_by_evidence,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read decisions whose sufficiency snapshot considered one evidence bundle.",
        :product,
        :declared
      ),
      spec(
        :decision_by_actor,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read bounded decisions attributed to one authority actor.",
        :product,
        :declared
      ),
      spec(
        :decision_waivers,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read explicit waiver decisions connected to one goal or claim.",
        :product,
        :declared
      ),
      spec(
        :decision_rejections,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read explicit rejection decisions connected to one goal or claim.",
        :product,
        :declared
      ),
      spec(
        :deferred_actions,
        :select,
        resource,
        :evidence,
        [:evidence],
        :table,
        "Read defer and request-more-evidence dispositions.",
        :product,
        :declared
      ),
      spec(
        :decision_supersession,
        :select,
        resource,
        :evidence,
        [:evidence],
        :timeline,
        "Read immutable decision supersession history.",
        :product,
        :declared
      ),
      spec(
        :satisfaction_path,
        :select,
        resource,
        :control,
        [:repository_control],
        :timeline,
        "Read accepted work transitions and their governing outcome stage.",
        :product,
        :declared
      ),
      spec(
        :decision_follow_up,
        :select,
        resource,
        :control,
        [:repository_control],
        :table,
        "Read lease-gated follow-up goals and tasks caused by one decision or goal.",
        :product,
        :declared
      )
    ]
  end

  defp memory_specifications(resource) do
    [
      spec(
        :knowledge_by_scope,
        :select,
        resource,
        :memory,
        [:memory],
        :table,
        "Read knowledge assertions for one exact repository or cohort scope.",
        :product,
        :declared
      ),
      spec(
        :knowledge_by_goal,
        :select,
        resource,
        :memory,
        [:memory],
        :table,
        "Read knowledge assertions explicitly related to one goal.",
        :product,
        :declared
      ),
      spec(
        :knowledge_by_task,
        :select,
        resource,
        :memory,
        [:memory],
        :table,
        "Read knowledge assertions explicitly related to one task.",
        :product,
        :declared
      ),
      spec(
        :knowledge_by_source,
        :select,
        resource,
        :memory,
        [:memory],
        :table,
        "Read knowledge assertions whose precise proposition names one source entity.",
        :product,
        :declared
      ),
      spec(
        :knowledge_by_policy,
        :select,
        resource,
        :memory,
        [:memory],
        :table,
        "Read knowledge assertions adopted under one policy version.",
        :product,
        :declared
      ),
      spec(
        :knowledge_by_classification,
        :select,
        resource,
        :memory,
        [:memory],
        :table,
        "Read knowledge assertions in one controlled classification.",
        :product,
        :declared
      ),
      spec(
        :knowledge_by_validity,
        :select,
        resource,
        :memory,
        [:memory],
        :table,
        "Read scope-bounded knowledge for deterministic validity filtering.",
        :product,
        :declared
      ),
      spec(
        :knowledge_neighborhood,
        :select,
        resource,
        :memory,
        [:memory],
        :table,
        "Read the bounded support, contradiction, and supersession neighborhood.",
        :product,
        :declared
      )
    ]
  end

  defp insight_specifications(resource) do
    [
      {:shared_dependencies, "Discover dependencies shared with other visible repositories."},
      {:repeated_findings, "Discover findings repeated across visible repositories."},
      {:repeated_failures, "Discover failures repeated across visible repositories."},
      {:policy_outcome_patterns,
       "Discover repeated policy outcomes across visible repositories."},
      {:reusable_evidence_methods,
       "Discover verification methods reused by visible repositories."},
      {:related_source_symbols, "Discover related source symbols across visible repositories."},
      {:applicable_lessons, "Discover accepted lessons applicable across visible repositories."}
    ]
    |> Enum.map(fn {name, purpose} ->
      spec(
        name,
        :select,
        resource,
        :reasoner,
        [:derived],
        :table,
        purpose,
        :product,
        :declared
      )
    end)
  end

  defp history_specifications(resource) do
    instant = Map.put(resource, :instant, %{type: :datetime, required: true})

    range =
      resource
      |> Map.put(:sequence_start, %{type: :non_negative_integer, required: true, max: 1_000_000})
      |> Map.put(:sequence_end, %{type: :non_negative_integer, required: true, max: 1_000_000})

    failure =
      instant
      |> Map.put(:signature, %{type: :literal, required: true, max_bytes: 512})

    [
      spec(
        :attempt_capture_completeness,
        :select,
        resource,
        :execution,
        [:run_event_segment],
        :table,
        "Read the explicit capture state of every expected body for one attempt.",
        :product,
        :declared
      ),
      spec(
        :task_attempt_lineage,
        :select,
        resource,
        :execution,
        [:repository_control],
        :timeline,
        "Read attempt, retry, lease, and outcome lineage for one task.",
        :product,
        :declared
      ),
      spec(
        :attempt_event_range,
        :select,
        range,
        :execution,
        [:run_event_segment],
        :timeline,
        "Read an exact bounded event range from one immutable attempt segment.",
        :product,
        :declared
      ),
      spec(
        :segment_event_range,
        :select,
        range,
        :execution,
        [:run_event_segment],
        :timeline,
        "Read one segment manifest and its exact bounded event range.",
        :product,
        :declared
      ),
      spec(
        :exact_failure_occurrences,
        :select,
        failure,
        :execution,
        [:run_event_segment],
        :timeline,
        "Read exact failure-signature occurrences no later than an effective-time cutoff.",
        :product,
        :declared
      ),
      spec(
        :issue_change_test_lineage,
        :select,
        instant,
        :evidence,
        [:evidence],
        :timeline,
        "Read source-linked issue, change, test, review, and incident lineage.",
        :product,
        :open_world
      ),
      spec(
        :incident_linkage,
        :select,
        instant,
        :evidence,
        [:evidence],
        :timeline,
        "Read bounded incident associations that existed by an effective-time cutoff.",
        :product,
        :open_world
      ),
      spec(
        :why_does_this_exist,
        :select,
        instant,
        :source,
        [:source_revision, :evidence],
        :timeline,
        "Trace a source resource to its issue, change, decision, evidence, and provenance anchors.",
        :product,
        :open_world
      )
    ]
  end

  defp experience_specifications(resource) do
    instant = Map.put(resource, :instant, %{type: :datetime, required: true})

    similar =
      instant
      |> Map.put(:signature, %{type: :literal, required: true, max_bytes: 64})
      |> Map.put(:framework, %{type: :literal, required: true, max_bytes: 128})
      |> Map.put(:framework_version, %{type: :literal, required: true, max_bytes: 128})
      |> Map.put(:environment, %{type: :literal, required: true, max_bytes: 128})
      |> Map.put(:dependency, %{type: :literal, required: true, max_bytes: 256})
      |> Map.put(:task_class, %{type: :literal, required: true, max_bytes: 64})
      |> Map.put(:plan_phase, %{type: :literal, required: true, max_bytes: 64})
      |> Map.put(:case_limit, %{type: :non_negative_integer, required: true, max: 10})

    [
      spec(
        :similar_resolved_cases,
        :select,
        similar,
        :experience_writer,
        [:experience],
        :table,
        "Read a few validated, chronologically eligible, applicable experience cases.",
        :product,
        :declared
      ),
      spec(
        :failed_interventions,
        :select,
        similar,
        :experience_writer,
        [:experience],
        :table,
        "Read applicable failed, reverted, flaky, infrastructure, abandoned, or ambiguous interventions.",
        :product,
        :declared
      ),
      spec(
        :experience_case_source_trace,
        :select,
        instant,
        :experience_writer,
        [:experience],
        :timeline,
        "Trace one experience case to its exact source events, artifacts, evidence, and manifest.",
        :product,
        :declared
      ),
      spec(
        :experience_case_contradictions,
        :select,
        instant,
        :experience_writer,
        [:experience],
        :table,
        "Read contradictions preserved against one experience case at an effective-time cutoff.",
        :product,
        :open_world
      ),
      spec(
        :experience_case_lifecycle,
        :select,
        instant,
        :experience_writer,
        [:experience],
        :timeline,
        "Read the append-only lifecycle of one experience case.",
        :product,
        :declared
      ),
      spec(
        :memory_use_outcomes,
        :select,
        instant,
        :experience_writer,
        [:experience],
        :timeline,
        "Read independent memory-use assessments for one exact case.",
        :product,
        :declared
      ),
      spec(
        :negative_transfer_cases,
        :select,
        instant,
        :experience_writer,
        [:experience],
        :table,
        "Read harmful or suspicious memory-use outcomes without rewriting their cases.",
        :product,
        :declared
      )
    ]
  end

  defp artifact_claim_specifications(resource) do
    instant = Map.put(resource, :instant, %{type: :datetime, required: true})

    [
      spec(
        :artifact_claims,
        :select,
        instant,
        :evidence,
        [:evidence],
        :table,
        "Read artifact claims with exact evidence strength and freshness history.",
        :product,
        :declared
      ),
      spec(
        :historical_test_risk,
        :select,
        instant,
        :evidence,
        [:evidence],
        :table,
        "Read historically failing or stale artifact claims without treating them as current.",
        :product,
        :declared
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
      definition.version in @versions and
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
