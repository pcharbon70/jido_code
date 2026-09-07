defmodule JidoCodeWeb.StreamRealStoreTest do
  use ExUnit.Case, async: false
  alias JidoCode.Identity.{Administration, Sessions, Store}
  alias JidoCode.Knowledge.{ChangeFeed, StoreServer}
  alias JidoCode.Product.StreamCoordinator

  alias JidoCode.TestSupport.{
    HypermediaStreamHTTPFixture,
    Phase06Fixture,
    Phase08ExecutionFixture
  }

  alias HypermediaStreamHTTPFixture, as: HTTP

  @moduletag :graph_store
  @admin %{
    source: :governed_identity_admin,
    actor_ref: "human_identity_administrator",
    assurance: :action_bound_step_up
  }

  setup context do
    fixture = Phase08ExecutionFixture.completed!(context)
    keys = [:product_surface, :product_read_projection_provider, :hui_d3_graph_fixture]
    old = Map.new(keys, &{&1, Application.get_env(:jido_code, &1)})
    original_data = :sys.get_state(Store).data

    surface =
      old.product_surface
      |> Keyword.put(:factory_iri, fixture.factory_iri)
      |> Keyword.put(:factory_scope_iri, fixture.factory_scope)

    Application.put_env(:jido_code, :product_surface, surface)

    Application.put_env(
      :jido_code,
      :product_read_projection_provider,
      JidoCode.TestSupport.RealStreamProjectionProvider
    )

    Application.put_env(:jido_code, :hui_d3_graph_fixture, fixture)

    :sys.replace_state(Store, fn state ->
      factory_ref = state.data.default_resource_ref

      resources =
        state.data.resources
        |> Map.update!(
          factory_ref,
          &%{&1 | iri: fixture.factory_iri, graph_scope_iri: fixture.factory_scope}
        )
        |> Map.update!(
          "project_browser_alpha",
          &%{&1 | iri: fixture.repository, graph_scope_iri: fixture.repository_scope}
        )
        |> Map.update!(
          "attempt_browser_alpha",
          &%{&1 | iri: fixture.attempt.iri, graph_scope_iri: fixture.repository_scope}
        )

      %{state | data: %{state.data | resources: resources}}
    end)

    {:ok, second} =
      Administration.enroll_account(
        @admin,
        %{display_name: "Second stream reader", login: "second-stream@example.test"},
        "test-named-human-credential"
      )

    {:ok, factory} = Store.resolve_resource(:factory)

    for project <- [nil, "browser_alpha"] do
      {:ok, _} =
        Administration.put_membership(@admin, %{
          subject_ref: second.subject_ref,
          tenant_ref: factory.tenant_ref,
          project_ref: project,
          roles: [:observer],
          route_groups: [:developer],
          clearance: :internal
        })
    end

    base = HTTP.start!()

    on_exit(fn ->
      StreamCoordinator.drain()
      HTTP.eventually(fn -> StreamCoordinator.stats().connections == 0 end)
      :sys.replace_state(Store, &%{&1 | data: original_data})

      Enum.each(old, fn {key, value} ->
        if value == nil,
          do: Application.delete_env(:jido_code, key),
          else: Application.put_env(:jido_code, key, value)
      end)
    end)

    %{fixture: fixture, base: base, client: HTTP.sign_in(base)}
  end

  test "durable changes converge after complete hint loss without stream writes", %{
    fixture: fixture,
    client: client
  } do
    initial_revision = StoreServer.summary(fixture.store_server).dataset_revision
    fleet = HTTP.connect(client)

    project =
      HTTP.connect(client, "/projects/project_browser_alpha/overview", HTTP.payload("project"))

    assert revision?(fleet.initial, initial_revision)

    assert Enum.any?(
             HTTP.documents(project.initial),
             &(LazyHTML.text(&1) =~ "One conceptual repository")
           )

    assert StoreServer.summary(fixture.store_server).dataset_revision == initial_revision

    updated =
      Phase06Fixture.provider_observation!(fixture, "hui-d3-first", fixture.git_snapshot,
        availability: false,
        completeness: :partial
      )

    revision = updated.observation_receipt.dataset_revision
    assert revision > initial_revision
    HTTP.until(fleet, &revision?(&1, revision))
    HTTP.until(project, &revision?(&1, revision))

    subscriptions = subscriptions()
    assert length(subscriptions) == 2

    for pid <- subscriptions do
      :sys.replace_state(pid, fn state ->
        for scope <- state.scopes do
          {:ok, topic} = ChangeFeed.topic(scope)
          :ok = Phoenix.PubSub.unsubscribe(JidoCode.PubSub, topic)
        end

        state
      end)
    end

    dropped =
      Phase06Fixture.provider_observation!(fixture, "hui-d3-dropped", fixture.git_snapshot)

    revision = dropped.observation_receipt.dataset_revision
    HTTP.until(fleet, &revision?(&1, revision))
    HTTP.until(project, &revision?(&1, revision))
    assert StoreServer.summary(fixture.store_server).dataset_revision == revision
    StreamCoordinator.drain()
    assert HTTP.terminal?(HTTP.finish(fleet).body)
    assert HTTP.terminal?(HTTP.finish(project).body)
    HTTP.eventually(fn -> Enum.all?(subscriptions, &(not Process.alive?(&1))) end)
  end

  test "same tab correlation across named users never shares scope or revocation", %{
    fixture: fixture,
    client: first,
    base: base
  } do
    second = HTTP.sign_in(base, "second-stream@example.test")
    tab = HTTP.random()
    left = HTTP.connect(first, "/fleet", HTTP.payload("fleet", %{tab: tab}))
    right = HTTP.connect(second, "/fleet", HTTP.payload("fleet", %{tab: tab}))
    assert StreamCoordinator.stats().connections == 2

    assert {:ok, %{status: 404}} =
             HTTP.post(second, "/projects/project_browser_beta/overview", HTTP.payload("project"))

    assert {:ok, %{status: 404}} =
             HTTP.post(
               second,
               "/projects/project_browser_alpha/attempts/attempt_browser_beta",
               HTTP.payload("attempt")
             )

    {:ok, sessions} = Sessions.managed(first.session)
    current = Enum.find(sessions, & &1.current)
    {:ok, :current} = Sessions.revoke_managed(first.session, current.management_ref)
    HTTP.until(left, &HTTP.terminal?/1)
    assert HTTP.terminal?(HTTP.finish(left).body)
    HTTP.eventually(fn -> StreamCoordinator.stats().connections == 1 end)

    changed =
      Phase06Fixture.provider_observation!(fixture, "hui-d3-other-user", fixture.git_snapshot)

    body = HTTP.until(right, &revision?(&1, changed.observation_receipt.dataset_revision))
    refute HTTP.terminal?(body)
    StreamCoordinator.drain()
    HTTP.finish(right)
  end

  test "subscription process loss clears content and reconnect re-queries durable truth", %{
    fixture: fixture,
    client: client
  } do
    tab = HTTP.random()
    first = HTTP.connect(client, "/fleet", HTTP.payload("fleet", %{tab: tab}))
    [_, cursor] = Regex.run(~r/^id: (.+)$/m, first.initial)
    [subscription] = subscriptions()
    Process.exit(subscription, :kill)

    recovery =
      HTTP.until(first, fn body ->
        Enum.any?(
          HTTP.documents(body),
          &Enum.any?(LazyHTML.query(&1, "[data-projection-state='recovery']"))
        )
      end)

    refute HTTP.terminal?(recovery)
    HTTP.finish(first)
    HTTP.eventually(fn -> StreamCoordinator.stats().connections == 0 end)

    changed =
      Phase06Fixture.provider_observation!(fixture, "hui-d3-reconnect", fixture.git_snapshot)

    second = HTTP.connect(client, "/fleet", HTTP.payload("fleet", %{tab: tab, cursor: cursor}))
    assert revision?(second.initial, changed.observation_receipt.dataset_revision)
    assert [new_subscription] = subscriptions()
    refute new_subscription == subscription
    StreamCoordinator.drain()
    HTTP.finish(second)
  end

  defp revision?(body, revision) do
    Enum.any?(HTTP.documents(body), fn doc ->
      doc |> LazyHTML.query("[id$='-trust-metadata-1'] dd") |> LazyHTML.text() |> String.trim() ==
        Integer.to_string(revision)
    end)
  end

  defp subscriptions do
    Enum.filter(Process.list(), fn pid ->
      case Process.info(pid, :dictionary) do
        {:dictionary, dictionary} ->
          Keyword.get(dictionary, :"$initial_call") ==
            {JidoCode.Knowledge.ProjectionSubscription, :init, 1}

        _ ->
          false
      end
    end)
  end
end
