# Evaluates to a runner for the disposable production instance only.
fn base, credential ->
  alias JidoCode.Product.StreamCoordinator
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Identity.Store
  revision = JidoCode.Knowledge.StoreServer.summary().dataset_revision

  port =
    Port.open({:spawn_executable, System.find_executable("node")}, [
      :binary,
      :exit_status,
      {:line, 8_192},
      args: ["scripts/qualify_hui_d4_faults.mjs"],
      env: [
        {~c"HUI_D4_BASE", String.to_charlist(base)},
        {~c"HUI_D4_LOGIN", ~c"local-proof@example.test"},
        {~c"HUI_D4_CREDENTIAL", String.to_charlist(credential)}
      ]
    ])

  receive_line = fn expected ->
    receive do
      {^port, {:data, {:eol, ^expected}}} -> :ok
      {^port, other} -> raise "unexpected qualification protocol: #{inspect(other)}"
    after
      30_000 -> raise "qualification protocol timeout"
    end
  end

  for {fault, supervisor, child} <- [
        {"query", JidoCode.Knowledge.Supervisor, QueryRunner},
        {"identity", JidoCode.Supervisor, Store},
        {"coordinator", JidoCode.Supervisor, StreamCoordinator}
      ] do
    receive_line.("D4_READY_" <> fault)
    started = System.monotonic_time(:millisecond)

    if fault == "coordinator" do
      Process.exit(Process.whereis(StreamCoordinator), :kill)
    else
      :ok = Supervisor.terminate_child(supervisor, child)
    end

    true = Port.command(port, "applied\n")
    receive_line.("D4_RECOVER_" <> fault)
    cleanup_ms = System.monotonic_time(:millisecond) - started
    true = cleanup_ms <= 10_000
    if fault != "coordinator", do: {:ok, _} = Supervisor.restart_child(supervisor, child)

    true =
      Enum.any?(1..300, fn _ ->
        case StreamCoordinator.stats() do
          %{connections: 0, queued_payload_bytes: 0, pressure: :normal} ->
            true

          _ ->
            Process.sleep(50)
            false
        end
      end)

    ^revision = JidoCode.Knowledge.StoreServer.summary().dataset_revision
    true = Port.command(port, "restored\n")

    IO.puts(
      Jason.encode!(%{
        fault: fault,
        cleanup_ms: cleanup_ms,
        recovery_ms: System.monotonic_time(:millisecond) - started,
        graph_revision_unchanged: true,
        protected_content_cleared: true
      })
    )
  end

  receive_line.("D4_DONE")

  receive do
    {^port, {:exit_status, 0}} -> :ok
    {^port, other} -> raise "qualification subprocess failed: #{inspect(other)}"
  after
    10_000 -> raise "qualification subprocess did not exit"
  end
end
