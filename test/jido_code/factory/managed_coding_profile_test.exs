defmodule JidoCode.Factory.ManagedCodingProfileTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.Budget
  alias JidoCode.Factory.ManagedCoding.Profile
  alias JidoCode.Factory.ManagedCoding.Vocabulary

  test "requires every bounded safety dimension and only accepted enforcement" do
    assert {:ok, budget} = Budget.new(budget_attributes())
    assert Budget.limit(budget, :turns) == %{limit: 20, enforcement: :hard}

    assert {:error, _error} =
             budget_attributes()
             |> Map.delete(:disk_bytes)
             |> Budget.new()

    assert {:error, _error} =
             budget_attributes()
             |> put_in([:processes, :enforcement], :unavailable)
             |> Budget.new()

    assert {:error, _error} =
             budget_attributes()
             |> put_in([:turns, :enforcement], :observed_only)
             |> Budget.new()

    assert {:ok, _budget} =
             budget_attributes()
             |> put_in([:tokens, :enforcement], :next_effect)
             |> Budget.new()
  end

  test "pins every material component and computes a stable profile digest" do
    assert {:ok, budget} = Budget.new(budget_attributes())
    attributes = profile_attributes(budget)

    assert {:ok, first} = Profile.new(attributes)

    assert {:ok, second} =
             attributes
             |> Map.update!(:actor_iris, &Enum.reverse/1)
             |> Profile.new()

    assert first.profile_digest == second.profile_digest
    assert first.jido_version == "2.3.2"

    assert Profile.selectable?(first, %{
             task_class: "focused_change",
             actor_iri: iri("actor-a"),
             tenant_iri: iri("tenant"),
             repository_iri: iri("repository"),
             capability_iri: iri("capability")
           })

    refute Profile.selectable?(first, %{
             task_class: "focused_change",
             actor_iri: iri("actor-a"),
             tenant_iri: iri("tenant"),
             repository_iri: iri("other-repository"),
             capability_iri: iri("capability")
           })
  end

  test "fails closed for version drift, incomplete pins, and incoherent lifecycle" do
    assert {:ok, budget} = Budget.new(budget_attributes())
    base = profile_attributes(budget)

    for override <- [
          %{jido_version: "2.3.3"},
          %{strategy_revision: "latest"},
          %{state: :revoked, rollout_stage: :shadow},
          %{state: :enabled, rollout_stage: :disabled},
          %{actor_iris: []},
          %{task_classes: ["Arbitrary Task"]}
        ] do
      assert {:error, _error} = Profile.new(Map.merge(base, override))
    end
  end

  test "keeps protocol vocabularies closed" do
    assert Vocabulary.valid?(:runtime_phase, :awaiting_model)
    assert Vocabulary.valid?(:retry_class, :query_reconcilable)
    refute Vocabulary.valid?(:runtime_phase, :self_verified)
    refute Vocabulary.valid?(:runtime_phase, "running")
    assert Vocabulary.values(:unknown) == []
  end

  defp profile_attributes(budget) do
    digest = String.duplicate("a", 64)

    %{
      iri: iri("managed-profile"),
      revision: 1,
      jido_version: "2.3.2",
      strategy_revision: digest,
      prompt_bundle_revision: digest,
      model_access_profile_iri: iri("model-profile"),
      context_policy_revision: digest,
      memory_policy_revision: digest,
      tool_catalog_revision: digest,
      adapter_set_revision: digest,
      sandbox_profile_revision: digest,
      verifier_profile_revision: digest,
      candidate_schema_revision: digest,
      budget: budget,
      state: :enabled,
      rollout_stage: :shadow,
      task_classes: ["focused_change", "inspect"],
      actor_iris: [iri("actor-b"), iri("actor-a")],
      tenant_iris: [iri("tenant")],
      repository_iris: [iri("repository")],
      capability_iris: [iri("capability")]
    }
  end

  defp budget_attributes do
    Map.new(Budget.dimensions(), fn dimension ->
      {dimension, %{limit: if(dimension == :turns, do: 20, else: 1_000), enforcement: :hard}}
    end)
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
