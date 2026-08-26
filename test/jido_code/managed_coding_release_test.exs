defmodule JidoCode.ManagedCodingReleaseTest do
  use ExUnit.Case, async: true

  alias JidoCode.ManagedCodingRelease

  test "pins the supported single-agent workflow and rejected features" do
    assert :ok = ManagedCodingRelease.verify()
    manifest = ManagedCodingRelease.manifest()

    assert manifest.contract_version == "8.0.0"
    assert manifest.production_profile == "single_agent"
    assert manifest.specialist_topology == :rejected
    assert manifest.agent_os == :rejected
    assert manifest.agent_os_adapter == :absent
    refute manifest.pod_managers_in_default_supervision
    assert manifest.merge_authority == :human_only
    assert :specialist_topology in manifest.disabled_features
    assert :automatic_merge in manifest.disabled_features
    assert :delegated_codex_selection in manifest.disabled_features
    assert manifest.delegated_profiles.codex_dga1.state == :disabled
    assert manifest.runtime_classes.delegated_cli == JidoCode.Runtime.JidoHarnessAdapter
    assert manifest.supported_workflow |> List.last() == :human_merge
    assert byte_size(ManagedCodingRelease.digest()) == 64
  end

  test "retains the exact 7.0.0 interpretation" do
    historical = ManagedCodingRelease.manifest("7.0.0")

    assert historical.contract_version == "7.0.0"

    assert historical.disabled_features == [
             :specialist_topology,
             :agent_os,
             :automatic_approval,
             :automatic_publication,
             :automatic_merge
           ]

    digest =
      historical
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    assert digest == "64b43c9786eb9c6d59de817aaa41f0efd287a0a7d08d84357bc604dc6f36e464"
    assert ManagedCodingRelease.manifest("6.0.0") == nil
  end

  test "keeps evaluation infrastructure outside default production supervision" do
    {:ok, {_flags, children}} = JidoCode.Runtime.Supervisor.init([])
    descriptions = Enum.map(children, &inspect/1)

    refute Enum.any?(descriptions, &String.contains?(&1, "ManagedCoding.PodManager"))
    refute Enum.any?(descriptions, &String.contains?(&1, "ManagedCoding.SpecialistManager"))
  end
end
