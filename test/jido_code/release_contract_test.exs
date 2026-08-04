defmodule JidoCode.ReleaseContractTest do
  use ExUnit.Case, async: true

  alias JidoCode.ReleaseContract

  test "pins and verifies every executable release contract" do
    assert :ok = ReleaseContract.verify()
    manifest = ReleaseContract.manifest()

    assert manifest.application == "0.1.0"
    assert manifest.ontology == "1.0.0"
    assert manifest.shapes == "1.0.0"
    assert manifest.query_catalog == "1.7.0"
    assert manifest.store_schema == 1
    assert manifest.backend_schema == 2
    assert String.starts_with?(manifest.runtime_contract, "jido:2.3.2/")
    assert byte_size(manifest.query_digest) == 64
    assert byte_size(manifest.reasoning_digest) == 64
    assert byte_size(ReleaseContract.digest()) == 64
  end

  test "declares the only compatible migration order" do
    assert ReleaseContract.migration_order() == [
             :application,
             :ontology,
             :shapes,
             :query_catalog,
             :reasoning,
             :backend_schema,
             :store_schema,
             :graphs,
             :derived_rebuild,
             :acceptance
           ]
  end
end
