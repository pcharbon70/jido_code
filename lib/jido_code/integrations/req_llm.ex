defmodule JidoCode.Integrations.ReqLLM do
  @moduledoc """
  ReqLLM adapter for the Factory model-interaction port.

  The adapter uses only ReqLLM's public facade, catalog, response projections,
  and non-executing tool-call resolver. It does not invoke tool execution,
  automatic tool loops, or provider implementation modules.
  """

  @behaviour JidoCode.Factory.Ports.ModelInteraction

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.Dispatch
  alias JidoCode.Factory.Model.Response
  alias JidoCode.Factory.Model.StreamEvent, as: ModelStreamEvent
  alias JidoCode.Factory.Model.SubscriptionProfile
  alias JidoCode.Factory.Model.Usage
  alias JidoCode.Integrations.OAuthFileLease

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
  def generate(%__MODULE__{} = adapter, %Dispatch{} = dispatch) do
    with :ok <- validate_dispatch(dispatch),
         {:ok, _model} <- validate_catalog_model(dispatch) do
      with_credential_lock(dispatch, fn ->
        case adapter.client.generate_text(
               Dispatch.model_spec(dispatch),
               dispatch.request.messages,
               dispatch.options
             ) do
          {:ok, %ReqLLM.Response{} = response} -> normalize(response, dispatch)
          {:error, error} -> {:error, normalize_error(error, :req_llm_generate)}
          _invalid -> {:error, AdapterError.new(:corrupt, :req_llm_generate)}
        end
      end)
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :req_llm_generate)}
  end

  def generate(_adapter, _dispatch),
    do: {:error, AdapterError.new(:invalid_input, :req_llm_generate)}

  @impl true
  def stream(%__MODULE__{} = adapter, %Dispatch{} = dispatch) do
    with :ok <- validate_dispatch(dispatch),
         {:ok, _model} <- validate_catalog_model(dispatch) do
      with_credential_lock(dispatch, fn ->
        case adapter.client.stream_text(
               Dispatch.model_spec(dispatch),
               dispatch.request.messages,
               dispatch.options
             ) do
          {:ok, %ReqLLM.StreamResponse{} = response} -> {:ok, response}
          {:error, error} -> {:error, normalize_error(error, :req_llm_stream)}
          _invalid -> {:error, AdapterError.new(:corrupt, :req_llm_stream)}
        end
      end)
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :req_llm_stream)}
  end

  def stream(_adapter, _dispatch),
    do: {:error, AdapterError.new(:invalid_input, :req_llm_stream)}

  @impl true
  def events(%__MODULE__{}, %ReqLLM.StreamResponse{} = response) do
    response
    |> ReqLLM.StreamResponse.events()
    |> Stream.map(&normalize_stream_event/1)
    |> Stream.reject(&is_nil/1)
  end

  def events(_adapter, _handle), do: [stream_event!(:error, :invalid_stream)]

  @impl true
  def close(%__MODULE__{}, %ReqLLM.StreamResponse{} = response) do
    ReqLLM.StreamResponse.close(response)
  rescue
    _error -> :ok
  catch
    _kind, _reason -> :ok
  end

  def close(_adapter, _handle), do: :ok

  defp normalize(response, dispatch) do
    with :ok <- validate_response_identity(response, dispatch),
         :ok <- reject_cache_hit(response),
         :ok <- reject_repairs(response),
         :ok <- validate_no_tool_calls(response) do
      classification = ReqLLM.Response.classify(response)

      Response.new(%{
        type: classification.type,
        text: classification.text,
        thinking: classification.thinking,
        tool_calls: classification.tool_calls,
        finish_reason: classification.finish_reason,
        usage: Usage.normalize(ReqLLM.Response.usage(response)),
        call_metadata: ReqLLM.Response.call_metadata(response),
        provenance: provenance(dispatch)
      })
    end
  end

  defp validate_response_identity(%ReqLLM.Response{model: model}, dispatch) do
    if model == dispatch.profile.model,
      do: :ok,
      else: {:error, AdapterError.new(:corrupt, :req_llm_response_model)}
  end

  defp validate_dispatch(%Dispatch{} = dispatch) do
    if Dispatch.valid?(dispatch),
      do: :ok,
      else: {:error, AdapterError.new(:unauthorized, :req_llm_dispatch)}
  end

  defp with_credential_lock(
         %Dispatch{
           profile: %SubscriptionProfile{
             credential_source: :oauth_file,
             oauth_file_reference: reference
           }
         },
         function
       ) do
    OAuthFileLease.with_lock(reference, function)
  end

  defp with_credential_lock(%Dispatch{}, function), do: function.()

  defp validate_catalog_model(dispatch) do
    case ReqLLM.model(Dispatch.model_spec(dispatch)) do
      {:ok, %LLMDB.Model{} = model} ->
        category = Map.get(model.extra, :category, Map.get(model.extra, "category"))

        if Atom.to_string(model.provider) == dispatch.profile.provider and
             model.id == dispatch.profile.model and is_nil(model.base_url) and
             category != "deep_research" and model.catalog_only != true and
             model.deprecated != true and model.retired != true do
          {:ok, model}
        else
          {:error, AdapterError.new(:unauthorized, :req_llm_model)}
        end

      _error ->
        {:error, AdapterError.new(:unavailable, :req_llm_model)}
    end
  end

  defp reject_cache_hit(%ReqLLM.Response{provider_meta: provider_meta}) do
    cache_hit? =
      Map.get(provider_meta, :response_cache_hit, Map.get(provider_meta, "response_cache_hit"))

    if cache_hit?,
      do: {:error, AdapterError.new(:corrupt, :req_llm_cache_hit)},
      else: :ok
  end

  defp reject_repairs(%ReqLLM.Response{provider_meta: provider_meta}) do
    diagnostic = Map.get(provider_meta, :req_llm_output, Map.get(provider_meta, "req_llm_output"))

    case diagnostic do
      nil ->
        :ok

      value when is_map(value) ->
        repairs = Map.get(value, :repairs, Map.get(value, "repairs", []))

        if repairs == [],
          do: :ok,
          else: {:error, AdapterError.new(:corrupt, :req_llm_output_repair)}

      _invalid ->
        {:error, AdapterError.new(:corrupt, :req_llm_output_diagnostic)}
    end
  end

  defp validate_no_tool_calls(response) do
    calls = ReqLLM.Response.tool_calls(response)

    resolutions =
      Enum.map(calls, fn call ->
        resolution = ReqLLM.ToolCall.resolve(call, [], json_repair: false)

        with raw when is_binary(raw) <- resolution.raw_arguments,
             {:ok, decoded} when is_map(decoded) <- Jason.decode(raw),
             ^decoded <- resolution.arguments do
          :ok
        else
          _invalid -> :error
        end
      end)

    cond do
      :error in resolutions -> {:error, AdapterError.new(:corrupt, :req_llm_tool_arguments)}
      calls != [] -> {:error, AdapterError.new(:unauthorized, :req_llm_tool_calls)}
      true -> :ok
    end
  end

  defp normalize_stream_event(%ReqLLM.StreamEvent{type: :start, data: data}),
    do: stream_event!(:start, safe_start(data))

  defp normalize_stream_event(%ReqLLM.StreamEvent{type: :text_delta, data: text})
       when is_binary(text),
       do: stream_event!(:text_delta, text)

  defp normalize_stream_event(%ReqLLM.StreamEvent{type: type})
       when type in [:tool_call_start, :tool_call_delta],
       do: stream_event!(type, :partial)

  defp normalize_stream_event(%ReqLLM.StreamEvent{type: :tool_call}),
    do: stream_event!(:tool_call, :complete)

  defp normalize_stream_event(%ReqLLM.StreamEvent{type: :usage, data: usage}),
    do: stream_event!(:usage, Usage.normalize(usage))

  defp normalize_stream_event(%ReqLLM.StreamEvent{type: type, data: data})
       when type in [:finish, :cancelled] do
    stream_event!(type, %{finish_reason: finish_reason(data)})
  end

  defp normalize_stream_event(%ReqLLM.StreamEvent{type: :error}),
    do: stream_event!(:error, :provider_error)

  defp normalize_stream_event(%ReqLLM.StreamEvent{type: type})
       when type in [:tool_result, :source, :file, :output_item, :provider_event],
       do: stream_event!(:policy_violation, :provider_output)

  defp normalize_stream_event(%ReqLLM.StreamEvent{}), do: nil

  defp safe_start(%{model: %{id: id, provider: provider}})
       when is_binary(id) and is_atom(provider),
       do: %{model: id, provider: provider}

  defp safe_start(_data), do: %{}

  defp finish_reason(%{finish_reason: reason}) when is_atom(reason), do: reason
  defp finish_reason(_data), do: :unknown

  defp stream_event!(type, data) do
    {:ok, event} = ModelStreamEvent.new(type, data)
    event
  end

  defp provenance(dispatch) do
    %{
      invocation_iri: dispatch.request.invocation_iri,
      profile_iri: dispatch.profile.profile_iri,
      context_manifest_iri: dispatch.request.context_manifest_iri,
      provider: dispatch.profile.provider,
      model: dispatch.profile.model,
      endpoint: dispatch.profile.endpoint,
      req_llm_version: "1.20.0",
      retention_posture: dispatch.profile.retention_posture,
      provider_cache_posture: dispatch.profile.provider_cache_posture,
      structured_effects: dispatch.profile.structured_effects,
      cost_enforcement: dispatch.profile.cost_enforcement,
      recovery_mode: Map.get(dispatch.profile, :recovery_mode, :new_interaction_from_graph),
      cost_unit: :micro_usd
    }
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
