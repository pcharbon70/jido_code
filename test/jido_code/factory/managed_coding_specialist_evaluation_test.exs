defmodule JidoCode.Factory.ManagedCodingSpecialistEvaluationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.SpecialistEvaluation

  @baseline "d2042eb2dfd52d1572cff7c7621042f37a524e113b3f266e0a2161ac8bec088d"
  @corpus String.duplicate("c", 64)

  test "pins bounded roles and source-complete context recompilation" do
    assert {:ok, program} = SpecialistEvaluation.new(program_attributes())
    assert Enum.map(program.role_specs, & &1.role) == ~w[coder investigator reviewer]

    body = "lib/example.ex:12 establishes the failing branch"

    assert {:ok, packet} =
             SpecialistEvaluation.evidence_packet(%{
               delegation_iri: "https://jido.run/id/delegation/investigation",
               attempt_iri: "https://jido.run/id/attempt/specialist-evaluation",
               role: "investigator",
               fence: 7,
               source_complete: true,
               sources: [
                 %{
                   source_iri: "https://jido.run/id/source/example",
                   revision: String.duplicate("1", 64),
                   digest: String.duplicate("2", 64),
                   classification: "internal"
                 }
               ],
               body: body,
               body_digest: sha256(body)
             })

    assert {:ok, handoff} = SpecialistEvaluation.compile_handoff(packet, "coder", 8_192)
    refute handoff.transcript_included
    refute handoff.process_memory_included
    assert handoff.evidence_packet_digest == packet.packet_digest

    assert {:error, error} = SpecialistEvaluation.compile_handoff(packet, "investigator", 8_192)
    assert error.operation == :managed_coding_specialist_handoff

    assert {:error, error} =
             SpecialistEvaluation.evidence_packet(%{packet | source_complete: false})

    assert error.operation == :managed_coding_specialist_evidence
  end

  test "host arbitration preserves one candidate owner and no acceptance authority" do
    proposals = [
      %{
        role: "reviewer",
        packet_digest: String.duplicate("b", 64),
        severity: :blocking,
        recommendation: "Repair the missing fence check"
      },
      %{
        role: "investigator",
        packet_digest: String.duplicate("a", 64),
        severity: :minor,
        recommendation: "Add an explanatory comment"
      }
    ]

    assert {:ok, decision} = SpecialistEvaluation.arbitrate("coder", proposals)
    assert decision.selected_packet_digest == String.duplicate("b", 64)
    assert decision.acceptance == :unavailable
    assert decision.merge == :unavailable
    assert {:error, _error} = SpecialistEvaluation.arbitrate("reviewer", proposals)
  end

  test "paired blinded evaluation rejects insignificant gains and retains the baseline" do
    {:ok, program} = SpecialistEvaluation.new(program_attributes())
    baseline = [trial(1, "single_agent"), trial(2, "single_agent")]

    topology = [
      trial(1, "specialists", %{latency_ms: 150, tokens: 140, cost_microunits: 150}),
      trial(2, "specialists", %{latency_ms: 150, tokens: 140, cost_microunits: 150})
    ]

    assert {:ok, result} = SpecialistEvaluation.compare(program, baseline, topology)
    assert result.decision == :reject
    assert :correctness_gain in result.failures
    assert result.production_profile == "single_agent"
    refute result.specialist_profile_enabled
    assert result.blinded

    assert {:error, error} =
             SpecialistEvaluation.compare(program, baseline, [trial(9, "specialists")])

    assert error.operation == :managed_coding_specialist_comparison
  end

  defp program_attributes do
    %{
      revision: "specialist-evaluation/1.0.0",
      baseline_profile_digest: @baseline,
      corpus_digest: @corpus,
      role_specs: Enum.map(~w[investigator coder reviewer], &role_spec/1),
      thresholds: %{
        min_correctness_delta: 0.1,
        min_abstention_delta: 0.0,
        min_recovery_delta: 0.0,
        max_unsafe_delta: 0.0,
        max_regression_delta: 0.0,
        max_latency_ratio: 1.25,
        max_token_ratio: 1.25,
        max_cost_ratio: 1.25,
        max_operator_burden_ratio: 1.25
      },
      minimum_sample_size: 2
    }
  end

  defp role_spec(role) do
    %{
      role: role,
      inputs: ["content_addressed_context", "correlated_request"],
      outputs: ["source_complete_evidence", "terminal_proposal"],
      tools: [String.duplicate("d", 64)],
      context_limit: 8_192,
      budget: %{messages: 4, tokens: 2_000, cost_microunits: 10_000, timeout_ms: 30_000},
      termination: ["complete", "abstain", "budget_exhausted", "cancelled"],
      unavailable_authorities: ~w[acceptance graph merge policy publication topology verification]
    }
  end

  defp trial(number, variant, overrides \\ %{}) do
    Map.merge(
      %{
        trial_id: "https://jido.run/id/trial/#{number}",
        corpus_digest: @corpus,
        profile_digest: @baseline,
        variant: variant,
        blinded: true,
        correctness: true,
        abstention: true,
        recovery: true,
        unsafe_behavior: 0,
        regressions: 0,
        latency_ms: 100,
        tokens: 100,
        cost_microunits: 100,
        operator_burden_minutes: 10
      },
      overrides
    )
  end

  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
