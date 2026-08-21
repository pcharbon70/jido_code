defmodule JidoCode.Knowledge.Memory.ContentStorageDecision do
  @moduledoc "Deterministic Phase 6 storage/profile posture derived from the signed benchmark."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ContentBenchmark
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Security.DataPolicy

  @revision "1.0.0"

  def revision, do: @revision

  def accept(decision, verifier) when is_map(decision) and is_function(verifier, 2) do
    with :ok <- ContentBenchmark.verify(decision, verifier),
         :graph_native <- decision.decision,
         true <- writers_active?(),
         true <- profiles_disabled?() do
      {:ok,
       %{
         revision: @revision,
         branch: :graph_native,
         accepted?: true,
         benchmark_iri: decision.iri,
         benchmark_digest: decision.metrics_digest,
         graph_authoritative?: true,
         vault_authorized?: false,
         content_gateway_only?: true,
         enabled_features: ~w[content_lifecycle_writer episode_content_writer content_gateway]a,
         disabled_profiles: ~w[diagnostic_capture project_total_history]a,
         provider_artifacts: :governed_external_reference
       }}
    else
      :vault_adr_required -> {:error, Error.new(:conflict, :vault_adr_required)}
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:conflict, :content_storage_decision)}
    end
  end

  def accept(_decision, _verifier),
    do: {:error, Error.new(:invalid_input, :content_storage_decision)}

  def accept_vault(decision, adr, proof)
      when is_map(decision) and is_map(adr) and is_map(proof) do
    if decision[:decision] == :vault_adr_required and adr[:accepted?] == true and
         proof[:graph_authoritative?] == true and proof[:pending_writes_inaccessible?] == true and
         proof[:activation_atomic?] == true and proof[:orphan_cleanup?] == true and
         proof[:backup_consistent?] == true and proof[:gateway_only?] == true and
         proof[:complete_erasure?] == true do
      {:ok, %{branch: :governed_vault, accepted?: true, adr_iri: adr[:iri]}}
    else
      {:error, Error.new(:conflict, :vault_not_authorized)}
    end
  end

  def accept_vault(_decision, _adr, _proof),
    do: {:error, Error.new(:conflict, :vault_not_authorized)}

  def provider_artifact_allowed?(attributes) when is_map(attributes) do
    attributes[:owner] == :external_provider and attributes[:authority] == :external_provider and
      attributes[:access] == :governed_reference and attributes[:jido_code_bucket?] == false
  end

  def provider_artifact_allowed?(_attributes), do: false

  defp writers_active? do
    Enum.all?(
      ~w[content_lifecycle_writer episode_content_writer content_gateway]a,
      &Guardrails.feature_enabled?/1
    )
  end

  defp profiles_disabled? do
    not DataPolicy.profile_enabled?(:diagnostic_capture) and
      not DataPolicy.profile_enabled?(:project_total_history)
  end
end
