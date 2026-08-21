defmodule JidoCode.Knowledge.Memory.Phase04CaseRetrievalTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CatalogQueryRequest
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-21 14:00:00Z]

  test "publishes bounded case, failure, source, contradiction, and lifecycle products" do
    assert QueryCatalog.experience_version() == "2.1.0"

    names = ~w[
      similar_resolved_cases failed_interventions experience_case_source_trace
      experience_case_contradictions experience_case_lifecycle
    ]a

    for name <- names do
      assert {:ok, definition} = QueryCatalog.fetch(name, QueryCatalog.experience_version())
      assert definition.graph_families == [:experience]
      assert definition.execution_class == :product
      assert String.contains?(definition.source, "{{instant}}")
      assert String.contains?(definition.source, "LIMIT")
    end

    refute Enum.any?(names, &(&1 in QueryCatalog.names(QueryCatalog.history_version())))
    assert :ok = QueryCatalog.verify()

    repository = resource(:repository_snapshot, "retrieval-repository")
    {:ok, graph} = GraphRegistry.graph_iri(:experience, %{repository: repository})
    {:ok, authority} = authority()

    parameters = %{
      graph: graph,
      resource: repository,
      signature: digest("problem"),
      framework: "phoenix",
      framework_version: "1.8",
      environment: "otp-28",
      dependency: "phoenix@1.8.1",
      task_class: "repair",
      plan_phase: "memory-phase-04",
      instant: @now,
      case_limit: 3
    }

    assert {:ok, request} =
             CatalogQueryRequest.new(
               :similar_resolved_cases,
               QueryCatalog.experience_version(),
               parameters,
               authority,
               resource(:execution_context, "retrieval-scope")
             )

    assert request.parameters.case_limit == 3

    assert {:error, %{kind: :invalid_input}} =
             CatalogQueryRequest.new(
               :similar_resolved_cases,
               QueryCatalog.experience_version(),
               Map.put(parameters, :case_limit, 11),
               authority,
               resource(:execution_context, "retrieval-scope")
             )
  end

  test "filters exact applicability before deterministic diverse ranking" do
    request = request()
    success = candidate(request, "success", :success, 0.8)
    failure = candidate(request, "failure", :failure, 0.7)
    ambiguity = candidate(request, "ambiguity", :ambiguous, 0.6)

    ineligible = [
      %{
        candidate(request, "foreign", :success, 1.0)
        | repository_iri: resource(:repository_snapshot, "other")
      },
      %{
        candidate(request, "future", :success, 1.0)
        | recorded_at: DateTime.add(@now, 1, :second)
      },
      %{candidate(request, "stale", :success, 1.0) | lifecycle_state: :stale},
      %{candidate(request, "wrong-version", :success, 1.0) | framework_version: "1.7"},
      %{candidate(request, "not-applicable", :success, 1.0) | current_applicable?: false}
    ]

    assert {:ok, result} =
             Knowledge.retrieve_experience_cases(request, [
               success,
               failure,
               ambiguity | ineligible
             ])

    assert result.eligible_count == 3
    assert result.omitted_count == 5
    assert Enum.map(result.selected, & &1.case_class) == [:success, :failure, :ambiguous]
    refute result.abstained?
    assert result.non_authoritative?

    assert Enum.all?(result.selected, fn selected ->
             Map.keys(selected.channel_scores) |> Enum.sort() ==
               ~w[dense failure_signature graph lexical]a
           end)

    assert {:ok, metrics} =
             Knowledge.evaluate_experience_retrieval(result, %{
               localized?: true,
               repeated_action_avoided?: true,
               retry_recovered?: false,
               no_applicable_case?: false
             })

    assert metrics.localization
    assert metrics.repeated_action_avoidance
  end

  test "abstains when no case is applicable and enforces the small case budget" do
    request = request()
    foreign = %{candidate(request, "foreign", :failure, 1.0) | plan_phase: "other"}

    assert {:ok, result} = Knowledge.retrieve_experience_cases(request, [foreign])
    assert result.selected == []
    assert result.abstained?

    assert {:ok, %{correct_abstention: true}} =
             Knowledge.evaluate_experience_retrieval(result, %{
               localized?: false,
               repeated_action_avoided?: false,
               retry_recovered?: false,
               no_applicable_case?: true
             })

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.retrieve_experience_cases(%{request | max_cases: 8}, [])
  end

  defp request do
    %{
      repository_iri: resource(:repository_snapshot, "retrieval-repository"),
      framework: "phoenix",
      framework_version: "1.8",
      environment: "otp-28",
      dependency: "phoenix@1.8.1",
      task_class: :repair,
      plan_phase: "memory-phase-04",
      effective_at: @now,
      max_cases: 3
    }
  end

  defp candidate(request, seed, case_class, score) do
    %{
      iri: resource(:experience_case, seed),
      repository_iri: request.repository_iri,
      framework: request.framework,
      framework_version: request.framework_version,
      environment: request.environment,
      dependency: request.dependency,
      task_class: request.task_class,
      plan_phase: request.plan_phase,
      case_class: case_class,
      lifecycle_state: :validated,
      current_applicable?: true,
      negative_transfer: 0.0,
      recorded_at: DateTime.add(@now, -2, :second),
      validated_at: DateTime.add(@now, -1, :second),
      channel_scores: %{
        lexical: score,
        graph: score,
        failure_signature: score,
        dense: nil
      }
    }
  end

  defp authority do
    AuthorityContext.new(%{
      principal_iri: resource(:authorization_grant, "retrieval-actor"),
      actor_iri: resource(:authorization_grant, "retrieval-actor"),
      delegated_agent_iri: nil,
      delegation_iri: nil
    })
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
