defmodule JidoCode.Factory.Sandbox.Request do
  @moduledoc "Bounded sandbox policy for one fenced execution request."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest

  @enforce_keys [
    :execution,
    :base_snapshot_iri,
    :allowed_write_paths,
    :command_allowlist,
    :environment_allowlist,
    :secret_reference_iris,
    :limits
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with %ExecutionRequest{} = execution <- attributes[:execution],
         true <- execution.snapshot_iri == attributes[:base_snapshot_iri],
         :ok <- relative_paths(attributes[:allowed_write_paths]),
         :ok <- strings(attributes[:command_allowlist], 50, 256),
         :ok <- strings(attributes[:environment_allowlist], 100, 128),
         :ok <- resource_references(attributes[:secret_reference_iris]),
         {:ok, limits} <- limits(attributes[:limits]) do
      {:ok,
       %__MODULE__{
         execution: execution,
         base_snapshot_iri: attributes.base_snapshot_iri,
         allowed_write_paths: Enum.sort(attributes.allowed_write_paths),
         command_allowlist: Enum.sort(attributes.command_allowlist),
         environment_allowlist: Enum.sort(attributes.environment_allowlist),
         secret_reference_iris: Enum.sort(attributes.secret_reference_iris),
         limits: limits
       }}
    else
      _invalid -> invalid(:sandbox_request)
    end
  rescue
    _error -> invalid(:sandbox_request)
  end

  def new(_attributes), do: invalid(:sandbox_request)

  defp limits(%{
         cpu_ms: cpu,
         memory_bytes: memory,
         disk_bytes: disk,
         timeout_ms: timeout,
         output_bytes: output,
         network: network
       })
       when cpu in 1..3_600_000 and memory in 1..17_179_869_184 and
              disk in 1..107_374_182_400 and timeout in 1..3_600_000 and
              output in 1..10_485_760 and network in [:deny, :allowlisted] do
    {:ok,
     %{
       cpu_ms: cpu,
       memory_bytes: memory,
       disk_bytes: disk,
       timeout_ms: timeout,
       output_bytes: output,
       network: network
     }}
  end

  defp limits(_limits), do: :error

  defp relative_paths(paths) when is_list(paths) and length(paths) <= 100 do
    if Enum.all?(paths, &relative_path?/1), do: :ok, else: :error
  end

  defp relative_paths(_paths), do: :error

  defp relative_path?(path) when is_binary(path) do
    normalized = String.replace(path, "\\", "/")

    normalized != "" and byte_size(normalized) <= 512 and
      not String.starts_with?(normalized, "/") and
      not Enum.any?(String.split(normalized, "/"), &(&1 in ["", ".", ".."]))
  end

  defp relative_path?(_path), do: false

  defp strings(values, count, bytes) when is_list(values) and length(values) <= count do
    if Enum.all?(values, &(is_binary(&1) and byte_size(&1) in 1..bytes)), do: :ok, else: :error
  end

  defp strings(_values, _count, _bytes), do: :error

  defp resource_references(values) when is_list(values) and length(values) <= 50 do
    if Enum.all?(values, &String.starts_with?(&1, "https://jido.run/id/")), do: :ok, else: :error
  end

  defp resource_references(_values), do: :error
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
