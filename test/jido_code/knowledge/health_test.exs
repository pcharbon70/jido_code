defmodule JidoCode.Knowledge.HealthTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Health

  test "reaches ready only after ordered store and ontology verification" do
    starting = Health.new()
    refute Health.ready?(starting)
    assert {:error, %Error{kind: :conflict}} = Health.ontology_verified(starting)

    assert {:ok, verifying_store} = Health.begin_verification(starting)
    assert verifying_store.state == :verifying_store
    refute Health.ready?(verifying_store)

    assert {:ok, verifying_ontology} = Health.store_verified(verifying_store)
    assert verifying_ontology.state == :verifying_ontology
    refute Health.ready?(verifying_ontology)

    assert {:ok, ready} = Health.ontology_verified(verifying_ontology)
    assert Health.ready?(ready)
    assert :ok = Health.gate(ready, :execute_command)
  end

  test "fails closed with stable backend health states" do
    for {kind, state} <- [
          unavailable: :unavailable,
          locked: :locked,
          incompatible: :incompatible,
          corrupt: :corrupt,
          persistence_failure: :degraded
        ] do
      error = Error.new(kind, :open_store)
      health = Health.fail(Health.new(), error)

      assert health.state == state
      refute Health.ready?(health)
      assert {:error, ^error} = Health.gate(health, :execute_command)
    end
  end
end
