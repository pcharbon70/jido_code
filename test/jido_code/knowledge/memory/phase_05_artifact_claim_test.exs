defmodule JidoCode.Knowledge.Memory.Phase05ArtifactClaimTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ArtifactClaim
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-21 16:00:00Z]

  test "binds exact artifact, verification, evidence strength, and time" do
    for strength <- ArtifactClaim.evidence_strengths() do
      assert {:ok, claim} = Knowledge.artifact_claim(attributes(strength))
      assert claim.evidence_strength == strength
      assert claim.transition.next_state == :fresh
      assert Knowledge.artifact_claim_current?(claim, current(claim))

      refute Knowledge.artifact_claim_current?(claim, %{
               current(claim)
               | content_digest: digest("changed")
             })

      refute Knowledge.artifact_claim_current?(claim, %{
               current(claim)
               | verification_environment: "otp-29"
             })
    end

    assert {:error, %{kind: :invalid_input}} =
             attributes(:strong)
             |> Map.put(:runtime_success_only?, true)
             |> Knowledge.artifact_claim()
  end

  test "appends exact freshness states without changing the original claim" do
    {:ok, claim} = Knowledge.artifact_claim(attributes(:strong))

    for state <- [:stale, :contradicted, :invalidated, :superseded] do
      changed =
        current(claim)
        |> Map.put(:content_digest, digest("#{state}-content"))
        |> Map.put(:contradicted?, state == :contradicted)
        |> Map.put(:invalidated?, state == :invalidated)
        |> Map.put(
          :superseded_by,
          if(state == :superseded, do: resource(:artifact_claim, "replacement"), else: nil)
        )

      assert {:ok, transition} =
               Knowledge.evaluate_artifact_claim_drift(claim, changed, claim.transition, %{
                 actor_iri: resource(:authorization_grant, "freshness-actor-#{state}"),
                 cause_iri: resource(:evidence_claim, "freshness-cause-#{state}"),
                 recorded_at: DateTime.add(@now, 1, :second)
               })

      assert transition.next_state == state
      assert claim.transition.next_state == :fresh
    end
  end

  test "publishes evidence-only commands and current plus historical query products" do
    {:ok, claim} = Knowledge.artifact_claim(attributes(:strong))

    {:ok, evidence_graph} =
      GraphRegistry.graph_iri(:evidence, %{repository: claim.repository_iri})

    assert {:ok, command} =
             Knowledge.record_artifact_claim(
               claim,
               evidence_graph,
               1,
               command_attributes(evidence_graph), clock: fn -> @now end)

    assert command.command_type == "RecordArtifactClaim"
    assert command.command_version == CommandRegistry.procedure_version()

    assert {:ok, definition} =
             CommandRegistry.resolve(command.command_type, command.command_version)

    assert definition.capability == :evidence
    refute definition.capability in [:execution, :control]

    for name <- [:artifact_claims, :historical_test_risk] do
      assert {:ok, query} = QueryCatalog.fetch(name, QueryCatalog.procedure_version())
      assert query.graph_families == [:evidence]
      assert String.contains?(query.source, "{{instant}}")
    end
  end

  defp attributes(strength) do
    repository = resource(:repository_snapshot, "artifact-claim-repository")
    snapshot = resource(:repository_snapshot, "artifact-claim-snapshot")

    %{
      repository_iri: repository,
      repository_revision_iri: snapshot,
      artifact_iri: resource(:source_artifact, "artifact-claim-source"),
      path: "lib/example.ex",
      symbol: "Example.run/1",
      selector: "#example-test",
      content_digest: digest("source-content"),
      claim: "Example.run/1 returns an explicit error for unsupported input.",
      verification_command: "mix test test/example_test.exs",
      verification_environment: "elixir-1.19/otp-28/linux",
      evidence_iri: resource(:evidence_claim, "artifact-claim-evidence"),
      evidence_strength: strength,
      valid_at: @now,
      checked_at: @now,
      actor_iri: resource(:authorization_grant, "artifact-claim-evaluator"),
      cause_iri: resource(:verification_activity, "artifact-claim-verification"),
      runtime_success_only?: false
    }
  end

  defp current(claim) do
    %{
      repository_revision_iri: claim.repository_revision_iri,
      artifact_iri: claim.artifact_iri,
      content_digest: claim.content_digest,
      symbol: claim.symbol,
      verification_environment: claim.verification_environment,
      verification_command: claim.verification_command,
      evidence_iri: claim.evidence_iri
    }
  end

  defp command_attributes(graph) do
    %{
      repository_scope_iri: resource(:execution_context, "artifact-claim-scope"),
      principal_iri: resource(:authorization_grant, "artifact-claim-principal"),
      actor_iri: resource(:authorization_grant, "artifact-claim-actor"),
      delegated_agent_iri: nil,
      delegation_iri: nil,
      correlation_iri: resource(:command_request, "artifact-claim-correlation"),
      causation_iri: resource(:verification_activity, "artifact-claim-command-cause"),
      expected_dataset_revision: 7,
      expected_graph_revisions: %{graph => 1},
      recorded_at: @now,
      reason: "record independently verified artifact claim"
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
