defmodule JidoCodeWeb.Phase10ProductAcceptanceTest do
  use JidoCodeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias JidoCode.Install
  alias JidoCode.Knowledge.Bootstrap
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Product.SurfaceContract
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase10ProductAdapter

  @operator_token "phase-04-integration-operator-token"

  setup context do
    prior_provider = Application.get_env(:jido_code, :product_projection_provider)
    prior_gateway = Application.get_env(:jido_code, :product_command_gateway)
    prior_substrate = Application.get_env(:jido_code, :phase_10_product_substrate)

    substrate = Phase04Fixture.start!(context)

    assert {:ok, bootstrap} =
             Install.bootstrap(@operator_token,
               store_server: substrate.store_server,
               writer: substrate.writer
             )

    Application.put_env(:jido_code, :product_projection_provider, Phase10ProductAdapter)
    Application.put_env(:jido_code, :product_command_gateway, Phase10ProductAdapter)
    Application.put_env(:jido_code, :phase_10_product_substrate, substrate)

    on_exit(fn ->
      restore_env(:product_projection_provider, prior_provider)
      restore_env(:product_command_gateway, prior_gateway)
      restore_env(:phase_10_product_substrate, prior_substrate)
    end)

    conn =
      context.conn
      |> init_test_session(%{})
      |> JidoCodeWeb.ProductAuth.establish_session()

    {:ok, conn: conn, bootstrap: bootstrap}
  end

  test "commits enrollment from LiveView and reconstructs the surface from graph", %{
    conn: conn,
    bootstrap: bootstrap
  } do
    substrate = Application.fetch_env!(:jido_code, :phase_10_product_substrate)
    abrupt_restart_substrate!(substrate)

    identity = JidoCodeWeb.ProductAuth.product_identity()
    {:ok, authority} = JidoCode.Product.authority(identity)

    assert {:ok, initial_projection} = Phase10ProductAdapter.load(authority, identity, [])
    assert initial_projection.state == :empty
    assert initial_projection.dataset_revision == bootstrap.authority_dataset_revision

    {:ok, view, _html} = live(conn, ~p"/?surface=repositories")

    assert has_element?(view, "#repository-catalog")
    assert has_element?(view, "#repositories-empty")

    assert has_element?(
             view,
             "#factory-sidebar-revision",
             "#{bootstrap.authority_dataset_revision}"
           )

    params = %{
      conceptual_key: "phase-10-live-product",
      provider: "https://github.com",
      external_id: "R_phase_10_live_product",
      owner: "agentjido",
      name: "phase-10-live-product",
      reason: "Phase 10 graph-backed product acceptance",
      confirmed: "true"
    }

    view
    |> form("#repository-enrollment-form", enrollment: params)
    |> render_change()

    assert has_element?(view, "#repository-enrollment-preview")

    view
    |> form("#repository-enrollment-form", enrollment: params)
    |> render_submit()

    assert has_element?(view, "#product-command-receipt", "committed")

    {:ok, july_audit_graph} = JidoCode.Knowledge.AuditPolicy.graph_iri(substrate.issued_at)

    assert {:ok, %{graph_revision: 2}} =
             JidoCode.Knowledge.StoreServer.request(
               substrate.store_server,
               {:graph_metadata, july_audit_graph}
             )

    {:ok, repository_iri} =
      JidoCode.Knowledge.ResourceIdentity.conceptual_repository("phase-10-live-product")

    {:ok, repository_ref} = SurfaceContract.encode_resource(repository_iri)

    assert {:ok, persisted_projection} = Phase10ProductAdapter.load(authority, identity, [])
    assert Enum.map(persisted_projection.repositories, & &1.iri) == [repository_iri]
    assert has_element?(view, "#repositories > button[phx-value-repository='#{repository_ref}']")

    view
    |> element("#repositories button[phx-value-repository='#{repository_ref}']")
    |> render_click()

    assert_patch(view, ~p"/?#{%{repository: repository_ref, surface: "repositories"}}")
    refute has_element?(view, "#projection-notice")
    assert has_element?(view, "#factory-sidebar-revision", "3")
    assert has_element?(view, "#repositories > button")

    GenServer.stop(view.pid, :normal)

    {:ok, reconnected, _html} =
      live(conn, ~p"/?#{%{repository: repository_ref, surface: "repositories"}}")

    refute has_element?(reconnected, "#projection-notice")
    assert has_element?(reconnected, "#repositories > button")

    reconnected
    |> element("#factory-nav-work")
    |> render_click()

    assert has_element?(reconnected, "#work-items-empty")

    reconnected
    |> element("#factory-nav-execution")
    |> render_click()

    assert has_element?(reconnected, "#attempts-empty")

    {:ok, catalog, _html} = live(conn, ~p"/?surface=repositories")

    assert has_element?(catalog, "#factory-sidebar-revision", "3")

    assert has_element?(
             catalog,
             "#repositories > button[phx-value-repository='#{repository_ref}']"
           )

    {:ok, concealed_ref} =
      SurfaceContract.encode_resource("https://jido.run/id/repository/not-authorized")

    {:ok, concealed, _html} =
      live(conn, ~p"/?#{%{repository: concealed_ref, surface: "repositories"}}")

    assert has_element?(concealed, "#projection-notice")
    refute has_element?(concealed, "#repositories > button")
  end

  test "reopens the exact product commit and rebuilds its projection from graph" do
    identity = JidoCodeWeb.ProductAuth.product_identity()
    {:ok, authority} = JidoCode.Product.authority(identity)

    assert {:ok, %{outcome: :committed}} =
             Phase10ProductAdapter.enroll_repository(authority, identity, %{
               "conceptual_key" => "phase-10-restart-product",
               "provider" => "https://github.com",
               "external_id" => "R_phase_10_restart_product",
               "owner" => "agentjido",
               "name" => "phase-10-restart-product",
               "reason" => "Phase 10 product restart acceptance",
               "confirmed" => "true",
               "idempotency_key" => "phase10restartproduct"
             })

    substrate = Application.fetch_env!(:jido_code, :phase_10_product_substrate)
    restart_substrate!(substrate)

    assert StoreServer.summary(substrate.store_server).ready?
    assert {:ok, projection} = Phase10ProductAdapter.load(authority, identity, [])
    assert projection.dataset_revision == 3
    assert length(projection.repositories) == 1
  end

  defp restart_substrate!(substrate) do
    Enum.each(
      [
        substrate.writer,
        substrate.query_runner,
        substrate.maintenance,
        substrate.store_server,
        substrate.readiness
      ],
      &stop_process/1
    )

    start_child!({Readiness, name: substrate.readiness})

    start_child!(
      {StoreServer,
       name: substrate.store_server,
       readiness: substrate.readiness,
       config: substrate.config,
       authorized_callers: %{
         read: [self(), substrate.query_runner],
         write: [substrate.writer],
         maintenance: [substrate.maintenance]
       }}
    )

    await_ready!(substrate.store_server)

    start_child!(
      {QueryRunner, name: substrate.query_runner, store_server: substrate.store_server}
    )

    start_child!(
      {Writer,
       name: substrate.writer,
       store_server: substrate.store_server,
       clock: fn -> substrate.issued_at end,
       bootstrap_config: %{
         enabled?: true,
         token_digest: Bootstrap.token_digest(@operator_token)
       }}
    )

    start_child!({Maintenance, name: substrate.maintenance, store_server: substrate.store_server})
  end

  defp abrupt_restart_substrate!(substrate) do
    %{store: %{dict_manager: dictionary}} = :sys.get_state(substrate.store_server)
    Process.exit(dictionary, :kill)
    await_unavailable!(substrate.store_server)
    restart_substrate!(substrate)
  end

  defp start_child!(child) do
    child
    |> Supervisor.child_spec(id: make_ref(), restart: :temporary)
    |> start_supervised!()
  end

  defp await_ready!(server, attempts \\ 500)
  defp await_ready!(server, 0), do: assert(StoreServer.summary(server).ready?)

  defp await_ready!(server, attempts) do
    if StoreServer.summary(server).ready? do
      :ok
    else
      Process.sleep(10)
      await_ready!(server, attempts - 1)
    end
  end

  defp await_unavailable!(server, attempts \\ 500)
  defp await_unavailable!(_server, 0), do: flunk("store remained ready after backend exit")

  defp await_unavailable!(server, attempts) do
    case GenServer.whereis(server) do
      nil ->
        :ok

      _pid ->
        case safe_summary(server) do
          {:ok, %{ready?: true}} ->
            Process.sleep(10)
            await_unavailable!(server, attempts - 1)

          {:ok, _summary} ->
            :ok

          :unavailable ->
            :ok
        end
    end
  end

  defp safe_summary(server) do
    {:ok, StoreServer.summary(server)}
  catch
    :exit, _reason -> :unavailable
  end

  defp stop_process(server) do
    case GenServer.whereis(server) do
      pid when is_pid(pid) -> GenServer.stop(pid)
      nil -> :ok
    end
  catch
    :exit, _reason -> :ok
  end

  defp restore_env(key, nil), do: Application.delete_env(:jido_code, key)
  defp restore_env(key, value), do: Application.put_env(:jido_code, key, value)
end
