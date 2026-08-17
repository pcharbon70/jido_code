defmodule JidoCode.Factory.ModelGateway do
  @moduledoc """
  The sole Factory dispatch seam for model interactions.

  Runtime callers select an enrolled adapter when building the gateway, then
  pass only validated requests. This module deliberately owns no provider
  fallback and never dispatches to a second adapter after an error.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.Model.Response
  alias JidoCode.Factory.Model.Stream

  @derive {Inspect, only: [:adapter_module]}
  @enforce_keys [:adapter_module, :adapter]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(module(), term()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(adapter_module, adapter) when is_atom(adapter_module) do
    if Code.ensure_loaded?(adapter_module) and
         function_exported?(adapter_module, :generate, 2) and
         function_exported?(adapter_module, :stream, 2) do
      {:ok, %__MODULE__{adapter_module: adapter_module, adapter: adapter}}
    else
      invalid(:model_gateway_adapter)
    end
  end

  def new(_adapter_module, _adapter), do: invalid(:model_gateway_adapter)

  @spec generate(t(), Request.t()) :: {:ok, Response.t()} | {:error, AdapterError.t()}
  def generate(%__MODULE__{} = gateway, %Request{} = request) do
    case gateway.adapter_module.generate(gateway.adapter, request) do
      {:ok, %Response{} = response} -> {:ok, response}
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:corrupt, :model_gateway_generate)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :model_gateway_generate)}
  end

  def generate(_gateway, _request), do: invalid(:model_gateway_generate)

  @spec stream(t(), Request.t()) :: {:ok, Stream.t()} | {:error, AdapterError.t()}
  def stream(%__MODULE__{} = gateway, %Request{} = request) do
    case gateway.adapter_module.stream(gateway.adapter, request) do
      {:ok, handle} -> {:ok, Stream.new(request.invocation_iri, handle)}
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:corrupt, :model_gateway_stream)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :model_gateway_stream)}
  end

  def stream(_gateway, _request), do: invalid(:model_gateway_stream)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
