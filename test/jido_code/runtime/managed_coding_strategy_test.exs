defmodule JidoCode.Runtime.ManagedCodingStrategyTest do
  use ExUnit.Case, async: false

  alias Jido.Signal
  alias JidoCode.Runtime.JidoInstance
  alias JidoCode.Runtime.ManagedCoding.Agent
  alias JidoCode.Runtime.ManagedCoding.AgentState
  alias JidoCode.Runtime.ManagedCoding.Actions.BeginAction
  alias JidoCode.Runtime.ManagedCoding.Actions.CandidateResultAction
  alias JidoCode.Runtime.ManagedCoding.Actions.ContextResultAction
  alias JidoCode.Runtime.ManagedCoding.Actions.ModelResultAction
  alias JidoCode.Runtime.ManagedCoding.Actions.ToolResultAction
  alias JidoCode.Runtime.ManagedCoding.Strategy
  alias JidoCode.Knowledge.ResourceIdentity

  test "runs the legal inspect-edit-candidate transition path as immutable agent values" do
    {:ok, agent} = Agent.new_managed(initial(), id: "managed-strategy")
    original = agent

    {agent, []} = Agent.cmd(agent, {BeginAction, correlated(1)})
    assert original.state.phase == :admitted
    assert agent.state.phase == :preparing

    model = resource(:model_invocation, "model-1")

    {agent, []} =
      Agent.cmd(
        agent,
        {ContextResultAction,
         correlated(2, %{context_digest: digest("context-2"), model_invocation_iri: model})}
      )

    assert agent.state.phase == :awaiting_model

    tool = resource(:tool_invocation, "tool-1")

    {agent, []} =
      Agent.cmd(
        agent,
        {ModelResultAction,
         correlated(3, %{
           invocation_iri: model,
           kind: :tool_proposal,
           next_invocation_iri: tool
         })}
      )

    assert agent.state.phase == :awaiting_tool

    {agent, []} =
      Agent.cmd(
        agent,
        {ToolResultAction, correlated(4, %{invocation_iri: tool, kind: :completed})}
      )

    next_model = resource(:model_invocation, "model-2")

    {agent, []} =
      Agent.cmd(
        agent,
        {ContextResultAction,
         correlated(5, %{context_digest: digest("context-3"), model_invocation_iri: next_model})}
      )

    candidate = resource(:patch_artifact, "candidate-1")

    {agent, []} =
      Agent.cmd(
        agent,
        {ModelResultAction,
         correlated(6, %{
           invocation_iri: next_model,
           kind: :completion_proposal,
           next_invocation_iri: candidate
         })}
      )

    {agent, []} =
      Agent.cmd(
        agent,
        {CandidateResultAction,
         correlated(7, %{invocation_iri: candidate, candidate_digest: digest("candidate")})}
      )

    snapshot = Agent.strategy_snapshot(agent)
    assert snapshot.done?
    assert snapshot.status == :success
    assert snapshot.result.kind == :candidate_proposal
    assert snapshot.details.sequence == 7
    refute Map.has_key?(snapshot.details, :profile_digest)
  end

  test "rejects stale, duplicate, gap, cross-attempt, wrong-fence, wrong-invocation and post-terminal actions" do
    {:ok, initial_agent} = Agent.new_managed(initial(), id: "managed-rejections")
    {agent, []} = Agent.cmd(initial_agent, {BeginAction, correlated(1)})

    for invalid <- [
          correlated(1),
          correlated(3),
          %{correlated(2) | attempt_iri: resource(:execution_attempt, "other")},
          %{correlated(2) | fencing_token: 99}
        ] do
      {unchanged, [%Jido.Agent.Directive.Error{}]} = Agent.cmd(agent, {BeginAction, invalid})
      assert unchanged.state == agent.state
    end

    model = resource(:model_invocation, "expected")

    {awaiting, []} =
      Agent.cmd(
        agent,
        {ContextResultAction,
         correlated(2, %{context_digest: digest("next"), model_invocation_iri: model})}
      )

    {unchanged, [%Jido.Agent.Directive.Error{}]} =
      Agent.cmd(
        awaiting,
        {ModelResultAction,
         correlated(3, %{
           invocation_iri: resource(:model_invocation, "wrong"),
           kind: :failure
         })}
      )

    assert unchanged.state == awaiting.state

    {terminal, []} =
      Agent.cmd(
        awaiting,
        {ModelResultAction, correlated(3, %{invocation_iri: model, kind: :failure})}
      )

    {same, [%Jido.Agent.Directive.Error{}]} =
      Agent.cmd(terminal, {BeginAction, correlated(4)})

    assert same.state == terminal.state
  end

  test "declares closed actions and signal routes through a real AgentServer" do
    assert Strategy.actions() == [
             JidoCode.Runtime.ManagedCoding.Actions.BeginAction,
             JidoCode.Runtime.ManagedCoding.Actions.ContextResultAction,
             JidoCode.Runtime.ManagedCoding.Actions.ModelResultAction,
             JidoCode.Runtime.ManagedCoding.Actions.ToolResultAction,
             JidoCode.Runtime.ManagedCoding.Actions.ActorResponseAction,
             JidoCode.Runtime.ManagedCoding.Actions.CandidateResultAction,
             JidoCode.Runtime.ManagedCoding.Actions.CancellationAction,
             JidoCode.Runtime.ManagedCoding.Actions.BudgetExhaustedAction,
             JidoCode.Runtime.ManagedCoding.Actions.RecoveryAction
           ]

    {:ok, state} = AgentState.initial(initial())
    id = "managed-server-#{System.unique_integer([:positive])}"

    assert {:ok, pid} =
             JidoInstance.start_agent(Agent,
               id: id,
               initial_state: AgentState.to_map(state)
             )

    on_exit(fn -> if Process.alive?(pid), do: JidoInstance.stop_agent(pid) end)

    {:ok, signal} = Signal.new("jido_code.managed_coding.begin", correlated(1))
    assert {:ok, _agent} = Jido.AgentServer.call(pid, signal)
    assert {:ok, server} = Jido.AgentServer.state(pid)
    assert server.agent.state.phase == :preparing
    assert server.agent.state.sequence == 1
  end

  defp initial do
    %{
      attempt_iri: attempt(),
      fencing_token: 7,
      profile_digest: digest("profile"),
      context_digest: digest("context"),
      tool_digest: digest("tools"),
      model_digest: digest("model")
    }
  end

  defp correlated(sequence, extra \\ %{}) do
    Map.merge(%{attempt_iri: attempt(), fencing_token: 7, sequence: sequence}, extra)
  end

  defp attempt, do: resource(:execution_attempt, "managed-strategy-attempt")

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
