defmodule JidoCode.Knowledge.Ontology.EvolutionTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Ontology.Evolution

  test "classifies ontology and operational shape changes explicitly" do
    assert {:ok, :additive_compatible} = Evolution.classify(%{added_terms: ["NewClass"]})
    assert {:ok, :validation_only} = Evolution.classify(%{shape_changes: ["ClaimShape"]})

    assert {:ok, :behaviorally_stricter} =
             Evolution.classify(%{behaviorally_stricter?: true})

    assert {:ok, :transform_required} =
             Evolution.classify(%{
               meaning_changes: ["old predicate semantics"],
               transformer_available?: true
             })

    assert {:ok, :breaking} = Evolution.classify(%{removed_terms: ["OldClass"]})
  end

  test "requires new versions and attributable transformers for changed meaning" do
    assert {:ok, plan} =
             Evolution.plan("0.9.0", "1.0.0", :transform_required, %{
               transformer_version: "2.1.0",
               rollback_posture: :retain_source
             })

    assert plan.migration_required?
    assert plan.transformer_version == "2.1.0"

    assert {:error, %Error{operation: :ontology_version_reuse}} =
             Evolution.plan("1.0.0", "1.0.0", :transform_required, %{
               transformer_version: "2.1.0"
             })
  end

  test "blocks affected writes and startup for missing or partial migrations" do
    assert :ok = Evolution.ensure_writable("1.0.0", "1.0.0", :breaking, :missing)
    assert :ok = Evolution.ensure_writable("0.9.0", "1.0.0", :additive_compatible, :missing)
    assert :ok = Evolution.ensure_writable("0.9.0", "1.0.0", :transform_required, :complete)

    assert {:error, %Error{kind: :incompatible}} =
             Evolution.ensure_writable("0.9.0", "1.0.0", :transform_required, :partial)

    assert {:error, %Error{operation: :required_graph_migration}} =
             Evolution.startup_status([
               %{
                 ontology_version: "0.9.0",
                 classification: :transform_required,
                 migration_state: :missing
               }
             ])
  end
end
