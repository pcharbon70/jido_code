defmodule JidoCode.Factory.Harness.PhaseH08AutonomousMergeTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Extensions.AutonomousMerge.Authority
  alias JidoCode.Factory.Extensions.AutonomousMerge.Pilot
  alias JidoCode.Factory.Extensions.AutonomousMerge.Policy
  alias JidoCode.Knowledge.ResourceIdentity

  @digest "sha256:" <> String.duplicate("a", 64)

  test "the current policy records the missing ADR and cannot express merge authority" do
    policy = Policy.current()

    assert policy.status == :blocked
    assert policy.adr_status == :missing
    refute policy.autonomous_merge_authorized
    assert policy.human_merge_required

    assert policy.prerequisites == [
             :separate_accepted_adr,
             :release_gate,
             :production_shadow_evidence,
             :pull_request_evidence
           ]

    assert policy.immediate_disable_triggers == [
             :evidence_mismatch,
             :protected_branch_mutation,
             :sandbox_escape,
             :secret_exposure,
             :stale_fence
           ]

    assert Policy.valid?(policy)
    assert Policy.contract_version() == "1.0.0"
  end

  test "a fully evidenced future pilot is still human-merge shadow only" do
    policy = Policy.current()
    assert {:ok, pilot} = Pilot.new(policy, pilot_attributes(policy))
    assert Pilot.valid?(pilot, policy)
    assert pilot.authority == :human_merge_shadow
    assert pilot.human_merge_required
    refute pilot.autonomous_merge_authorized

    assert {:ok, review} = Authority.shadow_review(policy, pilot)
    assert review.status == :human_merge_required
    assert review.authority == :shadow_only
    refute review.autonomous_merge_authorized

    assert {:error, %{operation: :autonomous_merge_blocked}} =
             Authority.authorize(policy, pilot)
  end

  test "future pilots reject risk, irreversibility, missing triggers, and human-merge removal" do
    policy = Policy.current()
    attributes = pilot_attributes(policy)

    invalid = [
      Map.put(attributes, :risk, :medium),
      Map.put(attributes, :reversible, false),
      Map.put(attributes, :human_merge_required, false),
      Map.put(attributes, :immediate_disable_triggers, [:secret_exposure]),
      Map.put(attributes, :task_class, :database_migration)
    ]

    for value <- invalid do
      assert {:error, %{operation: :autonomous_merge_pilot}} = Pilot.new(policy, value)
    end
  end

  test "ADR, release, shadow, pull-request, and rollback evidence are all digest bound" do
    policy = Policy.current()
    attributes = pilot_attributes(policy)

    for key <- [
          :accepted_adr_digest,
          :release_gate_digest,
          :production_shadow_digest,
          :pull_request_evidence_digest,
          :rollback_plan_digest
        ] do
      forged = put_in(attributes, [:evidence, key], "sha256:forged")
      assert {:error, %{operation: :autonomous_merge_evidence}} = Pilot.new(policy, forged)
    end

    unknown = Map.put(attributes.evidence, :rollout_stage_authorized, true)

    assert {:error, %{operation: :autonomous_merge_evidence}} =
             attributes
             |> Map.put(:evidence, unknown)
             |> then(&Pilot.new(policy, &1))
  end

  test "tampering with the blocker or pilot cannot create authority" do
    policy = Policy.current()
    {:ok, pilot} = Pilot.new(policy, pilot_attributes(policy))

    tampered_policy = %{policy | autonomous_merge_authorized: true}
    tampered_pilot = %{pilot | autonomous_merge_authorized: true, authority: :merge}

    refute Policy.valid?(tampered_policy)
    refute Pilot.valid?(tampered_pilot, policy)

    assert {:error, %{operation: :autonomous_merge_blocked}} =
             Authority.authorize(tampered_policy, pilot)

    assert {:error, %{operation: :autonomous_merge_blocked}} =
             Authority.authorize(policy, tampered_pilot)
  end

  defp pilot_attributes(policy) do
    %{
      policy_digest: policy.digest,
      pilot_iri: resource!(:knowledge_assertion, "merge-pilot"),
      task_iri: resource!(:task_proposal, "merge-pilot-task"),
      task_class: :documentation,
      risk: :low,
      reversible: true,
      evidence: %{
        accepted_adr_iri: resource!(:knowledge_assertion, "future-merge-adr"),
        accepted_adr_digest: @digest,
        release_gate_iri: resource!(:evidence_bundle, "future-merge-release"),
        release_gate_digest: @digest,
        production_shadow_iri: resource!(:evidence_bundle, "future-merge-shadow"),
        production_shadow_digest: @digest,
        pull_request_evidence_iri: resource!(:evidence_bundle, "future-merge-pr"),
        pull_request_evidence_digest: @digest,
        rollback_plan_iri: resource!(:plan_proposal, "future-merge-rollback"),
        rollback_plan_digest: @digest
      },
      immediate_disable_triggers: policy.immediate_disable_triggers,
      human_merge_required: true
    }
  end

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h08-merge-#{seed}")
    iri
  end
end
