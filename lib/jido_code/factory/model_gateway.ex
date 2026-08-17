defmodule JidoCode.Factory.ModelGateway do
  @moduledoc """
  The sole Factory dispatch seam for model interactions.

  Runtime callers select an enrolled adapter when building the gateway, then
  pass only validated requests. This module deliberately owns no provider
  fallback and never dispatches to a second adapter after an error.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.Dispatch
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.Model.Response
  alias JidoCode.Factory.Model.Stream

  @derive {Inspect, only: [:adapter_module]}
  @enforce_keys [
    :adapter_module,
    :adapter,
    :profile,
    :secret_provider_module,
    :secret_provider,
    :authority_module,
    :authority
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(module(), term(), keyword()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(adapter_module, adapter, options \\ [])

  def new(adapter_module, adapter, options) when is_atom(adapter_module) and is_list(options) do
    with true <- adapter?(adapter_module),
         %BufferedProfile{} = profile <- Keyword.get(options, :profile),
         {secret_module, secret_provider} when is_atom(secret_module) <-
           Keyword.get(options, :secret_provider),
         true <- secret_provider?(secret_module),
         {authority_module, authority} when is_atom(authority_module) <-
           Keyword.get(options, :authority),
         true <- authority?(authority_module) do
      {:ok,
       %__MODULE__{
         adapter_module: adapter_module,
         adapter: adapter,
         profile: profile,
         secret_provider_module: secret_module,
         secret_provider: secret_provider,
         authority_module: authority_module,
         authority: authority
       }}
    else
      _invalid -> invalid(:model_gateway_adapter)
    end
  end

  def new(_adapter_module, _adapter, _options), do: invalid(:model_gateway_adapter)

  @spec generate(t(), Request.t()) :: {:ok, Response.t()} | {:error, AdapterError.t()}
  def generate(%__MODULE__{} = gateway, %Request{} = request) do
    with {:ok, dispatch} <- prepare_dispatch(gateway, request) do
      case gateway.adapter_module.generate(gateway.adapter, dispatch) do
        {:ok, %Response{} = response} -> {:ok, response}
        {:error, %AdapterError{} = error} -> {:error, error}
        _invalid -> {:error, AdapterError.new(:corrupt, :model_gateway_generate)}
      end
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :model_gateway_generate)}
  end

  def generate(_gateway, _request), do: invalid(:model_gateway_generate)

  @spec stream(t(), Request.t()) :: {:ok, Stream.t()} | {:error, AdapterError.t()}
  def stream(%__MODULE__{} = gateway, %Request{} = request) do
    with {:ok, dispatch} <- prepare_dispatch(gateway, request) do
      case gateway.adapter_module.stream(gateway.adapter, dispatch) do
        {:ok, handle} -> {:ok, Stream.new(request.invocation_iri, handle)}
        {:error, %AdapterError{} = error} -> {:error, error}
        _invalid -> {:error, AdapterError.new(:corrupt, :model_gateway_stream)}
      end
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :model_gateway_stream)}
  end

  def stream(_gateway, _request), do: invalid(:model_gateway_stream)

  defp prepare_dispatch(gateway, request) do
    with :ok <- Dispatch.validate_request(request, gateway.profile),
         :ok <- authorize(gateway, :before_credential_release, request),
         {:ok, credential} <- fetch_credential(gateway),
         {:ok, dispatch} <- Dispatch.new(request, gateway.profile, credential),
         :ok <- authorize(gateway, :before_dispatch, request) do
      {:ok, dispatch}
    end
  end

  defp authorize(gateway, stage, request) do
    case gateway.authority_module.authorize(
           gateway.authority,
           stage,
           gateway.profile,
           request
         ) do
      :ok -> :ok
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:unauthorized, stage)}
    end
  end

  defp fetch_credential(gateway) do
    case gateway.secret_provider_module.fetch(
           gateway.secret_provider,
           gateway.profile.credential_reference
         ) do
      {:ok, credential} when is_binary(credential) -> {:ok, credential}
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:unavailable, :model_credential_fetch)}
    end
  end

  defp adapter?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :generate, 2) and
      function_exported?(module, :stream, 2)
  end

  defp secret_provider?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :fetch, 2)
  end

  defp authority?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :authorize, 4)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
