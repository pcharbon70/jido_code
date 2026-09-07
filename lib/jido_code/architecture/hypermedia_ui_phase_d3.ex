defmodule JidoCode.Architecture.HypermediaUIPhaseD3 do
  @moduledoc "Pinned D3 source inventory, predecessor evidence and phase closure."
  alias JidoCode.Architecture.{HypermediaUIPhaseD2, HypermediaUISuccessorEvidence}
  @manifest "priv/architecture/hypermedia_ui/phase_d3_implementation_evidence.json"
  @plan "docs/planning/secure-hypermedia-control-plane-ui/milestone-d-datastar-delivery/phase-03-projection-subscription-convergence-and-revocation.md"
  @receipt "docs/architecture/hypermedia-ui-milestone-d-phase-03-receipt.md"
  @merged_candidate nil
  @sections ~w[3.1 3.2 3.3 3.4]
  @invariants ~w[hint_is_not_truth registered_server_scope fresh_query_and_patch_authority scoped_cursor bounded_reconciliation terminal_revocation paused_security_bypass bounded_resources_and_cleanup predecessor_gates]
  @sources ~w[
    assets/js/stream_connection.js
    assets/js/read_projection.js
    lib/jido_code/architecture/hypermedia_ui_phase_d2.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/jido_code_web/components/product_page.ex
    lib/jido_code_web/product_controller.ex
    lib/jido_code_web/read_response.ex
    lib/jido_code_web/stream_admission.ex
    lib/jido_code_web/stream_context.ex
    lib/jido_code_web/stream_delivery.ex
    lib/jido_code_web/stream_update.ex
    lib/mix/tasks/architecture.check.ex
    lib/jido_code/knowledge/projection_subscription.ex
    lib/jido_code/product/stream_projection_registry.ex
    lib/jido_code/product/stream_subscription.ex
    lib/jido_code/product/stream_convergence.ex
    test/jido_code/product/stream_subscription_test.exs
    test/jido_code_web/stream_projection_registry_test.exs
    test/jido_code_web/stream_update_test.exs
    test/jido_code_web/stream_recovery_test.exs
    test/jido_code_web/stream_continuity_test.exs
    test/browser/hypermedia_ui_phase_d3.spec.mjs
    docs/architecture/hypermedia-ui-milestone-d-phase-03-receipt.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-d-datastar-delivery/phase-03-projection-subscription-convergence-and-revocation.md
    lib/jido_code/architecture/hypermedia_ui_phase_d3.ex
    test/jido_code/architecture/hypermedia_ui_phase_d3_test.exs
  ]
  def sources, do: @sources
  def invariants, do: @invariants

  def load(root \\ File.cwd!()) do
    with {:ok, body} <- File.read(Path.join(root, @manifest)), do: Jason.decode(body)
  end

  def check(root \\ File.cwd!()) do
    case load(root) do
      {:ok, evidence} ->
        case validate(evidence, root) do
          [] -> {:ok, []}
          errors -> {:error, errors}
        end

      _ ->
        {:error, ["D3 evidence unavailable"]}
    end
  end

  def validate(e, root) do
    {:ok, predecessor} = HypermediaUIPhaseD2.load(root)

    originals =
      Map.filter(predecessor["source_digests"], fn {path, _} ->
        HypermediaUISuccessorEvidence.phase_d3_mutable_path?(path)
      end)

    errors =
      []
      |> equal(e["schema_version"], 1, "schema")
      |> equal(e["phase"], "HUI-D3", "phase")
      |> equal(e["baseline_commit"], "c39f90316cb90d85a9413c2cc9da0115fdd65a9a", "baseline")
      |> equal(
        e["predecessor_candidate"],
        "1d55390108763052998cc6f6e6dfc4ce319998c0",
        "predecessor"
      )
      |> equal(e["predecessor_source_digests"], originals, "preserved D2 digests")
      |> equal(e["invariants"], @invariants, "reopening invariants")
      |> equal(e["exceptions"], [], "exceptions")
      |> equal(
        Enum.sort(Map.keys(e["source_digests"] || %{})),
        Enum.sort(@sources),
        "source inventory"
      )

    errors =
      Enum.reduce(e["source_digests"] || %{}, errors, fn {path, expected}, acc ->
        case File.read(Path.join(root, path)) do
          {:ok, body} ->
            equal(
              acc,
              Base.encode16(:crypto.hash(:sha256, body), case: :lower),
              expected,
              "source #{path}"
            )

          _ ->
            ["missing source #{path}" | acc]
        end
      end)

    lifecycle(errors, e, root)
  end

  defp lifecycle(errors, %{"status" => "accepted_at_merged_candidate"} = e, root) do
    errors
    |> equal(e["completed_sections"], @sections, "sections")
    |> equal(e["merged_candidate"], @merged_candidate, "candidate")
    |> equal(sha?(@merged_candidate), true, "full merge SHA")
    |> equal(e["clean_checkout_ci"], "pass", "CI")
    |> equal(e["local_verification"], "pass", "qualification")
    |> equal(
      Enum.all?(@sections, &sha?(get_in(e, ["section_commits", &1]))),
      true,
      "section commits"
    )
    |> equal(match?({:ok, _}, Date.from_iso8601(e["merge_date"] || "")), true, "merge date")
    |> equal(is_integer(e["implementation_pr"]) and e["implementation_pr"] > 0, true, "PR")
    |> equal(
      Enum.all?(~w[verify dialyzer], fn name ->
        match?(
          %{"id" => id, "result" => "pass"} when is_integer(id) and id > 0,
          get_in(e, ["clean_checkout_jobs", name])
        )
      end),
      true,
      "CI jobs"
    )
    |> contains(root, @receipt, "Status: **accepted-at-merged-candidate**")
    |> contains(root, @receipt, "Merged candidate: `#{@merged_candidate}`")
    |> contains(root, @plan, "- [x] 3 Phase")
    |> contains(root, @plan, "- [x] 3.4 Section")
    |> contains(root, @plan, "- [x] 3.4.2 Task")
    |> contains(root, @plan, "- [x] 3.4.2.3 Subtask")
  end

  defp lifecycle(errors, %{"status" => status} = e, root)
       when status in ["implementation_in_progress", "integration_candidate_merge_pending"] do
    sections = e["completed_sections"] || []

    errors =
      errors
      |> equal(
        sections != [] and sections == Enum.take(@sections, length(sections)),
        true,
        "section order"
      )
      |> equal(e["merged_candidate"], nil, "pending candidate")
      |> equal(e["clean_checkout_ci"], "pending", "pending CI")
      |> contains(root, @receipt, "Status: **merge-pending**")
      |> contains(root, @plan, "- [ ] 3 Phase")
      |> contains(root, @plan, "- [ ] 3.4 Section")

    if status == "integration_candidate_merge_pending",
      do:
        errors
        |> equal(sections, @sections, "integration sections")
        |> equal(e["local_verification"], "pass", "qualification"),
      else: errors
  end

  defp lifecycle(errors, _, _), do: ["unsupported lifecycle" | errors]

  defp contains(errors, root, path, text),
    do: equal(errors, String.contains?(File.read!(Path.join(root, path)), text), true, text)

  defp sha?(value), do: is_binary(value) and Regex.match?(~r/\A[0-9a-f]{40}\z/, value)
  defp equal(errors, value, value, _), do: errors
  defp equal(errors, _, _, label), do: ["invalid #{label}" | errors]
end
