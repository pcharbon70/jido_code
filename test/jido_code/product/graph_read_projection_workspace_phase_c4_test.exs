defmodule JidoCode.Product.GraphReadProjectionWorkspacePhaseC4Test do
  use ExUnit.Case, async: true

  alias JidoCode.Identity.Resource
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Health
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Product.GraphReadProjectionProvider

  test "builds a scoped project workspace and omits attempts without current field authority" do
    test_pid = self()
    project = project_resource()

    allowed_attempt =
      attempt_resource("attempt_allowed", "https://jido.run/id/attempt/allowed")

    hidden_attempt = attempt_resource("attempt_hidden", "https://jido.run/id/attempt/hidden")

    authorize = fn _context, operation, area, action, point, resource_ref ->
      send(test_pid, {:authorize, operation, area, action, point, resource_ref})

      if resource_ref == hidden_attempt.resource_ref do
        {:error, :concealed_not_found}
      else
        {:ok, authorization()}
      end
    end

    assert {:ok, projection} =
             GraphReadProjectionProvider.load(project_context(:project),
               authorize: authorize,
               resolve_resource: resolver([project]),
               resources: fn :attempt, 100 -> {:ok, [allowed_attempt, hidden_attempt]} end,
               query: query_fixture(),
               health: ready_health(),
               clock: fn -> ~U[2026-09-06 12:00:00Z] end
             )

    assert projection.state == :ready
    assert projection.project.repository_identity == "One conceptual repository"
    assert projection.project.project_alias =~ "presentation alias"
    assert projection.project.cost == "Unavailable; missing observations are not zero"
    assert projection.summaries.work.blocked == 1
    assert Enum.map(projection.attempts, & &1.label) == ["attempt_allowed"]
    assert hd(projection.attempts).href == "/projects/project_alpha/attempts/attempt_allowed"
    assert projection.wiki.state == "Manual"

    assert Enum.find(projection.capabilities, &(&1.key == :dependencies)).state == :unconfigured
    assert Enum.find(projection.capabilities, &(&1.key == :cost)).state == :unconfigured

    refute inspect(projection) =~ project.iri
    refute inspect(projection) =~ hidden_attempt.iri

    assert_receive {:authorize, :attempt_page, :developer, :query, :before_field_shaping,
                    "attempt_hidden"}
  end

  test "builds an attempt workspace with exact containment and separately authorized evidence" do
    project = project_resource()
    attempt = attempt_resource("attempt_allowed", "https://jido.run/id/attempt/allowed")

    assert {:ok, projection} =
             GraphReadProjectionProvider.load(attempt_context(project, attempt),
               authorize: allow_all(),
               resolve_resource: resolver([project, attempt]),
               query: query_fixture(),
               health: ready_health()
             )

    assert projection.state == :ready
    assert projection.attempt.label == "attempt_allowed"
    assert projection.attempt.task == "Compile"
    assert projection.attempt.agent == "Builder"
    assert projection.attempt.profile == "Trusted profile"
    assert projection.attempt.revision == "2"
    assert projection.attempt.fence == "7"
    assert Enum.map(projection.attempt.lifecycle_steps, & &1.label) == ["Prepared", "Running"]
    assert Enum.at(projection.attempt.lifecycle_steps, 1).state == :current
    assert Enum.at(projection.attempt.outcomes, 0).label == "Candidate artifact claimed"

    verification = Enum.find(projection.summaries.counts, &(&1.key == :verification))
    assert verification.value == 1
    assert verification.state == :ready

    assert projection.summaries.plan_state =~ "separately labeled"
    assert projection.summaries.source_state =~ "not externally applied"
    assert Enum.find(projection.capabilities, &(&1.key == :pause)).state == :unconfigured
    refute inspect(projection) =~ "https://jido.run/id/agent/builder"
    refute inspect(projection) =~ project.iri
    refute inspect(projection) =~ attempt.iri
  end

  test "conceals copied attempt refs and never infers an evidence zero after denial" do
    project = project_resource()

    copied = %{
      attempt_resource("attempt_copied", "https://jido.run/id/attempt/copied")
      | project_ref: "other"
    }

    assert {:ok, concealed} =
             GraphReadProjectionProvider.load(attempt_context(project, copied),
               authorize: allow_all(),
               resolve_resource: resolver([project, copied]),
               query: query_fixture(),
               health: ready_health()
             )

    assert concealed.state == :unauthorized
    assert concealed.attempt == nil

    attempt = attempt_resource("attempt_allowed", "https://jido.run/id/attempt/allowed")

    evidence_denied = fn _context, operation, _area, _action, _point, _resource_ref ->
      if operation == :evidence_page, do: {:error, :denied}, else: {:ok, authorization()}
    end

    assert {:ok, projection} =
             GraphReadProjectionProvider.load(attempt_context(project, attempt),
               authorize: evidence_denied,
               resolve_resource: resolver([project, attempt]),
               query: query_fixture(),
               health: ready_health()
             )

    verification = Enum.find(projection.summaries.counts, &(&1.key == :verification))
    assert verification.value == nil
    assert verification.state == :unauthorized
    assert Enum.at(projection.attempt.outcomes, 1).label =~ "not authorized"
  end

  defp project_context(surface) do
    %{
      session_ref: "session-phase-c4",
      page: %{
        key: surface,
        route_params: %{resource_ref: "project_alpha"},
        query: %{},
        canonical_url: "https://example.test/projects/project_alpha"
      }
    }
  end

  defp attempt_context(project, attempt) do
    %{
      session_ref: "session-phase-c4",
      page: %{
        key: :attempt,
        route_params: %{parent_ref: project.resource_ref, resource_ref: attempt.resource_ref},
        query: %{},
        canonical_url:
          "https://example.test/projects/#{project.resource_ref}/attempts/#{attempt.resource_ref}"
      }
    }
  end

  defp resolver(resources) do
    by_ref = Map.new(resources, &{&1.resource_ref, &1})

    fn resource_ref ->
      case Map.fetch(by_ref, resource_ref) do
        {:ok, resource} -> {:ok, resource}
        :error -> {:error, :not_found}
      end
    end
  end

  defp query_fixture do
    fn name, _version, parameters, _authority, _scope, _options ->
      {:ok, query_result(name, query_data(name, parameters), parameters)}
    end
  end

  defp query_data(:repository_description, _parameters), do: %{}

  defp query_data(:active_enrollment, _parameters),
    do: [%{"enrollment" => "urn:enrollment:alpha"}]

  defp query_data(:work_lens, %{state: :blocked}),
    do: [%{"work" => "urn:work:blocked", "successor" => nil}]

  defp query_data(:work_lens, _parameters), do: []

  defp query_data(:active_attempts, _parameters) do
    [
      %{
        "attempt" => "https://jido.run/id/attempt/allowed",
        "task" => "https://jido.run/id/task/compile",
        "state" => "https://jido.run/id/state/running",
        "fence" => 7
      },
      %{
        "attempt" => "https://jido.run/id/attempt/hidden",
        "task" => "https://jido.run/id/task/hidden",
        "state" => "https://jido.run/id/state/blocked",
        "fence" => 2
      }
    ]
  end

  defp query_data(:repository_wiki_enrollment_detail, _parameters) do
    [
      %{
        "state" => "https://jido.run/id/state/manual",
        "revision" => 4,
        "generation" => "https://jido.run/id/generation/on-demand",
        "currentEdition" => "https://jido.run/id/wiki-edition/current"
      }
    ]
  end

  defp query_data(:attempt_status, _parameters) do
    [
      %{
        "predicate" => "https://jido.run/ontology/task",
        "object" => "https://jido.run/id/task/compile"
      },
      %{
        "predicate" => "https://jido.run/ontology/agent",
        "object" => "https://jido.run/id/agent/builder"
      },
      %{"predicate" => "https://jido.run/ontology/runtimeVersion", "object" => "OTP 29"},
      %{"predicate" => "https://jido.run/ontology/branch", "object" => "codex/read"},
      %{"predicate" => "https://jido.run/ontology/worktree", "object" => "isolated"}
    ]
  end

  defp query_data(:attempt_timeline, _parameters) do
    [
      %{"state" => "https://jido.run/id/state/prepared", "revision" => 1},
      %{"state" => "https://jido.run/id/state/running", "revision" => 2}
    ]
  end

  defp query_data(:managed_coding_attempt, _parameters),
    do: [%{"profile" => "https://jido.run/id/profile/trusted_profile", "fence" => 7}]

  defp query_data(:attempt_artifacts, _parameters),
    do: [%{"kind" => "https://jido.run/id/artifact/candidate-patch"}]

  defp query_data(:tool_invocations, _parameters),
    do: [%{"tool" => "urn:tool:compiler"}]

  defp query_data(:run_completeness, _parameters),
    do: [%{"state" => "urn:completeness:declared"}]

  defp query_data(:evidence_by_attempt, _parameters),
    do: [%{"bundle" => "urn:evidence:bundle"}]

  defp query_data(_name, _parameters), do: []

  defp query_result(name, data, parameters) do
    graph_revisions =
      parameters
      |> Enum.filter(fn {key, _value} -> key in [:graph, :control_graph, :wiki_graph] end)
      |> Map.new(fn {_key, graph} -> {graph, 3} end)

    %QueryResult{
      query_name: name,
      query_version: "2.11.0",
      scope_iri: "https://jido.run/id/scope/repository/alpha",
      dataset_revision: 77,
      graph_revisions: graph_revisions,
      ontology_version: "1.5.0",
      completeness: %{complete?: true},
      freshness: :current,
      truncated?: false,
      cursor: nil,
      warnings: [],
      execution_class: :product,
      consistency: %{status: :current},
      evaluated_at: ~U[2026-09-06 12:00:00Z],
      data: data
    }
  end

  defp allow_all do
    fn _context, _operation, _area, _action, _point, _resource_ref ->
      {:ok, authorization()}
    end
  end

  defp authorization do
    %{
      decision: :allowed,
      product_identity: %{
        factory_iri: "https://jido.run/id/repository-factory/default",
        factory_scope_iri: "https://jido.run/id/scope/factory/default"
      },
      authority_context: authority()
    }
  end

  defp authority do
    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: "https://jido.run/id/human/phase-c4",
        actor_iri: "https://jido.run/id/human/phase-c4",
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    authority
  end

  defp project_resource do
    %Resource{
      resource_ref: "project_alpha",
      kind: :project,
      iri: "https://jido.run/id/repository/alpha",
      tenant_ref: "tenant_phase_c4",
      project_ref: "alpha",
      parent_ref: "factory_phase_c4",
      graph_scope_iri: "https://jido.run/id/scope/project/alpha",
      classification: :internal,
      environment: :test,
      lifecycle: :active,
      registry_revision: 4
    }
  end

  defp attempt_resource(resource_ref, iri) do
    %Resource{
      resource_ref: resource_ref,
      kind: :attempt,
      iri: iri,
      tenant_ref: "tenant_phase_c4",
      project_ref: "alpha",
      parent_ref: "project_alpha",
      graph_scope_iri: "https://jido.run/id/scope/project/alpha",
      classification: :internal,
      environment: :test,
      lifecycle: :active,
      registry_revision: 2
    }
  end

  defp ready_health do
    %Health{state: :ready, store_verified?: true, ontology_verified?: true}
  end
end
