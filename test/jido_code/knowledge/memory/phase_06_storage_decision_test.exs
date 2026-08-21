defmodule JidoCode.Knowledge.Memory.Phase06StorageDecisionTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  test "accepts the signed all-threshold graph-native branch and authorizes no vault" do
    signer = fn material -> :crypto.mac(:hmac, :sha256, key(), material) end
    verifier = fn material, signature -> secure_equal?(signer.(material), signature) end

    assert {:ok, decision} = Knowledge.decide_content_storage(metrics(), signer)
    assert {:ok, posture} = Knowledge.accept_content_storage(decision, verifier)

    assert posture.branch == :graph_native
    assert posture.accepted?
    assert posture.graph_authoritative?
    refute posture.vault_authorized?
    assert posture.content_gateway_only?
    assert posture.disabled_profiles == [:diagnostic_capture, :project_total_history]

    tampered = %{decision | metrics: %{decision.metrics | query_latency_ratio: 1.76}}
    assert {:error, %{kind: :unauthorized}} = Knowledge.accept_content_storage(tampered, verifier)

    assert {:ok, failed} =
             Knowledge.decide_content_storage(%{metrics() | query_latency_ratio: 2.01}, signer)

    assert {:error, %{kind: :conflict, operation: :vault_adr_required}} =
             Knowledge.accept_content_storage(failed, verifier)

    assert {:error, %{kind: :conflict, operation: :vault_not_authorized}} =
             Knowledge.accept_content_vault(failed, %{accepted?: false}, %{})
  end

  test "activates only the graph-native content boundary and keeps broad capture disabled" do
    for feature <- [:content_lifecycle_writer, :episode_content_writer, :content_gateway] do
      assert Guardrails.feature_enabled?(feature)
      refute Map.has_key?(Guardrails.disabled_features(), feature)
    end

    refute DataPolicy.profile_enabled?(:diagnostic_capture)
    refute DataPolicy.profile_enabled?(:project_total_history)

    assert DataPolicy.durable_allowed?(
             :encrypted_content,
             :episode_content,
             :ciphertext,
             :semantic_history
           )

    refute DataPolicy.durable_allowed?(:secret_value, :episode_content)
    refute DataPolicy.durable_allowed?(:prompt, :episode_content)

    repository = resource(:repository_snapshot, "storage-decision-repository")
    content = resource(:episode_content, "storage-decision-content")

    assert {:ok, lifecycle_graph} =
             GraphRegistry.graph_iri(:content_lifecycle, %{repository: repository})

    assert {:ok, content_graph} =
             GraphRegistry.graph_iri(:episode_content, %{repository: repository, content: content})

    assert {:ok, %{family: :content_lifecycle}} =
             GraphRegistry.validate_target(lifecycle_graph, :content_lifecycle_writer)

    assert {:ok, %{family: :episode_content}} =
             GraphRegistry.validate_target(content_graph, :content_writer)

    assert GraphRegistry.write_allowed?(:content_lifecycle, :append, %{lifecycle_state: :open})
    assert GraphRegistry.write_allowed?(:episode_content, :create)
    refute GraphRegistry.write_allowed?(:episode_content, :append, %{lifecycle_state: :closed})
  end

  test "allows provider-owned references but never relabels a JidoCode bucket as external authority" do
    assert Knowledge.provider_content_artifact_allowed?(%{
             owner: :external_provider,
             authority: :external_provider,
             access: :governed_reference,
             jido_code_bucket?: false
           })

    refute Knowledge.provider_content_artifact_allowed?(%{
             owner: :jido_code,
             authority: :external_provider,
             access: :governed_reference,
             jido_code_bucket?: true
           })
  end

  defp metrics do
    %{
      capture_latency_ratio: 1.5,
      query_latency_ratio: 1.75,
      backup_latency_ratio: 1.25,
      restore_latency_ratio: 1.4,
      rebuild_latency_ratio: 1.9,
      storage_amplification_ratio: 3.5,
      integrity_failures: 0,
      orphaned_objects: 0,
      unerased_objects: 0
    }
  end

  defp key, do: "phase-6-storage-decision-verification-key"

  defp secure_equal?(left, right) when byte_size(left) == byte_size(right),
    do: :crypto.hash_equals(left, right)

  defp secure_equal?(_left, _right), do: false

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end
