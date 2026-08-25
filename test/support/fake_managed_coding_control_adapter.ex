defmodule JidoCode.TestSupport.FakeManagedCodingControlAdapter do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ManagedCoding

  alias JidoCode.Factory.ManagedCoding.Outcome

  for operation <- [:admit, :start, :steer, :cancel, :status, :await, :handoff] do
    @impl true
    def unquote(operation)(command, options) do
      send(Keyword.fetch!(options, :test_pid), {:factory_command, unquote(operation), command})

      Outcome.new(%{
        attempt_iri: command.attempt_iri,
        fencing_token: command.fencing_token,
        state: :running,
        sequence: 10,
        occurred_at: ~U[2026-08-25 14:00:00Z],
        references: [command.command_iri]
      })
    end
  end
end
