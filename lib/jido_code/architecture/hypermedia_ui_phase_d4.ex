defmodule JidoCode.Architecture.HypermediaUIPhaseD4 do
  @moduledoc "D4 candidate inventory; incomplete qualification cannot accept HUI4."
  alias JidoCode.Architecture.HypermediaUISuccessorEvidence
  @manifest "priv/architecture/hypermedia_ui/phase_d4_implementation_evidence.json"
  @store_candidate "660ee1bf3a53e08f8ea3b3f39f1d688f03be5aab"
  @store_predecessor "6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f"
  # Exact successor lock: Igniter 0.8.4 and the TripleStore context-type repair.
  # Candidate identity never waives dependency audit findings.
  @audit_lock_digest "040a115655f0d086c6ce9754c7987d3d93a5e94dc48d730aec7a76bde68cc462"
  @dependency_baseline %{
    "mix.exs" => "d66c00f068f43943ed9bd94b0a2c77db152a224ad3e1d6deefee4745df3ffab9",
    "mix.lock" => "98b302693e9dbf826129aec7bdb85740201fb076096d253d10e4f7ba1660e10b"
  }
  @sources ~w[
    mix.exs
    mix.lock
    .dialyzer_ignore.exs
    test/jido_code/knowledge/backup_restore_integrity_test.exs
    lib/jido_code/knowledge/semantic_snapshot.ex
    lib/jido_code/knowledge/graph_metadata.ex
    test/jido_code/knowledge/semantic_snapshot_test.exs
    docs/architecture/hypermedia-ui-d4-dependency-audit-remediation.md
    test/jido_code/architecture/hypermedia_ui_dependency_security_test.exs
    lib/jido_code/architecture/hypermedia_ui_phase_b2.ex
    lib/jido_code/architecture/hypermedia_ui_phase_b4.ex
    scripts/qualify_hui_d4_resources.exs
    scripts/qualify_hui_d4_scopes.exs
    scripts/qualify_hui_d4_scopes.mjs
    scripts/qualify_hui_d4_restart.exs
    scripts/qualify_hui_d4_slow_reader.exs
    scripts/qualify_hui_d4_slow_reader.mjs
    lib/jido_code/architecture/hypermedia_ui_phase_c5.ex
    test/jido_code/architecture/hypermedia_ui_phase_c5_operations_test.exs
    package.json
    package-lock.json
    lib/jido_code/architecture/hypermedia_ui_phase_b3.ex
    scripts/qualify_hui_d4_faults.exs
    scripts/qualify_hui_d4_faults.mjs
    .github/workflows/ci.yml
    test/jido_code_web/local_graph_delivery_test.exs
    scripts/qualify_hui_d4_native.mjs
    scripts/qualify_hui_d4_orca.sh
    test/accessibility/hypermedia_ui_phase_d4_orca.mjs
    lib/jido_code/product/delivery_control.ex
    lib/jido_code_web/read_enhancement.ex
    lib/jido_code_web/read_response.ex
    lib/jido_code_web/stream_delivery.ex
    lib/jido_code_web/controllers/read_controller.ex
    test/jido_code_web/delivery_rollback_test.exs
    lib/jido_code/product/stream_coordinator.ex
    lib/jido_code/product/stream_pressure.ex
    lib/jido_code/product/stream_metrics.ex
    test/jido_code/product/stream_pressure_test.exs
    scripts/qualify_hui_d4_load.mjs
    scripts/qualify_hui_d4_local.exs
    scripts/qualify_hui_d4_local.mjs
    lib/jido_code_web/router.ex
    config/runtime.exs
    docs/architecture/hypermedia-ui-milestone-d-phase-04-receipt.md
    docs/operations/local-hypermedia-delivery.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-d-datastar-delivery/README.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-d-datastar-delivery/phase-04-proxy-capacity-recovery-and-delivery-acceptance.md
    lib/jido_code/application.ex
    lib/jido_code/architecture/hypermedia_ui_phase_d1.ex
    lib/jido_code/architecture/hypermedia_ui_phase_d2.ex
    lib/jido_code/architecture/hypermedia_ui_phase_d3.ex
    lib/jido_code/architecture/hypermedia_ui_phase_d4.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/jido_code/identity/authority/local_graph.ex
    lib/jido_code/knowledge/query_execution.ex
    lib/jido_code/knowledge/query_runner.ex
    lib/jido_code/knowledge/store_server.ex
    lib/jido_code/local_deployment.ex
    lib/jido_code/local_install.ex
    lib/jido_code_web/endpoint.ex
    lib/jido_code_web/plugs/local_transport.ex
    lib/mix/tasks/architecture.check.ex
    lib/mix/tasks/jido_code.local_install.ex
    test/jido_code/architecture/hypermedia_ui_phase_d4_test.exs
    test/jido_code/identity/local_graph_authority_test.exs
    test/jido_code/local_deployment_test.exs
    test/jido_code_web/local_transport_test.exs
  ]
  def sources, do: @sources

  def dependency_input_valid?("mix.lock", body) do
    Base.encode16(:crypto.hash(:sha256, body), case: :lower) == @audit_lock_digest
  end

  def dependency_input_valid?(path, body) do
    baseline = @dependency_baseline[path]
    restored = String.replace(body, @store_candidate, @store_predecessor)

    is_binary(baseline) and String.contains?(body, @store_candidate) and
      Base.encode16(:crypto.hash(:sha256, restored), case: :lower) == baseline
  end

  def dependency_digest(root, path) do
    with true <- Map.has_key?(@dependency_baseline, path),
         {:ok, evidence} <- load(root),
         @store_candidate <- evidence["triple_store_candidate"],
         {:ok, body} <- File.read(Path.join(root, path)),
         true <- dependency_input_valid?(path, body),
         digest = Base.encode16(:crypto.hash(:sha256, body), case: :lower),
         ^digest <- get_in(evidence, ["source_digests", path]) do
      digest
    else
      _ -> nil
    end
  end

  def load(root \\ File.cwd!()) do
    with {:ok, body} <- File.read(Path.join(root, @manifest)), do: Jason.decode(body)
  end

  def check(root \\ File.cwd!()) do
    with {:ok, evidence} <- load(root) do
      case validate(evidence, root) do
        [] -> {:ok, []}
        errors -> {:error, errors}
      end
    end
  end

  def validate(evidence, root) do
    originals =
      Map.new(~w[c1 c2 c3 c4 c5 d1 d2 d3], fn phase ->
        path = "priv/architecture/hypermedia_ui/phase_#{phase}_implementation_evidence.json"
        prior = Path.join(root, path) |> File.read!() |> Jason.decode!()

        digests =
          Map.take(
            prior["source_digests"],
            HypermediaUISuccessorEvidence.phase_d4_mutable_paths()
          )

        {phase, digests}
      end)

    errors =
      []
      |> equal(evidence["phase"], "HUI-D4", "phase")
      |> equal(evidence["schema_version"], 1, "schema")
      |> equal(
        evidence["baseline_commit"],
        "8cac85172eeda04a41ee68f4b3a6dbba935ca8eb",
        "baseline"
      )
      |> equal(
        evidence["predecessor_candidate"],
        "a25d1ba65138935bbd065e09518bcdc7c7945301",
        "D3 candidate"
      )
      |> equal(evidence["predecessor_source_digests"], originals, "preserved predecessor digests")
      |> equal(
        Enum.sort(Map.keys(evidence["source_digests"] || %{})),
        Enum.sort(@sources),
        "source inventory"
      )
      |> equal(evidence["status"], "implementation_in_progress", "qualification lifecycle")
      |> equal(evidence["merged_candidate"], nil, "no invented merge candidate")
      |> equal(evidence["completed_sections"], [], "unaccepted sections")
      |> equal(
        evidence["independent_reviews"],
        "deferred_by_maintainer_2026-09-09",
        "independent review lifecycle"
      )
      |> equal(evidence["browser_toolchain"], "1.63.0", "qualified browser pin")
      |> equal(
        evidence["triple_store_candidate"],
        @store_candidate,
        "iterator cleanup dependency candidate"
      )

    errors =
      Enum.reduce(@dependency_baseline, errors, fn {path, _baseline}, acc ->
        body = File.read!(Path.join(root, path))

        acc
        |> equal(String.contains?(body, @store_candidate), true, "fixed store pin #{path}")
        |> equal(
          dependency_input_valid?(path, body),
          true,
          "exact TripleStore and Igniter audit candidate #{path}"
        )
      end)

    package = Path.join(root, "package.json") |> File.read!() |> Jason.decode!()
    lock = Path.join(root, "package-lock.json") |> File.read!() |> Jason.decode!()

    errors =
      equal(
        errors,
        get_in(package, ["devDependencies", "@playwright/test"]),
        "1.63.0",
        "current browser package"
      )

    errors =
      Enum.reduce(~w[@playwright/test playwright playwright-core], errors, fn name, acc ->
        equal(
          acc,
          get_in(lock, ["packages", "node_modules/" <> name, "version"]),
          "1.63.0",
          "locked browser dependency"
        )
      end)

    receipt =
      File.read!(
        Path.join(root, "docs/architecture/hypermedia-ui-milestone-d-phase-04-receipt.md")
      )

    plan =
      File.read!(
        Path.join(
          root,
          "docs/planning/secure-hypermedia-control-plane-ui/milestone-d-datastar-delivery/phase-04-proxy-capacity-recovery-and-delivery-acceptance.md"
        )
      )

    errors =
      errors
      |> equal(String.contains?(receipt, "Status: **merge-pending**"), true, "receipt status")
      |> equal(
        String.contains?(receipt, "**merge-pending**. Milestone E is not authorized."),
        true,
        "HUI4 gate"
      )
      |> equal(String.contains?(plan, "status: proposed"), true, "phase frontmatter")
      |> equal(String.contains?(plan, "- [ ] 4 Phase"), true, "phase closure")
      |> equal(String.contains?(plan, "- [ ] 4.4 Section"), true, "integration closure")

    Enum.reduce(evidence["source_digests"] || %{}, errors, fn {path, digest}, acc ->
      case File.read(Path.join(root, path)) do
        {:ok, body} ->
          equal(acc, Base.encode16(:crypto.hash(:sha256, body), case: :lower), digest, path)

        _ ->
          ["missing #{path}" | acc]
      end
    end)
  end

  defp equal(errors, value, value, _), do: errors
  defp equal(errors, _, _, label), do: ["invalid #{label}" | errors]
end
