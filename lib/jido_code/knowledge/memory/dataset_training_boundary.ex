defmodule JidoCode.Knowledge.Memory.DatasetTrainingBoundary do
  @moduledoc "Declares prerequisites for a future training plan without creating training authority."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"

  def revision, do: @revision

  def requirements(manifest_iri, manifest_digest, implementation_plan_iri, evidence_gate_iris) do
    with :ok <- ResourceIdentity.validate(manifest_iri),
         true <- digest?(manifest_digest),
         :ok <- ResourceIdentity.validate(implementation_plan_iri),
         true <- is_list(evidence_gate_iris) and evidence_gate_iris != [],
         true <- Enum.all?(evidence_gate_iris, &(ResourceIdentity.validate(&1) == :ok)) do
      {:ok,
       %{
         revision: @revision,
         pinned_manifest_iri: manifest_iri,
         pinned_manifest_digest: manifest_digest,
         implementation_plan_iri: implementation_plan_iri,
         evidence_gate_iris: Enum.uniq(evidence_gate_iris) |> Enum.sort(),
         training_authorized?: false,
         checkpoint_authorized?: false,
         deployment_authorized?: false,
         next_required_decision: :separate_training_plan_acceptance
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :dataset_training_boundary)}
    end
  end

  def authorize_training(_attributes),
    do: {:error, Error.new(:conflict, :separate_training_plan_required)}

  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
end
