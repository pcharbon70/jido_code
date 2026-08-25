defmodule JidoCode.Factory.ManagedCoding.QualificationAudit do
  @moduledoc "End-to-end reconciliation of one profile qualification and controlled human outcome."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity

  @resource_fields ~w[task_iri attempt_iri effect_iri candidate_iri verification_iri publication_iri operator_decision_iri reviewer_actor_iri]a
  @digest_fields ~w[profile_digest effect_digest candidate_digest verification_digest publication_digest operator_decision_digest]a
  @drills ~w[evaluation_reproduction profile_drift shadow_non_interference pilot_eligibility draft_publication human_merge threshold_stop disable drain incident rollback reenable]a
  @digest ~r/^[a-f0-9]{64}$/

  @spec verify(map(), [atom()]) :: {:ok, map()} | {:error, AdapterError.t()}
  def verify(evidence, drills) when is_map(evidence) and is_list(drills) do
    with true <- Enum.all?(@resource_fields, &(Identity.validate_resource(evidence[&1]) == :ok)),
         true <- Enum.all?(@digest_fields, &valid_digest?(evidence[&1])),
         true <- Enum.all?(@digest_fields, &(evidence[&1] == evidence.profile_digest)),
         true <- Enum.sort(Enum.uniq(drills)) == Enum.sort(@drills),
         true <- evidence[:evaluation_qualified] == true,
         true <- evidence[:shadow_influenced_live_work] == false,
         true <- evidence[:publication_mode] == :draft,
         true <- evidence[:human_reviewed] == true,
         true <- evidence[:human_approved] == true,
         true <- evidence[:human_merged] == true,
         true <- evidence[:runtime_approval_authority] == false,
         true <- evidence[:runtime_merge_authority] == false,
         true <- evidence[:evidence_complete] == true,
         true <- evidence[:unresolved_findings] == [] do
      material = Map.take(evidence, @resource_fields ++ @digest_fields ++ Map.keys(evidence))

      {:ok,
       %{
         profile_digest: evidence.profile_digest,
         reconciled_links: @resource_fields,
         drills: @drills,
         release_ready: true,
         audit_digest: digest(material)
       }}
    else
      _invalid -> {:error, AdapterError.new(:corrupt, :managed_coding_qualification_audit)}
    end
  rescue
    _error -> {:error, AdapterError.new(:corrupt, :managed_coding_qualification_audit)}
  end

  def verify(_evidence, _drills),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_qualification_audit)}

  @spec drills() :: [atom()]
  def drills, do: @drills

  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
