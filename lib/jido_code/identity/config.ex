defmodule JidoCode.Identity.Config do
  @moduledoc false

  @enforce_keys [
    :enabled?,
    :persistence?,
    :path,
    :integrity_key,
    :policy_revision,
    :pbkdf2_iterations,
    :max_failed_attempts,
    :lockout_seconds,
    :recovery_adapter,
    :hard_lifetime_seconds,
    :idle_lifetime_seconds,
    :idle_warning_seconds,
    :maximum_authentication_age_seconds,
    :bootstrap,
    :authority_adapter
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          enabled?: boolean(),
          persistence?: boolean(),
          path: Path.t() | nil,
          integrity_key: binary() | nil,
          policy_revision: String.t(),
          pbkdf2_iterations: pos_integer(),
          max_failed_attempts: pos_integer(),
          lockout_seconds: pos_integer(),
          recovery_adapter: module(),
          hard_lifetime_seconds: pos_integer(),
          idle_lifetime_seconds: pos_integer(),
          idle_warning_seconds: pos_integer(),
          maximum_authentication_age_seconds: pos_integer(),
          bootstrap: map() | nil,
          authority_adapter: module()
        }

  @spec load(keyword()) :: {:ok, t()} | {:error, atom()}
  def load(overrides \\ []) do
    values =
      :jido_code
      |> Application.get_env(:human_identity, [])
      |> Keyword.merge(overrides)

    config = %__MODULE__{
      enabled?: Keyword.get(values, :enabled, false),
      persistence?: Keyword.get(values, :persistence, false),
      path: Keyword.get(values, :path),
      integrity_key: Keyword.get(values, :integrity_key),
      policy_revision: Keyword.get(values, :policy_revision, "hui.identity.v1"),
      pbkdf2_iterations: Keyword.get(values, :pbkdf2_iterations, 210_000),
      max_failed_attempts: Keyword.get(values, :max_failed_attempts, 5),
      lockout_seconds: Keyword.get(values, :lockout_seconds, 300),
      recovery_adapter:
        Keyword.get(values, :recovery_adapter, JidoCode.Identity.Recovery.Unconfigured),
      hard_lifetime_seconds: Keyword.get(values, :hard_lifetime_seconds, 43_200),
      idle_lifetime_seconds: Keyword.get(values, :idle_lifetime_seconds, 1_800),
      idle_warning_seconds: Keyword.get(values, :idle_warning_seconds, 300),
      maximum_authentication_age_seconds:
        Keyword.get(values, :maximum_authentication_age_seconds, 43_200),
      bootstrap: Keyword.get(values, :bootstrap),
      authority_adapter:
        Keyword.get(values, :authority_adapter, JidoCode.Identity.Authority.Unconfigured)
    }

    validate(config)
  end

  defp validate(%__MODULE__{} = config) do
    with true <- is_boolean(config.enabled?),
         true <- is_boolean(config.persistence?),
         true <- valid_path?(config),
         true <- valid_integrity_key?(config),
         true <- is_binary(config.policy_revision) and byte_size(config.policy_revision) in 1..128,
         true <- config.pbkdf2_iterations in 1_000..2_000_000,
         true <- config.max_failed_attempts in 1..20,
         true <- config.lockout_seconds in 1..86_400,
         true <- valid_adapter?(config.recovery_adapter, :verify, 2),
         true <- config.hard_lifetime_seconds in 300..43_200,
         true <- config.idle_lifetime_seconds in 60..1_800,
         true <- config.idle_warning_seconds in 30..300,
         true <- config.idle_warning_seconds < config.idle_lifetime_seconds,
         true <- config.maximum_authentication_age_seconds in 300..43_200,
         true <- is_nil(config.bootstrap) or is_map(config.bootstrap),
         true <- valid_adapter?(config.authority_adapter, :resolve, 5) do
      {:ok, config}
    else
      _invalid -> {:error, :invalid_identity_config}
    end
  end

  defp valid_path?(%__MODULE__{persistence?: false}), do: true

  defp valid_path?(%__MODULE__{path: path}),
    do: is_binary(path) and byte_size(path) > 0 and Path.type(path) == :absolute

  defp valid_integrity_key?(%__MODULE__{persistence?: false}), do: true

  defp valid_integrity_key?(%__MODULE__{integrity_key: key}),
    do: is_binary(key) and byte_size(key) >= 32

  defp valid_adapter?(module, function, arity) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, function, arity)
  end

  defp valid_adapter?(_module, _function, _arity), do: false
end
