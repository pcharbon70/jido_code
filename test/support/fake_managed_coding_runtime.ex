defmodule JidoCode.TestSupport.FakeManagedCodingRuntime do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ManagedCodingRuntime

  @impl true
  def start(agent, resolved, _options) do
    state = Agent.get(agent, & &1)
    send(state.owner, {:runtime, :start, resolved.attempt_iri})
    Map.get(state, :start_result, {:ok, %{pid: state.runtime_pid, references: []}})
  end

  @impl true
  def command(agent, command, _options) do
    state = Agent.get(agent, & &1)
    send(state.owner, {:runtime, command.operation, command.attempt_iri})

    {:ok,
     %{
       state: runtime_state(command.operation),
       sequence: 2,
       occurred_at: ~U[2026-08-25 12:00:00Z],
       references: [command.command_iri],
       classification: :pending
     }}
  end

  @impl true
  def await(agent, command, timeout) do
    state = Agent.get(agent, & &1)
    send(state.owner, {:runtime, :await, command.attempt_iri, timeout})
    command(agent, command, [])
  end

  defp runtime_state(:cancel), do: :cancelling
  defp runtime_state(:handoff), do: :candidate_ready
  defp runtime_state(_operation), do: :running
end
