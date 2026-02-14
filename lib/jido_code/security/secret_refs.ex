defmodule JidoCode.Security.SecretRefs do
  @moduledoc """
  SecretRef persistence and metadata reads for `/settings/security`.
  """

  alias JidoCode.Security.{Encryption, SecretRef}

  @provider_secret_specs %{
    anthropic: %{scope: :integration, name: "providers/anthropic_api_key"},
    openai: %{scope: :integration, name: "providers/openai_api_key"}
  }

  @provider_rotation_options [{"Anthropic", "anthropic"}, {"OpenAI", "openai"}]

  @encryption_unavailable_recovery_instruction """
  Set `JIDO_CODE_SECRET_REF_ENCRYPTION_KEY` to a base64-encoded 32-byte key and restart JidoCode.
  """

  @write_failed_recovery_instruction """
  Retry the save. If it still fails, inspect database connectivity and rerun containment steps from the security playbook.
  """

  @read_failed_recovery_instruction """
  Refresh this page. If metadata loading still fails, verify database health before retrying.
  """

  @rotation_precheck_failed_recovery_instruction """
  Validate the currently active provider credential and retry rotation once pre-checks pass.
  """

  @rotation_failed_recovery_instruction """
  Rotation validation failed and references were rolled back. Confirm the replacement credential and retry.
  """

  @rotation_rollback_failed_recovery_instruction """
  Rotation validation failed and rollback could not be confirmed. Pause new runs and follow containment steps in the security playbook.
  """

  @typedoc """
  Typed secret persistence/read error payload with remediation guidance.
  """
  @type typed_error :: %{
          error_type: String.t(),
          message: String.t(),
          recovery_instruction: String.t()
        }

  @typedoc """
  Non-sensitive SecretRef fields safe for settings displays.
  """
  @type secret_metadata :: %{
          id: Ecto.UUID.t(),
          scope: :instance | :project | :integration,
          name: String.t(),
          key_version: integer(),
          source: :env | :onboarding | :rotation,
          last_rotated_at: DateTime.t(),
          expires_at: DateTime.t() | nil
        }

  @typedoc """
  Provider keys supported by MVP rotation operations.
  """
  @type provider :: :anthropic | :openai

  @typedoc """
  Snapshot used by runtime callers to hold credential context during a run.
  """
  @type provider_credential_context :: %{
          provider: provider(),
          id: Ecto.UUID.t(),
          scope: :integration,
          name: String.t(),
          key_version: integer(),
          source: :env | :onboarding | :rotation,
          last_rotated_at: DateTime.t(),
          ciphertext: String.t()
        }

  @typedoc """
  Validation result for a rotation verification checkpoint.
  """
  @type verification_result :: %{
          status: :passed | :failed,
          detail: String.t(),
          checked_at: DateTime.t()
        }

  @typedoc """
  Rotation result for `/settings/security` with before/after verification state.
  """
  @type provider_rotation_report :: %{
          provider: provider(),
          scope: :integration,
          name: String.t(),
          before: %{
            key_version: integer(),
            verification: verification_result()
          },
          after: %{
            key_version: integer(),
            verification: verification_result()
          },
          references_switched_at: DateTime.t(),
          rollback_performed: boolean(),
          continuity_alarm: boolean()
        }

  @doc """
  Provider options shown in `/settings/security` rotation controls.
  """
  @spec provider_rotation_options() :: [{String.t(), String.t()}]
  def provider_rotation_options, do: @provider_rotation_options

  @doc """
  Canonical secret name for a supported provider credential.
  """
  @spec provider_secret_ref_name(provider()) :: String.t()
  def provider_secret_ref_name(provider) when provider in [:anthropic, :openai] do
    @provider_secret_specs
    |> Map.fetch!(provider)
    |> Map.fetch!(:name)
  end

  @doc """
  Returns a provider credential context snapshot for in-flight runtime usage.
  """
  @spec provider_credential_context(provider() | String.t()) ::
          {:ok, provider_credential_context()} | {:error, typed_error()}
  def provider_credential_context(provider) do
    with {:ok, normalized_provider} <- normalize_provider(provider),
         {:ok, %{scope: scope, name: name}} <- provider_secret_spec(normalized_provider),
         {:ok, secret_ref} <- get_secret_ref(scope, name),
         {:ok, active_secret_ref} <- require_existing_provider_secret(secret_ref, normalized_provider) do
      {:ok, to_provider_context(normalized_provider, active_secret_ref)}
    else
      {:error, :invalid_provider} ->
        {:error,
         typed_error(
           "provider_credential_invalid",
           "Provider must be one of anthropic or openai.",
           @write_failed_recovery_instruction
         )}

      {:error, {:provider_secret_missing, _provider}} ->
        {:error,
         typed_error(
           "provider_credential_missing",
           "No active provider credential is available for this provider.",
           "Store a provider credential in Security settings before starting runs."
         )}

      {:error, _reason} ->
        {:error,
         typed_error(
           "provider_credential_unavailable",
           "Provider credential context could not be loaded.",
           @read_failed_recovery_instruction
         )}
    end
  end

  @doc """
  Rotates provider credentials with atomic cutover and rollback-on-failed-validation.
  """
  @spec rotate_provider_credential(map()) ::
          {:ok, provider_rotation_report()} | {:error, typed_error()}
  def rotate_provider_credential(params) when is_map(params) do
    with {:ok, provider} <- normalize_provider(Map.get(params, :provider) || Map.get(params, "provider")),
         {:ok, value} <- normalize_value(Map.get(params, :value) || Map.get(params, "value")),
         {:ok, %{scope: scope, name: name} = provider_spec} <- provider_secret_spec(provider),
         {:ok, existing_secret_ref} <- get_secret_ref(scope, name),
         {:ok, active_secret_ref} <- require_existing_provider_secret(existing_secret_ref, provider),
         {:ok, before_verification} <-
           verify_rotation_stage(:before, provider, active_secret_ref, active_secret_ref, nil),
         {:ok, encrypted_ciphertext} <- Encryption.encrypt(value),
         {:ok, rotated_secret_ref} <- create_secret_ref(scope, name, encrypted_ciphertext, :rotation) do
      case verify_rotation_stage(:after, provider, rotated_secret_ref, active_secret_ref, value) do
        {:ok, after_verification} ->
          {:ok,
           build_rotation_report(
             provider,
             provider_spec,
             active_secret_ref,
             rotated_secret_ref,
             before_verification,
             after_verification,
             rollback_performed: false,
             continuity_alarm: false
           )}

        {:error, {:after_validation_failed, failed_after_verification}} ->
          rollback_after_validation_failure(
            provider,
            provider_spec,
            active_secret_ref,
            rotated_secret_ref,
            before_verification,
            failed_after_verification
          )
      end
    else
      {:error, :invalid_provider} ->
        {:error,
         typed_error(
           "provider_credential_invalid",
           "Provider must be one of anthropic or openai.",
           @write_failed_recovery_instruction
         )}

      {:error, :invalid_value} ->
        {:error,
         typed_error(
           "provider_credential_value_invalid",
           "Provider credential value must be a non-empty string.",
           @write_failed_recovery_instruction
         )}

      {:error, {:provider_secret_missing, _provider}} ->
        {:error,
         typed_error(
           "provider_credential_missing",
           "Provider credential rotation requires an existing active version.",
           "Create the initial provider credential in Security settings, then retry rotation."
         )}

      {:error, {:before_validation_failed, _failed_before_verification}} ->
        {:error,
         typed_error(
           "provider_rotation_precheck_failed",
           "Pre-rotation verification failed and references were not updated.",
           @rotation_precheck_failed_recovery_instruction
         )}

      {:error, :encryption_config_unavailable} ->
        {:error,
         typed_error(
           "secret_encryption_unavailable",
           "Secret encryption is unavailable and no secret was persisted.",
           @encryption_unavailable_recovery_instruction
         )}

      {:error, :encryption_failed} ->
        {:error,
         typed_error(
           "secret_encryption_failed",
           "Secret encryption failed and no secret was persisted.",
           @write_failed_recovery_instruction
         )}

      {:error, _reason} ->
        {:error,
         typed_error(
           "provider_rotation_failed",
           "Provider credential rotation failed and the active reference was not changed.",
           @write_failed_recovery_instruction
         )}
    end
  end

  def rotate_provider_credential(_params) do
    {:error,
     typed_error(
       "provider_rotation_failed",
       "Provider credential rotation failed and the active reference was not changed.",
       @write_failed_recovery_instruction
     )}
  end

  @doc """
  Persists an operational secret as an encrypted `SecretRef`.
  """
  @spec persist_operational_secret(map()) :: {:ok, secret_metadata()} | {:error, typed_error()}
  def persist_operational_secret(params) when is_map(params) do
    with {:ok, scope} <- normalize_scope(Map.get(params, :scope) || Map.get(params, "scope")),
         {:ok, name} <- normalize_name(Map.get(params, :name) || Map.get(params, "name")),
         {:ok, value} <- normalize_value(Map.get(params, :value) || Map.get(params, "value")),
         {:ok, source} <- normalize_source(Map.get(params, :source) || Map.get(params, "source")),
         {:ok, encrypted_ciphertext} <- Encryption.encrypt(value),
         {:ok, secret_ref} <- create_secret_ref(scope, name, encrypted_ciphertext, source) do
      {:ok, to_metadata(secret_ref)}
    else
      {:error, :invalid_scope} ->
        {:error,
         typed_error(
           "secret_scope_invalid",
           "Secret scope must be one of instance, project, or integration.",
           @write_failed_recovery_instruction
         )}

      {:error, :invalid_name} ->
        {:error,
         typed_error(
           "secret_name_invalid",
           "Secret name must be a non-empty string.",
           @write_failed_recovery_instruction
         )}

      {:error, :invalid_value} ->
        {:error,
         typed_error(
           "secret_value_invalid",
           "Secret value must be a non-empty string.",
           @write_failed_recovery_instruction
         )}

      {:error, :invalid_source} ->
        {:error,
         typed_error(
           "secret_source_invalid",
           "Secret source must be env, onboarding, or rotation.",
           @write_failed_recovery_instruction
         )}

      {:error, :encryption_config_unavailable} ->
        {:error,
         typed_error(
           "secret_encryption_unavailable",
           "Secret encryption is unavailable and no secret was persisted.",
           @encryption_unavailable_recovery_instruction
         )}

      {:error, :encryption_failed} ->
        {:error,
         typed_error(
           "secret_encryption_failed",
           "Secret encryption failed and no secret was persisted.",
           @write_failed_recovery_instruction
         )}

      {:error, _reason} ->
        {:error,
         typed_error(
           "secret_persistence_failed",
           "Secret persistence failed and no secret was persisted.",
           @write_failed_recovery_instruction
         )}
    end
  end

  def persist_operational_secret(_params) do
    {:error,
     typed_error(
       "secret_persistence_failed",
       "Secret persistence failed and no secret was persisted.",
       @write_failed_recovery_instruction
     )}
  end

  @doc """
  Reads non-sensitive SecretRef metadata for `/settings/security`.
  """
  @spec list_secret_metadata() :: {:ok, [secret_metadata()]} | {:error, typed_error()}
  def list_secret_metadata do
    case SecretRef.list_metadata(authorize?: false) do
      {:ok, records} ->
        {:ok, Enum.map(records, &to_metadata/1)}

      {:error, _reason} ->
        {:error,
         typed_error(
           "secret_metadata_unavailable",
           "Secret metadata could not be loaded.",
           @read_failed_recovery_instruction
         )}
    end
  end

  defp create_secret_ref(scope, name, encrypted_ciphertext, source) do
    with {:ok, existing_secret_ref} <- get_secret_ref(scope, name),
         {:ok, key_version} <- next_key_version(existing_secret_ref) do
      SecretRef.create(
        %{
          scope: scope,
          name: name,
          ciphertext: encrypted_ciphertext,
          source: metadata_source(source, existing_secret_ref),
          key_version: key_version,
          last_rotated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        },
        authorize?: false
      )
    end
  end

  defp get_secret_ref(scope, name) do
    case SecretRef.get_by_scope_name(scope, name, authorize?: false) do
      {:ok, %SecretRef{} = secret_ref} ->
        {:ok, secret_ref}

      {:ok, nil} ->
        {:ok, nil}

      {:error, reason} ->
        if secret_ref_not_found?(reason) do
          {:ok, nil}
        else
          {:error, reason}
        end
    end
  end

  defp secret_ref_not_found?(%Ash.Error.Query.NotFound{}), do: true

  defp secret_ref_not_found?(%Ash.Error.Invalid{errors: errors}) when is_list(errors) do
    Enum.any?(errors, &secret_ref_not_found?/1)
  end

  defp secret_ref_not_found?(%{errors: errors}) when is_list(errors) do
    Enum.any?(errors, &secret_ref_not_found?/1)
  end

  defp secret_ref_not_found?(_reason), do: false

  defp next_key_version(nil), do: {:ok, 1}

  defp next_key_version(%SecretRef{key_version: key_version}) when is_integer(key_version) do
    {:ok, key_version + 1}
  end

  defp next_key_version(_secret_ref), do: {:error, :invalid_key_version}

  defp metadata_source(source, nil), do: source
  defp metadata_source(:env, %SecretRef{}), do: :env
  defp metadata_source(_source, %SecretRef{}), do: :rotation

  defp normalize_scope(scope) when scope in [:instance, :project, :integration], do: {:ok, scope}
  defp normalize_scope("instance"), do: {:ok, :instance}
  defp normalize_scope("project"), do: {:ok, :project}
  defp normalize_scope("integration"), do: {:ok, :integration}
  defp normalize_scope(_scope), do: {:error, :invalid_scope}

  defp normalize_name(name) when is_binary(name) do
    case String.trim(name) do
      "" -> {:error, :invalid_name}
      normalized_name -> {:ok, normalized_name}
    end
  end

  defp normalize_name(_name), do: {:error, :invalid_name}

  defp normalize_value(value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, :invalid_value}
      _normalized_value -> {:ok, value}
    end
  end

  defp normalize_value(_value), do: {:error, :invalid_value}

  defp normalize_source(nil), do: {:ok, :onboarding}
  defp normalize_source(source) when source in [:env, :onboarding, :rotation], do: {:ok, source}
  defp normalize_source("env"), do: {:ok, :env}
  defp normalize_source("onboarding"), do: {:ok, :onboarding}
  defp normalize_source("rotation"), do: {:ok, :rotation}
  defp normalize_source(_source), do: {:error, :invalid_source}

  defp normalize_provider(provider) when provider in [:anthropic, :openai], do: {:ok, provider}
  defp normalize_provider("anthropic"), do: {:ok, :anthropic}
  defp normalize_provider("openai"), do: {:ok, :openai}
  defp normalize_provider(_provider), do: {:error, :invalid_provider}

  defp provider_secret_spec(provider) when provider in [:anthropic, :openai] do
    {:ok, Map.fetch!(@provider_secret_specs, provider)}
  end

  defp provider_secret_spec(_provider), do: {:error, :invalid_provider}

  defp require_existing_provider_secret(nil, provider), do: {:error, {:provider_secret_missing, provider}}
  defp require_existing_provider_secret(%SecretRef{} = secret_ref, _provider), do: {:ok, secret_ref}

  defp verify_rotation_stage(stage, provider, candidate_secret_ref, previous_secret_ref, value) do
    checked_at = DateTime.utc_now() |> DateTime.truncate(:second)

    context = %{
      provider: provider,
      stage: stage,
      credential_scope: candidate_secret_ref.scope,
      credential_name: candidate_secret_ref.name,
      candidate_key_version: candidate_secret_ref.key_version,
      previous_key_version: previous_secret_ref.key_version,
      value: value
    }

    case run_provider_rotation_validator(context) do
      {:ok, detail} ->
        {:ok, verification_result(:passed, normalize_text(detail, default_verification_detail(stage)), checked_at)}

      {:error, reason} ->
        verification =
          verification_result(:failed, verification_failure_detail(stage, reason), checked_at)

        case stage do
          :before -> {:error, {:before_validation_failed, verification}}
          :after -> {:error, {:after_validation_failed, verification}}
        end
    end
  end

  defp run_provider_rotation_validator(context) do
    validator =
      Application.get_env(
        :jido_code,
        :provider_credential_rotation_validator,
        &__MODULE__.default_provider_rotation_validator/1
      )

    safe_invoke_provider_rotation_validator(validator, context)
  end

  defp safe_invoke_provider_rotation_validator(validator, context) when is_function(validator, 1) do
    try do
      normalize_provider_rotation_validator_result(validator.(context), context)
    rescue
      _exception ->
        {:error, :validator_exception}
    catch
      _kind, _reason ->
        {:error, :validator_throw}
    end
  end

  defp safe_invoke_provider_rotation_validator(_validator, _context),
    do: {:error, :invalid_validator}

  defp normalize_provider_rotation_validator_result(:ok, context),
    do: {:ok, default_verification_detail(context.stage)}

  defp normalize_provider_rotation_validator_result({:ok, detail}, _context) when is_binary(detail),
    do: {:ok, detail}

  defp normalize_provider_rotation_validator_result(
         {:ok, %{detail: detail}},
         _context
       )
       when is_binary(detail),
       do: {:ok, detail}

  defp normalize_provider_rotation_validator_result({:error, reason}, _context), do: {:error, reason}

  defp normalize_provider_rotation_validator_result(_other, _context),
    do: {:error, :invalid_validator_result}

  defp rollback_after_validation_failure(
         provider,
         provider_spec,
         active_secret_ref,
         rotated_secret_ref,
         before_verification,
         failed_after_verification
       ) do
    case restore_secret_ref(active_secret_ref) do
      {:ok, _rolled_back_secret_ref} ->
        report =
          build_rotation_report(
            provider,
            provider_spec,
            active_secret_ref,
            rotated_secret_ref,
            before_verification,
            failed_after_verification,
            rollback_performed: true,
            continuity_alarm: false
          )

        {:error,
         typed_error(
           "provider_rotation_validation_failed",
           "Post-rotation validation failed. Credential references were rolled back to the prior version.",
           @rotation_failed_recovery_instruction,
           %{rotation_report: report}
         )}

      {:error, _reason} ->
        report =
          build_rotation_report(
            provider,
            provider_spec,
            active_secret_ref,
            rotated_secret_ref,
            before_verification,
            failed_after_verification,
            rollback_performed: false,
            continuity_alarm: true
          )

        {:error,
         typed_error(
           "provider_rotation_rollback_failed",
           "Post-rotation validation failed and rollback could not be confirmed.",
           @rotation_rollback_failed_recovery_instruction,
           %{rotation_report: report}
         )}
    end
  end

  defp restore_secret_ref(%SecretRef{} = secret_ref) do
    SecretRef.create(
      %{
        scope: secret_ref.scope,
        name: secret_ref.name,
        ciphertext: secret_ref.ciphertext,
        source: secret_ref.source,
        key_version: secret_ref.key_version,
        last_rotated_at: secret_ref.last_rotated_at,
        expires_at: secret_ref.expires_at
      },
      authorize?: false
    )
  end

  defp build_rotation_report(
         provider,
         provider_spec,
         before_secret_ref,
         after_secret_ref,
         before_verification,
         after_verification,
         opts
       ) do
    %{
      provider: provider,
      scope: provider_spec.scope,
      name: provider_spec.name,
      before: %{
        key_version: before_secret_ref.key_version,
        verification: before_verification
      },
      after: %{
        key_version: after_secret_ref.key_version,
        verification: after_verification
      },
      references_switched_at: DateTime.utc_now() |> DateTime.truncate(:second),
      rollback_performed: Keyword.get(opts, :rollback_performed, false),
      continuity_alarm: Keyword.get(opts, :continuity_alarm, false)
    }
  end

  @doc false
  def default_provider_rotation_validator(%{stage: :before, provider: provider}) do
    {:ok, "Current #{provider_display_name(provider)} credential context remains valid for in-flight runs."}
  end

  def default_provider_rotation_validator(%{stage: :after, provider: provider, value: value}) do
    if valid_provider_credential_value?(provider, value) do
      {:ok, "#{provider_display_name(provider)} rotated credential passed post-rotation verification."}
    else
      {:error, :invalid_provider_credential}
    end
  end

  def default_provider_rotation_validator(_context), do: {:error, :invalid_rotation_context}

  defp valid_provider_credential_value?(:anthropic, value)
       when is_binary(value),
       do: String.starts_with?(String.trim(value), "sk-ant-")

  defp valid_provider_credential_value?(:openai, value)
       when is_binary(value),
       do: String.starts_with?(String.trim(value), "sk-")

  defp valid_provider_credential_value?(_provider, _value), do: false

  defp provider_display_name(:anthropic), do: "Anthropic"
  defp provider_display_name(:openai), do: "OpenAI"

  defp default_verification_detail(:before), do: "Pre-rotation verification passed."
  defp default_verification_detail(:after), do: "Post-rotation verification passed."

  defp verification_failure_detail(_stage, :invalid_provider_credential),
    do: "Credential failed provider verification checks."

  defp verification_failure_detail(_stage, :invalid_rotation_context),
    do: "Rotation validation context was invalid."

  defp verification_failure_detail(_stage, :invalid_validator_result),
    do: "Rotation validator returned an invalid result."

  defp verification_failure_detail(_stage, :invalid_validator),
    do: "Rotation validator configuration is invalid."

  defp verification_failure_detail(_stage, :validator_exception),
    do: "Rotation validator raised an exception."

  defp verification_failure_detail(_stage, :validator_throw),
    do: "Rotation validator exited unexpectedly."

  defp verification_failure_detail(_stage, _reason),
    do: "Credential verification failed."

  defp verification_result(status, detail, checked_at) do
    %{
      status: status,
      detail: detail,
      checked_at: checked_at
    }
  end

  defp to_provider_context(provider, %SecretRef{} = secret_ref) do
    %{
      provider: provider,
      id: secret_ref.id,
      scope: secret_ref.scope,
      name: secret_ref.name,
      key_version: secret_ref.key_version,
      source: secret_ref.source,
      last_rotated_at: secret_ref.last_rotated_at,
      ciphertext: secret_ref.ciphertext
    }
  end

  defp typed_error(error_type, message, recovery_instruction, extra \\ %{}) do
    %{
      error_type: error_type,
      message: message,
      recovery_instruction: recovery_instruction
    }
    |> Map.merge(extra)
  end

  defp normalize_text(text, fallback) when is_binary(text) do
    case String.trim(text) do
      "" -> fallback
      normalized_text -> normalized_text
    end
  end

  defp normalize_text(_text, fallback), do: fallback

  defp to_metadata(%SecretRef{} = secret_ref) do
    %{
      id: secret_ref.id,
      scope: secret_ref.scope,
      name: secret_ref.name,
      key_version: secret_ref.key_version,
      source: secret_ref.source,
      last_rotated_at: secret_ref.last_rotated_at,
      expires_at: secret_ref.expires_at
    }
  end
end
