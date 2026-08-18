defmodule JidoCode.Factory.Extensions.AutonomousMerge.Pilot do
  @moduledoc "Future low-risk shadow envelope that retains human merge authority."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.AutonomousMerge.Policy
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge

  @keys [
    :policy_digest,
    :pilot_iri,
    :task_iri,
    :task_class,
    :risk,
    :reversible,
    :evidence,
    :immediate_disable_triggers,
    :human_merge_required
  ]
  @evidence_keys [
    :accepted_adr_iri,
    :accepted_adr_digest,
    :release_gate_iri,
    :release_gate_digest,
    :production_shadow_iri,
    :production_shadow_digest,
    :pull_request_evidence_iri,
    :pull_request_evidence_digest,
    :rollback_plan_iri,
    :rollback_plan_digest
  ]
  @evidence_iri_keys [
    :accepted_adr_iri,
    :release_gate_iri,
    :production_shadow_iri,
    :pull_request_evidence_iri,
    :rollback_plan_iri
  ]
  @evidence_digest_keys [
    :accepted_adr_digest,
    :release_gate_digest,
    :production_shadow_digest,
    :pull_request_evidence_digest,
    :rollback_plan_digest
  ]

  @enforce_keys @keys ++ [:authority, :autonomous_merge_authorized, :digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Policy.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%Policy{} = policy, attributes) when is_map(attributes) do
    with true <- Policy.valid?(policy),
         true <- exact_shape?(attributes, @keys),
         true <- attributes[:policy_digest] == policy.digest,
         :ok <- resources(attributes, [:pilot_iri, :task_iri]),
         true <- attributes[:task_class] in policy.pilot_task_classes,
         :low <- attributes[:risk],
         true <- attributes[:reversible],
         {:ok, evidence} <- evidence(attributes[:evidence]),
         true <- attributes[:immediate_disable_triggers] == policy.immediate_disable_triggers,
         true <- attributes[:human_merge_required],
         normalized <- Map.put(attributes, :evidence, evidence),
         shadow <-
           normalized
           |> Map.put(:authority, :human_merge_shadow)
           |> Map.put(:autonomous_merge_authorized, false),
         digest <- Definition.digest(shadow) do
      {:ok, struct!(__MODULE__, Map.put(shadow, :digest, digest))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:autonomous_merge_pilot)
    end
  rescue
    _error -> invalid(:autonomous_merge_pilot)
  end

  def new(_policy, _attributes), do: invalid(:autonomous_merge_pilot)

  @spec valid?(t(), Policy.t()) :: boolean()
  def valid?(%__MODULE__{} = pilot, %Policy{} = policy) do
    attributes = pilot |> Map.from_struct() |> Map.take(@keys)

    case new(policy, attributes) do
      {:ok, rebuilt} -> rebuilt == pilot
      {:error, %AdapterError{}} -> false
    end
  end

  def valid?(_pilot, _policy), do: false

  defp evidence(value) when is_map(value) do
    with true <- exact_shape?(value, @evidence_keys),
         :ok <- resources(value, @evidence_iri_keys),
         true <- Enum.all?(@evidence_digest_keys, &digest?(value[&1])) do
      {:ok, Map.take(value, @evidence_keys)}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:autonomous_merge_evidence)
    end
  end

  defp evidence(_value), do: invalid(:autonomous_merge_evidence)

  defp resources(attributes, keys) do
    if Enum.all?(keys, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid(:autonomous_merge_identity)
  end

  defp exact_shape?(value, keys),
    do: MapSet.new(Map.keys(value)) == MapSet.new(keys)

  defp digest?(value),
    do: is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
