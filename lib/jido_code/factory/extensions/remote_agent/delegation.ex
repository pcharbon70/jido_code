defmodule JidoCode.Factory.Extensions.RemoteAgent.Delegation do
  @moduledoc "One remote task mapped onto one local governed attempt, lease, and fence."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Extensions.RemoteAgent.Specification
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge

  @keys [
    :specification_digest,
    :remote_task_reference_iri,
    :execution,
    :capability,
    :context_manifest_iri,
    :context_manifest_digest,
    :budget,
    :capability_receipt
  ]
  @budget_keys [:output_bytes, :wall_time_ms, :cost_microunits, :model_tokens]
  @receipt_keys [
    :iri,
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :remote_agent_iri,
    :protocol_versions,
    :capability_digest,
    :digest
  ]

  @enforce_keys @keys ++ [:digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Specification.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%Specification{} = specification, attributes) when is_map(attributes) do
    with true <- Specification.valid?(specification),
         true <- exact_shape?(attributes, @keys),
         true <- attributes[:specification_digest] == specification.digest,
         :ok <- resources(attributes, [:remote_task_reference_iri, :context_manifest_iri]),
         true <- digest?(attributes[:context_manifest_digest]),
         %Request{} = execution <- attributes[:execution],
         %Capability{} = capability <- attributes[:capability],
         :ok <- execution_binding(execution, capability, specification),
         {:ok, budget} <- budget(attributes[:budget], specification, capability),
         {:ok, receipt} <-
           capability_receipt(
             attributes[:capability_receipt],
             execution,
             capability,
             specification
           ),
         normalized <-
           attributes
           |> Map.put(:budget, budget)
           |> Map.put(:capability_receipt, receipt),
         digest <- Definition.digest({specification.digest, Map.take(normalized, @keys)}) do
      {:ok, struct!(__MODULE__, Map.put(normalized, :digest, digest))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:remote_agent_delegation)
    end
  rescue
    _error -> invalid(:remote_agent_delegation)
  end

  def new(_specification, _attributes), do: invalid(:remote_agent_delegation)

  @spec valid?(t(), Specification.t()) :: boolean()
  def valid?(%__MODULE__{} = delegation, %Specification{} = specification) do
    attributes = delegation |> Map.from_struct() |> Map.take(@keys)

    case new(specification, attributes) do
      {:ok, rebuilt} -> rebuilt == delegation
      {:error, %AdapterError{}} -> false
    end
  end

  def valid?(_delegation, _specification), do: false

  @spec validate_set([t()]) :: :ok | {:error, AdapterError.t()}
  def validate_set(delegations) when is_list(delegations) and delegations != [] do
    fields = [
      Enum.map(delegations, & &1.remote_task_reference_iri),
      Enum.map(delegations, & &1.execution.attempt_iri),
      Enum.map(delegations, & &1.execution.lease_iri),
      Enum.map(delegations, &{&1.execution.repository_iri, &1.execution.fencing_token})
    ]

    if Enum.all?(delegations, &match?(%__MODULE__{}, &1)) and
         Enum.all?(fields, &(length(&1) == length(Enum.uniq(&1)))) do
      :ok
    else
      invalid(:remote_agent_delegation_set)
    end
  rescue
    _error -> invalid(:remote_agent_delegation_set)
  end

  def validate_set(_delegations), do: invalid(:remote_agent_delegation_set)

  @spec provenance(t(), Specification.t()) :: map()
  def provenance(%__MODULE__{} = delegation, %Specification{} = specification) do
    %{
      remote_agent_iri: specification.remote_agent_iri,
      remote_identity: specification.remote_identity,
      protocol_versions: specification.protocol_versions,
      capability_receipt_iri: delegation.capability_receipt.iri,
      capability_receipt_digest: delegation.capability_receipt.digest,
      delegation_digest: delegation.digest
    }
  end

  defp execution_binding(execution, capability, specification) do
    matches? =
      execution.attempt_iri == capability.attempt_iri and
        execution.lease_iri == capability.lease_iri and
        execution.task_iri == capability.task_iri and
        execution.repository_iri == capability.repository_iri and
        execution.snapshot_iri == capability.snapshot_iri and
        execution.actor_iri == capability.actor_iri and
        execution.agent_iri == capability.agent_iri and
        execution.agent_iri == specification.remote_agent_iri and
        execution.fencing_token == capability.fencing_token and
        capability.authority_classes == [:tool_execution]

    if matches?, do: :ok, else: {:error, AdapterError.new(:unauthorized, :remote_attempt)}
  end

  defp budget(value, specification, capability) when is_map(value) do
    with true <- exact_shape?(value, @budget_keys),
         true <-
           Enum.all?(@budget_keys, fn key ->
             amount = value[key]
             maximum = specification.maximum_budget[key]
             ceiling = Map.get(capability.resource_ceilings, key, 0)
             is_integer(amount) and amount > 0 and amount <= maximum and amount <= ceiling
           end) do
      {:ok, Map.take(value, @budget_keys)}
    else
      _invalid -> invalid(:remote_agent_delegation_budget)
    end
  end

  defp budget(_value, _specification, _capability),
    do: invalid(:remote_agent_delegation_budget)

  defp capability_receipt(receipt, execution, capability, specification)
       when is_map(receipt) do
    capability_digest = Definition.digest(Map.from_struct(capability))
    material = Map.take(receipt, @receipt_keys -- [:digest])

    with true <- exact_shape?(receipt, @receipt_keys),
         :ok <- Knowledge.validate_resource_identity(receipt[:iri]),
         true <- receipt[:attempt_iri] == execution.attempt_iri,
         true <- receipt[:lease_iri] == execution.lease_iri,
         true <- receipt[:fencing_token] == execution.fencing_token,
         true <- receipt[:remote_agent_iri] == specification.remote_agent_iri,
         true <- receipt[:protocol_versions] == specification.protocol_versions,
         true <- receipt[:capability_digest] == capability_digest,
         true <- receipt[:digest] == Definition.digest(material) do
      {:ok, Map.take(receipt, @receipt_keys)}
    else
      _invalid -> invalid(:remote_agent_capability_receipt)
    end
  end

  defp capability_receipt(_receipt, _execution, _capability, _specification),
    do: invalid(:remote_agent_capability_receipt)

  defp resources(attributes, keys) do
    if Enum.all?(keys, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid(:remote_agent_delegation_identity)
  end

  defp exact_shape?(value, keys),
    do: MapSet.new(Map.keys(value)) == MapSet.new(keys)

  defp digest?(value),
    do: is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
