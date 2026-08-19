defmodule JidoCode.Knowledge.Validation.ShapeCatalog do
  @moduledoc false

  @version "1.1.0"
  @ontology_version "1.1.0"
  @known_versions MapSet.new([{"1.0.0", "1.0.0"}, {@ontology_version, @version}])
  @jf "https://jido.run/ontology/factory#"

  @allowed_classes %{
    ontology: :schema,
    factory_catalog: ~w[
      RepositoryFactory SoftwareRepository RepositoryLocator ManagementEnrollment Actor Agent Scope
    ],
    factory_policy: ~w[
      DesiredOutcome Constraint Policy Obligation Capability AuthorizationGrant Delegation Scope
      Decision StateTransition RepositoryCohort GraphRevisionReference CredentialReference
      ModelAccessProfile HarnessProfile ToolDefinitionRevision
    ],
    observation_batch: ~w[
      ObservationActivity ObservationBatch RepositorySnapshot SourceArtifact Claim Finding
      Contradiction AssessmentActivity CompletenessAssertion
    ],
    source_revision: ~w[RepositorySnapshot SourceArtifact CodeSymbol Scope MigrationActivity],
    repository_control: ~w[
      Goal Constraint Obligation Task Plan Capability Lease StateTransition Decision MigrationActivity
      GraphRevisionReference ReconciliationActivity ReconciliationInput Gap ControlProposal
      EligibilityReceipt InteractionSession Message Instruction DecisionFollowUp ApprovalRequest
    ],
    run_attempt: ~w[
      ExecutionAttempt ExecutionContext ToolInvocation Patch VerificationActivity Artifact
      InteractionSession Message Instruction StateTransition Decision GraphRevisionReference
      MigrationActivity Finding ContextManifest ModelInvocation ActionProposal SandboxInstance
      CaptureManifest
    ],
    run_event_segment: ~w[
      SegmentManifest ContentCapture ToolInvocation Artifact ContextManifest ModelInvocation
      ActionProposal Finding ModelInvocationOutcome ToolInvocationOutcome StateTransition Message
      SandboxEvent CancellationObservation RetryObservation TerminalObservation
      ProviderObservation LifecycleObservation
    ],
    experience: ~w[
      ExperienceCase ProcedureRevision ArtifactClaim RetrievalActivity MemoryUseAssessment
      GraphRevisionReference MigrationActivity
    ],
    content_lifecycle: ~w[
      ContentLifecycleActivity ContentAccessPermit GraphRevisionReference MigrationActivity
    ],
    episode_content: ~w[
      EpisodeContent ContentChunk
    ],
    evidence: ~w[
      EvidenceBundle Decision Claim Finding Contradiction VerificationMethod VerificationActivity
      VerificationCheck EvidenceSufficiency GraphRevisionReference MigrationActivity
    ],
    memory: ~w[
      KnowledgeAssertion Claim AdoptionActivity KnowledgeStateTransition
      KnowledgeEvolutionActivity Contradiction MigrationActivity GraphRevisionReference
    ],
    security_audit: ~w[
      AuthorizationGrant CredentialReference ValidationReport ValidationResult MigrationActivity
    ],
    derived: ~w[
      Claim Finding Contradiction GraphRevisionReference ValidationReport ValidationResult
      CohortMembership CapabilityClassification ReasoningActivity ReasoningValidationReport
    ]
  }

  @spec version() :: String.t()
  def version, do: @version

  @spec ontology_version() :: String.t()
  def ontology_version, do: @ontology_version

  @spec known_versions?(String.t(), String.t()) :: boolean()
  def known_versions?(ontology_version, shape_version) do
    MapSet.member?(@known_versions, {ontology_version, shape_version})
  end

  @spec allowed_class?(atom(), String.t()) :: boolean()
  def allowed_class?(:ontology, _class), do: true

  def allowed_class?(family, @jf <> local) do
    local in Map.get(@allowed_classes, family, []) or local == "NamedGraph"
  end

  def allowed_class?(_family, _standard_class), do: true

  @spec shape(String.t()) :: String.t()
  def shape(name), do: "https://jido.run/ontology/shapes##{name}"
end
