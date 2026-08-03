defmodule JidoCode.Factory.ToolRunner do
  @moduledoc "Re-authorizing facade for a single governed tool effect."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ExecutionAuthority
  alias JidoCode.Factory.Tool.Request
  alias JidoCode.Factory.Tool.Result

  @spec execute(module(), term(), Request.t(), keyword()) ::
          {:ok, Result.t()} | {:error, AdapterError.t()}
  def execute(adapter_module, adapter, request, options \\ [])

  def execute(adapter_module, adapter, %Request{} = request, options)
      when is_atom(adapter_module) and is_list(options) do
    authority = Keyword.get(options, :authority, ExecutionAuthority)
    adapter_options = Keyword.drop(options, [:authority, :fence_validator])

    with true <- Code.ensure_loaded?(adapter_module),
         true <- Code.ensure_loaded?(authority),
         true <- function_exported?(adapter_module, :execute, 3),
         :ok <- authority.authorize(:tool_execute, request.execution, options),
         {:ok, %Result{} = result} <- adapter_module.execute(adapter, request, adapter_options) do
      {:ok, result}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:corrupt, :tool_execute)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :tool_execute)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :tool_execute)}
  end

  def execute(_module, _adapter, _request, _options),
    do: {:error, AdapterError.new(:invalid_input, :tool_execute)}
end
