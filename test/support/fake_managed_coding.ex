defmodule JidoCode.TestSupport.FakeManagedCoding do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ManagedCoding

  alias JidoCode.Factory.ManagedCoding.Outcome

  for operation <- [:admit, :start, :steer, :cancel, :status, :handoff] do
    @impl true
    def unquote(operation)(command, options) do
      Outcome.new(%{
        attempt_iri: command.attempt_iri || Keyword.fetch!(options, :attempt_iri),
        fencing_token: command.fencing_token || Keyword.fetch!(options, :fencing_token),
        state: if(command.operation == :admit, do: :admitted, else: :running),
        sequence: 0,
        occurred_at: ~U[2026-08-24 14:00:00Z],
        references: [command.command_iri]
      })
    end
  end
end
