defmodule JidoCode.Setup.ProviderCredentialChecks do
  @moduledoc """
  Verifies LLM provider credentials before setup step 3 can advance.
  """

  @default_checker_remediation "Verify provider credential checker configuration and retry setup."
  @default_not_set_remediation "Set this provider credential and retry verification."
  @default_invalid_remediation "Replace this provider credential and retry verification."
  @default_invalid_result_error_type "provider_credential_invalid_result"

  @type status :: :active | :invalid | :not_set | :rotating
  @type provider :: :anthropic | :openai

  @type credential_result :: %{
          provider: provider(),
          name: String.t(),
          status: status(),
          previous_status: status(),
          transition: String.t(),
          detail: String.t(),
          remediation: String.t(),
          error_type: String.t() | nil,
          verified_at: DateTime.t() | nil,
          checked_at: DateTime.t()
        }

  @type report :: %{
          checked_at: DateTime.t(),
          status: status(),
          credentials: [credential_result()]
        }

  @spec run(map() | nil) :: report()
  def run(previous_state \\ nil) do
    checked_at = DateTime.utc_now() |> DateTime.truncate(:second)
    previous_report = from_state(previous_state)
    previous_statuses = previous_statuses(previous_report)
    previous_verified_ats = previous_verified_ats(previous_report)

    checker =
      Application.get_env(
        :jido_code,
        :setup_provider_credential_checker,
        &__MODULE__.default_checker/1
      )

    checker
    |> safe_invoke_checker(%{
      checked_at: checked_at,
      previous_statuses: previous_statuses,
      previous_verified_ats: previous_verified_ats
    })
    |> normalize_report(checked_at, previous_statuses, previous_verified_ats)
  end

  @spec blocked?(report()) :: boolean()
  def blocked?(%{credentials: credentials}) when is_list(credentials) do
    not Enum.any?(credentials, fn credential -> credential.status == :active end)
  end

  def blocked?(_), do: true

  @spec blocked_credentials(report()) :: [credential_result()]
  def blocked_credentials(%{credentials: credentials}) when is_list(credentials) do
    Enum.filter(credentials, fn credential -> credential.status != :active end)
  end

  def blocked_credentials(_), do: []

  @spec serialize_for_state(report()) :: map()
  def serialize_for_state(%{checked_at: checked_at, status: status, credentials: credentials})
      when is_list(credentials) do
    %{
      "checked_at" => DateTime.to_iso8601(checked_at),
      "status" => Atom.to_string(status),
      "credentials" =>
        Enum.map(credentials, fn credential ->
          %{
            "provider" => Atom.to_string(credential.provider),
            "name" => credential.name,
            "status" => Atom.to_string(credential.status),
            "previous_status" => Atom.to_string(credential.previous_status),
            "transition" => credential.transition,
            "detail" => credential.detail,
            "remediation" => credential.remediation,
            "error_type" => credential.error_type,
            "verified_at" => format_datetime(credential.verified_at),
            "checked_at" => DateTime.to_iso8601(credential.checked_at)
          }
        end)
    }
  end

  def serialize_for_state(_), do: %{}

  @spec from_state(map() | nil) :: report() | nil
  def from_state(nil), do: nil

  def from_state(state) when is_map(state) do
    checked_at =
      state
      |> map_get(:checked_at, "checked_at")
      |> normalize_checked_at(DateTime.utc_now() |> DateTime.truncate(:second))

    credentials =
      state
      |> map_get(:credentials, "credentials", [])
      |> normalize_credentials(checked_at, %{}, %{}, preserve_failed_verification?: false)

    if credentials == [] do
      nil
    else
      %{
        checked_at: checked_at,
        credentials: credentials,
        status:
          state
          |> map_get(:status, "status", nil)
          |> normalize_status(overall_status(credentials))
      }
    end
  end

  def from_state(_), do: nil

  @doc false
  def default_checker(%{checked_at: checked_at, previous_statuses: previous_statuses} = context)
      when is_map(previous_statuses) do
    previous_verified_ats = Map.get(context, :previous_verified_ats, %{})

    Enum.map(provider_definitions(), fn definition ->
      previous_status = Map.get(previous_statuses, definition.provider, :not_set)
      previous_verified_at = Map.get(previous_verified_ats, definition.provider)

      {status, detail, remediation, error_type, verified_at} =
        case credential_value(definition) do
          nil ->
            {
              :not_set,
              definition.not_set_detail,
              definition.not_set_remediation,
              definition.not_set_error_type,
              previous_verified_at
            }

          credential ->
            if definition.valid?.(credential) do
              {:active, definition.active_detail, "Credential is active.", nil, checked_at}
            else
              {
                :invalid,
                definition.invalid_detail,
                definition.invalid_remediation,
                definition.invalid_error_type,
                previous_verified_at
              }
            end
        end

      %{
        provider: definition.provider,
        name: definition.name,
        status: status,
        previous_status: previous_status,
        transition: transition_label(previous_status, status),
        detail: detail,
        remediation: remediation,
        error_type: error_type,
        verified_at: verified_at,
        checked_at: checked_at
      }
    end)
  end

  defp safe_invoke_checker(checker, context) when is_function(checker, 1) do
    try do
      checker.(context)
    rescue
      exception ->
        {:error, {:checker_exception, Exception.message(exception)}}
    catch
      kind, reason ->
        {:error, {:checker_throw, {kind, reason}}}
    end
  end

  defp safe_invoke_checker(_checker, _context), do: {:error, :invalid_checker}

  defp normalize_report(
         %{credentials: credentials} = report,
         default_checked_at,
         previous_statuses,
         previous_verified_ats
       )
       when is_list(credentials) do
    checked_at =
      report
      |> map_get(:checked_at, "checked_at")
      |> normalize_checked_at(default_checked_at)

    normalized_credentials =
      normalize_credentials(
        credentials,
        checked_at,
        previous_statuses,
        previous_verified_ats,
        preserve_failed_verification?: true
      )

    %{
      checked_at: checked_at,
      credentials: normalized_credentials,
      status:
        report
        |> map_get(:status, "status", nil)
        |> normalize_status(overall_status(normalized_credentials))
    }
  end

  defp normalize_report(credentials, default_checked_at, previous_statuses, previous_verified_ats)
       when is_list(credentials) do
    normalize_report(%{credentials: credentials}, default_checked_at, previous_statuses, previous_verified_ats)
  end

  defp normalize_report({:error, reason}, default_checked_at, previous_statuses, previous_verified_ats) do
    checker_error_report(reason, default_checked_at, previous_statuses, previous_verified_ats)
  end

  defp normalize_report(other, default_checked_at, previous_statuses, previous_verified_ats) do
    checker_error_report(
      {:invalid_checker_result, other},
      default_checked_at,
      previous_statuses,
      previous_verified_ats
    )
  end

  defp checker_error_report(reason, checked_at, previous_statuses, previous_verified_ats) do
    credentials =
      Enum.map(provider_definitions(), fn definition ->
        previous_status = Map.get(previous_statuses, definition.provider, :not_set)

        %{
          provider: definition.provider,
          name: definition.name,
          status: :invalid,
          previous_status: previous_status,
          transition: transition_label(previous_status, :invalid),
          detail: "Unable to verify provider credential [#{definition.checker_failed_error_type}]: #{inspect(reason)}",
          remediation: @default_checker_remediation,
          error_type: definition.checker_failed_error_type,
          verified_at: Map.get(previous_verified_ats, definition.provider),
          checked_at: checked_at
        }
      end)

    %{
      checked_at: checked_at,
      status: :invalid,
      credentials: credentials
    }
  end

  defp normalize_credentials(credentials, checked_at, previous_statuses, previous_verified_ats, opts) do
    credentials
    |> Enum.with_index()
    |> Enum.map(fn {credential, index} ->
      normalize_credential(credential, checked_at, previous_statuses, previous_verified_ats, index, opts)
    end)
  end

  defp normalize_credential(
         credential,
         default_checked_at,
         previous_statuses,
         previous_verified_ats,
         index,
         opts
       )
       when is_map(credential) do
    definition = default_provider_definition(index)

    provider =
      credential
      |> map_get(:provider, "provider", definition.provider)
      |> normalize_provider(definition.provider)

    provider_definition = provider_definition(provider)
    status = credential |> map_get(:status, "status", nil) |> normalize_status(:not_set)

    previous_status =
      credential
      |> map_get(:previous_status, "previous_status", Map.get(previous_statuses, provider, :not_set))
      |> normalize_status(Map.get(previous_statuses, provider, :not_set))

    previous_verified_at = Map.get(previous_verified_ats, provider)

    %{
      provider: provider,
      name:
        credential
        |> map_get(:name, "name", provider_definition.name)
        |> normalize_text(provider_definition.name),
      status: status,
      previous_status: previous_status,
      transition:
        credential
        |> map_get(:transition, "transition", nil)
        |> normalize_text(transition_label(previous_status, status)),
      detail:
        credential
        |> map_get(:detail, "detail", nil)
        |> normalize_text(default_detail(provider_definition, status)),
      remediation:
        credential
        |> map_get(:remediation, "remediation", nil)
        |> normalize_text(default_remediation(provider_definition, status)),
      error_type:
        credential
        |> map_get(:error_type, "error_type", nil)
        |> normalize_error_type(default_error_type(provider_definition, status)),
      verified_at:
        credential
        |> map_get(:verified_at, "verified_at")
        |> normalize_verified_at(
          status,
          default_checked_at,
          previous_verified_at,
          Keyword.get(opts, :preserve_failed_verification?, true)
        ),
      checked_at:
        credential
        |> map_get(:checked_at, "checked_at")
        |> normalize_checked_at(default_checked_at)
    }
  end

  defp normalize_credential(
         _credential,
         default_checked_at,
         previous_statuses,
         previous_verified_ats,
         index,
         _opts
       ) do
    definition = default_provider_definition(index)
    previous_status = Map.get(previous_statuses, definition.provider, :not_set)

    %{
      provider: definition.provider,
      name: definition.name,
      status: :invalid,
      previous_status: previous_status,
      transition: transition_label(previous_status, :invalid),
      detail: "Provider check result was not a map.",
      remediation: @default_invalid_remediation,
      error_type: @default_invalid_result_error_type,
      verified_at: Map.get(previous_verified_ats, definition.provider),
      checked_at: default_checked_at
    }
  end

  defp provider_definitions do
    [
      %{
        provider: :anthropic,
        name: "Anthropic",
        env: "ANTHROPIC_API_KEY",
        app_env: :anthropic_api_key,
        valid?: &valid_anthropic_key?/1,
        active_detail: "ANTHROPIC_API_KEY is configured and passed verification checks.",
        invalid_detail: "Configured ANTHROPIC_API_KEY failed verification checks.",
        invalid_remediation:
          "Set a valid `ANTHROPIC_API_KEY` (typically prefixed with `sk-ant-`) and retry verification.",
        invalid_error_type: "anthropic_credentials_invalid",
        not_set_detail: "No ANTHROPIC_API_KEY credential is configured.",
        not_set_remediation: "Set `ANTHROPIC_API_KEY` and retry verification.",
        not_set_error_type: "anthropic_not_set",
        rotating_error_type: "anthropic_credentials_rotating",
        checker_failed_error_type: "anthropic_provider_check_failed"
      },
      %{
        provider: :openai,
        name: "OpenAI",
        env: "OPENAI_API_KEY",
        app_env: :openai_api_key,
        valid?: &valid_openai_key?/1,
        active_detail: "OPENAI_API_KEY is configured and passed verification checks.",
        invalid_detail: "Configured OPENAI_API_KEY failed verification checks.",
        invalid_remediation: "Set a valid `OPENAI_API_KEY` (typically prefixed with `sk-`) and retry verification.",
        invalid_error_type: "openai_credentials_invalid",
        not_set_detail: "No OPENAI_API_KEY credential is configured.",
        not_set_remediation: "Set `OPENAI_API_KEY` and retry verification.",
        not_set_error_type: "openai_not_set",
        rotating_error_type: "openai_credentials_rotating",
        checker_failed_error_type: "openai_provider_check_failed"
      }
    ]
  end

  defp provider_definition(provider) do
    Enum.find(provider_definitions(), fn definition -> definition.provider == provider end) ||
      default_provider_definition(0)
  end

  defp default_provider_definition(index) do
    providers = provider_definitions()
    Enum.at(providers, index, hd(providers))
  end

  defp credential_value(definition) do
    definition.env
    |> System.get_env()
    |> present_runtime_value()
    |> case do
      nil ->
        Application.get_env(:jido_code, definition.app_env)
        |> present_runtime_value()

      value ->
        value
    end
  end

  defp valid_anthropic_key?(value), do: String.starts_with?(value, "sk-ant-")

  defp valid_openai_key?(value) do
    String.starts_with?(value, "sk-") and not String.starts_with?(value, "sk-ant-")
  end

  defp normalize_provider(:anthropic, _default), do: :anthropic
  defp normalize_provider(:openai, _default), do: :openai
  defp normalize_provider("anthropic", _default), do: :anthropic
  defp normalize_provider("openai", _default), do: :openai
  defp normalize_provider(_provider, default), do: default

  defp normalize_status(:active, _default), do: :active
  defp normalize_status(:invalid, _default), do: :invalid
  defp normalize_status(:not_set, _default), do: :not_set
  defp normalize_status(:rotating, _default), do: :rotating
  defp normalize_status("active", _default), do: :active
  defp normalize_status("invalid", _default), do: :invalid
  defp normalize_status("not_set", _default), do: :not_set
  defp normalize_status("rotating", _default), do: :rotating
  defp normalize_status(_status, default), do: default

  defp normalize_verified_at(value, :active, default_checked_at, _previous_verified_at, _preserve_failed?) do
    value
    |> normalize_checked_at(default_checked_at)
  end

  defp normalize_verified_at(_value, _status, _default_checked_at, previous_verified_at, true) do
    normalize_checked_at(previous_verified_at, nil)
  end

  defp normalize_verified_at(value, _status, _default_checked_at, previous_verified_at, false) do
    normalize_checked_at(value, normalize_checked_at(previous_verified_at, nil))
  end

  defp normalize_checked_at(%DateTime{} = checked_at, _default), do: checked_at

  defp normalize_checked_at(checked_at, default) when is_binary(checked_at) do
    case DateTime.from_iso8601(checked_at) do
      {:ok, parsed_checked_at, _offset} -> parsed_checked_at
      {:error, _reason} -> default
    end
  end

  defp normalize_checked_at(_checked_at, default), do: default

  defp map_get(map, atom_key, string_key) do
    map_get(map, atom_key, string_key, nil)
  end

  defp map_get(map, atom_key, string_key, default) do
    cond do
      Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  defp normalize_text(value, _fallback) when is_binary(value) and byte_size(value) > 0 do
    String.trim(value)
  end

  defp normalize_text(_value, fallback), do: fallback

  defp normalize_error_type(value, _fallback) when is_binary(value) and value != "" do
    String.trim(value)
  end

  defp normalize_error_type(nil, fallback), do: fallback

  defp normalize_error_type(value, fallback) when is_atom(value) do
    value
    |> Atom.to_string()
    |> normalize_error_type(fallback)
  end

  defp normalize_error_type(_value, fallback), do: fallback

  defp transition_label(previous_status, status) do
    "#{status_label(previous_status)} -> #{status_label(status)}"
  end

  defp status_label(:active), do: "Active"
  defp status_label(:invalid), do: "Invalid"
  defp status_label(:not_set), do: "Not set"
  defp status_label(:rotating), do: "Rotating"

  defp default_detail(provider_definition, :active), do: provider_definition.active_detail
  defp default_detail(provider_definition, :invalid), do: provider_definition.invalid_detail
  defp default_detail(provider_definition, :not_set), do: provider_definition.not_set_detail
  defp default_detail(_provider_definition, :rotating), do: "Credential is currently rotating."

  defp default_remediation(_provider_definition, :active), do: "Credential is active."

  defp default_remediation(provider_definition, :invalid),
    do: provider_definition.invalid_remediation

  defp default_remediation(provider_definition, :not_set), do: provider_definition.not_set_remediation
  defp default_remediation(_provider_definition, :rotating), do: @default_not_set_remediation

  defp default_error_type(_provider_definition, :active), do: nil
  defp default_error_type(provider_definition, :invalid), do: provider_definition.invalid_error_type
  defp default_error_type(provider_definition, :not_set), do: provider_definition.not_set_error_type
  defp default_error_type(provider_definition, :rotating), do: provider_definition.rotating_error_type

  defp format_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp format_datetime(_), do: nil

  defp present_runtime_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp present_runtime_value(_value), do: nil

  defp previous_statuses(%{credentials: credentials}) when is_list(credentials) do
    Enum.reduce(credentials, %{}, fn credential, acc ->
      Map.put(acc, credential.provider, credential.status)
    end)
  end

  defp previous_statuses(_), do: %{}

  defp previous_verified_ats(%{credentials: credentials}) when is_list(credentials) do
    Enum.reduce(credentials, %{}, fn credential, acc ->
      Map.put(acc, credential.provider, credential.verified_at)
    end)
  end

  defp previous_verified_ats(_), do: %{}

  defp overall_status(credentials) do
    cond do
      Enum.any?(credentials, fn credential -> credential.status == :active end) -> :active
      Enum.any?(credentials, fn credential -> credential.status == :invalid end) -> :invalid
      Enum.any?(credentials, fn credential -> credential.status == :rotating end) -> :rotating
      true -> :not_set
    end
  end
end
