defmodule JidoCode.Factory.Extensions.Registry do
  @moduledoc "Explicit runtime enablement registry for optional Harness extensions."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.MCP.Specification, as: MCPSpecification
  alias JidoCode.Factory.Extensions.MultiAgent.Specification, as: MultiAgentSpecification
  alias JidoCode.Factory.Extensions.RemoteAgent.Specification, as: RemoteAgentSpecification
  alias JidoCode.Factory.Tool.Definition

  @contract_version "1.0.0"
  @extensions [:mcp, :remote_agent, :multi_agent, :autonomous_merge]
  @status_keys [:state, :specification_digest, :evidence_digest, :monitor]
  @monitors %{
    mcp: :phase3_reference_monitor,
    remote_agent: :delegated_result_gate,
    multi_agent: :graph_work_contract
  }

  @enforce_keys [:revision, :extensions, :digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec disabled() :: t()
  def disabled do
    extensions =
      Map.new(@extensions, fn extension ->
        {extension,
         %{
           state: :disabled,
           specification_digest: nil,
           evidence_digest: nil,
           monitor: nil
         }}
      end)

    build("extension-registry-1", extensions)
  end

  @spec extensions() :: [atom()]
  def extensions, do: @extensions

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = registry) do
    MapSet.new(Map.keys(registry.extensions)) == MapSet.new(@extensions) and
      Enum.all?(registry.extensions, fn {extension, status} -> status?(extension, status) end) and
      registry == build(registry.revision, registry.extensions)
  rescue
    _error -> false
  end

  def valid?(_registry), do: false

  @spec enable(t(), atom(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def enable(%__MODULE__{} = registry, extension, proof)
      when extension in [:mcp, :remote_agent, :multi_agent] and is_map(proof) do
    with true <- valid?(registry),
         true <- MapSet.new(Map.keys(proof)) == proof_keys(),
         :ok <- accepted_specification(extension, proof[:specification]),
         true <- proof[:specification_digest] == proof.specification.digest,
         true <- digest?(proof[:evidence_digest]),
         true <- proof[:monitor] == @monitors[extension] do
      status = %{
        state: :enabled,
        specification_digest: proof.specification_digest,
        evidence_digest: proof.evidence_digest,
        monitor: proof.monitor
      }

      {:ok, build(registry.revision, Map.put(registry.extensions, extension, status))}
    else
      _invalid -> denied(:extension_enablement)
    end
  rescue
    _error -> denied(:extension_enablement)
  end

  def enable(%__MODULE__{}, :autonomous_merge, _proof),
    do: denied(:autonomous_merge_blocked)

  def enable(_registry, _extension, _proof), do: denied(:extension_enablement)

  @spec authorize(t(), atom(), struct()) :: :ok | {:error, AdapterError.t()}
  def authorize(%__MODULE__{} = registry, extension, specification)
      when extension in [:mcp, :remote_agent, :multi_agent] do
    with true <- valid?(registry),
         %{state: :enabled} = status <- registry.extensions[extension],
         :ok <- accepted_specification(extension, specification),
         true <- status.specification_digest == specification.digest,
         true <- status.monitor == @monitors[extension],
         true <- digest?(status.evidence_digest) do
      :ok
    else
      _invalid -> denied(:extension_disabled)
    end
  end

  def authorize(%__MODULE__{}, :autonomous_merge, _specification),
    do: denied(:autonomous_merge_blocked)

  def authorize(_registry, _extension, _specification), do: denied(:extension_disabled)

  @spec posture(t()) :: map()
  def posture(%__MODULE__{} = registry) do
    Map.new(@extensions, fn extension ->
      status = registry.extensions[extension]

      {extension,
       %{
         runtime: status.state,
         specification_digest: status.specification_digest,
         evidence_digest: status.evidence_digest,
         monitor: status.monitor
       }}
    end)
  end

  defp accepted_specification(:mcp, %MCPSpecification{} = specification) do
    if MCPSpecification.valid?(specification), do: :ok, else: :error
  end

  defp accepted_specification(:remote_agent, %RemoteAgentSpecification{} = specification) do
    if RemoteAgentSpecification.valid?(specification), do: :ok, else: :error
  end

  defp accepted_specification(:multi_agent, %MultiAgentSpecification{} = specification) do
    if MultiAgentSpecification.valid?(specification), do: :ok, else: :error
  end

  defp accepted_specification(_extension, _specification), do: :error

  defp status?(extension, status) when is_map(status) do
    if MapSet.new(Map.keys(status)) == MapSet.new(@status_keys) do
      case status.state do
        :disabled ->
          is_nil(status.specification_digest) and is_nil(status.evidence_digest) and
            is_nil(status.monitor)

        :enabled when extension in [:mcp, :remote_agent, :multi_agent] ->
          digest?(status.specification_digest) and digest?(status.evidence_digest) and
            status.monitor == @monitors[extension]

        _other ->
          false
      end
    else
      false
    end
  end

  defp status?(_extension, _status), do: false

  defp build(revision, extensions) do
    attributes = %{revision: revision, extensions: extensions}
    struct!(__MODULE__, Map.put(attributes, :digest, Definition.digest(attributes)))
  end

  defp proof_keys,
    do: MapSet.new([:specification, :specification_digest, :evidence_digest, :monitor])

  defp digest?(value),
    do: is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp denied(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end
