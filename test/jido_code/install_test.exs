defmodule JidoCode.InstallTest do
  use ExUnit.Case, async: false

  alias JidoCode.Install
  alias JidoCode.TestSupport.Phase04Fixture

  test "bootstraps a pristine dataset exactly once through ontology and authority commands",
       context do
    substrate = Phase04Fixture.start!(context)
    actor = Phase04Fixture.resource!("phase-10-install-actor")

    identity = %{
      factory_iri: Phase04Fixture.resource!("phase-10-install-factory"),
      factory_scope_iri: Phase04Fixture.scope!(:factory, "phase-10-install-factory"),
      principal_iri: actor,
      actor_iri: actor
    }

    options = [
      store_server: substrate.store_server,
      writer: substrate.writer,
      identity: identity
    ]

    assert {:ok, receipt} =
             Install.bootstrap("phase-04-integration-operator-token", options)

    assert receipt.ontology_version == "1.0.0"
    assert receipt.actor_iri == actor
    assert receipt.authority_dataset_revision == 2
    assert byte_size(receipt.release_contract_digest) == 64

    assert {:error, error} =
             Install.bootstrap("phase-04-integration-operator-token", options)

    assert error.kind == :conflict
    assert error.operation == :clean_install_already_initialized
  end
end
