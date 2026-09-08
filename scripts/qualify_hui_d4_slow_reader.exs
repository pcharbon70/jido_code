fn base, credential ->
  alias JidoCode.Product.StreamCoordinator

  port =
    Port.open({:spawn_executable, System.find_executable("node")}, [
      :binary,
      :exit_status,
      {:line, 8_192},
      args: ["scripts/qualify_hui_d4_slow_reader.mjs"],
      env: [
        {~c"HUI_D4_BASE", String.to_charlist(base)},
        {~c"HUI_D4_LOGIN", ~c"local-proof@example.test"},
        {~c"HUI_D4_CREDENTIAL", String.to_charlist(credential)}
      ]
    ])

  receive do
    {^port, {:data, {:eol, "D4_SLOW_READY"}}} -> :ok
    {^port, _} -> raise "slow reader failed admission"
  after
    30_000 -> raise "slow reader admission timeout"
  end

  started = System.monotonic_time(:millisecond)
  %{connections: 1, queued_payload_bytes: 0} = StreamCoordinator.stats()

  true =
    Enum.any?(1..650, fn _ ->
      %{connections: connections, queued_payload_bytes: 0} = StreamCoordinator.stats()
      true = connections in 0..1

      if connections == 0,
        do: true,
        else:
          (
            Process.sleep(100)
            false
          )
    end)

  elapsed = System.monotonic_time(:millisecond) - started
  true = elapsed <= 65_000
  true = Port.command(port, "retired\n")

  receive do
    {^port, {:data, {:eol, "D4_SLOW_DONE"}}} -> :ok
    {^port, _} -> raise "slow reader recovery failed"
  after
    15_000 -> raise "slow reader recovery timeout"
  end

  receive do
    {^port, {:exit_status, 0}} -> :ok
    {^port, _} -> raise "slow reader subprocess failed"
  after
    10_000 -> raise "slow reader subprocess did not exit"
  end

  IO.puts(
    Jason.encode!(%{
      nonreading_client: "pass",
      owner_retired_ms: elapsed,
      queued_protected_bytes: 0,
      claim: "bounded owner lifetime; not TCP-buffer saturation"
    })
  )

  :ok
end
