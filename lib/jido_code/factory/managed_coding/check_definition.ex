defmodule JidoCode.Factory.ManagedCoding.CheckDefinition do
  @moduledoc "A server-owned, revision-pinned registered check contract."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest

  @enforce_keys [
    :name,
    :executable,
    :arguments,
    :cwd,
    :environment,
    :toolchain_digest,
    :timeout_ms,
    :output_bytes,
    :resources,
    :retry_policy,
    :network
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with name when is_binary(name) and byte_size(name) in 1..64 <- attributes[:name],
         executable when is_binary(executable) and byte_size(executable) in 1..256 <-
           attributes[:executable],
         true <- Path.type(executable) == :absolute,
         arguments when is_list(arguments) and length(arguments) <= 64 <- attributes[:arguments],
         true <- Enum.all?(arguments, &(is_binary(&1) and byte_size(&1) <= 1_024)),
         cwd when is_binary(cwd) <- attributes[:cwd],
         true <- safe_relative?(cwd),
         environment when is_map(environment) and map_size(environment) <= 32 <-
           attributes[:environment],
         true <- Enum.all?(environment, &valid_environment?/1),
         digest when is_binary(digest) and byte_size(digest) == 64 <-
           attributes[:toolchain_digest],
         timeout when is_integer(timeout) and timeout in 1..3_600_000 <- attributes[:timeout_ms],
         output when is_integer(output) and output in 1..1_048_576 <- attributes[:output_bytes],
         resources when is_map(resources) <- attributes[:resources],
         retry when retry in [:never, :safe_idempotent, :flake_once] <- attributes[:retry_policy],
         network when network in [:deny, :allowlisted] <- attributes[:network] do
      {:ok, struct!(__MODULE__, Map.take(attributes, @enforce_keys))}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec digest(t()) :: String.t()
  def digest(%__MODULE__{} = definition), do: WorkspaceDigest.digest(Map.from_struct(definition))

  defp safe_relative?("."), do: true

  defp safe_relative?(path) do
    Path.type(path) == :relative and
      Enum.all?(Path.split(path), &(&1 not in ["", ".", ".."]))
  end

  defp valid_environment?({key, value}),
    do:
      is_binary(key) and key =~ ~r/^[A-Z][A-Z0-9_]{0,63}$/ and is_binary(value) and
        byte_size(value) <= 4_096

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :registered_check_definition)}
end
