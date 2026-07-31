defmodule JidoCode.Knowledge.Validation.ShapeCatalog do
  @moduledoc false

  @version "1.0.0"
  @ontology_version "1.0.0"
  @jf "https://jido.run/ontology/factory#"

  @allowed_classes %{
    ontology: :schema,
    factory_catalog: ~w[
      RepositoryFactory SoftwareRepository RepositoryLocator ManagementEnrollment Actor Agent Scope
    ],
    factory_policy: ~w[
      DesiredOutcome Constraint Policy Obligation Capability AuthorizationGrant Delegation Scope Decision
    ],
    observation_batch: ~w[
      ObservationActivity ObservationBatch RepositorySnapshot SourceArtifact Claim Finding
      Contradiction AssessmentActivity
    ],
    source_revision: ~w[RepositorySnapshot SourceArtifact CodeSymbol Scope MigrationActivity],
    repository_control: ~w[
      Goal Constraint Obligation Task Plan Capability Lease StateTransition Decision MigrationActivity
    ],
    run_attempt: ~w[
      ExecutionAttempt ToolInvocation Patch VerificationActivity Artifact Message MigrationActivity
    ],
    evidence: ~w[
      EvidenceBundle Decision Claim Finding Contradiction VerificationActivity MigrationActivity
    ],
    memory: ~w[KnowledgeAssertion Claim AdoptionActivity Contradiction MigrationActivity],
    security_audit: ~w[
      AuthorizationGrant CredentialReference ValidationReport ValidationResult MigrationActivity
    ],
    derived:
      ~w[Claim Finding Contradiction GraphRevisionReference ValidationReport ValidationResult]
  }

  @spec version() :: String.t()
  def version, do: @version

  @spec ontology_version() :: String.t()
  def ontology_version, do: @ontology_version

  @spec known_versions?(String.t(), String.t()) :: boolean()
  def known_versions?(ontology_version, shape_version) do
    ontology_version == @ontology_version and shape_version == @version
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
