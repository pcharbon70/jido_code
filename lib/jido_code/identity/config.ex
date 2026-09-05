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
    :recovery_adapter
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
          recovery_adapter: module()
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
        Keyword.get(values, :recovery_adapter, JidoCode.Identity.Recovery.Unconfigured)
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
         true <- is_atom(config.recovery_adapter) do
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
end
