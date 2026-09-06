defmodule JidoCode.Product.StreamCoordinatorTest do
  use ExUnit.Case, async: true
  alias JidoCode.Product.StreamCoordinator, as: Coordinator

  setup do
    name = Module.concat(__MODULE__, "Admission")
    start_supervised!({Coordinator, name: name})
    %{server: name}
  end

  test "same session/tab takes over across routes, duplicate nonce never evicts", %{
    server: server
  } do
    context = context()
    assert {:ok, first} = Coordinator.admit(context, server)
    assert {:error, :duplicate} = Coordinator.admit(context, server)
    assert :ok = Coordinator.active(first, server)

    assert {:ok, second} =
             Coordinator.admit(%{context | request: "second", route: "/projects"}, server)

    assert_receive {:product_stream, ^first, {:closed, :takeover}}
    assert :ok = Coordinator.release(first, server)
    assert {:error, :closed} = Coordinator.active(first, server)
    assert :ok = Coordinator.active(second, server)
    assert %{connections: 1, nonce_keys: 2} = Coordinator.stats(server)
  end

  test "two tabs per session, separate sessions and exact owner cleanup", %{server: server} do
    assert {:ok, lease} = Coordinator.admit(context(), server)
    assert {:ok, _} = Coordinator.admit(%{context() | tab: "tab2", request: "r2"}, server)

    assert {:error, :rate_limited} =
             Coordinator.admit(%{context() | tab: "tab3", request: "r3"}, server)

    task =
      Task.async(fn ->
        assert {:error, :closed} = Coordinator.active(lease, server)
        assert {:ok, _} = Coordinator.admit(%{context() | session: "another"}, server)
        Coordinator.release_owner(server)
      end)

    assert :ok = Task.await(task)
    assert %{connections: 2} = Coordinator.stats(server)
    assert :ok = Coordinator.release_owner(server)
    assert %{connections: 0} = Coordinator.stats(server)
  end

  test "expired session fails admission without any lease", %{server: server} do
    assert {:error, :expired} = Coordinator.admit(%{context() | hard_expires_at: 0}, server)
    assert %{connections: 0} = Coordinator.stats(server)
  end

  defp context do
    %{
      subject: "human",
      session: "session",
      tenant: "tenant",
      tab: "tab",
      request: "request",
      route: "/factory",
      projection: :factory,
      hard_expires_at: System.system_time(:millisecond) + 60_000,
      idle_expires_at: System.system_time(:millisecond) + 60_000
    }
  end
end
