defmodule JidoCode.Factory.ExecutionAuthority do
  @moduledoc "Default fail-closed runtime authority boundary."

  @behaviour JidoCode.Factory.Ports.ExecutionAuthority

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request

  @operations ~w[prepare start signal cancel status terminate]a

  @impl true
  def authorize(operation, %Request{} = request, options) when operation in @operations do
    case Keyword.get(options, :fence_validator) do
      validator when is_function(validator, 2) ->
        case validator.(operation, request) do
          :ok -> :ok
          {:error, %AdapterError{} = error} -> {:error, error}
          _other -> {:error, AdapterError.new(:unauthorized, operation)}
        end

      _missing ->
        {:error, AdapterError.new(:unavailable, operation)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, operation)}
  end

  def authorize(operation, _request, _options),
    do: {:error, AdapterError.new(:invalid_input, operation)}
end
