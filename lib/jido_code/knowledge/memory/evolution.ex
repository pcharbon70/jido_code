defmodule JidoCode.Knowledge.Memory.Evolution do
  @moduledoc "Append-only review, contradiction, invalidation, expiry, and supersession."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.Assertion
  alias JidoCode.Knowledge.Memory.Graph, as: MemoryGraph
  alias JidoCode.Knowledge.Memory.StateTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @terminal_with_replacement [:superseded]
  @review_states ~w[under_review contradicted]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @spec record_command(Assertion.t(), map(), Assertion.t() | nil, map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def record_command(assertion, resolution, replacement, attributes, options \\ [])

  def record_command(
        %Assertion{} = assertion,
        resolution,
        replacement,
        attributes,
        options
      )
      when is_map(resolution) and is_map(attributes) and is_list(options) do
    with true <- resolution[:subject_iri] == assertion.iri,
         true <- resolution[:current_state] in StateTransition.states(),
         true <- attributes[:scope_iri] == assertion.repository_scope_iri,
         true <- attributes[:policy_iri] == policy_iri(assertion, replacement),
         :ok <- replacement_allowed(assertion, replacement, attributes[:next_state]),
         {:ok, evidence} <- evidence(attributes[:evidence_iris], attributes[:next_state]),
         :ok <- ResourceIdentity.validate(attributes[:decision_iri]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         recorded_at when is_struct(recorded_at, DateTime) <- attributes[:recorded_at],
         {:ok, transition} <-
           StateTransition.new(%{
             subject_iri: assertion.iri,
             prior_state: resolution.current_state,
             next_state: attributes.next_state,
             revision: resolution.current_revision + 1,
             expected_predecessor: resolution.current_transition,
             actor_iri: attributes.actor_iri,
             cause_iri: attributes.decision_iri,
             reason: attributes.reason,
             recorded_at: recorded_at
           }),
         {:ok, activity_iri} <-
           ResourceIdentity.deterministic(:knowledge_evolution_activity, transition.iri),
         true <- exact_revisions?(assertion, attributes),
         memory_revision when is_integer(memory_revision) and memory_revision > 0 <-
           attributes.expected_graph_revisions[assertion.memory_graph_iri],
         additions <-
           statements(assertion, transition, activity_iri, evidence, replacement, attributes),
         {:ok, target} <-
           MemoryGraph.target(
             assertion.memory_graph_iri,
             memory_revision,
             attributes.scope_iri,
             activity_iri,
             recorded_at,
             additions
           ),
         {:ok, command} <-
           CommandEnvelope.new(
             command(
               assertion,
               transition,
               activity_iri,
               evidence,
               replacement,
               target,
               attributes
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:supersede_claim)
    end
  rescue
    _error -> invalid(:supersede_claim)
  end

  def record_command(_assertion, _resolution, _replacement, _attributes, _options),
    do: invalid(:supersede_claim)

  defp statements(assertion, transition, activity, evidence, replacement, attributes) do
    [
      {activity, @rdf_type, RDF.iri(@jf <> "KnowledgeEvolutionActivity")},
      {activity, @prov <> "wasAssociatedWith", RDF.iri(attributes.actor_iri)},
      {activity, @jf <> "about", RDF.iri(assertion.iri)},
      {activity, @jf <> "causedBy", RDF.iri(attributes.decision_iri)},
      {activity, @jf <> "governedBy", RDF.iri(attributes.policy_iri)},
      {activity, @jf <> "accepts", RDF.iri(transition.iri)},
      {activity, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(attributes.recorded_at)}
    ] ++
      StateTransition.statements(transition) ++
      Enum.map(evidence, &{activity, @jf <> "evidenceSource", RDF.iri(&1)}) ++
      contradiction_statements(assertion, evidence, transition.next_state) ++
      replacement_statements(replacement)
  end

  defp contradiction_statements(assertion, evidence, state) when state in @review_states,
    do: Enum.map(evidence, &{assertion.iri, @jf <> "contradicts", RDF.iri(&1)})

  defp contradiction_statements(_assertion, _evidence, _state), do: []

  defp replacement_statements(%Assertion{} = replacement), do: Assertion.statements(replacement)
  defp replacement_statements(nil), do: []

  defp command(assertion, transition, activity, evidence, replacement, target, attributes) do
    command_iri = command_iri(assertion, transition)

    %{
      command_type: "SupersedeClaim",
      command_version: "1.7.0",
      command_iri: command_iri,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes.actor_iri,
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes.scope_iri,
      idempotency_key: command_iri,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes.decision_iri,
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: attributes[:expected_graph_revisions],
      reason: attributes.reason,
      payload: %{
        changes: [target],
        guards: guards(assertion, transition, activity, evidence, replacement, attributes),
        assertion_iri: assertion.iri,
        transition_iri: transition.iri,
        next_state: transition.next_state,
        replacement_iri: replacement_iri(replacement),
        direct_side_effects: []
      }
    }
  end

  defp guards(assertion, transition, activity, evidence, replacement, attributes) do
    memory = assertion.memory_graph_iri
    source_decision = replacement_iri(replacement, :source_decision, attributes.decision_iri)

    [
      {:subject_present, memory, assertion.iri},
      {:subject_absent, memory, activity},
      {:subject_absent, memory, transition.iri},
      {:transition_endpoint, memory, assertion.iri, transition.expected_predecessor},
      {:subject_present, attributes.evidence_graph_iri, source_decision},
      {:subject_present, attributes.policy_graph_iri, attributes.policy_iri}
    ] ++
      Enum.map(evidence, &{:subject_present, attributes.evidence_graph_iri, &1}) ++
      contradiction_guards(evidence, transition.next_state, attributes) ++
      replacement_guards(replacement, attributes)
  end

  defp contradiction_guards(evidence, state, attributes) when state in @review_states do
    Enum.map(evidence, fn evidence_iri ->
      {:triple_present, attributes.evidence_graph_iri, evidence_iri,
       @jf <> "evidenceClassification", RDF.iri(@concept <> "Contradictory")}
    end)
  end

  defp contradiction_guards(_evidence, _state, _attributes), do: []

  defp replacement_guards(%Assertion{} = replacement, attributes) do
    [
      {:subject_absent, replacement.memory_graph_iri, replacement.iri},
      {:subject_present, attributes.evidence_graph_iri, replacement.source_decision_iri}
    ] ++
      Enum.flat_map(replacement.source_claim_iris, fn claim ->
        [
          {:subject_present, attributes.evidence_graph_iri, claim},
          {:triple_present, attributes.evidence_graph_iri, claim, @jf <> "epistemicState",
           RDF.iri(@concept <> "Accepted")},
          {:triple_present, attributes.evidence_graph_iri, replacement.source_decision_iri,
           @jf <> "accepts", RDF.iri(claim)},
          {:object_absent, attributes.evidence_graph_iri, @jf <> "supersedes", claim},
          {:object_absent, attributes.evidence_graph_iri, @jf <> "rejects", claim},
          {:object_absent, attributes.evidence_graph_iri, @jf <> "contradicts", claim}
        ]
      end) ++
      Enum.map(replacement.source_evidence_iris, fn evidence ->
        {:subject_present, attributes.evidence_graph_iri, evidence}
      end)
  end

  defp replacement_guards(nil, _attributes), do: []

  defp replacement_allowed(assertion, %Assertion{} = replacement, state)
       when state in @terminal_with_replacement do
    if replacement.memory_graph_iri == assertion.memory_graph_iri and
         replacement.repository_iri == assertion.repository_iri and
         replacement.repository_scope_iri == assertion.repository_scope_iri and
         replacement.scope_iri == assertion.scope_iri and
         assertion.iri in replacement.supersedes_iris,
       do: :ok,
       else: :error
  end

  defp replacement_allowed(_assertion, nil, state) when state not in @terminal_with_replacement,
    do: :ok

  defp replacement_allowed(_assertion, _replacement, _state), do: :error

  defp evidence(values, state) when is_list(values) and length(values) <= 30 do
    values = values |> Enum.uniq() |> Enum.sort()

    if (state not in @review_states or values != []) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, values},
       else: :error
  end

  defp evidence(_values, _state), do: :error

  defp exact_revisions?(assertion, attributes) do
    expected = attributes[:expected_graph_revisions]

    required = [
      assertion.memory_graph_iri,
      attributes[:evidence_graph_iri],
      attributes[:policy_graph_iri]
    ]

    is_map(expected) and Map.keys(expected) |> Enum.sort() == Enum.sort(required) and
      is_integer(expected[assertion.memory_graph_iri]) and
      expected[assertion.memory_graph_iri] > 0 and
      is_integer(expected[attributes.evidence_graph_iri]) and
      expected[attributes.evidence_graph_iri] > 0 and
      is_integer(expected[attributes.policy_graph_iri]) and
      expected[attributes.policy_graph_iri] > 0
  end

  defp replacement_iri(%Assertion{} = replacement), do: replacement.iri
  defp replacement_iri(nil), do: nil

  defp replacement_iri(%Assertion{} = replacement, :source_decision, _fallback),
    do: replacement.source_decision_iri

  defp replacement_iri(nil, :source_decision, fallback), do: fallback

  defp policy_iri(_assertion, %Assertion{} = replacement), do: replacement.policy_iri
  defp policy_iri(assertion, nil), do: assertion.policy_iri

  defp command_iri(assertion, transition) do
    {:ok, iri} =
      ResourceIdentity.deterministic(
        :command_request,
        Enum.join([assertion.iri, transition.iri, "evolve-knowledge"], "\n")
      )

    iri
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
