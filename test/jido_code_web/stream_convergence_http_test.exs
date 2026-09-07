defmodule JidoCodeWeb.StreamConvergenceHTTPTest do
  use ExUnit.Case, async: false
  alias JidoCode.Identity.Store
  alias JidoCode.Product.StreamCoordinator
  alias JidoCode.TestSupport.HypermediaStreamHTTPFixture, as: HTTP
  alias JidoCode.TestSupport.HypermediaUIPhaseC4Fixture, as: Fixture

  @routes [
    {:factory, "/factory"},
    {:fleet, "/fleet"},
    {:projects, "/projects"},
    {:project, "/projects/project_browser_alpha/overview"},
    {:project_attempts, "/projects/project_browser_alpha/attempts"},
    {:project_wiki, "/projects/project_browser_alpha/wiki"},
    {:project_dependencies, "/projects/project_browser_alpha/dependencies"},
    {:attempt, "/projects/project_browser_alpha/attempts/attempt_browser_alpha"}
  ]

  setup do
    keys = [:product_read_projection_provider, :read_projection_fixture]
    prior = Map.new(keys, &{&1, Application.get_env(:jido_code, &1)})

    Application.put_env(
      :jido_code,
      :product_read_projection_provider,
      JidoCode.TestSupport.FakeReadProjectionProvider
    )

    fixture(4)
    base = HTTP.start!()

    on_exit(fn ->
      StreamCoordinator.drain()
      HTTP.eventually(fn -> StreamCoordinator.stats().connections == 0 end)

      Enum.each(prior, fn {key, value} ->
        if value == nil,
          do: Application.delete_env(:jido_code, key),
          else: Application.put_env(:jido_code, key, value)
      end)
    end)

    %{client: HTTP.sign_in(base)}
  end

  test "all registered graph routes requery their own root and clean subscriptions", %{
    client: client
  } do
    for {surface, route} <- @routes do
      HTTP.reset!()
      fixture(4)
      stream = HTTP.connect(client, route, HTTP.payload(Atom.to_string(surface)))
      assert revision?(stream.initial, 4)
      [subscription] = subscriptions()
      state = :sys.get_state(subscription)
      assert state.families == JidoCode.Product.StreamProjectionRegistry.entries()[surface]
      fixture(8)

      for family <- state.families, revision <- [8, 7, 8, 6] do
        send(
          subscription,
          {:jido_code_change,
           %JidoCode.Knowledge.ChangeEvent{
             command_class: "test",
             scope_iri: hd(state.scopes),
             dataset_revision: revision,
             affected_graphs: [%{family: family}],
             receipt_iri: "NEVER-DISPLAY-HINT"
           }}
        )
      end

      body = HTTP.until(stream, &revision?(&1, 8))

      for doc <- HTTP.documents(body) do
        assert LazyHTML.attribute(
                 LazyHTML.query(doc, "#product-owned-content"),
                 "data-read-surface"
               ) == [Atom.to_string(surface)]

        refute LazyHTML.text(doc) =~ "NEVER-DISPLAY-HINT"
      end

      assert :sys.get_state(subscription).last_revision == 8
      StreamCoordinator.drain()
      HTTP.finish(stream)
      HTTP.eventually(fn -> not Process.alive?(subscription) end)
    end
  end

  test "lag clears content and a later durable query converges without accepting hint truth", %{
    client: client
  } do
    stream = HTTP.connect(client)
    [subscription] = subscriptions()
    hint(subscription, 8)
    body = HTTP.until(stream, &recovery?/1)
    refute revision?(body, 8)
    assert :sys.get_state(subscription).last_revision == 4
    fixture(8)
    HTTP.until(stream, &revision?(&1, 8))
    assert :sys.get_state(subscription).failures == 0
    StreamCoordinator.drain()
    HTTP.finish(stream)
  end

  test "permanent query failure clears then closes after three bounded attempts", %{
    client: client
  } do
    stream = HTTP.connect(client)
    [subscription] = subscriptions()

    Application.put_env(:jido_code, :read_projection_fixture, fn context ->
      JidoCode.Product.ReadProjection.unavailable(context.page.key, :error)
    end)

    hint(subscription, 8)
    HTTP.until(stream, &recovery?/1)
    HTTP.until(stream, &HTTP.terminal?/1)
    assert HTTP.terminal?(HTTP.finish(stream).body)

    HTTP.eventually(fn ->
      StreamCoordinator.stats().connections == 0 and not Process.alive?(subscription)
    end)
  end

  test "registry supports the provider's bounded project and attempt enumeration only" do
    for kind <- [:project, :attempt] do
      assert {:ok, resources} = Store.registered_resources(kind, 100)
      assert resources != []
      assert Enum.all?(resources, &(&1.kind == kind))

      for limit <- [0, 101, "100"],
          do: assert({:error, :invalid_resource_query} == Store.registered_resources(kind, limit))
    end

    assert {:error, :invalid_resource_query} = Store.registered_resources(:factory, 100)
  end

  defp fixture(revision),
    do:
      Application.put_env(:jido_code, :read_projection_fixture, fn context ->
        Fixture.projection(context.page.key, %{dataset_revision: revision})
      end)

  defp revision?(body, revision),
    do:
      Enum.any?(HTTP.documents(body), fn doc ->
        LazyHTML.text(LazyHTML.query(doc, "[id$='-trust-metadata-1'] dd")) |> String.trim() ==
          Integer.to_string(revision)
      end)

  defp recovery?(body),
    do:
      Enum.any?(
        HTTP.documents(body),
        &Enum.any?(LazyHTML.query(&1, "[data-projection-state='recovery']"))
      )

  defp hint(pid, revision) do
    state = :sys.get_state(pid)

    send(
      pid,
      {:jido_code_change,
       %JidoCode.Knowledge.ChangeEvent{
         command_class: "test",
         receipt_iri: "NEVER-DISPLAY-HINT",
         scope_iri: hd(state.scopes),
         dataset_revision: revision,
         affected_graphs: [%{family: hd(state.families)}]
       }}
    )
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
