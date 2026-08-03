defmodule JidoCode.Factory.ExecutionRuntime do
  @moduledoc """
  Product-owned facade over disposable execution runtime implementations.

  Every operation is re-authorized immediately before adapter dispatch. The
  adapter receives no graph handle or authorization capability.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Execution.RuntimeEvent

  @operations ~w[prepare start signal cancel status terminate]a

  @spec prepare(module(), Request.t(), keyword()) :: runtime_result()
  def prepare(adapter, request, options \\ []),
    do: dispatch(:prepare, adapter, request, nil, options)

  @spec start(module(), Request.t(), keyword()) :: runtime_result()
  def start(adapter, request, options \\ []), do: dispatch(:start, adapter, request, nil, options)

  @spec signal(module(), Request.t(), RuntimeEvent.t(), keyword()) :: runtime_result()
  def signal(adapter, request, event, options \\ []),
    do: dispatch(:signal, adapter, request, event, options)

  @spec cancel(module(), Request.t(), map(), keyword()) :: runtime_result()
  def cancel(adapter, request, cancellation, options \\ []),
    do: dispatch(:cancel, adapter, request, cancellation, options)

  @spec status(module(), Request.t(), keyword()) :: runtime_result()
  def status(adapter, request, options \\ []),
    do: dispatch(:status, adapter, request, nil, options)

  @spec terminate(module(), Request.t(), map(), keyword()) :: runtime_result()
  def terminate(adapter, request, reason, options \\ []),
    do: dispatch(:terminate, adapter, request, reason, options)

  @typep runtime_result :: {:ok, RuntimeEvent.t()} | {:error, AdapterError.t()}

  defp dispatch(operation, adapter, %Request{} = request, argument, options)
       when operation in @operations and is_atom(adapter) and is_list(options) do
    authority = Keyword.get(options, :authority, JidoCode.Factory.ExecutionAuthority)
    adapter_options = Keyword.drop(options, [:authority, :fence_validator])

    with true <- Code.ensure_loaded?(authority),
         true <- Code.ensure_loaded?(adapter),
         true <- function_exported?(authority, :authorize, 3),
         true <- function_exported?(adapter, operation, adapter_arity(operation)),
         :ok <- authority.authorize(operation, request, options) do
      invoke(adapter, operation, request, argument, adapter_options)
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:invalid_input, operation)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, operation)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, operation)}
  end

  defp dispatch(operation, _adapter, _request, _argument, _options),
    do: {:error, AdapterError.new(:invalid_input, operation)}

  defp invoke(adapter, operation, request, nil, options),
    do: apply(adapter, operation, [request, options])

  defp invoke(adapter, operation, request, argument, options),
    do: apply(adapter, operation, [request, argument, options])

  defp adapter_arity(operation) when operation in [:prepare, :start, :status], do: 2
  defp adapter_arity(_operation), do: 3
end
