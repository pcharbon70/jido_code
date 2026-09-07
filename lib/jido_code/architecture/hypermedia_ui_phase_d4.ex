defmodule JidoCode.Architecture.HypermediaUIPhaseD4 do
  @moduledoc "D4 candidate inventory; incomplete qualification cannot accept HUI4."
  alias JidoCode.Architecture.HypermediaUISuccessorEvidence
  @manifest "priv/architecture/hypermedia_ui/phase_d4_implementation_evidence.json"
  @sources ~w[
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
