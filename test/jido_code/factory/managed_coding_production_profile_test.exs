defmodule JidoCode.Factory.ManagedCodingProductionProfileTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.Budget
  alias JidoCode.Factory.ManagedCoding.ProductionProfile
  alias JidoCode.Factory.ManagedCoding.ProfileChangeControl

  @digest String.duplicate("a", 64)

  test "pins every material production component and the complete operating envelope" do
    profile = profile(1, :shadow)

    assert Map.keys(profile.components) |> Enum.sort() ==
             ProductionProfile.components() |> Enum.sort()

    assert profile.check_limit == 12
    assert profile.retry_limit == 2
    assert profile.signed_digest == profile.profile_digest

    assert ProductionProfile.admits?(profile, eligible_request())
    refute ProductionProfile.admits?(profile, %{eligible_request() | language: "ruby"})

    refute ProductionProfile.admits?(profile, %{
             eligible_request()
             | matched_exclusions: ["generated_repo"]
           })

    refute ProductionProfile.admits?(profile, %{
             eligible_request()
             | requested_capabilities: ["automatic_merge"]
           })
  end

  test "rejects missing, mismatched, expired, unknown, and unapproved components without fallback" do
    profile = profile(1, :shadow)
    inventory = Map.put(profile.components, :approved_profile_digest, profile.profile_digest)
    assert ProductionProfile.compatible?(profile, inventory, ~U[2026-08-25 12:30:00Z])

    refute ProductionProfile.compatible?(
             profile,
             Map.delete(inventory, :tool_adapter),
             ~U[2026-08-25 12:30:00Z]
           )

    refute ProductionProfile.compatible?(
             profile,
             put_in(inventory, [:sandbox_image, :digest], String.duplicate("b", 64)),
             ~U[2026-08-25 12:30:00Z]
           )

    refute ProductionProfile.compatible?(
             profile,
             %{inventory | approved_profile_digest: String.duplicate("b", 64)},
             ~U[2026-08-25 12:30:00Z]
           )

    refute ProductionProfile.compatible?(profile, inventory, ~U[2026-09-02 00:00:00Z])
  end

  test "forces signed digest change control and reevaluation for every material change" do
    current = profile(1, :shadow)
    proposed = profile(2, :pilot, %{check_limit: 13})

    assert {:ok, change} =
             ProfileChangeControl.propose(
               current,
               proposed,
               iri("release-approver"),
               "raise check ceiling"
             )

    assert change.requires_reevaluation
    refute change.prior_qualification_valid
    refute change.publication_authority
    assert change.to_digest == proposed.signed_digest
  end

  defp profile(revision, stage, overrides \\ %{}) do
    attributes =
      %{
        profile_iri: iri("production-profile"),
        revision: revision,
        components:
          Map.new(ProductionProfile.components(), &{&1, %{revision: @digest, digest: @digest}}),
        budget: budget(),
        check_limit: 12,
        retry_limit: 2,
        envelope: %{
          repository_classes: ["small", "medium"],
          task_classes: ["inspect", "defect_repair", "focused_feature"],
          languages: ["elixir"],
          dependency_policies: ["locked_only"],
          network_modes: ["deny"],
          actor_requirements: ["authenticated", "pilot_trained"],
          exclusion_rules: ["generated_repo", "regulated_data"],
          unavailable_capabilities: ["automatic_approval", "automatic_merge", "multi_agent"]
        },
        state: :approved,
        rollout_stage: stage,
        approved_at: ~U[2026-08-25 12:00:00Z],
        expires_at: ~U[2026-09-01 12:00:00Z],
        signer_iri: iri("release-approver")
      }
      |> Map.merge(overrides)

    attributes =
      Map.put(attributes, :signed_digest, ProductionProfile.material_digest(attributes))

    {:ok, profile} = ProductionProfile.new(attributes)
    profile
  end

  defp budget do
    attributes =
      Map.new(Budget.dimensions(), fn dimension ->
        enforcement = if dimension in [:tokens, :cost_microunits], do: :next_effect, else: :hard
        {dimension, %{limit: 1_000, enforcement: enforcement}}
      end)

    {:ok, budget} = Budget.new(attributes)
    budget
  end

  defp eligible_request do
    %{
      repository_class: "small",
      task_class: "defect_repair",
      language: "elixir",
      dependency_policy: "locked_only",
      network_mode: "deny",
      actor_attributes: ["authenticated", "pilot_trained"],
      requested_capabilities: [],
      matched_exclusions: []
    }
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
