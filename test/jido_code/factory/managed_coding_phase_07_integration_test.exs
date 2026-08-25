defmodule JidoCode.Factory.ManagedCodingPhase07IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.ManagedCoding.AgentOSDecision
  alias JidoCode.Factory.ManagedCoding.QualificationAudit
  alias JidoCode.Factory.ManagedCoding.SpecialistEvaluation
  alias JidoCode.Factory.ManagedCoding.TopologyCoordinator
  alias JidoCode.ManagedCodingRelease
  alias JidoCode.Runtime.ManagedCoding.TopologyAdapter
  alias JidoCode.TestSupport.ManagedCodingPhase06Fixture
  alias JidoCode.TestSupport.ManagedCodingPhase07Fixture

  test "evaluates the bounded topology end to end and retains the single-agent release" do
    start_managers()
    contract = ManagedCodingPhase07Fixture.contract()

    assert {:ok, runtime} =
             TopologyCoordinator.reconcile(
               contract,
               ManagedCodingPhase07Fixture.projection(),
               runtime: TopologyAdapter
             )

    assert {:ok, admission} =
             TopologyCoordinator.admit_delegation(
               contract,
               runtime,
               ManagedCodingPhase07Fixture.delegation()
             )

    assert {:ok, %{route: :managed_coding_tool, direct_graph_access: false}} =
             TopologyCoordinator.route_effect(admission, "tool")

    assert {:ok, handoff} =
             SpecialistEvaluation.compile_handoff(
               ManagedCodingPhase07Fixture.evidence(),
               "coder",
               8_192
             )

    refute handoff.transcript_included

    assert {:ok, evaluation} =
             SpecialistEvaluation.compare(
               ManagedCodingPhase07Fixture.evaluation_program(),
               ManagedCodingPhase07Fixture.trials("single_agent"),
               ManagedCodingPhase07Fixture.trials("specialists")
             )

    assert evaluation.decision == :reject
    assert evaluation.production_profile == "single_agent"
    refute evaluation.specialist_profile_enabled
    assert :ok = TopologyCoordinator.stop(contract, runtime: TopologyAdapter)
    assert :ok = ManagedCodingRelease.verify()
  end

  test "contains Pod loss, corrupt handoff, budget contention, and forged or stale signals" do
    start_managers()
    contract = ManagedCodingPhase07Fixture.contract()

    {:ok, runtime} =
      TopologyCoordinator.reconcile(
        contract,
        ManagedCodingPhase07Fixture.projection(),
        runtime: TopologyAdapter
      )

    reviewer = runtime.roles["reviewer"]
    Process.exit(reviewer, :kill)

    assert eventually(fn ->
             match?(
               {:ok, replacement} when replacement != reviewer,
               Jido.Pod.lookup_node(runtime.pod_pid, "reviewer")
             )
           end)

    assert {:ok, rebuilt} =
             TopologyCoordinator.reconcile(
               contract,
               ManagedCodingPhase07Fixture.projection(),
               runtime: TopologyAdapter
             )

    assert rebuilt.roles["reviewer"] != reviewer
    assert rebuilt.watermark == runtime.watermark

    corrupted = Map.update!(ManagedCodingPhase07Fixture.evidence(), :body, &(&1 <> " altered"))
    assert {:error, _error} = SpecialistEvaluation.compile_handoff(corrupted, "coder", 8_192)

    assert {:error, _error} =
             TopologyCoordinator.admit_delegation(
               contract,
               rebuilt,
               ManagedCodingPhase07Fixture.delegation(%{concurrent: 3})
             )

    assert TopologyCoordinator.classify_signal(1, 2, "coder", "reviewer", 9, 9) == :forged
    assert TopologyCoordinator.classify_signal(1, 2, "coder", "coder", 9, 8) == :superseded
    assert TopologyCoordinator.classify_signal(2, 1, "coder", "coder", 9, 9) == :stale
    assert :ok = TopologyCoordinator.stop(contract, runtime: TopologyAdapter)
  end

  test "reproduces rejected decisions and proves disabled features have no production path" do
    program = ManagedCodingPhase07Fixture.evaluation_program()
    baseline = ManagedCodingPhase07Fixture.trials("single_agent")
    topology = ManagedCodingPhase07Fixture.trials("specialists")

    assert {:ok, first} = SpecialistEvaluation.compare(program, baseline, topology)
    assert {:ok, second} = SpecialistEvaluation.compare(program, baseline, topology)
    assert first == second
    assert first.decision == :reject

    decision = ManagedCodingPhase07Fixture.agent_os_decision()
    assert decision.decision == :reject

    assert :ok =
             AgentOSDecision.verify_reconstruction(
               decision,
               ManagedCodingPhase07Fixture.agent_os_scenarios()
             )

    assert Application.spec(:jido_agent_os) == nil

    assert {:error, error} =
             TopologyCoordinator.reconcile(
               ManagedCodingPhase07Fixture.contract(),
               ManagedCodingPhase07Fixture.projection()
             )

    assert error.operation == :managed_coding_topology_reconciliation
    refute ManagedCodingRelease.manifest().pod_managers_in_default_supervision
    assert ManagedCodingRelease.manifest().merge_authority == :human_only
  end

  test "retains Phase 6 qualification, graph reconstruction, and human merge authority" do
    assert {:ok, audit} =
             QualificationAudit.verify(
               ManagedCodingPhase06Fixture.evidence(),
               ManagedCodingPhase06Fixture.drills()
             )

    assert audit.release_ready
    assert audit.profile_digest == ManagedCodingPhase06Fixture.digest()
    assert :ok = JidoCode.ReleaseContract.verify()
    assert byte_size(ManagedCodingPhase07Fixture.digest()) == 64
    assert ManagedCodingRelease.manifest().durable_authority == :triple_store
    assert ManagedCodingRelease.manifest().verification == :independent_fresh_checkout
    assert ManagedCodingRelease.manifest().publication == :separate_human_authorized_boundary
  end

  defp start_managers do
    Enum.each(ManagedCodingPhase07Fixture.manager_specs(), &start_supervised!/1)
  end

  defp eventually(fun, attempts \\ 50)
  defp eventually(fun, 0), do: fun.()

  defp eventually(fun, attempts) do
    if fun.() do
      true
    else
      Process.sleep(10)
      eventually(fun, attempts - 1)
    end
  end
end
