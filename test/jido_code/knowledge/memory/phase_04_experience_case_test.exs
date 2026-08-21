defmodule JidoCode.Knowledge.Memory.Phase04ExperienceCaseTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ExperienceCase
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-21 12:00:00Z]

  test "builds every closed non-authoritative case class with exact lineage" do
    for case_class <- ExperienceCase.case_classes() do
      assert {:ok, experience} =
               base_attributes()
               |> Map.put(:case_class, case_class)
               |> Map.put(:problem_signature, digest(to_string(case_class)))
               |> Knowledge.experience_case()

      assert experience.case_class == case_class
      assert experience.non_authoritative?
      assert experience.transition.next_state == :candidate
      assert experience.source_event_iris != []
      assert experience.source_evidence_iris != []

      assert Enum.any?(ExperienceCase.statements(experience), fn statement ->
               {subject, predicate, object} = RDF.Triple.new(statement)

               to_string(subject) == experience.iri and
                 String.ends_with?(to_string(predicate), "nonAuthoritative") and
                 RDF.Literal.value(object) == true
             end)
    end
  end

  test "resolves only contiguous governed lifecycle transitions" do
    assert {:ok, experience} = Knowledge.experience_case(base_attributes())

    assert {:ok, validated} =
             transition(experience, experience.transition, :candidate, :validated, 1)

    assert {:ok, stale} = transition(experience, validated, :validated, :stale, 2)
    assert {:ok, revalidated} = transition(experience, stale, :stale, :validated, 3)
    assert {:ok, superseded} = transition(experience, revalidated, :validated, :superseded, 4)

    assert {:ok, endpoint} =
             Knowledge.resolve_experience_lifecycle([
               superseded,
               experience.transition,
               stale,
               validated,
               revalidated
             ])

    assert endpoint.state == :superseded
    assert endpoint.revision == 4

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.resolve_experience_lifecycle([
               experience.transition,
               stale
             ])

    assert {:error, %{kind: :invalid_input}} =
             transition(experience, experience.transition, :candidate, :candidate, 1)
  end

  test "retains MG4 lineage invariants after later memory gates activate" do
    assert GraphRegistry.revision() == "2.4.0"
    assert {:ok, %{enabled: true}} = GraphRegistry.fetch(:experience)
    assert Guardrails.revision() == "1.5.0"
    assert Guardrails.feature_enabled?(:experience_writer)
    refute Map.has_key?(Guardrails.disabled_features(), :experience_writer)
    assert Guardrails.feature_enabled?(:content_lifecycle_writer)

    assert {:error, %{kind: :invalid_input}} =
             base_attributes()
             |> Map.put(:source_event_iris, [])
             |> Knowledge.experience_case()

    assert {:error, %{kind: :invalid_input}} =
             base_attributes()
             |> put_in([:delayed_outcome, :observed_at], DateTime.add(@now, 1, :second))
             |> Knowledge.experience_case()
  end

  defp transition(experience, prior, prior_state, next_state, revision) do
    Knowledge.experience_transition(%{
      case_iri: experience.iri,
      prior_state: prior_state,
      next_state: next_state,
      revision: revision,
      expected_predecessor: prior.iri,
      actor_iri: resource(:authorization_grant, "validator-#{revision}"),
      cause_iri: resource(:evidence_claim, "cause-#{revision}"),
      reason: "governed experience transition #{revision}",
      recorded_at: DateTime.add(@now, revision, :second)
    })
  end

  defp base_attributes do
    repository = resource(:repository_snapshot, "phase-04-repository")
    {:ok, graph} = GraphRegistry.graph_iri(:experience, %{repository: repository})

    %{
      repository_iri: repository,
      repository_scope_iri: resource(:execution_context, "phase-04-repository-scope"),
      experience_graph_iri: graph,
      repository_version: "tree-1234",
      problem_signature: digest("failure-signature"),
      task_class: :repair,
      plan_phase: "memory-phase-04",
      environment: %{framework: "phoenix", version: "1.8", os: "linux", runtime: "otp-28"},
      dependencies: [%{name: "phoenix", version: "1.8.1"}],
      symptoms: ["request returns an unavailable result"],
      reproduction: ["run the bounded catalog query"],
      inspected_files: ["lib/example.ex"],
      inspected_symbols: ["Example.run/1"],
      interventions: ["remove unsupported graph-local binding"],
      disproved_assumptions: ["the backend accepts every parsed algebra node"],
      terminal_intervention: "use graph revision metadata as the source pin",
      verification_iris: [resource(:verification_check, "phase-04-check")],
      delayed_outcome: %{
        outcome: :success,
        evidence_iri: resource(:evidence_claim, "phase-04-delayed"),
        observed_at: @now
      },
      exceptions: [],
      limitations: ["validated only for the pinned framework version"],
      source_event_iris: [resource(:execution_event, "phase-04-event")],
      source_artifact_iris: [resource(:generated_artifact, "phase-04-artifact")],
      source_evidence_iris: [resource(:evidence_claim, "phase-04-evidence")],
      case_class: :success,
      effective_at: @now,
      recorded_at: @now,
      actor_iri: resource(:authorization_grant, "phase-04-author"),
      cause_iri: resource(:evidence_claim, "phase-04-cause")
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
