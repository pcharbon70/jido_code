defmodule JidoCode.Factory.ManagedCoding do
  @moduledoc """
  Stable Factory facade for one graph-authorized managed coding attempt.

  Callers provide semantic commands and receive bounded semantic outcomes. The
  facade deliberately exposes no process identifiers, graph handles, provider
  sessions, credentials, or workspace paths. Phase 1 defines the contract;
  later phases provide the production coordinator behind the port.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Command
  alias JidoCode.Factory.ManagedCoding.Outcome

  @operations ~w[admit start steer cancel status handoff]a

  @spec admit(module(), Command.t(), keyword()) :: result()
  def admit(adapter, command, options \\ []), do: dispatch(:admit, adapter, command, options)

  @spec start(module(), Command.t(), keyword()) :: result()
  def start(adapter, command, options \\ []), do: dispatch(:start, adapter, command, options)

  @spec steer(module(), Command.t(), keyword()) :: result()
  def steer(adapter, command, options \\ []), do: dispatch(:steer, adapter, command, options)

  @spec cancel(module(), Command.t(), keyword()) :: result()
  def cancel(adapter, command, options \\ []), do: dispatch(:cancel, adapter, command, options)

  @spec status(module(), Command.t(), keyword()) :: result()
  def status(adapter, command, options \\ []), do: dispatch(:status, adapter, command, options)

  @spec handoff(module(), Command.t(), keyword()) :: result()
  def handoff(adapter, command, options \\ []), do: dispatch(:handoff, adapter, command, options)

  @type result :: {:ok, Outcome.t()} | {:error, AdapterError.t()}

  defp dispatch(operation, adapter, %Command{operation: operation} = command, options)
       when operation in @operations and is_atom(adapter) and is_list(options) do
    with true <- Code.ensure_loaded?(adapter),
         true <- function_exported?(adapter, operation, 2),
         {:ok, %Outcome{} = outcome} <- apply(adapter, operation, [command, options]) do
      {:ok, outcome}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(operation)
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, operation)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, operation)}
  end

  defp dispatch(operation, _adapter, _command, _options), do: invalid(operation)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
