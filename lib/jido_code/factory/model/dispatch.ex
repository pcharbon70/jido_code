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
  alias JidoCode.Factory.Model.Profile
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.Model.SubscriptionProfile

  @derive {Inspect, only: [:request, :profile]}
  @enforce_keys [:request, :profile, :credential, :options]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @caller_options [:temperature, :max_tokens]

  @spec new(Request.t(), BufferedProfile.t() | SubscriptionProfile.t(), binary()) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def new(%Request{} = request, profile, credential) when is_binary(credential) do
    with true <- Profile.valid?(profile),
         :ok <- validate_request(request, profile),
         true <- credential?(profile, credential),
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

  @spec validate_request(Request.t(), BufferedProfile.t() | SubscriptionProfile.t()) ::
          :ok | {:error, AdapterError.t()}
  def validate_request(%Request{} = request, profile) do
    with true <- Profile.valid?(profile),
         true <- Profile.accepts?(profile, request),
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

  defp credential?(%BufferedProfile{}, credential), do: token?(credential)

  defp credential?(%SubscriptionProfile{credential_source: :oauth_file} = profile, path) do
    profile.deployment == :developer_local and profile.refresh_owner == :req_llm and
      Path.type(path) == :absolute and byte_size(path) <= 1_024 and
      profile.oauth_file_reference.path == path
  end

  defp credential?(%SubscriptionProfile{}, credential), do: token?(credential)
  defp credential?(_profile, _credential), do: false

  defp token?(credential) do
    byte_size(credential) in 1..8_192 and
      not Regex.match?(~r/[\x00-\x1F\x7F]/u, credential)
  end

  defp hardened_options(%BufferedProfile{} = profile, credential, caller_options) do
    security_options =
      common_options(profile) ++ [api_key: credential, provider_options: [store: false]]

    Keyword.merge(caller_options, security_options)
  end

  defp hardened_options(
         %SubscriptionProfile{provider: "github_copilot"} = profile,
         credential,
         caller_options
       ) do
    security_options =
      common_options(profile) ++
        [api_key: credential, github_copilot_auth: :token, provider_options: []]

    Keyword.merge(caller_options, security_options)
  end

  defp hardened_options(
         %SubscriptionProfile{credential_source: :oauth_file} = profile,
         path,
         caller_options
       ) do
    security_options =
      common_options(profile) ++
        [auth_mode: :oauth, oauth_file: path, provider_options: provider_options(profile)]

    Keyword.merge(caller_options, security_options)
  end

  defp hardened_options(%SubscriptionProfile{} = profile, token, caller_options) do
    security_options =
      common_options(profile) ++
        [access_token: token, auth_mode: :oauth, provider_options: provider_options(profile)]

    Keyword.merge(caller_options, security_options)
  end

  defp common_options(profile) do
    [
      cache: nil,
      max_retries: 0,
      receive_timeout: profile.timeouts.receive_ms,
      total_timeout: profile.timeouts.total_ms,
      stream_idle_timeout: profile.timeouts.stream_idle_ms,
      telemetry: [payloads: :none],
      json_repair: false,
      output_validation: :strict,
      on_unsupported: :error,
      tools: [],
      tool_choice: :none
    ]
  end

  defp provider_options(%SubscriptionProfile{provider: "openai_codex"}) do
    [store: false, openai_reuse_websocket: false, openai_stream_transport: :sse]
  end

  defp provider_options(%SubscriptionProfile{}), do: []

  defp invalid, do: {:error, AdapterError.new(:unauthorized, :model_dispatch)}
end
