defmodule JidoCode.Factory.ManagedCodingTopologyContractTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.TopologyContract

  @digest String.duplicate("a", 64)

  test "pins graph-owned topology, roles, budgets, and reconstruction watermark" do
    assert {:ok, contract} = TopologyContract.new(attributes())
    assert contract.jido_version == "2.3.2"
    assert contract.pod_revision == "jido-pod/2.3.2"
    assert Enum.map(contract.roles, & &1.name) == ["coder", "investigator", "reviewer"]
    assert "reconstruction_watermark" in TopologyContract.entities()
    assert "quarantine" in TopologyContract.transitions()

    projection = %{
      topology_iri: contract.topology_iri,
      revision: 1,
      profile_digest: @digest,
      watermark: String.duplicate("b", 64),
      state: :active
    }

    assert {:ok, %{desired_state: :active, watermark: watermark}} =
             TopologyContract.projection(contract, projection)

    assert watermark == projection.watermark
    assert {:error, error} = TopologyContract.projection(contract, %{projection | revision: 2})
    assert error.operation == :managed_coding_topology_projection
  end

  test "accepts only closed content-addressed packets with full correlation" do
    {:ok, contract} = TopologyContract.new(attributes())
    payload = ~s({"finding":"bounded"})

    packet = %{
      packet_type: "evidence",
      topology_iri: contract.topology_iri,
      delegation_iri: "https://jido.run/id/delegation/1",
      task_iri: "https://jido.run/id/task/1",
      attempt_iri: "https://jido.run/id/attempt/1",
      fence: 4,
      role: "investigator",
      sequence: 1,
      payload_digest: sha256(payload),
      payload: payload
    }

    assert :ok = TopologyContract.validate_packet(contract, packet)

    for invalid <- [
          Map.put(packet, :fence, 0),
          Map.put(packet, :role, "publisher"),
          Map.put(packet, :payload, payload <> "!"),
          Map.put(packet, :credential, "secret")
        ] do
      assert {:error, error} = TopologyContract.validate_packet(contract, invalid)
      assert error.operation == :managed_coding_topology_packet
    end
  end

  test "rejects unsupported Jido behavior and caller-selected modules or roles" do
    assert {:error, error} =
             TopologyContract.new(%{
               attributes()
               | jido_version: "2.3.3",
                 roles: [role("publisher", __MODULE__, :dynamic_manager)]
             })

    assert error.operation == :managed_coding_topology_contract
  end

  defp attributes do
    %{
      topology_iri: "https://jido.run/id/topology/phase-7",
      revision: 1,
      profile_digest: @digest,
      jido_version: "2.3.2",
      pod_revision: "jido-pod/2.3.2",
      roles: [
        role("investigator", JidoCode.Runtime.ManagedCoding.Agent, :investigator_manager),
        role("coder", JidoCode.Runtime.ManagedCoding.Agent, :coder_manager),
        role("reviewer", JidoCode.Runtime.ManagedCoding.Agent, :reviewer_manager)
      ],
      max_fan_out: 3,
      max_depth: 1,
      max_message_bytes: 8_192,
      restart_limit: 2,
      timeout_ms: 30_000,
      state: :evaluation
    }
  end

  defp role(name, module, manager) do
    %{
      name: name,
      module: module,
      manager: manager,
      activation: "lazy",
      capability_refs: [@digest],
      budget: %{
        max_messages: 4,
        max_input_bytes: 8_192,
        max_output_bytes: 8_192,
        max_tokens: 2_000,
        max_cost_microunits: 10_000,
        timeout_ms: 30_000
      }
    }
  end

  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
