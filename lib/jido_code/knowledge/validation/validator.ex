defmodule JidoCode.Knowledge.Validation.Validator do
  @moduledoc """
  Fail-closed, SHACL-compatible validation for semantic write commands.

  Ontology statements remain open-world guidance. The checks here are the
  closed-world operational subset required before a command can become
  visible.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Validation.ShapeCatalog

  @version "1.0.0"
  @max_quads 10_000
  @max_issues 100
  @max_safe_message_bytes 160
  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdf_subject "http://www.w3.org/1999/02/22-rdf-syntax-ns#subject"
  @rdf_predicate "http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate"
  @rdf_object "http://www.w3.org/1999/02/22-rdf-syntax-ns#object"
  @prov_associated "http://www.w3.org/ns/prov#wasAssociatedWith"
  @prov_generated_at "http://www.w3.org/ns/prov#generatedAtTime"
  @prov_started_at "http://www.w3.org/ns/prov#startedAtTime"
  @prov_ended_at "http://www.w3.org/ns/prov#endedAtTime"
  @prov_invalidated_at "http://www.w3.org/ns/prov#invalidatedAtTime"
  @allowed_epistemic MapSet.new(~w[
    Observed Asserted Inferred ClaimProposed Accepted Rejected Waived Contradicted ClaimSuperseded
    Invalidated KnowledgeStillValid KnowledgeUnderReview KnowledgeContradicted KnowledgeInvalidated
    KnowledgeExpired KnowledgeSuperseded
  ])
  @relationship_predicates MapSet.new(~w[
    enrolls manages locatedBy inScope about derivedFrom supports contradicts addresses
    decomposesInto dependsOn blocks requiresCapability governedBy executes evaluates accepts
    rejects waives satisfies supersedes claimedBy validFor sourceActivity graphScope
    epistemicState confidenceBand priorState nextState transitionSubject expectedPredecessor
    cause decisionAuthority ontologyVersion creationActivity ownerScope graphKind lifecycleState
    completenessState sourceRevision parentGraph sourceGraph targetGraph validationReport
    sourceGraphRevision sourceOntologyVersion targetOntologyVersion focusNode resultShape resultPath
    severity ruleSet invalidationState
    priority expectedEvidence constrainedBy targetCapability includesTask alternativeTo requiresArtifact
    sourceSnapshot planner originActivity expectedEffect transitionDomain conflictsWith taskKind
    ownedBy policyKind applicabilityEvaluator closedInput obligationTemplate requiresDecision
    conflictPosture staticMember queryDerived member inCohort membershipPath applicabilityEvidence
    requiredOutcome acceptanceRequirement heldBy capabilityKind supportsScope supportsEffect
    authorizedBy evidenceSource broaderCapability
    inputPackage evaluatedContext proposes reuses omittedBecause governedProposal
    leasesTask eligibilityReceipt livenessEvidence
    usesVerificationMethod evaluatorCapability expectedClaim evaluatesArtifact generatedClaim
    verificationActivity evaluatedAttempt evaluatedTask evaluatedGoal evaluatedSnapshot
    hasCheck rawOutcome
    verificationKind inputClass checkStatus evidenceStrength evidenceClassification
    defers requestsMoreEvidence decisionMode outcomeStage decisionDisposition rationaleReference
    consideredEvidence causedBy followUpGoal followUpTask followUpKind confirmation
    riskClass knowledgeClassification sourceClaim hasFinding hasFailure policyOutcome
    relatedSymbol applicableLesson reasoningProfile validatedResource
    accessMode credentialReference credentialClass billingMode readinessState
    usesModelAccessProfile manifestOf hasContextManifest proposalOf sandboxOf
    evidenceReference
  ])
  @secret_predicate ~r/(?:credentialvalue|secret|password|privatekey|accesstoken|bearertoken)$/i
  @secret_literal ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i

  @spec version() :: String.t()
  def version, do: @version

  @spec validate(map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()} | {:error, Error.t(), map()}
  def validate(change, options \\ [])

  def validate(change, options) when is_map(change) and is_list(options) do
    deadline =
      Keyword.get_lazy(options, :deadline_monotonic_ms, fn ->
        System.monotonic_time(:millisecond) + Keyword.get(options, :timeout, 1_000)
      end)

    with :ok <- validate_deadline(deadline),
         :ok <- validate_change_envelope(change),
         :ok <- validate_deadline(deadline) do
      issues = collect_issues(change, deadline) |> Enum.take(@max_issues)
      report = report(change, issues)

      if issues == [] do
        {:ok, report}
      else
        {:error, Error.new(:invalid_input, :semantic_validation), report}
      end
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :semantic_validation)}
  catch
    _kind, _reason -> {:error, Error.new(:invalid_input, :semantic_validation)}
  end

  def validate(_change, _options), do: {:error, Error.new(:invalid_input, :semantic_validation)}

  defp validate_deadline(deadline) when is_integer(deadline) do
    if System.monotonic_time(:millisecond) < deadline,
      do: :ok,
      else: {:error, Error.new(:timeout, :semantic_validation)}
  end

  defp validate_deadline(_deadline), do: {:error, Error.new(:invalid_input, :semantic_validation)}

  defp validate_change_envelope(change) do
    additions = Map.get(change, :additions)
    existing = Map.get(change, :existing, [])

    cond do
      Map.get(change, :operation) not in [:create, :append, :replace, :migration] ->
        invalid()

      not is_atom(Map.get(change, :family)) ->
        invalid()

      not is_binary(Map.get(change, :graph_iri)) ->
        invalid()

      not is_map(Map.get(change, :metadata)) ->
        invalid()

      not is_list(additions) or not is_list(existing) ->
        invalid()

      length(additions) + length(existing) > @max_quads ->
        invalid()

      true ->
        :ok
    end
  end

  defp collect_issues(change, deadline) do
    effective = Enum.uniq(change.existing ++ change.additions)
    index = index(effective)

    []
    |> add_issue(validate_deadline_issue(deadline, change.graph_iri))
    |> add_issue(version_issue(change))
    |> add_issue(graph_issue(change))
    |> Kernel.++(term_issues(effective, change.graph_iri))
    |> Kernel.++(class_issues(index, change.family, change.graph_iri))
    |> Kernel.++(resource_shape_issues(index, change.graph_iri))
    |> Kernel.++(relationship_issues(effective, change.graph_iri))
    |> Kernel.++(secret_issues(effective, change.graph_iri))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&{&1.focus_node, &1.shape, &1.path, &1.issue_code})
  end

  defp validate_deadline_issue(deadline, focus) do
    if System.monotonic_time(:millisecond) < deadline,
      do: nil,
      else:
        issue(
          focus,
          "ValidationDeadlineShape",
          nil,
          "validation_timeout",
          "validation deadline exceeded"
        )
  end

  defp version_issue(change) do
    ontology_version = release_version(change.metadata.ontology_version)
    shape_version = Map.get(change, :shape_version, ShapeCatalog.version())

    if ShapeCatalog.known_versions?(ontology_version, shape_version) do
      nil
    else
      issue(
        change.graph_iri,
        "VersionShape",
        @jf <> "ontologyVersion",
        "unknown_semantic_version",
        "ontology or shape version is not admitted"
      )
    end
  end

  defp graph_issue(change) do
    with {:ok, family} <- GraphRegistry.identify(change.graph_iri),
         true <- family == change.family,
         true <- completeness_allowed?(change.family, change.metadata.completeness_state),
         true <-
           GraphRegistry.write_allowed?(
             family,
             change.operation,
             Map.get(change, :existing_metadata)
           ) do
      nil
    else
      _invalid ->
        issue(
          change.graph_iri,
          "NamedGraphShape",
          @jf <> "graphKind",
          "graph_contract",
          "named graph family or lifecycle contract is invalid"
        )
    end
  end

  defp completeness_allowed?(:run_attempt, state),
    do: state in [:building, :complete, :incomplete]

  defp completeness_allowed?(_family, state), do: state == :complete

  defp term_issues(quads, graph_iri) do
    Enum.flat_map(quads, fn quad ->
      case quad do
        {subject, predicate, _object, %RDF.IRI{value: ^graph_iri}} ->
          if RDF.Quad.valid?(quad) and not RDF.Quad.has_bnode?(quad) and iri?(subject) and
               iri?(predicate) do
            []
          else
            [
              issue(
                graph_iri,
                "RDFTermShape",
                nil,
                "invalid_rdf_term",
                "RDF term form is not admitted"
              )
            ]
          end

        _wrong_graph ->
          [
            issue(
              graph_iri,
              "GraphPlacementShape",
              nil,
              "wrong_graph",
              "statement graph placement is invalid"
            )
          ]
      end
    end)
  end

  defp class_issues(index, family, graph_iri) do
    index
    |> subjects_with_type()
    |> Enum.flat_map(fn {subject, classes} ->
      Enum.flat_map(classes, fn class ->
        if ShapeCatalog.allowed_class?(family, class) do
          []
        else
          [
            issue(
              subject,
              "GraphFamilyClassShape",
              @rdf_type,
              "class_not_allowed",
              "resource class is not allowed in this graph family",
              graph_iri
            )
          ]
        end
      end)
    end)
  end

  defp resource_shape_issues(index, graph_iri) do
    index
    |> subjects_with_type()
    |> Enum.flat_map(fn {subject, classes} ->
      Enum.flat_map(classes, &shape_issues(&1, subject, index, graph_iri))
    end)
  end

  defp shape_issues(@jf <> "RepositoryLocator", subject, index, graph),
    do:
      cardinality(
        index,
        subject,
        @jf <> "canonicalLocator",
        1,
        1,
        "RepositoryLocatorShape",
        graph
      ) ++
        datatype(
          index,
          subject,
          @jf <> "canonicalLocator",
          RDF.XSD.String,
          "RepositoryLocatorShape",
          graph
        )

  defp shape_issues(@jf <> "Claim", subject, index, graph) do
    []
    |> Kernel.++(cardinality(index, subject, @rdf_subject, 1, 1, "ClaimShape", graph))
    |> Kernel.++(cardinality(index, subject, @rdf_predicate, 1, 1, "ClaimShape", graph))
    |> Kernel.++(cardinality(index, subject, @rdf_object, 1, 1, "ClaimShape", graph))
    |> Kernel.++(cardinality(index, subject, @jf <> "sourceActivity", 1, 1, "ClaimShape", graph))
    |> Kernel.++(cardinality(index, subject, @jf <> "graphScope", 1, 1, "ClaimShape", graph))
    |> Kernel.++(cardinality(index, subject, @jf <> "epistemicState", 1, 1, "ClaimShape", graph))
    |> Kernel.++(node_kind(index, subject, @rdf_subject, :iri, "ClaimShape", graph))
    |> Kernel.++(node_kind(index, subject, @rdf_predicate, :iri, "ClaimShape", graph))
    |> Kernel.++(node_kind(index, subject, @jf <> "sourceActivity", :iri, "ClaimShape", graph))
    |> Kernel.++(node_kind(index, subject, @jf <> "graphScope", :iri, "ClaimShape", graph))
    |> Kernel.++(epistemic_issues(index, subject, graph))
    |> Kernel.++(confidence_issues(index, subject, graph))
    |> Kernel.++(temporal_issues(index, subject, "ClaimShape", graph))
    |> Kernel.++(decision_backing_issues(index, subject, graph))
  end

  defp shape_issues(@jf <> "StateTransition", subject, index, graph) do
    issues =
      []
      |> Kernel.++(
        cardinality(index, subject, @jf <> "transitionSubject", 1, 1, "TransitionShape", graph)
      )
      |> Kernel.++(
        cardinality(index, subject, @jf <> "nextState", 1, 1, "TransitionShape", graph)
      )
      |> Kernel.++(
        cardinality(index, subject, @jf <> "subjectRevision", 1, 1, "TransitionShape", graph)
      )
      |> Kernel.++(cardinality(index, subject, @prov_associated, 1, 1, "TransitionShape", graph))
      |> Kernel.++(
        cardinality(index, subject, @prov_generated_at, 1, 1, "TransitionShape", graph)
      )
      |> Kernel.++(cardinality(index, subject, @jf <> "cause", 1, 1, "TransitionShape", graph))
      |> Kernel.++(cardinality(index, subject, @jf <> "reason", 1, 1, "TransitionShape", graph))
      |> Kernel.++(
        cardinality(index, subject, @jf <> "recordedAt", 1, 1, "TransitionShape", graph)
      )
      |> Kernel.++(
        datatype(
          index,
          subject,
          @jf <> "subjectRevision",
          RDF.XSD.NonNegativeInteger,
          "TransitionShape",
          graph
        )
      )
      |> Kernel.++(
        datatype(
          index,
          subject,
          @prov_generated_at,
          RDF.XSD.DateTime,
          "TransitionShape",
          graph
        )
      )
      |> Kernel.++(
        datatype(index, subject, @jf <> "recordedAt", RDF.XSD.DateTime, "TransitionShape", graph)
      )

    issues ++ transition_predecessor_issues(index, subject, graph)
  end

  defp shape_issues(@jf <> "Lease", subject, index, graph) do
    []
    |> Kernel.++(cardinality(index, subject, @jf <> "claimedBy", 1, 1, "LeaseShape", graph))
    |> Kernel.++(cardinality(index, subject, @jf <> "fencingToken", 1, 1, "LeaseShape", graph))
    |> Kernel.++(cardinality(index, subject, @jf <> "validFrom", 1, 1, "LeaseShape", graph))
    |> Kernel.++(cardinality(index, subject, @jf <> "validTo", 1, 1, "LeaseShape", graph))
    |> Kernel.++(
      datatype(
        index,
        subject,
        @jf <> "fencingToken",
        RDF.XSD.NonNegativeInteger,
        "LeaseShape",
        graph
      )
    )
    |> Kernel.++(
      datatype(index, subject, @jf <> "validFrom", RDF.XSD.DateTime, "LeaseShape", graph)
    )
    |> Kernel.++(
      datatype(index, subject, @jf <> "validTo", RDF.XSD.DateTime, "LeaseShape", graph)
    )
  end

  defp shape_issues(@jf <> "EvidenceBundle", subject, index, graph) do
    if values(index, subject, @jf <> "supports") ++ values(index, subject, @jf <> "contradicts") ==
         [] do
      [
        issue(
          subject,
          "EvidenceShape",
          @jf <> "supports",
          "missing_evidence_link",
          "evidence must support or contradict a resource",
          graph
        )
      ]
    else
      []
    end
  end

  defp shape_issues(@jf <> "Decision", subject, index, graph) do
    authority =
      cardinality(index, subject, @jf <> "decisionAuthority", 1, 1, "DecisionShape", graph)

    dispositions =
      Enum.flat_map(
        ~w[accepts rejects waives defers requestsMoreEvidence supersedes],
        &values(index, subject, @jf <> &1)
      )

    if dispositions == [] do
      [
        issue(
          subject,
          "DecisionShape",
          @jf <> "accepts",
          "missing_disposition",
          "decision requires a governed disposition",
          graph
        )
        | authority
      ]
    else
      authority
    end
  end

  defp shape_issues(@jf <> "CredentialReference", subject, index, graph) do
    cardinality(
      index,
      subject,
      @jf <> "credentialProvider",
      1,
      1,
      "CredentialReferenceShape",
      graph
    ) ++
      cardinality(index, subject, @jf <> "credentialKey", 1, 1, "CredentialReferenceShape", graph) ++
      datatype(
        index,
        subject,
        @jf <> "credentialProvider",
        RDF.XSD.String,
        "CredentialReferenceShape",
        graph
      ) ++
      datatype(
        index,
        subject,
        @jf <> "credentialKey",
        RDF.XSD.String,
        "CredentialReferenceShape",
        graph
      )
  end

  defp shape_issues(@jf <> "MigrationActivity", subject, index, graph) do
    required_iris = [
      @jf <> "sourceGraph",
      @jf <> "targetGraph",
      @jf <> "sourceOntologyVersion",
      @jf <> "targetOntologyVersion",
      @jf <> "validationReport",
      @prov_associated
    ]

    required_literals = [
      {@jf <> "transformerVersion", RDF.XSD.String},
      {@jf <> "rollbackPosture", RDF.XSD.String},
      {@jf <> "sourceCount", RDF.XSD.NonNegativeInteger},
      {@jf <> "targetCount", RDF.XSD.NonNegativeInteger},
      {@prov_started_at, RDF.XSD.DateTime},
      {@prov_ended_at, RDF.XSD.DateTime}
    ]

    iri_issues =
      Enum.flat_map(required_iris, fn predicate ->
        cardinality(index, subject, predicate, 1, 1, "MigrationShape", graph) ++
          node_kind(index, subject, predicate, :iri, "MigrationShape", graph)
      end)

    Enum.reduce(required_literals, iri_issues, fn {predicate, datatype_module}, issues ->
      issues ++
        cardinality(index, subject, predicate, 1, 1, "MigrationShape", graph) ++
        datatype(index, subject, predicate, datatype_module, "MigrationShape", graph)
    end)
  end

  defp shape_issues(@jf <> "ValidationReport", subject, index, graph) do
    cardinality(index, subject, @jf <> "shapeVersion", 1, 1, "ValidationReportShape", graph) ++
      datatype(
        index,
        subject,
        @jf <> "shapeVersion",
        RDF.XSD.String,
        "ValidationReportShape",
        graph
      )
  end

  defp shape_issues(@jf <> "ValidationResult", subject, index, graph) do
    iri_predicates = [@jf <> "focusNode", @jf <> "resultShape", @jf <> "severity"]
    literal_predicates = [@jf <> "issueCode", @jf <> "safeMessage"]

    iri_issues =
      Enum.flat_map(iri_predicates, fn predicate ->
        cardinality(index, subject, predicate, 1, 1, "ValidationResultShape", graph) ++
          node_kind(index, subject, predicate, :iri, "ValidationResultShape", graph)
      end)

    Enum.reduce(literal_predicates, iri_issues, fn predicate, issues ->
      issues ++
        cardinality(index, subject, predicate, 1, 1, "ValidationResultShape", graph) ++
        datatype(index, subject, predicate, RDF.XSD.String, "ValidationResultShape", graph)
    end)
  end

  defp shape_issues(@jf <> "GraphRevisionReference", subject, index, graph) do
    cardinality(
      index,
      subject,
      @jf <> "sourceGraph",
      1,
      1,
      "GraphRevisionReferenceShape",
      graph
    ) ++
      node_kind(
        index,
        subject,
        @jf <> "sourceGraph",
        :iri,
        "GraphRevisionReferenceShape",
        graph
      ) ++
      cardinality(
        index,
        subject,
        @jf <> "sourceRevisionNumber",
        1,
        1,
        "GraphRevisionReferenceShape",
        graph
      ) ++
      datatype(
        index,
        subject,
        @jf <> "sourceRevisionNumber",
        RDF.XSD.NonNegativeInteger,
        "GraphRevisionReferenceShape",
        graph
      )
  end

  defp shape_issues(@jf <> "ModelAccessProfile", subject, index, graph) do
    required_iris = [
      @jf <> "accessMode",
      @jf <> "credentialReference",
      @jf <> "credentialClass",
      @jf <> "billingMode"
    ]

    Enum.flat_map(required_iris, fn predicate ->
      cardinality(index, subject, predicate, 1, 1, "ModelAccessProfileShape", graph) ++
        node_kind(index, subject, predicate, :iri, "ModelAccessProfileShape", graph)
    end) ++
      cardinality(
        index,
        subject,
        @jf <> "revocationGeneration",
        1,
        nil,
        "ModelAccessProfileShape",
        graph
      ) ++
      datatype(
        index,
        subject,
        @jf <> "revocationGeneration",
        RDF.XSD.NonNegativeInteger,
        "ModelAccessProfileShape",
        graph
      ) ++
      concept_values(
        index,
        subject,
        @jf <> "accessMode",
        ~w[HostApi HostSubscription DelegatedCli],
        "ModelAccessProfileShape",
        graph
      ) ++
      concept_values(
        index,
        subject,
        @jf <> "credentialClass",
        ~w[StaticReusable ShortLivedBearer WorkloadExchange AttachingProxy],
        "ModelAccessProfileShape",
        graph
      ) ++
      concept_values(
        index,
        subject,
        @jf <> "billingMode",
        ~w[MeteredApi Subscription Unknown],
        "ModelAccessProfileShape",
        graph
      ) ++
      concept_values(
        index,
        subject,
        @jf <> "readinessState",
        ~w[
          Installed CredentialAvailable Authenticated ModelAvailable SandboxReady PolicyAllowed
          LiveVerified
        ],
        "ModelAccessProfileShape",
        graph
      )
  end

  defp shape_issues(@jf <> "HarnessProfile", subject, index, graph) do
    cardinality(
      index,
      subject,
      @jf <> "usesModelAccessProfile",
      1,
      1,
      "HarnessProfileShape",
      graph
    ) ++
      node_kind(
        index,
        subject,
        @jf <> "usesModelAccessProfile",
        :iri,
        "HarnessProfileShape",
        graph
      ) ++
      Enum.flat_map(
        ~w[version workflowVersion promptTemplateVersion toolCatalogVersion policyRevision budgetProfile],
        fn local ->
          cardinality(index, subject, @jf <> local, 1, 1, "HarnessProfileShape", graph) ++
            datatype(index, subject, @jf <> local, RDF.XSD.String, "HarnessProfileShape", graph)
        end
      )
  end

  defp shape_issues(@jf <> "ToolDefinitionRevision", subject, index, graph) do
    Enum.flat_map(
      ~w[toolName toolVersion inputSchemaDigest outputSchemaDigest adapterDigest],
      fn local ->
        cardinality(index, subject, @jf <> local, 1, 1, "ToolDefinitionRevisionShape", graph) ++
          datatype(index, subject, @jf <> local, RDF.XSD.String, "ToolDefinitionRevisionShape", graph)
      end
    ) ++
      concept_values(
        index,
        subject,
        @jf <> "effectClass",
        ~w[Read Write External Publish],
        "ToolDefinitionRevisionShape",
        graph
      )
  end

  defp shape_issues(@jf <> "ApprovalRequest", subject, index, graph) do
    cardinality(index, subject, @jf <> "actionDigest", 1, 1, "ApprovalRequestShape", graph) ++
      datatype(
        index,
        subject,
        @jf <> "actionDigest",
        RDF.XSD.String,
        "ApprovalRequestShape",
        graph
      ) ++
      cardinality(
        index,
        subject,
        @jf <> "approvalExpiresAt",
        1,
        1,
        "ApprovalRequestShape",
        graph
      ) ++
      datatype(
        index,
        subject,
        @jf <> "approvalExpiresAt",
        RDF.XSD.DateTime,
        "ApprovalRequestShape",
        graph
      ) ++
      node_kind(index, subject, @jf <> "evidenceReference", :iri, "ApprovalRequestShape", graph)
  end

  defp shape_issues(@jf <> "ContextManifest", subject, index, graph) do
    Enum.flat_map([@jf <> "manifestOf", @jf <> "manifestDigest"], fn predicate ->
      cardinality(index, subject, predicate, 1, 1, "ContextManifestShape", graph) ++
        (if predicate == @jf <> "manifestOf",
           do: node_kind(index, subject, predicate, :iri, "ContextManifestShape", graph),
           else: datatype(index, subject, predicate, RDF.XSD.String, "ContextManifestShape", graph))
    end) ++
      cardinality(index, subject, @jf <> "manifestIndex", 1, 1, "ContextManifestShape", graph) ++
      datatype(
        index,
        subject,
        @jf <> "manifestIndex",
        RDF.XSD.NonNegativeInteger,
        "ContextManifestShape",
        graph
      ) ++
      concept_values(
        index,
        subject,
        @jf <> "manifestKind",
        ~w[HostContext DelegatedInput],
        "ContextManifestShape",
        graph
      ) ++
      concept_values(
        index,
        subject,
        @jf <> "reconstructionState",
        ~w[Exact Partial Unavailable],
        "ContextManifestShape",
        graph
      )
  end

  defp shape_issues(@jf <> "ModelInvocation", subject, index, graph) do
    Enum.flat_map([@jf <> "usesModelAccessProfile", @jf <> "attempts"], fn predicate ->
      cardinality(index, subject, predicate, 1, 1, "ModelInvocationShape", graph) ++
        node_kind(index, subject, predicate, :iri, "ModelInvocationShape", graph)
    end) ++
      cardinality(index, subject, @jf <> "invocationSequence", 1, 1, "ModelInvocationShape", graph) ++
      datatype(
        index,
        subject,
        @jf <> "invocationSequence",
        RDF.XSD.NonNegativeInteger,
        "ModelInvocationShape",
        graph
      ) ++
      datatype(
        index,
        subject,
        @jf <> "modelVersion",
        RDF.XSD.String,
        "ModelInvocationShape",
        graph
      )
  end

  defp shape_issues(@jf <> "ActionProposal", subject, index, graph) do
    cardinality(index, subject, @jf <> "proposalOf", 1, 1, "ActionProposalShape", graph) ++
      node_kind(index, subject, @jf <> "proposalOf", :iri, "ActionProposalShape", graph) ++
      cardinality(index, subject, @jf <> "proposalDigest", 1, 1, "ActionProposalShape", graph) ++
      datatype(
        index,
        subject,
        @jf <> "proposalDigest",
        RDF.XSD.String,
        "ActionProposalShape",
        graph
      )
  end

  defp shape_issues(@jf <> "SandboxInstance", subject, index, graph) do
    cardinality(index, subject, @jf <> "sandboxOf", 1, 1, "SandboxInstanceShape", graph) ++
      node_kind(index, subject, @jf <> "sandboxOf", :iri, "SandboxInstanceShape", graph) ++
      cardinality(index, subject, @jf <> "imageDigest", 1, 1, "SandboxInstanceShape", graph) ++
      datatype(
        index,
        subject,
        @jf <> "imageDigest",
        RDF.XSD.String,
        "SandboxInstanceShape",
        graph
      ) ++
      concept_values(
        index,
        subject,
        @jf <> "isolationTier",
        ~w[RestrictedBeam ContainerSandbox MicroVm DedicatedHost],
        "SandboxInstanceShape",
        graph
      )
  end

  defp shape_issues(_class, _subject, _index, _graph), do: []

  defp epistemic_issues(index, subject, graph) do
    Enum.flat_map(values(index, subject, @jf <> "epistemicState"), fn
      %RDF.IRI{value: "https://jido.run/ontology/concept/" <> state} ->
        if MapSet.member?(@allowed_epistemic, state),
          do: [],
          else: [controlled_issue(subject, graph)]

      _invalid ->
        [controlled_issue(subject, graph)]
    end)
  end

  defp controlled_issue(subject, graph) do
    issue(
      subject,
      "ClaimShape",
      @jf <> "epistemicState",
      "unknown_epistemic_state",
      "claim epistemic state is not controlled",
      graph
    )
  end

  defp confidence_issues(index, subject, graph) do
    case values(index, subject, @jf <> "confidenceValue") do
      [] ->
        []

      [literal] ->
        case literal_decimal(literal) do
          value when is_number(value) and value >= 0 and value <= 1 ->
            []

          _invalid ->
            [
              issue(
                subject,
                "ClaimShape",
                @jf <> "confidenceValue",
                "invalid_confidence",
                "confidence must be a decimal from zero through one",
                graph
              )
            ]
        end

      _many ->
        [
          issue(
            subject,
            "ClaimShape",
            @jf <> "confidenceValue",
            "cardinality",
            "confidence has invalid cardinality",
            graph
          )
        ]
    end
  end

  defp temporal_issues(index, subject, shape, graph) do
    required =
      cardinality(index, subject, @jf <> "recordedAt", 1, 1, shape, graph) ++
        datatype(index, subject, @jf <> "recordedAt", RDF.XSD.DateTime, shape, graph)

    optional_predicates = [
      @prov_generated_at,
      @jf <> "validFrom",
      @jf <> "validTo",
      @jf <> "sourceObservedAt",
      @prov_invalidated_at
    ]

    Enum.reduce(optional_predicates, required, fn predicate, issues ->
      issues ++
        cardinality(index, subject, predicate, 0, 1, shape, graph) ++
        datatype(index, subject, predicate, RDF.XSD.DateTime, shape, graph)
    end) ++ temporal_order_issues(index, subject, shape, graph)
  end

  defp temporal_order_issues(index, subject, shape, graph) do
    recorded_at = time_value(index, subject, @jf <> "recordedAt")
    generated_at = time_value(index, subject, @prov_generated_at)
    observed_at = time_value(index, subject, @jf <> "sourceObservedAt")
    invalidated_at = time_value(index, subject, @prov_invalidated_at)
    valid_from = time_value(index, subject, @jf <> "validFrom")
    valid_to = time_value(index, subject, @jf <> "validTo")

    []
    |> maybe_add_temporal_order_issue(
      later?(generated_at, recorded_at),
      subject,
      shape,
      @prov_generated_at,
      graph
    )
    |> maybe_add_temporal_order_issue(
      later?(observed_at, recorded_at),
      subject,
      shape,
      @jf <> "sourceObservedAt",
      graph
    )
    |> maybe_add_temporal_order_issue(
      not is_nil(valid_from) and not is_nil(valid_to) and
        DateTime.compare(valid_from, valid_to) != :lt,
      subject,
      shape,
      @jf <> "validTo",
      graph
    )
    |> maybe_add_temporal_order_issue(
      earlier?(invalidated_at, recorded_at),
      subject,
      shape,
      @prov_invalidated_at,
      graph
    )
  end

  defp maybe_add_temporal_order_issue(issues, false, _subject, _shape, _path, _graph),
    do: issues

  defp maybe_add_temporal_order_issue(issues, true, subject, shape, path, graph) do
    [
      issue(
        subject,
        shape,
        path,
        "invalid_temporal_order",
        "temporal values violate transaction-time or valid-time ordering",
        graph
      )
      | issues
    ]
  end

  defp time_value(index, subject, predicate) do
    case values(index, subject, predicate) do
      [%RDF.Literal{} = literal] ->
        case RDF.Literal.value(literal) do
          %DateTime{} = value -> value
          _invalid -> nil
        end

      _missing_or_many ->
        nil
    end
  end

  defp later?(%DateTime{} = first, %DateTime{} = second),
    do: DateTime.compare(first, second) == :gt

  defp later?(_first, _second), do: false

  defp earlier?(%DateTime{} = first, %DateTime{} = second),
    do: DateTime.compare(first, second) == :lt

  defp earlier?(_first, _second), do: false

  defp decision_backing_issues(index, subject, graph) do
    state = values(index, subject, @jf <> "epistemicState")

    required_predicate =
      case state do
        [%RDF.IRI{value: "https://jido.run/ontology/concept/Accepted"}] -> @jf <> "accepts"
        [%RDF.IRI{value: "https://jido.run/ontology/concept/Rejected"}] -> @jf <> "rejects"
        _other -> nil
      end

    if is_nil(required_predicate) or incoming_decision?(index, required_predicate, subject) do
      []
    else
      [
        issue(
          subject,
          "ClaimShape",
          required_predicate,
          "missing_governed_decision",
          "accepted or rejected claim requires an explicit decision",
          graph
        )
      ]
    end
  end

  defp incoming_decision?(index, predicate, object) do
    Enum.any?(index, fn {_subject, predicates} ->
      types = Map.get(predicates, RDF.iri(@rdf_type), [])
      authorities = Map.get(predicates, RDF.iri(@jf <> "decisionAuthority"), [])

      RDF.iri(object) in Map.get(predicates, RDF.iri(predicate), []) and
        RDF.iri(@jf <> "Decision") in types and length(authorities) == 1 and
        Enum.all?(authorities, &iri?/1)
    end)
  end

  defp transition_predecessor_issues(index, subject, graph) do
    case values(index, subject, @jf <> "subjectRevision") do
      [%RDF.Literal{} = literal] ->
        case RDF.Literal.value(literal) do
          0 ->
            cardinality(index, subject, @jf <> "priorState", 0, 0, "TransitionShape", graph) ++
              cardinality(
                index,
                subject,
                @jf <> "expectedPredecessor",
                0,
                0,
                "TransitionShape",
                graph
              )

          revision when is_integer(revision) and revision > 0 ->
            cardinality(index, subject, @jf <> "priorState", 1, 1, "TransitionShape", graph) ++
              cardinality(
                index,
                subject,
                @jf <> "expectedPredecessor",
                1,
                1,
                "TransitionShape",
                graph
              )

          _invalid ->
            []
        end

      _invalid ->
        []
    end
  end

  defp relationship_issues(quads, graph_iri) do
    Enum.flat_map(quads, fn {_subject, %RDF.IRI{value: predicate}, object, _graph} ->
      local = String.replace_prefix(predicate, @jf, "")

      if (MapSet.member?(@relationship_predicates, local) or predicate == @rdf_type) and
           not iri?(object) do
        [
          issue(
            graph_iri,
            "RelationshipShape",
            predicate,
            "literal_relationship",
            "graph relationship object must be an IRI"
          )
        ]
      else
        []
      end
    end)
  end

  defp secret_issues(quads, graph_iri) do
    Enum.flat_map(quads, fn {_subject, %RDF.IRI{value: predicate}, object, _graph} ->
      local = String.replace_prefix(predicate, @jf, "")
      lexical = literal_lexical(object)

      cond do
        Regex.match?(@secret_predicate, local) ->
          [
            issue(
              graph_iri,
              "SecretReferenceShape",
              predicate,
              "secret_predicate",
              "credential values are prohibited"
            )
          ]

        is_binary(lexical) and Regex.match?(@secret_literal, lexical) ->
          [
            issue(
              graph_iri,
              "SecretReferenceShape",
              predicate,
              "secret_literal",
              "secret-like literal is prohibited"
            )
          ]

        true ->
          []
      end
    end)
  end

  defp cardinality(index, subject, predicate, min, max, shape, graph) do
    count = length(values(index, subject, predicate))

    if count >= min and count <= max do
      []
    else
      [
        issue(
          subject,
          shape,
          predicate,
          "cardinality",
          "required predicate cardinality is not satisfied",
          graph
        )
      ]
    end
  end

  defp node_kind(index, subject, predicate, :iri, shape, graph) do
    Enum.flat_map(values(index, subject, predicate), fn value ->
      if iri?(value) do
        []
      else
        [issue(subject, shape, predicate, "node_kind", "predicate value must be an IRI", graph)]
      end
    end)
  end

  defp datatype(index, subject, predicate, datatype, shape, graph) do
    Enum.flat_map(values(index, subject, predicate), fn
      %RDF.Literal{} = literal ->
        if RDF.Literal.is_a?(literal, datatype) do
          []
        else
          [
            issue(
              subject,
              shape,
              predicate,
              "datatype",
              "literal datatype is not admitted",
              graph
            )
          ]
        end

      _non_literal ->
        [
          issue(
            subject,
            shape,
            predicate,
            "datatype",
            "predicate value must be a typed literal",
            graph
          )
        ]
    end)
  end

  defp index(quads) do
    Enum.reduce(quads, %{}, fn {subject, predicate, object, _graph}, acc ->
      Map.update(acc, subject, %{predicate => [object]}, fn predicates ->
        Map.update(predicates, predicate, [object], &[object | &1])
      end)
    end)
  end

  defp subjects_with_type(index) do
    Enum.map(index, fn {subject, predicates} ->
      classes =
        predicates
        |> Map.get(RDF.iri(@rdf_type), [])
        |> Enum.flat_map(fn
          %RDF.IRI{value: value} -> [value]
          _literal -> []
        end)

      {focus_iri(subject), classes}
    end)
  end

  defp values(index, subject, predicate) do
    index |> Map.get(RDF.iri(subject), %{}) |> Map.get(RDF.iri(predicate), [])
  end

  defp concept_values(index, subject, predicate, allowed, shape, graph) do
    index
    |> values(subject, predicate)
    |> Enum.flat_map(fn
      %RDF.IRI{value: "https://jido.run/ontology/concept/" <> local} ->
        if local in allowed,
          do: [],
          else: [
            issue(
              subject,
              shape,
              predicate,
              "controlled_concept",
              "predicate value is outside the controlled concept scheme",
              graph
            )
          ]

      _invalid ->
        [
          issue(
            subject,
            shape,
            predicate,
            "controlled_concept",
            "predicate value must be a controlled concept IRI",
            graph
          )
        ]
    end)
  end

  defp report(change, issues) do
    material =
      {change.graph_iri, change.family, Map.get(change, :shape_version, ShapeCatalog.version()),
       issues}
      |> :erlang.term_to_binary([:deterministic])
      |> Base.encode16(case: :lower)

    {:ok, report_iri} = ResourceIdentity.deterministic(:validation_report, material)

    results =
      Enum.map(issues, fn issue ->
        {:ok, result_iri} =
          ResourceIdentity.deterministic(
            :validation_result,
            :erlang.term_to_binary(issue, [:deterministic])
          )

        Map.put(issue, :result_iri, result_iri)
      end)

    %{
      report_iri: report_iri,
      conforms?: results == [],
      validator_version: @version,
      ontology_version: release_version(change.metadata.ontology_version),
      shape_version: Map.get(change, :shape_version, ShapeCatalog.version()),
      graph_iri: change.graph_iri,
      issues: results,
      issue_count: length(results)
    }
  end

  defp issue(focus, shape, path, code, message, graph_iri \\ nil) do
    %{
      focus_node: focus_iri(focus) || graph_iri,
      shape: ShapeCatalog.shape(shape),
      path: path,
      issue_code: code,
      severity: :violation,
      safe_message: binary_part(message, 0, min(byte_size(message), @max_safe_message_bytes))
    }
  end

  defp add_issue(issues, nil), do: issues
  defp add_issue(issues, issue), do: [issue | issues]

  defp release_version(@jf <> _term), do: nil

  defp release_version("https://jido.run/ontology/release/" <> version), do: version
  defp release_version(_value), do: nil

  defp focus_iri(%RDF.IRI{value: value}), do: value
  defp focus_iri(value) when is_binary(value) and byte_size(value) <= 512, do: value
  defp focus_iri(_value), do: nil

  defp iri?(%RDF.IRI{} = value), do: RDF.IRI.valid?(value)
  defp iri?(_value), do: false

  defp literal_decimal(%RDF.Literal{} = literal) do
    case RDF.Literal.value(literal) do
      %Decimal{} = value -> Decimal.to_float(value)
      value when is_integer(value) or is_float(value) -> value
      _invalid -> nil
    end
  end

  defp literal_decimal(_value), do: nil

  defp literal_lexical(%RDF.Literal{} = literal), do: RDF.Literal.lexical(literal)
  defp literal_lexical(_value), do: nil
  defp invalid, do: {:error, Error.new(:invalid_input, :semantic_validation)}
end
