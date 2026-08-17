defmodule JidoCode.Factory.Sandbox.Tier do
  @moduledoc "Closed workload-to-production-isolation tier table."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Sandbox.IsolationProfile

  @tiers ~w[restricted_beam container_sandbox micro_vm dedicated_host]a
  @workloads %{
    read_only_analysis: :restricted_beam,
    non_executing_transformation: :container_sandbox,
    build: :micro_vm,
    test: :micro_vm,
    hook: :micro_vm,
    compiler: :micro_vm,
    native_tool: :micro_vm,
    unknown_high_risk: :dedicated_host
  }

  @images %{
    restricted_beam: {
      :beam_worker,
      "restricted-beam",
      "sha256:2d98580af76e3bea20cae762b5b1f938db7c4b44f371bbf24f3b18989bb34ac4"
    },
    container_sandbox: {
      :gvisor,
      "gvisor-transform",
      "sha256:22e9d5f74bfef1c7365405fd077371107a48218dbe9b7a8ba45c902f0ad7d434"
    },
    micro_vm: {
      :firecracker,
      "firecracker-build",
      "sha256:785f0a40904108fb7f2b90a760d4d628d9c9d9d7d2c4d0743b4ba005af31c35e"
    },
    dedicated_host: {
      :dedicated_micro_vm_host,
      "dedicated-host",
      "sha256:49f5e81b78a95905ee7ddb8c16c506a71f34cc328fb24b2ee37ffb718ed6eaf0"
    }
  }

  @limits %{
    restricted_beam: %{
      cpu_ms: 30_000,
      memory_bytes: 268_435_456,
      process_count: 32,
      disk_bytes: 67_108_864,
      output_bytes: 1_048_576,
      timeout_ms: 30_000
    },
    container_sandbox: %{
      cpu_ms: 60_000,
      memory_bytes: 536_870_912,
      process_count: 64,
      disk_bytes: 536_870_912,
      output_bytes: 2_097_152,
      timeout_ms: 60_000
    },
    micro_vm: %{
      cpu_ms: 300_000,
      memory_bytes: 2_147_483_648,
      process_count: 256,
      disk_bytes: 4_294_967_296,
      output_bytes: 10_485_760,
      timeout_ms: 600_000
    },
    dedicated_host: %{
      cpu_ms: 600_000,
      memory_bytes: 4_294_967_296,
      process_count: 512,
      disk_bytes: 8_589_934_592,
      output_bytes: 10_485_760,
      timeout_ms: 900_000
    }
  }

  @spec all() :: [atom()]
  def all, do: @tiers

  @spec select(atom()) :: {:ok, atom()} | {:error, AdapterError.t()}
  def select(workload) when is_atom(workload) do
    case Map.fetch(@workloads, workload) do
      {:ok, tier} -> {:ok, tier}
      :error -> invalid(:sandbox_workload_class)
    end
  end

  def select(_workload), do: invalid(:sandbox_workload_class)

  @spec profile(atom()) :: {:ok, IsolationProfile.t()} | {:error, AdapterError.t()}
  def profile(tier) when tier in @tiers do
    {technology, image, image_digest} = Map.fetch!(@images, tier)

    IsolationProfile.new(%{
      tier: tier,
      technology: technology,
      image_reference: "https://registry.jido.run/sandbox/#{image}@#{image_digest}",
      image_digest: image_digest,
      tool_digests: %{
        "jido-code-toolchain" =>
          "sha256:f3a51c2672e90de762e80db6ba714a8f3c4b541ce4dae850068ab586e7e42bf4"
      },
      unprivileged: true,
      read_only_root: true,
      copy_on_write_workspace: true,
      host_filesystem: false,
      docker_socket: false,
      device_access: false,
      ambient_credentials: false,
      capabilities: [],
      no_new_privs: true,
      syscall_policy_digest:
        "sha256:e783ee8d6a9170625db3f7a9373e5e824ee7c60c5fff5d40ca7107c8ec0206e4",
      network: :deny,
      mounts: [:workspace, :artifact],
      limits: Map.fetch!(@limits, tier)
    })
  end

  def profile(_tier), do: invalid(:sandbox_tier)

  @spec pins() :: map()
  def pins do
    Map.new(@tiers, fn tier ->
      {:ok, profile} = profile(tier)
      {tier, %{image_digest: profile.image_digest, tool_digests: profile.tool_digests}}
    end)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
