defmodule JidoCode.Knowledge do
  @moduledoc """
  Public command and health boundary for the authoritative knowledge substrate.

  It never exposes raw backend handles, write batches, or arbitrary SPARQL.
  """

  alias JidoCode.Knowledge.ChangeFeed
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Commands.PublishSourceGraph
  alias JidoCode.Knowledge.Control.DesiredOutcome
  alias JidoCode.Knowledge.Control.Eligibility
  alias JidoCode.Knowledge.Control.ExecutionLease
  alias JidoCode.Knowledge.Control.CapabilityRegistry
  alias JidoCode.Knowledge.Control.Cohort
  alias JidoCode.Knowledge.Control.GovernanceProjection
  alias JidoCode.Knowledge.Control.ModelAccessProfile
  alias JidoCode.Knowledge.Control.HarnessProfile
  alias JidoCode.Knowledge.Control.Obligation
  alias JidoCode.Knowledge.Control.Policy
  alias JidoCode.Knowledge.Control.ApprovalRequest
  alias JidoCode.Knowledge.Control.Reconciliation
  alias JidoCode.Knowledge.Control.ReconciliationPackage
  alias JidoCode.Knowledge.Control.ToolDefinition
  alias JidoCode.Knowledge.Control.ReconciliationProjection
  alias JidoCode.Knowledge.Control.WorkGraph
  alias JidoCode.Knowledge.Control.WorkProjection
  alias JidoCode.Knowledge.Execution.InteractionMessage
  alias JidoCode.Knowledge.Execution.InteractionProjection
  alias JidoCode.Knowledge.Execution.InteractionSession
  alias JidoCode.Knowledge.Execution.Attempt
  alias JidoCode.Knowledge.Execution.AttemptProjection
  alias JidoCode.Knowledge.Execution.Artifact
  alias JidoCode.Knowledge.Execution.ActionProposal
  alias JidoCode.Knowledge.Execution.ContextManifest
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.Execution.ImmutableEvent
  alias JidoCode.Knowledge.Execution.ModelInvocation
  alias JidoCode.Knowledge.Execution.ToolInvocation
  alias JidoCode.Knowledge.Execution.Provenance
  alias JidoCode.Knowledge.Execution.SegmentedRun
  alias JidoCode.Knowledge.Decision.GoalOutcome
  alias JidoCode.Knowledge.Decision.Projection, as: DecisionProjection
  alias JidoCode.Knowledge.Evidence.Bundle, as: EvidenceBundle
  alias JidoCode.Knowledge.Evidence.Graph, as: EvidenceGraph
  alias JidoCode.Knowledge.Evidence.Projection, as: EvidenceProjection
  alias JidoCode.Knowledge.Evidence.Sufficiency, as: EvidenceSufficiency
  alias JidoCode.Knowledge.Evidence.VerificationActivity
  alias JidoCode.Knowledge.Evidence.VerificationMethod
  alias JidoCode.Knowledge.Memory.Adoption, as: KnowledgeAdoption
  alias JidoCode.Knowledge.Memory.CaptureManifest
  alias JidoCode.Knowledge.Memory.ContentCapture
  alias JidoCode.Knowledge.Memory.Assertion, as: KnowledgeAssertion
  alias JidoCode.Knowledge.Memory.Evolution, as: KnowledgeEvolution
  alias JidoCode.Knowledge.Memory.Graph, as: MemoryGraph
  alias JidoCode.Knowledge.Memory.Retrieval, as: KnowledgeRetrieval
  alias JidoCode.Knowledge.Memory.CandidateAccess
  alias JidoCode.Knowledge.Memory.ArtifactClaim
  alias JidoCode.Knowledge.Memory.ArtifactClaimCommand
  alias JidoCode.Knowledge.Memory.ArtifactClaimTransition
  alias JidoCode.Knowledge.Memory.CaseRetrieval
  alias JidoCode.Knowledge.Memory.EvidencePacket
  alias JidoCode.Knowledge.Memory.ContentBenchmark
  alias JidoCode.Knowledge.Memory.EpisodeContent
  alias JidoCode.Knowledge.Memory.EpisodeContentCommand
  alias JidoCode.Knowledge.Memory.ExperienceCase
  alias JidoCode.Knowledge.Memory.ExperienceCommand
  alias JidoCode.Knowledge.Memory.ExperienceConstruction
  alias JidoCode.Knowledge.Memory.ExperienceQuarantine
  alias JidoCode.Knowledge.Memory.ExperienceSourceManifest
  alias JidoCode.Knowledge.Memory.ExperienceTransition
  alias JidoCode.Knowledge.Memory.ExperienceValidation
  alias JidoCode.Knowledge.Memory.MemoryUseAssessment
  alias JidoCode.Knowledge.Memory.NegativeTransfer
  alias JidoCode.Knowledge.Memory.ProcedureInduction
  alias JidoCode.Knowledge.Memory.ProcedureAuthority
  alias JidoCode.Knowledge.Memory.ProcedureCommand
  alias JidoCode.Knowledge.Memory.ProcedureRevision
  alias JidoCode.Knowledge.Memory.ProcedureRetrieval
  alias JidoCode.Knowledge.Memory.ProcedureTransition
  alias JidoCode.Knowledge.Memory.ProcedureUseObservation
  alias JidoCode.Knowledge.Memory.ProcedureValidation
  alias JidoCode.Knowledge.Memory.CandidateFactOrSummary
  alias JidoCode.Knowledge.Memory.RetrievalIndex
  alias JidoCode.Knowledge.Memory.RetrievalPipeline
  alias JidoCode.Knowledge.Memory.RetrievalActivity
  alias JidoCode.Knowledge.Memory.RetrievalRequest
  alias JidoCode.Knowledge.Memory.StateTransition, as: KnowledgeStateTransition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Learning.Feedback, as: LearningFeedback
  alias JidoCode.Knowledge.Learning.Insight, as: LearningInsight
  alias JidoCode.Knowledge.Reasoning.Profiles, as: ReasoningProfiles
  alias JidoCode.Knowledge.Reasoning.Service, as: ReasoningService
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Queries.ExecutionRecovery
  alias JidoCode.Knowledge.Projection
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.DerivedGraphManager
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Writer

  @cross_graph_insight_queries ~w[
    shared_dependencies repeated_findings repeated_failures policy_outcome_patterns
    reusable_evidence_methods related_source_symbols applicable_lessons
  ]a

  def execute(%CommandEnvelope{} = envelope, options \\ []), do: Writer.execute(envelope, options)

  def command_status(%CommandEnvelope{} = envelope, options \\ []),
    do: Writer.command_status(envelope, options)

  @doc "Returns whether a value is the accepted verification-evidence command contract."
  @spec verification_evidence_command?(term()) :: boolean()
  def verification_evidence_command?(%CommandEnvelope{
        command_type: "RecordVerificationEvidence",
        command_version: "1.7.0"
      }),
      do: true

  def verification_evidence_command?(_command), do: false

  @doc "Returns whether a value is the accepted external-observation command contract."
  @spec observation_command?(term()) :: boolean()
  def observation_command?(%CommandEnvelope{
        command_type: "RecordObservationBatch",
        command_version: "1.1.0"
      }),
      do: true

  def observation_command?(_command), do: false

  @doc "Returns whether a value is the accepted goal-outcome command contract."
  @spec goal_outcome_command?(term()) :: boolean()
  def goal_outcome_command?(%CommandEnvelope{
        command_type: "DecideGoalOutcome",
        command_version: "1.7.0"
      }),
      do: true

  def goal_outcome_command?(_command), do: false

  def subscribe_changes(scope_iri), do: ChangeFeed.subscribe(scope_iri)
  def bootstrap(attributes, options \\ []), do: Writer.bootstrap(attributes, options)

  def query(name, version, parameters, authority, scope_iri, options \\ [])

  def query(name, _version, _parameters, %AuthorityContext{}, _scope_iri, _options)
      when name in @cross_graph_insight_queries,
      do: {:error, Error.new(:unauthorized, :cross_graph_insight)}

  def query(name, version, parameters, %AuthorityContext{} = authority, scope_iri, options),
    do: QueryRunner.execute(name, version, parameters, authority, scope_iri, options)

  def reviewed_query(name, version), do: QueryCatalog.fetch(name, version)

  def discover_cross_graph_insights(
        name,
        version,
        parameters,
        authority,
        scope_iri,
        context,
        options \\ []
      )

  def discover_cross_graph_insights(
        name,
        version,
        parameters,
        %AuthorityContext{} = authority,
        scope_iri,
        context,
        options
      )
      when name in @cross_graph_insight_queries and is_map(context) and is_list(options) do
    options = Keyword.put(options, :evaluated_at, context[:evaluated_at])

    with {:ok, result} <-
           QueryRunner.execute(name, version, parameters, authority, scope_iri, options),
         {:ok, projection} <- LearningInsight.build(result, context) do
      {:ok, projection}
    end
  end

  def discover_cross_graph_insights(
        _name,
        _version,
        _parameters,
        _authority,
        _scope_iri,
        _context,
        _options
      ),
      do: {:error, Error.new(:invalid_input, :cross_graph_insight)}

  def project(result, %AuthorityContext{} = authority, scope_iri, options \\ []),
    do: Projection.build(result, authority, scope_iri, options)

  def publish_derived(attributes, options \\ []),
    do: DerivedGraphManager.publish(attributes, options)

  def source_publication_command(attributes, options \\ []),
    do: PublishSourceGraph.build(attributes, options)

  def desired_outcome(attributes), do: DesiredOutcome.new(attributes)

  def assert_desired_outcome(outcome, attributes, options \\ []),
    do: DesiredOutcome.assert_command(outcome, attributes, options)

  def propose_goal(attributes, options \\ []), do: WorkGraph.propose_goal(attributes, options)
  def propose_plan(attributes, options \\ []), do: WorkGraph.propose_plan(attributes, options)

  def adopt_plan(plan, attributes, options \\ []),
    do: WorkGraph.adopt_plan(plan, attributes, options)

  def project_work(result, context), do: WorkProjection.build(result, context)

  def policy(attributes), do: Policy.new(attributes)

  def propose_policy(policy, attributes, options \\ []),
    do: Policy.propose_command(policy, attributes, options)

  def resolve_policy_conflicts(policies), do: Policy.resolve_conflicts(policies)
  def repository_cohort(attributes), do: Cohort.new(attributes)

  def define_repository_cohort(cohort, attributes, options \\ []),
    do: Cohort.define_command(cohort, attributes, options)

  def publish_cohort_membership(cohort, memberships, attributes, options \\ []),
    do: Cohort.publish_membership(cohort, memberships, attributes, options)

  def policy_obligation(attributes), do: Obligation.new(attributes)

  def derive_policy_obligation(obligation, attributes, options \\ []),
    do: Obligation.derive_command(obligation, attributes, options)

  def capability(attributes), do: CapabilityRegistry.new(attributes)

  def register_capability(capability, attributes, options \\ []),
    do: CapabilityRegistry.register_command(capability, attributes, options)

  def project_governance(result, context), do: GovernanceProjection.build(result, context)
  def reconciliation_package(attributes), do: ReconciliationPackage.new(attributes)

  def reconcile(package, evaluations, attributes),
    do: Reconciliation.new(package, evaluations, attributes)

  def record_reconciliation(reconciliation, attributes, options \\ []),
    do: Reconciliation.record_command(reconciliation, attributes, options)

  def project_reconciliation(result, context), do: ReconciliationProjection.build(result, context)

  def evaluate_eligibility(context), do: Eligibility.evaluate(context)

  def acquire_execution_lease(eligibility, task_resolution, attributes, options \\ []),
    do: ExecutionLease.acquire_command(eligibility, task_resolution, attributes, options)

  def transition_execution_lease(
        lease,
        lease_resolution,
        task_resolution,
        attributes,
        options \\ []
      ),
      do:
        ExecutionLease.transition_command(
          lease,
          lease_resolution,
          task_resolution,
          attributes,
          options
        )

  def execution_lease_guard(lease, control_graph_iri, fence, at),
    do: ExecutionLease.execution_guard(lease, control_graph_iri, fence, at)

  def interaction_session(attributes), do: InteractionSession.new(attributes)

  def open_interaction_session(session, attributes, options \\ []),
    do: InteractionSession.open_command(session, attributes, options)

  def transition_interaction_session(session, resolution, attributes, options \\ []),
    do: InteractionSession.transition_command(session, resolution, attributes, options)

  def interaction_message(attributes), do: InteractionMessage.new(attributes)

  def record_interaction_message(message, resolution, attributes, options \\ []),
    do: InteractionMessage.record_command(message, resolution, attributes, options)

  def project_interaction(result, context), do: InteractionProjection.build(result, context)

  def execution_attempt(context, attributes), do: Attempt.new(context, attributes)

  def capture_manifest(attempt_iri, attributes),
    do: CaptureManifest.new(attempt_iri, attributes)

  def content_capture(manifest, body_iri, attributes),
    do: ContentCapture.new(manifest, body_iri, attributes)

  def open_event_segment(attempt_iri, attributes),
    do: EventSegment.open(attempt_iri, attributes)

  def start_segmented_execution_attempt(
        segment,
        opening_statements,
        attempt_targets,
        manifest,
        attributes,
        options \\ []
      ) do
    with {:ok, targets} <- CaptureManifest.attach_to_run_targets(manifest, attempt_targets) do
      EventSegment.start_attempt_command(
        segment,
        opening_statements,
        targets,
        manifest.iri,
        attributes,
        options
      )
    end
  end

  def record_execution_event(event, segment, attributes, options \\ []),
    do: ImmutableEvent.record_command(event, segment, attributes, options)

  def immutable_execution_event(authority, attributes),
    do: ImmutableEvent.new(authority, attributes)

  def close_event_segment(segment, closure, attributes, options \\ []),
    do: EventSegment.close_command(segment, closure, attributes, options)

  def finalize_segmented_run(attempt_iri, segments, manifest, attributes),
    do: SegmentedRun.finalize(attempt_iri, segments, manifest, attributes)

  def finalize_segmented_run_command(run, metadata, attributes, options \\ []),
    do: SegmentedRun.finalize_command(run, metadata, attributes, options)

  def recover_segmented_run(dataset, attempt_iri),
    do: SegmentedRun.recover(dataset, attempt_iri)

  def project_segmented_run(run), do: SegmentedRun.project(run)

  def start_execution_attempt(attempt, context, lease, resolutions, attributes, options \\ []),
    do: Attempt.start_command(attempt, context, lease, resolutions, attributes, options)

  def transition_execution_attempt(
        attempt,
        attempt_resolution,
        lease,
        task_resolution,
        attributes,
        options \\ []
      ),
      do:
        Attempt.transition_command(
          attempt,
          attempt_resolution,
          lease,
          task_resolution,
          attributes,
          options
        )

  def tool_invocation(attempt, attributes), do: ToolInvocation.new(attempt, attributes)

  def model_access_profile(attributes), do: ModelAccessProfile.new(attributes)

  def enroll_model_access_profile(profile, attributes, options \\ []),
    do: ModelAccessProfile.enroll_command(profile, attributes, options)

  def revoke_model_access_profile(profile, expected_generation, attributes, options \\ []),
    do: ModelAccessProfile.revoke_command(profile, expected_generation, attributes, options)

  def harness_profile(attributes), do: HarnessProfile.new(attributes)

  def adopt_harness_profile(profile, attributes, options \\ []),
    do: HarnessProfile.adopt_command(profile, attributes, options)

  def tool_definition(attributes), do: ToolDefinition.new(attributes)

  def publish_tool_definition(definition, attributes, options \\ []),
    do: ToolDefinition.publish_command(definition, attributes, options)

  def approval_request(attributes), do: ApprovalRequest.new(attributes)

  def create_approval_request(request, attributes, options \\ []),
    do: ApprovalRequest.create_command(request, attributes, options)

  def context_manifest(attempt_iri, attributes), do: ContextManifest.new(attempt_iri, attributes)

  def model_invocation(attempt, attributes), do: ModelInvocation.new(attempt, attributes)

  def start_model_invocation(invocation, attempt, resolution, lease, attributes, options \\ []),
    do: ModelInvocation.start_command(invocation, attempt, resolution, lease, attributes, options)

  def record_model_outcome(invocation, attempt, resolution, lease, attributes, options \\ []),
    do:
      ModelInvocation.outcome_command(invocation, attempt, resolution, lease, attributes, options)

  def action_proposal(attributes), do: ActionProposal.new(attributes)

  def start_tool_invocation(invocation, attempt, resolution, lease, attributes, options \\ []),
    do: ToolInvocation.start_command(invocation, attempt, resolution, lease, attributes, options)

  def record_tool_outcome(invocation, attempt, resolution, lease, attributes, options \\ []),
    do:
      ToolInvocation.outcome_command(invocation, attempt, resolution, lease, attributes, options)

  def execution_artifact(attributes), do: Artifact.new(attributes)

  def record_execution_artifact(artifact, attempt, resolution, lease, attributes, options \\ []),
    do: Artifact.record_command(artifact, attempt, resolution, lease, attributes, options)

  def verify_execution_artifact(artifact, options \\ []), do: Artifact.verify(artifact, options)

  def sandbox_instance_identity(attempt_iri, tier, image_digest, fencing_token)
      when tier in [:restricted_beam, :container_sandbox, :micro_vm, :dedicated_host] and
             is_binary(image_digest) and is_integer(fencing_token) and fencing_token > 0 do
    with :ok <- ResourceIdentity.validate(attempt_iri),
         true <- Regex.match?(~r/^sha256:[a-f0-9]{64}$/, image_digest) do
      ResourceIdentity.deterministic(
        :sandbox_instance,
        Enum.join(
          [attempt_iri, Atom.to_string(tier), image_digest, Integer.to_string(fencing_token)],
          "\n"
        )
      )
    else
      _invalid -> {:error, Error.new(:invalid_input, :sandbox_instance_identity)}
    end
  end

  def sandbox_instance_identity(_attempt_iri, _tier, _image_digest, _fencing_token),
    do: {:error, Error.new(:invalid_input, :sandbox_instance_identity)}

  def finalize_execution_run(attempt, resolution, lease, attributes, options \\ []),
    do: Provenance.finalize_command(attempt, resolution, lease, attributes, options)

  def project_execution_attempt(results, context), do: AttemptProjection.build(results, context)

  def execution_recovery_candidates(result, graph_iri),
    do: ExecutionRecovery.candidates(result, graph_iri)

  def verification_method(attributes), do: VerificationMethod.new(attributes)

  def verification_activity(method, attributes),
    do: VerificationActivity.new(method, attributes)

  def evidence_bundle(activity, evidence_graph_iri, attributes),
    do: EvidenceBundle.new(activity, evidence_graph_iri, attributes)

  def record_verification_evidence(bundle, attributes, options \\ []),
    do: EvidenceBundle.record_command(bundle, attributes, options)

  def evaluate_evidence_sufficiency(bundles, requirements, context),
    do: EvidenceSufficiency.evaluate(bundles, requirements, context)

  def project_evidence(result, context), do: EvidenceProjection.build(result, context)
  def project_evidence_sufficiency(assessment), do: EvidenceProjection.sufficiency(assessment)

  def evidence_graph_identity(repository_iri), do: EvidenceGraph.evidence_graph(repository_iri)

  def goal_outcome_decision(assessment, bundles, goal_resolution, task_resolution, attributes),
    do: GoalOutcome.new(assessment, bundles, goal_resolution, task_resolution, attributes)

  def decide_goal_outcome(decision, attributes, options \\ []),
    do: GoalOutcome.record_command(decision, attributes, options)

  def project_decision(result, context), do: DecisionProjection.build(result, context)

  def knowledge_assertion(decision, source_claims, attributes),
    do: KnowledgeAssertion.new(decision, source_claims, attributes)

  def adopt_knowledge(assertion, decision, attributes, options \\ []),
    do: KnowledgeAdoption.record_command(assertion, decision, attributes, options)

  def evolve_knowledge(assertion, resolution, replacement, attributes, options \\ []),
    do:
      KnowledgeEvolution.record_command(
        assertion,
        resolution,
        replacement,
        attributes,
        options
      )

  def resolve_knowledge_state(transitions), do: KnowledgeStateTransition.resolve(transitions)
  def retrieve_knowledge(result, context), do: KnowledgeRetrieval.build(result, context)
  def memory_retrieval_request(attributes), do: RetrievalRequest.new(attributes)
  def memory_evidence_packet?(%EvidencePacket{}), do: true
  def memory_evidence_packet?(_value), do: false
  def experience_case(attributes), do: ExperienceCase.new(attributes)
  def experience_source_manifest(attributes), do: ExperienceSourceManifest.new(attributes)
  def experience_transition(attributes), do: ExperienceTransition.new(attributes)
  def resolve_experience_lifecycle(transitions), do: ExperienceTransition.resolve(transitions)

  def construct_experience_case(run, evidence, attributes),
    do: ExperienceConstruction.build(run, evidence, attributes)

  def experience_candidate_summary(case_iri, manifest, attributes),
    do: CandidateFactOrSummary.new(case_iri, manifest, attributes)

  def quarantine_experience_case(experience, summary, manifest, context),
    do: ExperienceQuarantine.evaluate(experience, summary, manifest, context)

  def validate_experience_case(experience, summary, manifest, report, attributes),
    do: ExperienceValidation.validate(experience, summary, manifest, report, attributes)

  def propose_experience_case(experience, manifest, summary, report, attributes, options \\ []),
    do: ExperienceCommand.propose(experience, manifest, summary, report, attributes, options)

  def quarantine_experience_case_command(experience, report, attributes, options \\ []),
    do: ExperienceCommand.quarantine(experience, report, attributes, options)

  def transition_experience_case(experience, transition, attributes, options \\ []),
    do: ExperienceCommand.transition(experience, transition, attributes, options)

  def retrieve_experience_cases(request, candidates),
    do: CaseRetrieval.retrieve(request, candidates)

  def evaluate_experience_retrieval(result, outcome),
    do: CaseRetrieval.evaluate(result, outcome)

  def memory_use_assessment(attributes), do: MemoryUseAssessment.new(attributes)

  def record_memory_use_assessment(assessment, graph, revision, attributes, options \\ []),
    do: MemoryUseAssessment.record_command(assessment, graph, revision, attributes, options)

  def evaluate_negative_transfer(experience, assessments, transition, attributes),
    do: NegativeTransfer.evaluate(experience, assessments, transition, attributes)

  def artifact_claim(attributes), do: ArtifactClaim.new(attributes)
  def artifact_claim_transition(attributes), do: ArtifactClaimTransition.new(attributes)

  def resolve_artifact_claim_lifecycle(transitions),
    do: ArtifactClaimTransition.resolve(transitions)

  def artifact_claim_current?(claim, current, transitions \\ nil),
    do: ArtifactClaim.current?(claim, current, transitions)

  def evaluate_artifact_claim_drift(claim, current, transition, attributes),
    do: ArtifactClaim.drift_transition(claim, current, transition, attributes)

  def record_artifact_claim(claim, graph, revision, attributes, options \\ []),
    do: ArtifactClaimCommand.record(claim, graph, revision, attributes, options)

  def transition_artifact_claim(claim, transition, graph, revision, attributes, options \\ []),
    do: ArtifactClaimCommand.transition(claim, transition, graph, revision, attributes, options)

  def propose_procedure(attributes, context), do: ProcedureInduction.propose(attributes, context)

  def quarantine_procedure(procedure, context),
    do: ProcedureInduction.quarantine(procedure, context)

  def procedure_revision(attributes), do: ProcedureRevision.new(attributes)
  def procedure_transition(attributes), do: ProcedureTransition.new(attributes)
  def resolve_procedure_lifecycle(transitions), do: ProcedureTransition.resolve(transitions)

  def validate_procedure(procedure, report, executions, attributes),
    do: ProcedureValidation.validate(procedure, report, executions, attributes)

  def evaluate_procedure_drift(procedure, current, transition, attributes),
    do: ProcedureValidation.drift(procedure, current, transition, attributes)

  def procedure_knowledge_proposition(procedure, validation, attributes),
    do: ProcedureAuthority.knowledge_proposition(procedure, validation, attributes)

  def procedure_policy_representation(procedure, validation, attributes),
    do: ProcedureAuthority.sanitized_policy(procedure, validation, attributes)

  def record_procedure_proposal(procedure, graph, revision, report, attributes, options \\ []),
    do: ProcedureCommand.propose(procedure, graph, revision, report, attributes, options)

  def transition_procedure(procedure, transition, graph, revision, attributes, options \\ []),
    do: ProcedureCommand.transition(procedure, transition, graph, revision, attributes, options)

  def retrieve_procedures(request, candidates),
    do: ProcedureRetrieval.retrieve(request, candidates)

  def evaluate_procedure_retrieval(result, baseline),
    do: ProcedureRetrieval.evaluate(result, baseline)

  def procedure_use_observation(attributes), do: ProcedureUseObservation.new(attributes)

  def record_procedure_use(observation, graph, revision, attributes, options \\ []),
    do: ProcedureUseObservation.record(observation, graph, revision, attributes, options)

  def episode_content(attributes), do: EpisodeContent.new(attributes)

  def store_episode_content(content, attributes, options \\ []),
    do: EpisodeContentCommand.store(content, attributes, options)

  def measure_content_benchmark(baseline, measured, integrity),
    do: ContentBenchmark.measure(baseline, measured, integrity)

  def decide_content_storage(metrics, signer), do: ContentBenchmark.decide(metrics, signer)

  def generate_memory_candidates(request, channel, generator),
    do: CandidateAccess.generate(request, channel, generator)

  def build_memory_retrieval_index(request, channel, generator),
    do: RetrievalIndex.build(request, channel, generator)

  def lookup_memory_retrieval_index(index, request),
    do: RetrievalIndex.lookup(index, request)

  def retrieve_memory(request, generators),
    do: RetrievalPipeline.retrieve(request, generators)

  def start_memory_retrieval(request, occurred_at),
    do: RetrievalActivity.start(request, occurred_at)

  def finish_memory_retrieval(start, attributes),
    do: RetrievalActivity.outcome(start, attributes)

  def record_memory_retrieval(activity, segment, attributes, options \\ []),
    do: RetrievalActivity.record_command(activity, segment, attributes, options)

  def memory_graph_identity(repository_iri), do: MemoryGraph.memory_graph(repository_iri)

  def reasoning_profiles, do: ReasoningProfiles.names()

  def materialize_reasoning(attributes, options \\ []),
    do: ReasoningService.materialize(attributes, options)

  def project_cross_graph_insight(result, context), do: LearningInsight.build(result, context)

  def build_learning_inputs(retrieval, reasoning, attributes),
    do: LearningFeedback.build_inputs(retrieval, reasoning, attributes)

  def learning_feedback_stale?(package, current_revisions),
    do: LearningFeedback.stale?(package, current_revisions)

  def learning_measurement(attributes), do: LearningFeedback.measurement(attributes)

  def repository_locator_identity(provider, external_id),
    do: ResourceIdentity.repository_locator(provider, external_id)

  def repository_address(provider, owner, name),
    do: ResourceIdentity.repository_locator(provider, owner, name)

  def provider_identity(provider), do: ResourceIdentity.provider_host(provider)

  def provider_object_identity(locator_iri, kind, external_id),
    do: ResourceIdentity.provider_object(locator_iri, kind, external_id)

  def git_object_identity(algorithm, value), do: ResourceIdentity.git_object(algorithm, value)

  def repository_snapshot_identity(repository_iri, algorithm, tree_digest),
    do: ResourceIdentity.repository_snapshot(repository_iri, algorithm, tree_digest)

  def source_artifact_identity(snapshot_iri, path, digest),
    do: ResourceIdentity.source_artifact(snapshot_iri, path, digest)

  def code_symbol_identity(snapshot_iri, kind, name),
    do: ResourceIdentity.code_symbol(snapshot_iri, kind, name)

  def source_analysis_identity(snapshot_iri, analyzer_version, configuration_digest),
    do: ResourceIdentity.source_analysis(snapshot_iri, analyzer_version, configuration_digest)

  def source_graph_identity(repository_iri, snapshot_iri),
    do:
      GraphRegistry.graph_iri(:source_revision, %{
        repository: repository_iri,
        revision: snapshot_iri
      })

  def run_graph_identity(attempt_iri), do: ExecutionGraph.run_graph(attempt_iri)

  def validate_resource_identity(iri), do: ResourceIdentity.validate(iri)
  def validate_graph_identity(iri), do: GraphRegistry.identify(iri)

  def health, do: Readiness.snapshot()
  def ready?, do: health() |> JidoCode.Knowledge.Health.ready?()
  def gate(operation) when is_atom(operation), do: Readiness.gate(Readiness, operation)
  def store_summary, do: StoreServer.summary()
end
