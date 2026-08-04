defmodule JidoCode.Knowledge.Memory.Adoption do
  @moduledoc "Governed promotion of accepted claims into a repository memory graph."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Decision.GoalOutcome
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.Assertion
  alias JidoCode.Knowledge.Memory.Graph, as: MemoryGraph
  alias JidoCode.Knowledge.ResourceIdentity

  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @spec record_command(Assertion.t(), GoalOutcome.t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def record_command(assertion, decision, attributes, options \\ [])

  def record_command(
        %Assertion{} = assertion,
        %GoalOutcome{} = decision,
        attributes,
        options
      )
      when is_map(attributes) and is_list(options) do
    memory_graph = assertion.memory_graph_iri
    expected = attributes[:expected_graph_revisions]

    with true <- assertion.source_decision_iri == decision.iri,
         true <- assertion.recorded_at == attributes[:recorded_at],
         true <- is_map(expected) and exact_revisions?(assertion, attributes),
         memory_revision when is_integer(memory_revision) and memory_revision >= 0 <-
           expected[memory_graph],
         {:ok, target} <-
           MemoryGraph.target(
             memory_graph,
             memory_revision,
             decision.scope_iri,
             assertion.activity_iri,
             assertion.recorded_at,
             Assertion.statements(assertion)
           ),
         {:ok, envelope} <-
           CommandEnvelope.new(command(assertion, decision, attributes, target), options) do
      {:ok, envelope}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:adopt_knowledge)
    end
  rescue
    _error -> invalid(:adopt_knowledge)
  end

  def record_command(_assertion, _decision, _attributes, _options),
    do: invalid(:adopt_knowledge)

  defp command(assertion, decision, attributes, target) do
    command_iri = command_iri(assertion)

    %{
      command_type: "AdoptKnowledge",
      command_version: "1.7.0",
      command_iri: command_iri,
      principal_iri: attributes[:principal_iri],
      actor_iri: assertion.adoption_actor_iri,
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: decision.scope_iri,
      idempotency_key: command_iri,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: decision.iri,
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: attributes[:expected_graph_revisions],
      reason: attributes[:reason],
      payload: %{
        changes: [target],
        guards: guards(assertion, decision, attributes),
        assertion_iri: assertion.iri,
        source_decision_iri: decision.iri,
        prompt_context: nil,
        direct_side_effects: []
      }
    }
  end

  defp guards(assertion, decision, attributes) do
    memory_graph = assertion.memory_graph_iri
    evidence_graph = attributes.evidence_graph_iri

    [
      {:subject_absent, memory_graph, assertion.iri},
      {:subject_absent, memory_graph, assertion.activity_iri},
      {:subject_present, evidence_graph, decision.iri},
      {:subject_present, attributes.policy_graph_iri, assertion.policy_iri}
    ] ++
      Enum.flat_map(assertion.source_claim_iris, fn claim ->
        [
          {:subject_present, evidence_graph, claim},
          {:triple_present, evidence_graph, claim, @jf <> "epistemicState",
           RDF.iri(@concept <> "Accepted")},
          {:triple_present, evidence_graph, decision.iri, @jf <> "accepts", RDF.iri(claim)},
          {:object_absent, evidence_graph, @jf <> "supersedes", claim},
          {:object_absent, evidence_graph, @jf <> "rejects", claim},
          {:object_absent, evidence_graph, @jf <> "contradicts", claim}
        ]
      end) ++
      Enum.map(assertion.source_evidence_iris, fn evidence ->
        {:subject_present, evidence_graph, evidence}
      end) ++
      Enum.map(assertion.supporting_assertion_iris, fn support ->
        {:subject_present, memory_graph, support}
      end) ++
      cohort_guards(assertion, attributes)
  end

  defp cohort_guards(%{scope_kind: :cohort} = assertion, attributes) do
    Enum.map(assertion.cohort_evidence_iris, fn evidence ->
      {:subject_present, attributes.cohort_graph_iri, evidence}
    end)
  end

  defp cohort_guards(_assertion, _attributes), do: []

  defp exact_revisions?(assertion, attributes) do
    expected = attributes.expected_graph_revisions

    required =
      [
        assertion.memory_graph_iri,
        attributes.evidence_graph_iri,
        attributes.policy_graph_iri
      ] ++ if(assertion.scope_kind == :cohort, do: [attributes[:cohort_graph_iri]], else: [])

    Map.keys(expected) |> Enum.sort() == Enum.sort(required) and
      is_integer(expected[assertion.memory_graph_iri]) and
      expected[assertion.memory_graph_iri] >= 0 and
      is_integer(expected[attributes.evidence_graph_iri]) and
      expected[attributes.evidence_graph_iri] > 0 and
      is_integer(expected[attributes.policy_graph_iri]) and
      expected[attributes.policy_graph_iri] > 0 and
      cohort_revision_exact?(assertion, attributes) and
      cohort_revision?(assertion, attributes)
  end

  defp cohort_revision_exact?(%{scope_kind: :cohort} = assertion, attributes),
    do:
      assertion.source_graph_revisions[attributes.cohort_graph_iri] ==
        attributes.expected_graph_revisions[attributes.cohort_graph_iri]

  defp cohort_revision_exact?(_assertion, _attributes), do: true

  defp cohort_revision?(%{scope_kind: :cohort}, attributes),
    do:
      is_integer(attributes.expected_graph_revisions[attributes.cohort_graph_iri]) and
        attributes.expected_graph_revisions[attributes.cohort_graph_iri] > 0

  defp cohort_revision?(_assertion, _attributes), do: true

  defp command_iri(assertion) do
    {:ok, iri} =
      ResourceIdentity.deterministic(:command_request, assertion.iri <> "\nadopt-knowledge")

    iri
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
