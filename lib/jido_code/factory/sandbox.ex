defmodule JidoCode.Factory.Sandbox do
  @moduledoc "Re-authorizing facade over disposable sandbox adapters."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ExecutionAuthority
  alias JidoCode.Factory.Sandbox.Request

  @operations ~w[provision materialize execute inspect cancel collect destroy]a

  def provision(adapter_module, adapter, request, options \\ []),
    do: dispatch(:provision, adapter_module, adapter, request, nil, options)

  def materialize(adapter_module, adapter, request, snapshot, options \\ []),
    do: dispatch(:materialize, adapter_module, adapter, request, snapshot, options)

  def execute(adapter_module, adapter, request, command, options \\ []),
    do: dispatch(:execute, adapter_module, adapter, request, command, options)

  def inspect(adapter_module, adapter, request, options \\ []),
    do: dispatch(:inspect, adapter_module, adapter, request, nil, options)

  def cancel(adapter_module, adapter, request, options \\ []),
    do: dispatch(:cancel, adapter_module, adapter, request, nil, options)

  def collect(adapter_module, adapter, request, options \\ []),
    do: dispatch(:collect, adapter_module, adapter, request, nil, options)

  def destroy(adapter_module, adapter, request, options \\ []),
    do: dispatch(:destroy, adapter_module, adapter, request, nil, options)

  defp dispatch(operation, adapter_module, adapter, %Request{} = request, argument, options)
       when operation in @operations and is_atom(adapter_module) and is_list(options) do
    authority = Keyword.get(options, :authority, ExecutionAuthority)
    adapter_options = Keyword.drop(options, [:authority, :fence_validator])

    with true <- Code.ensure_loaded?(adapter_module),
         true <- Code.ensure_loaded?(authority),
         :ok <- authority.authorize(operation, request.execution, options),
         true <- function_exported?(adapter_module, operation, arity(operation)) do
      invoke(adapter_module, operation, adapter, request, argument, adapter_options)
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:invalid_input, operation)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, operation)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, operation)}
  end

  defp dispatch(operation, _module, _adapter, _request, _argument, _options),
    do: {:error, AdapterError.new(:invalid_input, operation)}

  defp invoke(module, operation, adapter, request, nil, options),
    do: apply(module, operation, [adapter, request, options])

  defp invoke(module, operation, adapter, request, argument, options),
    do: apply(module, operation, [adapter, request, argument, options])

  defp arity(operation) when operation in [:provision, :inspect, :cancel, :collect, :destroy],
    do: 3

  defp arity(_operation), do: 4
end
