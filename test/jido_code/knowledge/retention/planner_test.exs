defmodule JidoCode.Knowledge.Retention.PlannerTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Retention.Planner
  alias JidoCode.Knowledge.Retention.Policy

  test "policy covers every graph family and durable supplemental record" do
    assert :ok = Policy.verify()

    for family <- GraphRegistry.families() do
      assert {:ok, class} = Policy.class_for_family(family)
      assert Map.has_key?(Policy.classes(), class)
    end

    for kind <- [
          :command_receipt,
          :validation_report,
          :decision,
          :accepted_knowledge,
          :desired_outcome,
          :goal,
          :policy,
          :audit,
          :derived_cache
        ] do
      assert {:ok, _class} = Policy.class_for_resource(kind)
    end
  end

  test "reachability and legal holds preserve transitive evidence and reject held erasure" do
    repository = iri("repository/retention")
    control = graph!(:repository_control, %{repository: repository})
    evidence = graph!(:evidence, %{repository: repository})
    audit = graph!(:security_audit, %{period: "2026-08"})

    goal = resource("goal", control, :repository_control, [iri("evidence/one")], 3_000)
    evidence_resource = resource("evidence/one", evidence, :evidence, [], 3_000)

    snapshot =
      snapshot([goal, evidence_resource], audit,
        roots: [goal.iri],
        legal_holds: [evidence_resource.iri]
      )

    assert {:ok, plan} = Planner.plan(snapshot)
    assert Enum.sort(plan.retain) == Enum.sort([goal.iri, evidence_resource.iri])
    assert plan.archive == []
    assert plan.removals == []

    assert {:error, error} =
             snapshot
             |> Map.put(:legal_erase, [evidence_resource.iri])
             |> Planner.plan()

    assert error.operation == :retention_legal_hold
  end

  test "plans exact archival, legal erasure, audit evidence, and derived rebuilds" do
    repository = iri("repository/retention")

    observations =
      graph!(:observation_batch, %{repository: repository, batch: iri("batch/old")})

    derived = graph!(:derived, %{rule_set: "fleet", revision: 4})
    audit = graph!(:security_audit, %{period: "2026-08"})

    old = resource("batch/old", observations, :observation_batch, [], 100)
    inferred = resource("derived/old", derived, :derived, [old.iri], 1)

    assert {:ok, plan} =
             Planner.plan(snapshot([old, inferred], audit, legal_erase: [old.iri]))

    assert plan.erase == [old.iri]
    assert inferred.iri in plan.archive
    assert plan.rebuild_graphs == [derived]
    assert Enum.sort(plan.affected_graphs) == Enum.sort([audit, observations, derived])
    assert length(plan.removals) == 2
    assert byte_size(plan.checksum) == 64
    assert Enum.any?(plan.audit_additions, &quad_mentions?(&1, old.iri))
  end

  defp snapshot(resources, audit, overrides) do
    graphs = resources |> Enum.map(& &1.graph_iri) |> Enum.uniq()

    Map.merge(
      %{
        resources: resources,
        roots: [],
        legal_holds: [],
        legal_erase: [],
        dataset_revision: 20,
        graph_revisions: Map.new([audit | graphs], &{&1, 2}),
        actor_iri: iri("actor/retention-operator"),
        activity_iri: iri("activity/retention"),
        audit_graph_iri: audit,
        rationale: "Apply the accepted retention schedule",
        validation_report_iri: iri("validation/retention")
      },
      Map.new(overrides)
    )
  end

  defp resource(name, graph, family, links, age_days) do
    resource = iri(name)

    %{
      iri: resource,
      graph_iri: graph,
      family: family,
      age_days: age_days,
      links: links,
      quads: [RDF.quad(resource, iri("predicate/value"), "value", graph)]
    }
  end

  defp quad_mentions?({_, _, %RDF.IRI{value: value}, _}, expected), do: value == expected
  defp quad_mentions?(_quad, _expected), do: false

  defp graph!(family, scopes) do
    {:ok, graph} = GraphRegistry.graph_iri(family, scopes)
    graph
  end

  defp iri(suffix), do: "https://jido.run/id/#{suffix}"
end
