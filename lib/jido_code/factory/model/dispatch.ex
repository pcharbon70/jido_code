defmodule JidoCode.Factory.Model.Dispatch do
  @moduledoc """
  Broker-authorized, hardened input passed to the model adapter.

  Credential bytes exist only in this transient value and are excluded from
  inspection. All ReqLLM options are rebuilt from the closed profile; caller
  options cannot introduce caches, retries, repairs, hooks, provider options,
  tools, alternate endpoints, or ambient authentication.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.Request

  @derive {Inspect, only: [:request, :profile]}
  @enforce_keys [:request, :profile, :credential, :options]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @caller_options [:temperature, :max_tokens]

  @spec new(Request.t(), BufferedProfile.t(), binary()) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def new(%Request{} = request, %BufferedProfile{} = profile, credential)
      when is_binary(credential) do
    with :ok <- validate_request(request, profile),
         true <- credential?(credential),
         {:ok, caller_options} <- caller_options(request.options),
         options <- hardened_options(profile, credential, caller_options) do
      {:ok,
       %__MODULE__{
         request: request,
         profile: profile,
         credential: credential,
         options: options
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_request, _profile, _credential), do: invalid()

  @spec validate_request(Request.t(), BufferedProfile.t()) ::
          :ok | {:error, AdapterError.t()}
  def validate_request(%Request{} = request, %BufferedProfile{} = profile) do
    with true <- BufferedProfile.accepts?(profile, request),
         {:ok, _caller_options} <- caller_options(request.options) do
      :ok
    else
      _invalid -> invalid()
    end
  end

  def validate_request(_request, _profile), do: invalid()

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = dispatch) do
    case new(dispatch.request, dispatch.profile, dispatch.credential) do
      {:ok, expected} -> expected.options == dispatch.options
      {:error, _error} -> false
    end
  end

  @spec model_spec(t()) :: String.t()
  def model_spec(%__MODULE__{request: request}), do: Request.model_spec(request)

  defp caller_options(options) do
    with true <- Enum.all?(Keyword.keys(options), &(&1 in @caller_options)),
         :ok <- temperature(Keyword.get(options, :temperature)),
         :ok <- max_tokens(Keyword.get(options, :max_tokens)) do
      {:ok, options}
    else
      _invalid -> :error
    end
  end

  defp temperature(nil), do: :ok
  defp temperature(value) when is_number(value) and value >= 0 and value <= 2, do: :ok
  defp temperature(_value), do: :error

  defp max_tokens(nil), do: :ok
  defp max_tokens(value) when is_integer(value) and value in 1..32_768, do: :ok
  defp max_tokens(_value), do: :error

  defp credential?(credential) do
    byte_size(credential) in 1..8_192 and
      not Regex.match?(~r/[\x00-\x1F\x7F]/u, credential)
  end

  defp hardened_options(profile, credential, caller_options) do
    security_options = [
      api_key: credential,
      cache: nil,
      max_retries: 0,
      receive_timeout: profile.timeouts.receive_ms,
      total_timeout: profile.timeouts.total_ms,
      stream_idle_timeout: profile.timeouts.stream_idle_ms,
      telemetry: [payloads: :none],
      json_repair: false,
      output_validation: :strict,
      on_unsupported: :error,
      provider_options: [store: false],
      tools: [],
      tool_choice: :none
    ]

    Keyword.merge(caller_options, security_options)
  end

  defp invalid, do: {:error, AdapterError.new(:unauthorized, :model_dispatch)}
end
