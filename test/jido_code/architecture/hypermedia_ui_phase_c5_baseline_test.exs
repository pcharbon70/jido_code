defmodule JidoCode.Architecture.HypermediaUIPhaseC5BaselineTest do
  use ExUnit.Case, async: true

  @path "priv/architecture/hypermedia_ui/phase_c5_product_baseline.json"
  @states ~w[ready empty stale incomplete contradicted truncated unauthorized unavailable maintenance recovery]
  @surfaces ~w[factory fleet projects project project_attempts project_wiki project_dependencies attempt]

  test "inventories every accepted controller route and stable native contract" do
    baseline = @path |> File.read!() |> Jason.decode!()
    routes = baseline["routes"]

    assert baseline["phase"] == "HUI-C5"
    assert baseline["gate"] == "HUI3"
    assert baseline["status"] == "fragment_candidate_merge_pending"
    assert length(routes) == 27
    assert length(Enum.uniq_by(routes, &{&1["method"], &1["path"]})) == 27
    assert Enum.all?(routes, &complete_route?/1)
    assert Enum.all?(routes, &(&1["method"] in ~w[GET POST DELETE]))

    signatures = MapSet.new(routes, &"#{&1["method"]} #{&1["path"]}")
    assert signatures == expected_routes()

    router = File.read!("lib/jido_code_web/router.ex")

    for route <- routes do
      assert router =~ ~s|"#{route["path"]}"|,
             "router no longer contains #{route["method"]} #{route["path"]}"
    end

    assert get_in(baseline, ["shell", "authority_owner"]) == "JidoCodeWeb.ProductRequest"
    assert get_in(baseline, ["shell", "main_focus_target"]) == "product-main"
    assert baseline["state_envelope"] == @states
  end

  test "freezes only the eight bounded read roots as Milestone D candidates" do
    baseline = @path |> File.read!() |> Jason.decode!()
    candidates = baseline["projection_candidates"]

    assert Enum.map(candidates, & &1["surface"]) == @surfaces
    assert Enum.all?(candidates, &(length(&1["roots"]) > 0))
    assert Enum.all?(candidates, &(&1["query"] == "2.11.0"))

    assert Enum.all?(
             candidates,
             &String.contains?(&1["authorization"], ["route", "project", "parent"])
           )

    assert length(baseline["milestone_d_candidates"]) == 5
    assert length(baseline["enhancement_prohibitions"]) == 7
    assert length(baseline["unsupported_placeholders"]) == 5
    assert length(baseline["reopening_conditions"]) == 5
  end

  test "reconciles every predecessor and Phase 5 evidence seam" do
    baseline = @path |> File.read!() |> Jason.decode!()
    reconciled = baseline["reconciled_evidence"]

    assert map_size(reconciled) == 6

    for {phase, candidate} <- baseline["predecessor_candidates"] do
      phase_number = String.last(phase)

      evidence =
        "priv/architecture/hypermedia_ui/phase_c#{phase_number}_implementation_evidence.json"
        |> File.read!()
        |> Jason.decode!()

      assert evidence["merged_candidate"] == candidate
    end

    for evidence <- [
          "priv/architecture/hypermedia_ui/phase_c1_implementation_evidence.json",
          "priv/architecture/hypermedia_ui/phase_c2_implementation_evidence.json",
          "priv/architecture/hypermedia_ui/phase_c3_implementation_evidence.json",
          "priv/architecture/hypermedia_ui/phase_c4_implementation_evidence.json",
          "priv/architecture/hypermedia_ui/phase_c5_accessibility_evidence.json",
          "priv/architecture/hypermedia_ui/phase_c5_operations_evidence.json"
        ] do
      assert File.exists?(evidence)
    end

    receipt = File.read!("docs/architecture/hypermedia-ui-milestone-c-phase-05-receipt.md")
    assert receipt =~ "Status: **merge-pending**"
    assert receipt =~ "Merged candidate: `merge-pending`"
    assert receipt =~ "Milestone D is not authorized"
  end

  defp complete_route?(route) do
    Enum.all?(~w[method path controller root focus authority native], &is_binary(route[&1]))
  end

  defp expected_routes do
    MapSet.new([
      "GET /sign-in",
      "POST /sign-in",
      "GET /recovery",
      "POST /recovery",
      "DELETE /sign-out",
      "DELETE /sessions",
      "GET /step-up",
      "POST /step-up",
      "DELETE /account/sessions/:management_ref",
      "GET /factory",
      "GET /factory/fleet",
      "GET /projects",
      "GET /projects/switch",
      "GET /projects/:project_ref",
      "GET /projects/:project_ref/attempts",
      "GET /projects/:project_ref/wiki",
      "GET /projects/:project_ref/dependencies",
      "GET /projects/:project_ref/attempts/:attempt_ref",
      "GET /projects/:project_ref/knowledge/:lens",
      "GET /reviews/:candidate_ref",
      "GET /operations",
      "GET /operations/costs",
      "GET /security",
      "GET /security/incidents",
      "GET /governance",
      "GET /account",
      "GET /account/sessions"
    ])
  end
end
