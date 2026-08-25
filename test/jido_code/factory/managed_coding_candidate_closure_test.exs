defmodule JidoCode.Factory.ManagedCodingCandidateClosureTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding.CandidateClosure
  alias JidoCode.Factory.ManagedCoding.CandidateManifest
  alias JidoCode.TestSupport.FakeManagedCodingCandidateStore, as: Store

  setup do
    store = start_supervised!({Agent, fn -> %{} end})
    %{store: store}
  end

  test "closes exact candidate evidence once and never retains mutable caller state", %{
    store: store
  } do
    capture = capture()

    assert {:ok, result} = CandidateClosure.close(Store, store, capture, policy())
    assert result.status == :ready
    assert result.reason == :none
    assert %CandidateManifest{} = result.manifest

    candidate_iri = result.manifest.candidate_iri
    assert {:ok, stored} = Store.fetch(store, candidate_iri)
    assert stored == result.manifest

    changed = put_in(capture, [:changed_files, Access.at(0), :digest], digest("mutated"))
    assert {:ok, changed_result} = CandidateClosure.close(Store, store, changed, policy())
    refute changed_result.manifest.candidate_iri == candidate_iri
    assert {:ok, ^stored} = Store.fetch(store, candidate_iri)
  end

  test "keeps identity stable for equivalent canonical captures", %{store: store} do
    first = capture()

    second = %{
      first
      | changed_files: Enum.reverse(first.changed_files),
        generated_artifact_iris: Enum.reverse(first.generated_artifact_iris),
        captured_at: ~U[2026-08-25 13:00:00Z]
    }

    assert {:ok, first_result} = CandidateClosure.close(Store, store, first, policy())
    assert {:ok, second_result} = CandidateClosure.close(Store, store, second, policy())
    assert first_result.manifest.candidate_digest == second_result.manifest.candidate_digest
    assert first_result.manifest.candidate_iri == second_result.manifest.candidate_iri
  end

  test "changes identity for every class of material provenance", %{store: store} do
    base = capture()
    assert {:ok, original} = CandidateClosure.close(Store, store, base, policy())

    mutations = [
      &Map.put(&1, :attempt_iri, iri("other-attempt")),
      &Map.put(&1, :fencing_token, 8),
      &Map.put(&1, :repository_iri, iri("other-repository")),
      &Map.put(&1, :base_snapshot_iri, iri("other-snapshot")),
      &Map.put(&1, :base_revision, digest("other-base")),
      &Map.put(&1, :normalized_patch_digest, digest("other-patch")),
      &Map.put(&1, :patch_artifact_iri, iri("other-patch-artifact")),
      &Map.put(&1, :tree_digest, digest("other-tree")),
      &put_in(&1, [:changed_files, Access.at(0), :digest], digest("other-file")),
      &Map.put(&1, :generated_artifact_iris, [iri("other-artifact")]),
      &Map.put(&1, :terminal_summary_digest, digest("other-summary")),
      &Map.put(&1, :policy_revision, digest("other-policy")),
      &Map.put(&1, :profile_revision, digest("other-profile")),
      &Map.put(&1, :toolchain_revision, digest("other-toolchain")),
      &Map.put(&1, :secret_scan_evidence_iri, iri("other-secret-scan")),
      &Map.put(&1, :check_evidence_iris, [iri("other-check")]),
      &Map.put(&1, :model_invocation_iris, [iri("other-model")]),
      &Map.put(&1, :tool_invocation_iris, [iri("other-tool")])
    ]

    Enum.each(mutations, fn mutate ->
      assert {:ok, result} = CandidateClosure.close(Store, store, mutate.(base), policy())
      refute result.manifest.candidate_digest == original.manifest.candidate_digest
    end)
  end

  test "represents every incomplete or policy-blocked closure without a candidate", %{
    store: store
  } do
    cases = [
      {%{capture() | changed_files: [], manifest_paths: [], untracked_paths: []}, :empty,
       :no_changes},
      {%{capture() | capture_status: :partial}, :partial, :incomplete_capture},
      {%{capture() | capture_status: :conflicting}, :conflicting, :conflicting_capture},
      {%{capture() | diff_bytes: 100_001}, :oversized, :diff_byte_limit},
      {%{capture() | changed_files: [file("priv/outside", "outside")]}, :policy_blocked,
       :path_scope},
      {put_in(capture(), [:changed_files, Access.at(0), :binary?], true), :policy_blocked,
       :binary_policy},
      {%{capture() | forbidden_content_scan: :blocked}, :policy_blocked, :forbidden_content},
      {%{capture() | secret_scan: :unavailable}, :policy_blocked, :secret_scan},
      {%{capture() | untracked_paths: ["lib/hidden.ex"]}, :policy_blocked, :untracked_material},
      {%{capture() | capture_status: :failed}, :capture_failed, :capture_unavailable}
    ]

    Enum.each(cases, fn {candidate, status, reason} ->
      assert {:ok, result} = CandidateClosure.close(Store, store, candidate, policy())
      assert result.status == status
      assert result.reason == reason
      assert is_nil(result.manifest)
    end)

    assert Agent.get(store, &map_size/1) == 0
  end

  defp capture do
    changed_files = [file("lib/a.ex", "a"), file("lib/b.ex", "b")]

    %{
      capture_status: :complete,
      omissions: [],
      attempt_iri: iri("attempt"),
      fencing_token: 7,
      repository_iri: iri("repository"),
      base_snapshot_iri: iri("snapshot"),
      base_revision: digest("base"),
      normalized_patch_digest: digest("patch"),
      patch_artifact_iri: iri("patch-artifact"),
      tree_digest: digest("tree"),
      changed_files: changed_files,
      manifest_paths: Enum.map(changed_files, & &1.path),
      untracked_paths: ["lib/b.ex"],
      diff_bytes: 2_048,
      generated_artifact_iris: [iri("artifact-b"), iri("artifact-a")],
      check_evidence_iris: [iri("check")],
      model_invocation_iris: [iri("model")],
      tool_invocation_iris: [iri("tool")],
      terminal_summary_digest: digest("summary"),
      policy_revision: digest("policy"),
      profile_revision: digest("profile"),
      toolchain_revision: digest("toolchain"),
      secret_scan_evidence_iri: iri("secret-scan"),
      forbidden_content_scan: :clean,
      secret_scan: :clean,
      closure_evidence_iris: [iri("closure-evidence")],
      captured_at: ~U[2026-08-25 12:00:00Z]
    }
  end

  defp policy do
    %{
      allowed_paths: ["lib"],
      max_changed_files: 10,
      max_diff_bytes: 100_000,
      allow_binary?: false
    }
  end

  defp file(path, seed) do
    %{path: path, digest: digest(seed), size: 20, mode: 0o644, binary?: false}
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
