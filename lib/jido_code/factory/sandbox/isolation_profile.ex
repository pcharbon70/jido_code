defmodule JidoCode.Factory.Sandbox.IsolationProfile do
  @moduledoc "Pinned production isolation controls attested by a sandbox adapter."

  alias JidoCode.Factory.AdapterError

  @derive {Inspect, only: [:tier, :technology, :image_digest, :limits]}
  @enforce_keys [
    :tier,
    :technology,
    :image_reference,
    :image_digest,
    :tool_digests,
    :unprivileged,
    :read_only_root,
    :copy_on_write_workspace,
    :host_filesystem,
    :docker_socket,
    :device_access,
    :ambient_credentials,
    :capabilities,
    :no_new_privs,
    :syscall_policy_digest,
    :network,
    :mounts,
    :limits
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @tiers ~w[restricted_beam container_sandbox micro_vm dedicated_host]a
  @technologies ~w[beam_worker gvisor firecracker dedicated_micro_vm_host]a
  @mounts ~w[workspace artifact]a
  @limit_keys ~w[cpu_ms memory_bytes process_count disk_bytes output_bytes timeout_ms]a

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with tier when tier in @tiers <- attributes[:tier],
         technology when technology in @technologies <- attributes[:technology],
         :ok <- safe_image(attributes[:image_reference], attributes[:image_digest]),
         :ok <- digests(attributes[:tool_digests]),
         true <- attributes[:unprivileged] == true,
         true <- attributes[:read_only_root] == true,
         true <- attributes[:copy_on_write_workspace] == true,
         true <- attributes[:host_filesystem] == false,
         true <- attributes[:docker_socket] == false,
         true <- attributes[:device_access] == false,
         true <- attributes[:ambient_credentials] == false,
         [] <- attributes[:capabilities],
         true <- attributes[:no_new_privs] == true,
         :ok <- validate_digest(attributes[:syscall_policy_digest]),
         :deny <- attributes[:network],
         mounts when is_list(mounts) <- attributes[:mounts],
         true <- Enum.sort(mounts) == Enum.sort(@mounts),
         :ok <- limits(attributes[:limits]) do
      {:ok, struct!(__MODULE__, Map.take(attributes, @enforce_keys))}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec admits?(t(), map()) :: boolean()
  def admits?(%__MODULE__{} = profile, request_limits) when is_map(request_limits) do
    Enum.all?(@limit_keys, fn key ->
      requested = request_limit(request_limits, key)
      maximum = Map.fetch!(profile.limits, key)
      is_integer(requested) and requested > 0 and requested <= maximum
    end) and request_limits[:network] == :deny
  end

  def admits?(_profile, _limits), do: false

  @spec digest(t()) :: String.t()
  def digest(%__MODULE__{} = profile) do
    profile
    |> Map.from_struct()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> then(&("sha256:" <> &1))
  end

  defp safe_image(reference, digest) when is_binary(reference) do
    with %URI{scheme: "https", host: host} when is_binary(host) <- URI.parse(reference),
         :ok <- validate_digest(digest),
         true <- String.ends_with?(reference, "@" <> digest) do
      :ok
    else
      _invalid -> :error
    end
  end

  defp safe_image(_reference, _digest), do: :error

  defp digests(values) when is_map(values) and map_size(values) in 1..64 do
    if Enum.all?(values, fn {name, value} ->
         is_binary(name) and byte_size(name) in 1..128 and validate_digest(value) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp digests(_values), do: :error

  defp validate_digest(value) when is_binary(value) do
    if Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value), do: :ok, else: :error
  end

  defp validate_digest(_value), do: :error

  defp limits(values) when is_map(values) do
    if MapSet.new(Map.keys(values)) == MapSet.new(@limit_keys) and
         Enum.all?(@limit_keys, fn key ->
           value = Map.fetch!(values, key)
           is_integer(value) and value > 0
         end),
       do: :ok,
       else: :error
  end

  defp limits(_values), do: :error
  defp request_limit(values, :process_count), do: Map.get(values, :process_count, 64)
  defp request_limit(values, key), do: Map.get(values, key)
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :sandbox_isolation_profile)}
end
