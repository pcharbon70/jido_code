defmodule JidoCode.Factory.Extensions.RemoteAgent.Result do
  @moduledoc "Bounded remote output observation that cannot express accepted work."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.RemoteAgent.Delegation
  alias JidoCode.Factory.Extensions.RemoteAgent.Specification
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge

  @keys [
    :delegation_digest,
    :remote_task_reference_iri,
    :output,
    :output_digest,
    :output_bytes,
    :claim_digests,
    :provenance,
    :verifier_iri,
    :decision_actor_iri,
    :completed_at
  ]
  @provenance_keys [
    :remote_agent_iri,
    :remote_identity,
    :protocol_versions,
    :capability_receipt_iri,
    :capability_receipt_digest,
    :delegation_digest
  ]

  @enforce_keys @keys ++ [:trust, :verification, :decision, :accepted, :digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Specification.t(), Delegation.t(), map()) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def new(%Specification{} = specification, %Delegation{} = delegation, attributes)
      when is_map(attributes) do
    with true <- Specification.valid?(specification),
         true <- Delegation.valid?(delegation, specification),
         true <- exact_shape?(attributes, @keys),
         true <- attributes[:delegation_digest] == delegation.digest,
         true <- attributes[:remote_task_reference_iri] == delegation.remote_task_reference_iri,
         {:ok, output} <- Specification.validate_output(specification, attributes[:output]),
         output_bytes <- byte_size(:erlang.term_to_binary(output, [:deterministic])),
         true <- attributes[:output_bytes] == output_bytes,
         true <- output_bytes <= delegation.budget.output_bytes,
         true <- attributes[:output_digest] == Definition.digest(output),
         true <- digests?(attributes[:claim_digests], 64),
         true <- attributes[:provenance] == Delegation.provenance(delegation, specification),
         true <- exact_shape?(attributes[:provenance], @provenance_keys),
         :ok <- resources(attributes, [:verifier_iri, :decision_actor_iri]),
         :ok <- independent_route(attributes, delegation, specification),
         %DateTime{} = completed_at <- attributes[:completed_at],
         normalized <-
           attributes
           |> Map.put(:output, output)
           |> Map.put(:completed_at, DateTime.truncate(completed_at, :microsecond)),
         governed <-
           normalized
           |> Map.put(:trust, :untrusted_observation)
           |> Map.put(:verification, :required)
           |> Map.put(:decision, :pending)
           |> Map.put(:accepted, false),
         digest <- Definition.digest(governed) do
      {:ok, struct!(__MODULE__, Map.put(governed, :digest, digest))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:remote_agent_result)
    end
  rescue
    _error -> invalid(:remote_agent_result)
  end

  def new(_specification, _delegation, _attributes), do: invalid(:remote_agent_result)

  @spec accepting_output?(t()) :: false
  def accepting_output?(%__MODULE__{}), do: false

  @spec persistent_attributes(t()) :: map()
  def persistent_attributes(%__MODULE__{} = result) do
    %{
      delegation_digest: result.delegation_digest,
      remote_task_reference_iri: result.remote_task_reference_iri,
      output_digest: result.output_digest,
      output_bytes: result.output_bytes,
      claim_digests: result.claim_digests,
      provenance: result.provenance,
      verifier_iri: result.verifier_iri,
      decision_actor_iri: result.decision_actor_iri,
      trust: result.trust,
      verification: result.verification,
      decision: result.decision,
      accepted: result.accepted,
      result_digest: result.digest
    }
  end

  @spec verification_route(t()) :: map()
  def verification_route(%__MODULE__{} = result) do
    %{
      verifier_iri: result.verifier_iri,
      decision_actor_iri: result.decision_actor_iri,
      output: result.output,
      output_digest: result.output_digest,
      provenance: result.provenance,
      verification: :required,
      decision: :pending
    }
  end

  defp independent_route(attributes, delegation, specification) do
    actors = [
      delegation.execution.actor_iri,
      specification.remote_agent_iri,
      attributes.verifier_iri,
      attributes.decision_actor_iri
    ]

    if length(actors) == length(Enum.uniq(actors)),
      do: :ok,
      else: {:error, AdapterError.new(:unauthorized, :remote_agent_independent_route)}
  end

  defp resources(attributes, keys) do
    if Enum.all?(keys, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid(:remote_agent_result_identity)
  end

  defp digests?(values, maximum) when is_list(values) and length(values) <= maximum do
    Enum.all?(values, fn value ->
      is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)
    end) and length(values) == length(Enum.uniq(values))
  end

  defp digests?(_values, _maximum), do: false

  defp exact_shape?(value, keys),
    do: is_map(value) and MapSet.new(Map.keys(value)) == MapSet.new(keys)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
