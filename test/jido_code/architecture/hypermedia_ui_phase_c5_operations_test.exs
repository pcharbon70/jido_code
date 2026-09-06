defmodule JidoCode.Architecture.HypermediaUIPhaseC5OperationsTest do
  use ExUnit.Case, async: true

  @evidence_path "priv/architecture/hypermedia_ui/phase_c5_operations_evidence.json"

  test "pins real adapters, capacity thresholds, faults, privacy, and limitations" do
    evidence = @evidence_path |> File.read!() |> Jason.decode!()

    assert evidence["phase"] == "HUI-C5"
    assert evidence["section"] == "5.2"
    assert evidence["profile"] == "read-only-shell-production-like-v1"

    assert get_in(evidence, ["adapter_posture", "triple_store", "backend"]) ==
             "RocksDB quad store"

    assert get_in(evidence, ["adapter_posture", "graph_authority", "result"]) ==
             "pass_unavailable"

    assert evidence["thresholds"] == %{
             "cache_entries" => 512,
             "cache_fresh_ms" => 5_000,
             "cache_operation_p95_ms" => 25,
             "cache_process_memory_bytes" => 16_777_216,
             "cache_retention_ms" => 30_000,
             "candidate_limit" => 100,
             "page_rows" => 20,
             "parallel_users" => 8,
             "queries_per_factory_surface" => 121,
             "scan_limit" => 24,
             "serialized_projection_bytes" => 262_144,
             "surface_timeout_ms" => 5_500,
             "tabs_per_user" => 4
           }

    assert Enum.all?(evidence["failure_matrix"], fn {_case, result} -> result == "pass" end)
    assert Enum.all?(evidence["privacy_matrix"], fn {_case, result} -> result == "pass" end)
    assert evidence["production_asset_build"]["result"] == "pass"
    assert Enum.all?(evidence["limitations"], &complete_limitation?/1)
    assert length(evidence["reopening_conditions"]) == 6
  end

  test "locks and TLS fixture retain the qualified digests" do
    evidence = @evidence_path |> File.read!() |> Jason.decode!()
    assets = evidence["production_asset_build"]

    assert sha256("package-lock.json") == assets["package_lock_sha256"]
    assert sha256("mix.lock") == assets["mix_lock_sha256"]

    assert sha256("test/browser/support/hui-b4-local.crt") ==
             "f0458f35e0e0538bcae12bf5031d2d011fa7398390bd128e6238abb89dc02967"
  end

  defp sha256(path) do
    path |> File.read!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end

  defp complete_limitation?(limitation) do
    Enum.all?(~w[id detail owner expires_on reopens_on], &is_binary(limitation[&1]))
  end
end
