defmodule JidoCode.Factory.Ports.ManagedCoding do
  @moduledoc "Factory-owned port implemented by the later managed coding coordinator."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Command
  alias JidoCode.Factory.ManagedCoding.Outcome

  @type result :: {:ok, Outcome.t()} | {:error, AdapterError.t()}

  @callback admit(Command.t(), keyword()) :: result()
  @callback start(Command.t(), keyword()) :: result()
  @callback steer(Command.t(), keyword()) :: result()
  @callback cancel(Command.t(), keyword()) :: result()
  @callback status(Command.t(), keyword()) :: result()
  @callback await(Command.t(), keyword()) :: result()
  @callback handoff(Command.t(), keyword()) :: result()
end
