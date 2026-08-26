defmodule JidoCode.Factory.DelegatedExecutionRuntime do
  @moduledoc "Closed delegated lifecycle facade that re-resolves exact runtime authority per operation."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Execution.RuntimeEvent
  alias JidoCode.Factory.ExecutionRuntime
  alias JidoCode.Runtime.DelegatedRuntimeRegistry

  @type runtime_result :: {:ok, RuntimeEvent.t()} | {:error, AdapterError.t()}

  @spec prepare(map(), Request.t(), keyword()) :: runtime_result()
  def prepare(selection, request, options \\ []),
    do: dispatch(:prepare, selection, request, nil, options)

  @spec start(map(), Request.t(), keyword()) :: runtime_result()
  def start(selection, request, options \\ []),
    do: dispatch(:start, selection, request, nil, options)

  @spec signal(map(), Request.t(), RuntimeEvent.t(), keyword()) :: runtime_result()
  def signal(selection, request, event, options \\ []),
    do: dispatch(:signal, selection, request, event, options)

  @spec status(map(), Request.t(), keyword()) :: runtime_result()
  def status(selection, request, options \\ []),
    do: dispatch(:status, selection, request, nil, options)

  @spec cancel(map(), Request.t(), map(), keyword()) :: runtime_result()
  def cancel(selection, request, cancellation, options \\ []),
    do: dispatch(:cancel, selection, request, cancellation, options)

  @spec terminate(map(), Request.t(), map(), keyword()) :: runtime_result()
  def terminate(selection, request, reason, options \\ []),
    do: dispatch(:terminate, selection, request, reason, options)

  defp dispatch(operation, selection, %Request{} = request, argument, options)
       when is_map(selection) and is_list(options) do
    with {:ok, resolved} <- DelegatedRuntimeRegistry.resolve(selection) do
      adapter_options =
        options
        |> Keyword.put(:profile, resolved.profile)
        |> Keyword.put(:runner, resolved.runner)
        |> Keyword.put(:delegated_runtime, resolved)

      invoke(operation, resolved.adapter, request, argument, adapter_options)
    else
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, operation)}
  end

  defp dispatch(operation, _selection, _request, _argument, _options),
    do: {:error, AdapterError.new(:invalid_input, operation)}

  defp invoke(:prepare, adapter, request, _argument, options),
    do: ExecutionRuntime.prepare(adapter, request, options)

  defp invoke(:start, adapter, request, _argument, options),
    do: ExecutionRuntime.start(adapter, request, options)

  defp invoke(:signal, adapter, request, event, options),
    do: ExecutionRuntime.signal(adapter, request, event, options)

  defp invoke(:status, adapter, request, _argument, options),
    do: ExecutionRuntime.status(adapter, request, options)

  defp invoke(:cancel, adapter, request, cancellation, options),
    do: ExecutionRuntime.cancel(adapter, request, cancellation, options)

  defp invoke(:terminate, adapter, request, reason, options),
    do: ExecutionRuntime.terminate(adapter, request, reason, options)
end
