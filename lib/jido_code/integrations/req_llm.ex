defmodule JidoCode.Integrations.ReqLLM do
  @moduledoc """
  ReqLLM adapter for the Factory model-interaction port.

  The adapter uses only ReqLLM's public facade and response projections. It
  does not invoke ReqLLM tool execution, automatic tool loops, or provider
  implementation modules.
  """

  @behaviour JidoCode.Factory.Ports.ModelInteraction

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.Model.Response

  @derive {Inspect, only: []}
  @enforce_keys [:client]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(keyword()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(options \\ [])

  def new(options) when is_list(options) do
    client = Keyword.get(options, :client, ReqLLM)

    if Code.ensure_loaded?(client) and
         function_exported?(client, :generate_text, 3) and
         function_exported?(client, :stream_text, 3) do
      {:ok, %__MODULE__{client: client}}
    else
      {:error, AdapterError.new(:invalid_input, :req_llm_adapter)}
    end
  end

  def new(_options), do: {:error, AdapterError.new(:invalid_input, :req_llm_adapter)}

  @impl true
  def generate(%__MODULE__{} = adapter, %Request{} = request) do
    case adapter.client.generate_text(
           Request.model_spec(request),
           request.messages,
           request.options
         ) do
      {:ok, %ReqLLM.Response{} = response} -> normalize(response)
      {:error, error} -> {:error, normalize_error(error, :req_llm_generate)}
      _invalid -> {:error, AdapterError.new(:corrupt, :req_llm_generate)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :req_llm_generate)}
  end

  def generate(_adapter, _request),
    do: {:error, AdapterError.new(:invalid_input, :req_llm_generate)}

  @impl true
  def stream(%__MODULE__{} = adapter, %Request{} = request) do
    case adapter.client.stream_text(
           Request.model_spec(request),
           request.messages,
           request.options
         ) do
      {:ok, %ReqLLM.StreamResponse{} = response} -> {:ok, response}
      {:error, error} -> {:error, normalize_error(error, :req_llm_stream)}
      _invalid -> {:error, AdapterError.new(:corrupt, :req_llm_stream)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :req_llm_stream)}
  end

  def stream(_adapter, _request),
    do: {:error, AdapterError.new(:invalid_input, :req_llm_stream)}

  defp normalize(response) do
    classification = ReqLLM.Response.classify(response)

    Response.new(%{
      type: classification.type,
      text: classification.text,
      thinking: classification.thinking,
      tool_calls: classification.tool_calls,
      finish_reason: classification.finish_reason,
      usage: ReqLLM.Response.usage(response),
      call_metadata: ReqLLM.Response.call_metadata(response)
    })
  end

  defp normalize_error(error, operation) do
    kind =
      case error do
        %ReqLLM.Error.API.Request{status: status} when status in [401, 403] ->
          :unauthorized

        %ReqLLM.Error.API.Request{reason: reason}
        when reason in [:timeout, :connect_timeout, :receive_timeout] ->
          :timeout

        _error ->
          :unavailable
      end

    AdapterError.new(kind, operation)
  rescue
    _error -> AdapterError.new(:unavailable, operation)
  end
end
