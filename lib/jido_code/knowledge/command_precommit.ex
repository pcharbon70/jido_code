defmodule JidoCode.Knowledge.CommandPrecommit do
  @moduledoc false

  alias JidoCode.Knowledge.ChangeSet
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Validation.Validator

  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
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
    scopedTo participant audience replyTo resultingCommand instruction contextItem
    attempts delegatedAgent retryOf
    usesVerificationMethod evaluatorCapability expectedClaim evaluatesArtifact generatedClaim
    verificationActivity evaluatedAttempt evaluatedTask evaluatedGoal evaluatedSnapshot
    hasCheck rawOutcome
    verificationKind inputClass checkStatus evidenceStrength evidenceClassification
    defers requestsMoreEvidence decisionMode outcomeStage decisionDisposition rationaleReference
    consideredEvidence causedBy followUpGoal followUpTask followUpKind confirmation
    riskClass knowledgeClassification sourceClaim hasFinding hasFailure policyOutcome
    relatedSymbol applicableLesson reasoningProfile validatedResource
    hasEventSegment activeSegment headEvent consumesHead hasSuccessor eventPredecessor
    eventPredecessorHead accountsResource opensEffect closesEffect carriedOpenEffect
    ambiguousOpenEffect cancelledEffect ambiguousEffect captureManifest hasCapture expectedBody
    capturedBody sourceEvent redactionReceipt outcomeOf effectJournal providerSource attributedBy
    relatedEvent acceptedGraph captureProfile captureOutcome contentRepresentation storageLocation
    availabilityState retentionState holdState contentClassification reconstructionStatus
    externalProviderAvailability captureCompleteness
    delegatedAgentProfile adapterRelease harnessProfile modelAccessProfile runtimeClass
    deploymentClass authenticationKind billingMode capabilityClass readinessEvidence
    invocationBeforeEffect
  ])
  @max_guards 100

  @spec validate(CommandEnvelope.t(), ChangeSet.t(), map(), map(), integer()) ::
          {:ok, [map()]} | {:error, Error.t()} | {:error, Error.t(), map()}
  def validate(envelope, change_set, snapshot, audit, deadline) do
    with :ok <- before_deadline(deadline),
         :ok <- revision_preconditions(envelope, snapshot),
         :ok <- target_lifecycle(change_set, snapshot),
         :ok <- topology(change_set),
         :ok <- guards(envelope.payload[:guards] || [], snapshot),
         {:ok, reports} <- validate_targets(change_set, snapshot, deadline),
         {:ok, audit_report} <- validate_audit(snapshot, audit, deadline),
         :ok <- before_deadline(deadline) do
      {:ok, reports ++ [audit_report]}
    end
  end

  defp revision_preconditions(envelope, snapshot) do
    current = Map.take(snapshot.graph_revisions, Map.keys(envelope.expected_graph_revisions))

    if snapshot.dataset_revision == envelope.expected_dataset_revision and
         current == envelope.expected_graph_revisions do
      :ok
    else
      {:error, Error.new(:stale_precondition, :command_revisions), current}
    end
  end

  defp target_lifecycle(change_set, snapshot) do
    Enum.reduce_while(change_set.targets, :ok, fn target, :ok ->
      existing = Map.get(snapshot.graph_metadata, target.graph_iri)
      operation = if target.operation == :maintenance, do: :append, else: target.operation

      valid? =
        case operation do
          :create ->
            is_nil(existing) and GraphRegistry.write_allowed?(target.family, :create)

          :append ->
            not is_nil(existing) and
              GraphRegistry.write_allowed?(target.family, :append, existing)

          :close ->
            not is_nil(existing) and
              GraphRegistry.write_allowed?(target.family, :close, existing)

          :replace ->
            not is_nil(existing) and
              GraphRegistry.write_allowed?(target.family, :replace, existing)
        end

      if valid?, do: {:cont, :ok}, else: {:halt, {:error, Error.new(:conflict, :graph_lifecycle)}}
    end)
  end

  defp topology(change_set) do
    Enum.reduce_while(change_set.additions, :ok, fn quad, :ok ->
      case quad do
        {_subject, %RDF.IRI{value: @jf <> local}, %RDF.IRI{value: object}, graph}
        when is_binary(object) ->
          if MapSet.member?(@relationship_predicates, local) and
               String.starts_with?(object, "https://jido.run/graph/") do
            with {:ok, source_family} <- GraphRegistry.identify(RDF.IRI.to_string(graph)),
                 {:ok, target_family} <- GraphRegistry.identify(object),
                 true <- GraphRegistry.allowed_link?(source_family, target_family) do
              {:cont, :ok}
            else
              _invalid -> {:halt, {:error, Error.new(:invalid_input, :cross_graph_link)}}
            end
          else
            {:cont, :ok}
          end

        _other ->
          {:cont, :ok}
      end
    end)
  end

  defp guards(guards, snapshot) when is_list(guards) and length(guards) <= @max_guards do
    Enum.reduce_while(guards, :ok, fn guard, :ok ->
      if guard_satisfied?(guard, snapshot.dataset),
        do: {:cont, :ok},
        else: {:halt, {:error, Error.new(:stale_precondition, :command_guard)}}
    end)
  end

  defp guards(_guards, _snapshot), do: {:error, Error.new(:invalid_input, :command_guards)}

  defp guard_satisfied?({:subject_present, graph, subject}, dataset) do
    Enum.any?(graph_quads(dataset, graph), fn {stored, _, _, _} ->
      term_equal?(stored, subject)
    end)
  end

  defp guard_satisfied?({:subject_absent, graph, subject}, dataset) do
    not guard_satisfied?({:subject_present, graph, subject}, dataset)
  end

  defp guard_satisfied?({:triple_present, graph, subject, predicate, object}, dataset) do
    {expected_subject, expected_predicate, expected_object} =
      RDF.Triple.new({subject, predicate, object})

    Enum.any?(graph_quads(dataset, graph), fn {s, p, o, _g} ->
      RDF.Term.equal_value?(s, expected_subject) and
        RDF.Term.equal_value?(p, expected_predicate) and
        RDF.Term.equal_value?(o, expected_object)
    end)
  rescue
    _error -> false
  end

  defp guard_satisfied?({:triple_absent, graph, subject, predicate, object}, dataset) do
    not guard_satisfied?({:triple_present, graph, subject, predicate, object}, dataset)
  end

  defp guard_satisfied?({:predicate_absent, graph, subject, predicate}, dataset) do
    not Enum.any?(graph_quads(dataset, graph), fn {stored_subject, stored_predicate, _, _} ->
      term_equal?(stored_subject, subject) and term_equal?(stored_predicate, predicate)
    end)
  rescue
    _error -> false
  end

  defp guard_satisfied?({:object_absent, graph, predicate, object}, dataset) do
    not Enum.any?(graph_quads(dataset, graph), fn {_subject, stored_predicate, stored_object, _g} ->
      term_equal?(stored_predicate, predicate) and term_equal?(stored_object, object)
    end)
  rescue
    _error -> false
  end

  defp guard_satisfied?({:transition_endpoint, graph, subject, transition}, dataset) do
    quads = graph_quads(dataset, graph)

    current? =
      triple_present?(quads, transition, @jf <> "transitionSubject", subject) and
        Enum.any?(quads, fn {_decision, predicate, object, _graph} ->
          term_equal?(predicate, @jf <> "accepts") and term_equal?(object, transition)
        end)

    accepted_successor? =
      Enum.any?(quads, fn {successor, predicate, object, _graph} ->
        term_equal?(predicate, @jf <> "expectedPredecessor") and term_equal?(object, transition) and
          Enum.any?(quads, fn {_decision, accepts, accepted, _graph} ->
            term_equal?(accepts, @jf <> "accepts") and RDF.Term.equal_value?(accepted, successor)
          end)
      end)

    current? and not accepted_successor?
  rescue
    _error -> false
  end

  defp guard_satisfied?({:no_active_lease, graph, task, %DateTime{} = at}, dataset) do
    dataset
    |> graph_quads(graph)
    |> active_leases(task, at)
    |> Enum.empty?()
  rescue
    _error -> false
  end

  defp guard_satisfied?({:next_fence, graph, task, fence}, dataset)
       when is_integer(fence) and fence > 0 do
    fences =
      dataset
      |> graph_quads(graph)
      |> lease_subjects(task)
      |> Enum.flat_map(&literal_values(graph_quads(dataset, graph), &1, @jf <> "fencingToken"))

    fence == Enum.max([0 | Enum.filter(fences, &is_integer/1)]) + 1
  rescue
    _error -> false
  end

  defp guard_satisfied?(
         {:current_lease_fence, graph, task, lease, fence, %DateTime{} = at},
         dataset
       )
       when is_integer(fence) and fence > 0 do
    guard_satisfied?({:current_lease_fence, graph, task, lease, fence, at, :current}, dataset)
  end

  defp guard_satisfied?(
         {:current_lease_fence, graph, task, lease, fence, %DateTime{} = at, mode},
         dataset
       )
       when is_integer(fence) and fence > 0 and mode in [:current, :expired] do
    quads = graph_quads(dataset, graph)

    lease in lease_subjects(quads, task) and
      literal_values(quads, lease, @jf <> "fencingToken") == [fence] and
      lease_temporally_valid?(quads, lease, at, mode)
  rescue
    _error -> false
  end

  defp guard_satisfied?({:no_active_attempt, task}, dataset) do
    quads = RDF.Dataset.quads(dataset)

    quads
    |> attempt_subjects(task)
    |> Enum.all?(fn attempt ->
      case transition_endpoint(quads, attempt) do
        %{state: state} -> state not in active_attempt_states()
        nil -> false
      end
    end)
  rescue
    _error -> false
  end

  defp guard_satisfied?(_guard, _dataset), do: false

  defp active_leases(quads, task, at) do
    quads
    |> lease_subjects(task)
    |> Enum.filter(fn lease ->
      case transition_endpoint(quads, lease) do
        %{state: state, transition: transition}
        when state in [@concept <> "LeaseActive", @concept <> "LeaseExecuting"] ->
          case literal_values(quads, transition, @jf <> "validTo") do
            [%DateTime{} = expiry] -> DateTime.compare(at, expiry) == :lt
            _invalid -> false
          end

        _inactive ->
          false
      end
    end)
  end

  defp lease_temporally_valid?(quads, lease, at, mode) do
    case transition_endpoint(quads, lease) do
      %{state: state, transition: transition}
      when state in [@concept <> "LeaseActive", @concept <> "LeaseExecuting"] ->
        case literal_values(quads, transition, @jf <> "validTo") do
          [%DateTime{} = expiry] when mode == :current ->
            DateTime.compare(at, expiry) == :lt

          [%DateTime{} = expiry] when mode == :expired ->
            DateTime.compare(at, expiry) in [:eq, :gt]

          _invalid ->
            false
        end

      _inactive ->
        false
    end
  end

  defp lease_subjects(quads, task) do
    quads
    |> Enum.flat_map(fn {subject, predicate, object, _graph} ->
      if term_equal?(predicate, @jf <> "leasesTask") and term_equal?(object, task),
        do: [to_string(subject)],
        else: []
    end)
    |> Enum.uniq()
  end

  defp attempt_subjects(quads, task) do
    quads
    |> Enum.flat_map(fn {subject, predicate, object, _graph} ->
      if term_equal?(predicate, @jf <> "executes") and term_equal?(object, task) and
           triple_present?(
             quads,
             to_string(subject),
             "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
             @jf <> "ExecutionAttempt"
           ) do
        [to_string(subject)]
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  defp active_attempt_states do
    Enum.map(
      ~w[prepared starting running waiting_tool cancelling recovered],
      &(@concept <> "ExecutionAttempt" <> Macro.camelize(&1))
    )
  end

  defp transition_endpoint(quads, subject) do
    accepted =
      quads
      |> Enum.flat_map(fn {transition, predicate, object, _graph} ->
        if term_equal?(predicate, @jf <> "transitionSubject") and term_equal?(object, subject) and
             accepted_transition?(quads, transition) do
          [transition]
        else
          []
        end
      end)

    endpoints =
      Enum.reject(accepted, fn transition ->
        Enum.any?(accepted, fn successor ->
          triple_present?(
            quads,
            to_string(successor),
            @jf <> "expectedPredecessor",
            to_string(transition)
          )
        end)
      end)

    case endpoints do
      [transition] ->
        case iri_values(quads, to_string(transition), @jf <> "nextState") do
          [state] -> %{transition: to_string(transition), state: state}
          _invalid -> nil
        end

      _invalid ->
        nil
    end
  end

  defp accepted_transition?(quads, transition) do
    Enum.any?(quads, fn {_decision, predicate, object, _graph} ->
      term_equal?(predicate, @jf <> "accepts") and RDF.Term.equal_value?(object, transition)
    end)
  end

  defp iri_values(quads, subject, predicate) do
    quads
    |> Enum.flat_map(fn {stored_subject, stored_predicate, object, _graph} ->
      if term_equal?(stored_subject, subject) and term_equal?(stored_predicate, predicate) do
        case object do
          %RDF.IRI{value: value} -> [value]
          _other -> []
        end
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  defp literal_values(quads, subject, predicate) do
    quads
    |> Enum.flat_map(fn {stored_subject, stored_predicate, object, _graph} ->
      if term_equal?(stored_subject, subject) and term_equal?(stored_predicate, predicate) do
        case object do
          %RDF.Literal{} = literal -> [RDF.Literal.value(literal)]
          _other -> []
        end
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  defp validate_targets(change_set, snapshot, deadline) do
    Enum.reduce_while(change_set.targets, {:ok, []}, fn target, {:ok, reports} ->
      existing_metadata = Map.get(snapshot.graph_metadata, target.graph_iri)

      metadata =
        if target.operation in [:replace, :close],
          do: target.metadata,
          else: existing_metadata || target.metadata

      operation =
        if target.operation in [:maintenance, :close], do: :append, else: target.operation

      existing =
        case target.operation do
          :replace -> []
          :close -> graph_quads(snapshot.dataset, target.graph_iri) -- target.removals
          _other -> graph_quads(snapshot.dataset, target.graph_iri)
        end

      result =
        Validator.validate(
          %{
            operation: operation,
            family: target.family,
            graph_iri: target.graph_iri,
            metadata: metadata,
            existing_metadata: existing_metadata,
            additions: target.additions,
            existing: existing,
            shape_version: change_set.shape_version
          },
          deadline_monotonic_ms: deadline
        )

      case result do
        {:ok, report} -> {:cont, {:ok, [report | reports]}}
        {:error, %Error{} = error, report} -> {:halt, {:error, error, report}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, reports} -> {:ok, Enum.reverse(reports)}
      error -> error
    end
  end

  defp validate_audit(snapshot, audit, deadline) do
    existing_metadata = Map.get(snapshot.graph_metadata, audit.graph_iri)

    valid_lifecycle? =
      case audit.operation do
        :append -> is_map(existing_metadata)
        :create -> is_nil(existing_metadata)
      end

    if valid_lifecycle? do
      Validator.validate(
        %{
          operation: audit.operation,
          family: :security_audit,
          graph_iri: audit.graph_iri,
          metadata: audit.metadata,
          existing_metadata: existing_metadata,
          additions: audit.additions,
          existing: graph_quads(snapshot.dataset, audit.graph_iri),
          shape_version: "1.0.0"
        },
        deadline_monotonic_ms: deadline
      )
    else
      {:error, Error.new(:conflict, :audit_graph_lifecycle)}
    end
  end

  defp graph_quads(dataset, graph) do
    case RDF.Dataset.graph(dataset, RDF.iri(graph)) do
      nil -> []
      graph_data -> RDF.Graph.quads(graph_data)
    end
  end

  defp term_equal?(stored, expected) do
    RDF.Term.equal_value?(stored, RDF.iri(expected))
  rescue
    _error -> false
  end

  defp triple_present?(quads, subject, predicate, object) do
    Enum.any?(quads, fn {stored_subject, stored_predicate, stored_object, _graph} ->
      term_equal?(stored_subject, subject) and term_equal?(stored_predicate, predicate) and
        term_equal?(stored_object, object)
    end)
  end

  defp before_deadline(deadline) when is_integer(deadline) do
    if System.monotonic_time(:millisecond) < deadline,
      do: :ok,
      else: {:error, Error.new(:timeout, :command_precommit)}
  end

  defp before_deadline(_deadline), do: {:error, Error.new(:invalid_input, :command_deadline)}
end
