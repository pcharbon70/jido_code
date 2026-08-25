defmodule JidoCode.Factory.ManagedCodingAgentOSDecisionTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.AgentOSDecision

  test "inventories duplicate services and rejects competing persistence" do
    assert {:ok, result} = AgentOSDecision.evaluate(attributes())
    assert result.decision == :reject
    assert result.adapter == :none
    assert result.graph_authority == :exclusive
    assert result.persistence_conflict
    refute result.dependency_present
    assert result.novel_benefits == []

    assert Map.keys(result.existing_services) |> Enum.sort() ==
             AgentOSDecision.candidate_capabilities() |> Enum.sort()

    assert Enum.sort(result.authoritative_domains) ==
             AgentOSDecision.authoritative_domains() |> Enum.sort()
  end

  test "proves graph-only outcomes through restart and split-state fault classes" do
    {:ok, decision} = AgentOSDecision.evaluate(attributes())

    scenarios =
      Enum.map(AgentOSDecision.faults(), fn fault ->
        %{
          fault: fault,
          graph_outcome: :accepted_baseline,
          agent_os_outcome: :irrelevant,
          duplicate_effect: false,
          split_authority: false
        }
      end)

    assert :ok = AgentOSDecision.verify_reconstruction(decision, scenarios)

    corrupted =
      Enum.map(scenarios, fn
        %{fault: :split_state} = scenario -> %{scenario | split_authority: true}
        scenario -> scenario
      end)

    assert {:error, error} = AgentOSDecision.verify_reconstruction(decision, corrupted)
    assert error.operation == :managed_coding_agent_os_reconstruction
  end

  test "fails closed on incomplete inventory or an authoritative persistence proposal" do
    assert {:error, error} =
             AgentOSDecision.evaluate(%{
               attributes()
               | capabilities: [],
                 persistence_modes: [:ecto]
             })

    assert error.operation == :managed_coding_agent_os_evaluation
  end

  defp attributes do
    %{
      source_revision: "548b2a345765ba33e687341c661bbbcbdda73d94",
      dependency_present: false,
      capabilities:
        Enum.map(AgentOSDecision.candidate_capabilities(), fn name ->
          %{name: name, benefit: :duplicative, evidence_digest: nil}
        end),
      persistence_modes: [:ecto, :ephemeral],
      measured_benefits: %{latency_delta_ms: 0, operator_minutes_saved: 0},
      operational_cost: %{new_datastores: 1, new_reconcilers: 1, new_on_call_surfaces: 1},
      owner: "JidoCode runtime maintainers"
    }
  end
end
