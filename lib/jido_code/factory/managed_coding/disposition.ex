defmodule JidoCode.Factory.ManagedCoding.Disposition do
  @moduledoc "Authorized candidate disposition, separate from verifier and publication authority."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.VerificationResult

  @decisions ~w[accepted rejected indeterminate expired superseded]a
  @enforce_keys ~w[disposition_iri candidate_iri candidate_digest verification_iri decision actor_iri capability_iri policy_revision reason_evidence_iris decided_at publication_authority]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec decide(VerificationResult.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def decide(%VerificationResult{} = result, attributes) when is_map(attributes) do
    with decision when decision in @decisions <- attributes[:decision],
         true <- authorized_decision?(decision, result.status),
         true <- attributes[:actor_iri] != result.verifier_actor_iri,
         :ok <- resource(attributes[:actor_iri]),
         :ok <- resource(attributes[:capability_iri]),
         true <- attributes[:policy_revision] == result.policy_revision,
         true <- attributes[:policy_current?] == true,
         true <- attributes[:authorized?] == true,
         {:ok, evidence} <- evidence(attributes[:reason_evidence_iris]),
         %DateTime{} = decided_at <- attributes[:decided_at],
         {:ok, iri} <- identity(result, decision, attributes) do
      {:ok,
       %__MODULE__{
         disposition_iri: iri,
         candidate_iri: result.candidate_iri,
         candidate_digest: result.candidate_digest,
         verification_iri: result.verification_iri,
         decision: decision,
         actor_iri: attributes.actor_iri,
         capability_iri: attributes.capability_iri,
         policy_revision: attributes.policy_revision,
         reason_evidence_iris: evidence,
         decided_at: DateTime.truncate(decided_at, :microsecond),
         publication_authority: false
       }}
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :managed_coding_disposition)}
    end
  rescue
    _error -> {:error, AdapterError.new(:invalid_input, :managed_coding_disposition)}
  end

  def decide(_result, _attributes),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_disposition)}

  defp authorized_decision?(:accepted, :passed), do: true
  defp authorized_decision?(:rejected, :failed), do: true

  defp authorized_decision?(:indeterminate, status)
       when status in [:indeterminate, :unavailable, :timeout], do: true

  defp authorized_decision?(:expired, :expired), do: true
  defp authorized_decision?(:superseded, _status), do: true
  defp authorized_decision?(_decision, _status), do: false

  defp resource(value), do: Identity.validate_resource(value)

  defp evidence(values) when is_list(values) and values != [] and length(values) <= 64 do
    if Enum.all?(values, &(resource(&1) == :ok)),
      do: {:ok, Enum.sort(Enum.uniq(values))},
      else: :error
  end

  defp evidence(_values), do: :error

  defp identity(result, decision, attributes) do
    Identity.deterministic(
      :claim_disposition,
      Enum.join(
        [
          result.verification_iri,
          decision,
          attributes[:actor_iri],
          attributes[:capability_iri],
          attributes[:policy_revision]
        ],
        "\n"
      )
    )
  end
end
