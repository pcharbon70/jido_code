defmodule JidoCode.Product.ReadProjectionRealStorePhaseC4Test do
  use ExUnit.Case, async: false

  alias JidoCode.Identity.Resource
  alias JidoCode.Knowledge.Health
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Product.GraphReadProjectionProvider
  alias JidoCode.TestSupport.Phase08ExecutionFixture

  @moduletag :graph_store

  test "projects factory, project, and attempt views from the real TripleStore without writes",
       context do
    fixture = Phase08ExecutionFixture.completed!(context)
    project = project_resource(fixture)
    attempt = attempt_resource(fixture, project)
    hidden = hidden_project_resource(fixture)
    before_revision = StoreServer.summary(fixture.store_server).dataset_revision

    query = fn name, version, parameters, authority, scope, _options ->
      QueryRunner.execute(name, version, parameters, authority, scope,
        server: fixture.query_runner,
        evaluated_at: fixture.issued_at
      )
    end

    options = [
      authorize: allow_all(fixture),
      resources: resource_loader(project, attempt, hidden),
      resolve_resource: resolver(project, attempt),
      query: query,
      health: %Health{state: :ready, store_verified?: true, ontology_verified?: true},
      cache_server: nil,
      clock: fn -> fixture.issued_at end
    ]

    assert {:ok, factory} =
             GraphReadProjectionProvider.load(page_context(:factory), options)

    assert factory.state in [:ready, :incomplete, :stale, :truncated]
    assert Enum.map(factory.fleet, & &1.project) == [project.project_ref]
    refute inspect(factory) =~ hidden.iri

    assert {:ok, project_projection} =
             GraphReadProjectionProvider.load(
               page_context(:project, %{resource_ref: project.resource_ref}),
               options
             )

    assert project_projection.state in [:ready, :incomplete, :stale, :truncated]
    assert project_projection.project.repository_identity == "One conceptual repository"
    assert Enum.any?(project_projection.attempts, &(&1.label == attempt.resource_ref))
    assert project_projection.project.cost =~ "not zero"

    assert {:ok, attempt_projection} =
             GraphReadProjectionProvider.load(
               page_context(:attempt, %{
                 parent_ref: project.resource_ref,
                 resource_ref: attempt.resource_ref
               }),
               options
             )

    assert attempt_projection.state in [:ready, :incomplete, :stale, :truncated]
    assert attempt_projection.attempt.label == attempt.resource_ref
    assert attempt_projection.attempt.lifecycle_steps != []
    assert Enum.find(attempt_projection.capabilities, &(&1.key == :pause)).state == :unconfigured
    refute inspect(attempt_projection) =~ fixture.attempt.iri
    refute inspect(attempt_projection) =~ fixture.repository

    assert StoreServer.summary(fixture.store_server).dataset_revision == before_revision
  end

  defp page_context(surface, route_params \\ %{}) do
    path =
      case surface do
        :factory -> "/factory"
        :project -> "/projects/#{route_params.resource_ref}"
        :attempt -> "/projects/#{route_params.parent_ref}/attempts/#{route_params.resource_ref}"
      end

    %{
      session_ref: "real-store-session",
      page: %{
        key: surface,
        route_params: route_params,
        query: %{},
        canonical_url: "https://example.test" <> path
      }
    }
  end

  defp allow_all(fixture) do
    fn _context, _operation, _area, _action, _point, _resource_ref ->
      {:ok,
       %{
         decision: :allowed,
         product_identity: %{
           factory_iri: fixture.factory_iri,
           factory_scope_iri: fixture.factory_scope
         },
         authority_context: fixture.authority
       }}
    end
  end

  defp resource_loader(project, attempt, hidden) do
    fn
      :project, 100 -> {:ok, [project, hidden]}
      :attempt, 100 -> {:ok, [attempt]}
    end
  end

  defp resolver(project, attempt) do
    fn
      ref when ref == project.resource_ref -> {:ok, project}
      ref when ref == attempt.resource_ref -> {:ok, attempt}
      _other -> {:error, :not_found}
    end
  end

  defp project_resource(fixture) do
    %Resource{
      resource_ref: "project_real_store_c4",
      kind: :project,
      iri: fixture.repository,
      tenant_ref: "tenant_real_store_c4",
      project_ref: "real_store_c4",
      parent_ref: "factory_real_store_c4",
      graph_scope_iri: fixture.repository_scope,
      classification: :internal,
      environment: :test,
      lifecycle: :active,
      registry_revision: 1
    }
  end

  defp attempt_resource(fixture, project) do
    %Resource{
      resource_ref: "attempt_real_store_c4",
      kind: :attempt,
      iri: fixture.attempt.iri,
      tenant_ref: project.tenant_ref,
      project_ref: project.project_ref,
      parent_ref: project.resource_ref,
      graph_scope_iri: project.graph_scope_iri,
      classification: :internal,
      environment: :test,
      lifecycle: :active,
      registry_revision: 1
    }
  end

  defp hidden_project_resource(fixture) do
    %Resource{
      resource_ref: "project_hidden_real_store_c4",
      kind: :project,
      iri: fixture.factory_iri,
      tenant_ref: "tenant_real_store_c4",
      project_ref: "hidden_real_store_c4",
      parent_ref: "factory_real_store_c4",
      graph_scope_iri: fixture.factory_scope,
      classification: :internal,
      environment: :test,
      lifecycle: :active,
      registry_revision: 1
    }
  end
end
