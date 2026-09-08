defmodule JidoCode.Identity.LocalGraphAuthorityTest do
  use ExUnit.Case, async: false
  alias JidoCode.Identity.{Authority, AuthorityBuilder, Store}
  alias JidoCode.Knowledge.{Bootstrap, QueryRunner, StoreServer}
  alias JidoCode.TestSupport.Phase04Fixture

  @moduletag :graph_store
  @token "local-graph-test-only-bootstrap-token"

  setup context do
    fixture = Phase04Fixture.start!(context)
    original_query = :sys.get_state(QueryRunner)
    original_identity = :sys.get_state(Store)

    :sys.replace_state(fixture.store_server, fn state ->
      %{
        state
        | authorized_callers: Map.update!(state.authorized_callers, :read, &[QueryRunner | &1])
      }
    end)

    :sys.replace_state(QueryRunner, &%{&1 | store_server: fixture.store_server})

    :sys.replace_state(
      fixture.writer,
      &%{&1 | bootstrap_config: %{enabled?: true, token_digest: Bootstrap.token_digest(@token)}}
    )

    on_exit(fn ->
      :sys.replace_state(QueryRunner, fn _ -> original_query end)
      :sys.replace_state(Store, fn _ -> original_identity end)
    end)

    surface = Application.fetch_env!(:jido_code, :product_surface)
    human = "https://jido.run/id/human/human_test_operator"

    identity = %{
      principal_iri: human,
      actor_iri: human,
      factory_iri: surface[:factory_iri],
      factory_scope_iri: surface[:factory_scope_iri]
    }

    assert {:ok, _} =
             JidoCode.Install.bootstrap(@token,
               identity: identity,
               store_server: fixture.store_server,
               writer: fixture.writer
             )

    :sys.replace_state(
      Store,
      &%{&1 | config: %{&1.config | authority_adapter: Authority.LocalGraph}}
    )

    {:ok, resource} = Store.resolve_resource(:factory)
    %{fixture: fixture, identity: identity, resource: resource}
  end

  test "actual named human receives only a current graph grant; a second human and writes are denied",
       %{identity: identity, resource: resource, fixture: fixture} do
    {:ok, request} =
      AuthorityBuilder.request(:factory_shell, :developer, :page, :factory,
        reauthorization_point: :before_response_start,
        correlation_ref: "local-graph-proof"
      )

    revision = StoreServer.summary(fixture.store_server).dataset_revision
    assert {:ok, grant} = Authority.LocalGraph.resolve(identity, [], [], resource, request)
    assert is_binary(grant.grant_ref)
    assert Map.keys(grant.graph_revisions) == ["https://jido.run/graph/factory/policy"]
    assert StoreServer.summary(fixture.store_server).dataset_revision == revision

    other = %{
      identity
      | principal_iri: "https://jido.run/id/human/other",
        actor_iri: "https://jido.run/id/human/other"
    }

    assert {:error, :concealed_not_found} =
             Authority.LocalGraph.resolve(other, [], [], resource, request)

    assert {:error, :denied} =
             Authority.LocalGraph.resolve(identity, [], [], resource, %{
               request
               | action: :command
             })

    assert {:error, :denied} =
             Authority.LocalGraph.resolve(
               identity,
               [],
               [],
               %{resource | iri: "https://jido.run/id/other"},
               request
             )
  end

  test "loss of the actual query process cannot reuse an old grant", %{
    identity: identity,
    resource: resource
  } do
    {:ok, request} =
      AuthorityBuilder.request(:factory_shell, :developer, :query, :factory,
        reauthorization_point: :before_query_execution,
        correlation_ref: "local-outage-proof"
      )

    assert {:ok, _} = Authority.LocalGraph.resolve(identity, [], [], resource, request)
    :sys.replace_state(QueryRunner, &%{&1 | store_server: :missing_local_store})

    assert {:error, :unavailable} =
             Authority.LocalGraph.resolve(identity, [], [], resource, request)
  end
end
