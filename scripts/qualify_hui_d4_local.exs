# Run after MIX_ENV=prod mix assets.deploy, with PHX_SERVER=false.
# Only disposable qualification data is written; credentials are never emitted.
true = Mix.env() == :prod
false = Application.get_env(:jido_code, :hypermedia_qualification_build)
asset_manifest = File.read!("priv/static/cache_manifest.json")

IO.puts(
  Jason.encode!(%{
    asset_manifest_sha256: Base.encode16(:crypto.hash(:sha256, asset_manifest), case: :lower)
  })
)

root =
  Path.join(
    System.tmp_dir!(),
    "hui-d4-local-" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
  )

File.mkdir!(root)
File.chmod!(root, 0o700)
{:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
{:ok, port} = :inet.port(socket)
:ok = :gen_tcp.close(socket)
{:ok, transport} = JidoCode.LocalDeployment.transport(%{"PORT" => Integer.to_string(port)})
{candidate, 0} = System.cmd("git", ["rev-parse", "HEAD"])
{dirty, 0} = System.cmd("git", ["status", "--porcelain", "--untracked-files=no"])

hardware = %{
  cpu: Regex.run(~r/^model name\s+: (.+)$/m, File.read!("/proc/cpuinfo")) |> Enum.at(1),
  memory_kib: Regex.run(~r/^MemTotal:\s+(\d+) kB/m, File.read!("/proc/meminfo")) |> Enum.at(1)
}

IO.puts(
  Jason.encode!(%{
    candidate: String.trim(candidate),
    dirty_checkout: dirty != "",
    hardware: hardware,
    profile: JidoCode.LocalDeployment.profile(),
    transport_sha256:
      Base.encode16(:crypto.hash(:sha256, :erlang.term_to_binary(transport)), case: :lower),
    limits:
      Map.merge(
        JidoCode.Product.StreamCoordinator.limits(),
        JidoCode.LocalDeployment.stream_limits()
      )
  })
)

credential = Base.url_encode64(:crypto.strong_rand_bytes(32))
token = Base.url_encode64(:crypto.strong_rand_bytes(32))

Application.put_env(:jido_code, :authority_bootstrap, %{
  enabled?: true,
  token_digest: :crypto.hash(:sha256, token)
})

Application.put_env(:jido_code, :knowledge_store,
  enabled: true,
  root: Path.join(root, "graph"),
  backup_root: Path.join(root, "backups")
)

Application.put_env(
  :jido_code,
  :human_identity,
  Application.fetch_env!(:jido_code, :human_identity)
  |> Keyword.merge(
    enabled: true,
    persistence: true,
    path: Path.join(root, "identity"),
    integrity_key: :crypto.strong_rand_bytes(32),
    bootstrap: nil,
    authority_adapter: JidoCode.Identity.Authority.LocalGraph
  )
)

Application.put_env(
  :jido_code,
  JidoCodeWeb.Endpoint,
  Application.fetch_env!(:jido_code, JidoCodeWeb.Endpoint)
  |> Keyword.merge(transport)
  |> Keyword.merge(server: true, secret_key_base: Base.encode64(:crypto.strong_rand_bytes(64)))
)

{:ok, _} = Application.ensure_all_started(:jido_code)

stage_metrics = :ets.new(:hui_d4_stages, [:set, :public, write_concurrency: true])
stage_names = [:authorization, :cohort_query, :detail_query, :resource_lookup, :fleet_row]

:ok =
  :telemetry.attach(
    "hui-d4-guard-deadline",
    [:jido_code, :product_stream, :guard_deadline],
    fn _, _, metadata, _ ->
      IO.puts(Jason.encode!(%{qualification: "guard deadline", kind: metadata.kind}))
    end,
    nil
  )

for stage <- stage_names, do: :ets.insert(stage_metrics, {stage, 0, 0, 0})

:ok =
  :telemetry.attach(
    "hui-d4-projection-stages",
    [:jido_code, :product, :projection_stage],
    fn _, measurements, metadata, {table, stages} ->
      if metadata[:stage] in stages do
        case metadata[:phase] do
          :start ->
            :ets.update_counter(table, metadata.stage, {2, 1})

          :stop ->
            :ets.update_counter(table, metadata.stage, [{3, 1}, {4, measurements.duration_us}])

          _ ->
            :ok
        end
      end
    end,
    {stage_metrics, stage_names}
  )

# The provider already validates these closed telemetry dimensions. Print only
# fixed classes on failure; never dump the result, request, graph, or error.
:ok =
  :telemetry.attach(
    "hui-d4-projection-failure",
    JidoCode.Product.ReadProjectionTelemetry.event(),
    fn _, measurements, metadata, _ ->
      if metadata.outcome in [:error, :rejected] do
        IO.puts(
          Jason.encode!(%{
            qualification: "projection failure",
            surface: metadata.surface,
            outcome: metadata.outcome,
            state: metadata.state,
            cache_status: metadata.cache_status,
            duration_ms: measurements.duration_ms
          })
        )
      end
    end,
    nil
  )

{:ok, _} =
  JidoCode.LocalInstall.bootstrap(
    %{login: "local-proof@example.test", display_name: "Local qualification human"},
    credential,
    token
  )

%{ready?: true} = JidoCode.LocalDeployment.readiness()
base = "http://127.0.0.1:#{port}"

for headers <- [
      [{"host", "attacker.example"}],
      [{"forwarded", "for=127.0.0.1"}],
      [{"x-forwarded-proto", "https"}]
    ] do
  %{status: 421} = Req.get!(base <> "/sign-in", headers: headers, retry: false)
end

{output, result} =
  System.cmd("node", ["scripts/qualify_hui_d4_local.mjs"],
    env: [
      {"HUI_D4_BASE", base},
      {"HUI_D4_LOGIN", "local-proof@example.test"},
      {"HUI_D4_CREDENTIAL", credential}
    ],
    stderr_to_stdout: true
  )

IO.write(output)

true =
  Enum.any?(
    :telemetry.list_handlers([:phoenix, :router_dispatch, :start]),
    &(&1.id == {Phoenix.Logger, [:phoenix, :router_dispatch, :start]})
  )

:ok = JidoCode.LocalDeployment.drain()
Process.sleep(500)
%{connections: 0} = JidoCode.Product.StreamCoordinator.stats()
revision = JidoCode.Knowledge.StoreServer.summary().dataset_revision
:ok = Application.stop(:jido_code)
{:ok, _} = Application.ensure_all_started(:jido_code)

true =
  Enum.any?(1..150, fn _ ->
    if JidoCode.LocalDeployment.readiness().ready?,
      do: true,
      else:
        (
          Process.sleep(100)
          false
        )
  end)

^revision = JidoCode.Knowledge.StoreServer.summary().dataset_revision

{restarted_output, restarted_result} =
  System.cmd("node", ["scripts/qualify_hui_d4_local.mjs"],
    env: [
      {"HUI_D4_BASE", base},
      {"HUI_D4_LOGIN", "local-proof@example.test"},
      {"HUI_D4_CREDENTIAL", credential}
    ],
    stderr_to_stdout: true
  )

IO.write(restarted_output)

for browser <- ["firefox", "webkit"] do
  {browser_output, browser_result} =
    System.cmd("node", ["scripts/qualify_hui_d4_local.mjs"],
      env: [
        {"HUI_D4_BASE", base},
        {"HUI_D4_LOGIN", "local-proof@example.test"},
        {"HUI_D4_CREDENTIAL", credential},
        {"HUI_D4_BROWSER", browser}
      ],
      stderr_to_stdout: true
    )

  IO.write(browser_output)

  IO.puts(
    Jason.encode!(%{browser: browser, stream_stats: JidoCode.Product.StreamCoordinator.stats()})
  )

  0 = browser_result
end

if System.get_env("HUI_D4_ORCA") == "true" do
  {orca_output, 0} =
    System.cmd(
      "dbus-run-session",
      ["--", "xvfb-run", "-a", "bash", "scripts/qualify_hui_d4_orca.sh"],
      env: [
        {"HUI_D4_BASE", base},
        {"HUI_D4_LOGIN", "local-proof@example.test"},
        {"HUI_D4_CREDENTIAL", credential}
      ],
      stderr_to_stdout: true
    )

  IO.write(orca_output)
end

{fault_runner, _} = Code.eval_file("scripts/qualify_hui_d4_faults.exs")
:ok = fault_runner.(base, credential)

{scope_runner, _} = Code.eval_file("scripts/qualify_hui_d4_scopes.exs")
{:ok, scope_commits} = scope_runner.(base, credential)
Process.sleep(8_000)

{resource_check, _} = Code.eval_file("scripts/qualify_hui_d4_resources.exs")
:ok = resource_check.(credential)

{restart_runner, _} = Code.eval_file("scripts/qualify_hui_d4_restart.exs")
:ok = restart_runner.(base, credential)

{slow_reader, _} = Code.eval_file("scripts/qualify_hui_d4_slow_reader.exs")
:ok = slow_reader.(base, credential)

sample = fn sample, peak, remaining ->
  receive do
    :stop -> peak
  after
    100 ->
      if remaining == 0 do
        peak
      else
        pressure = JidoCode.Product.StreamPressure.sample()
        stats = JidoCode.Product.StreamCoordinator.stats()
        [_, rss] = Regex.run(~r/^VmRSS:\s+(\d+)/m, File.read!("/proc/self/status"))

        sockets =
          File.ls!("/proc/self/fd")
          |> Enum.count(fn fd ->
            case File.read_link("/proc/self/fd/" <> fd) do
              {:ok, "socket:" <> _} -> true
              _ -> false
            end
          end)

        current = %{
          beam_bytes: pressure.memory_bytes,
          beam_processes: :erlang.system_info(:process_count),
          connections: stats.connections,
          queued_payload_bytes: stats.queued_payload_bytes,
          query_queue: pressure.query_queue,
          run_queue: pressure.run_queue,
          process_rss_bytes: String.to_integer(rss) * 1024,
          process_sockets: sockets
        }

        true = stats.connections <= 4
        0 = stats.queued_payload_bytes

        next = Map.merge(peak, current, fn _, old, value -> max(old, value) end)
        sample.(sample, next, remaining - 1)
      end
  end
end

load_rounds = String.to_integer(System.get_env("HUI_D4_LOAD_ROUNDS", "3"))
true = load_rounds in 3..20
load_budget_ms = (load_rounds * 40 + 60) * 1_000
collector = Task.async(fn -> sample.(sample, %{}, div(load_budget_ms, 100)) end)

contend = fn contend, buffer, deadline ->
  receive do
    :stop -> :ok
  after
    0 ->
      if System.monotonic_time(:millisecond) < deadline do
        :crypto.hash(:sha256, buffer)
        contend.(contend, buffer, deadline)
      end
  end
end

contenders =
  for _ <- 1..2 do
    Task.async(fn ->
      contend.(
        contend,
        :binary.copy(<<0>>, 64 * 1024 * 1024),
        System.monotonic_time(:millisecond) + load_budget_ms
      )
    end)
  end

{cpu_before, _} = :erlang.statistics(:runtime)

# Replay actual committed notifications in bounded duplicate/out-of-order bursts.
# These are disposable hints; they must not advance graph truth or expose the
# concealed repository. No synthetic authority or query result is introduced.
hint_bursts =
  Task.async(fn ->
    Enum.reduce_while(1..div(load_budget_ms, 1_000), 0, fn _, count ->
      receive do
        :stop -> {:halt, count}
      after
        1_000 ->
          for index <- 1..16 do
            {command, receipt} = Enum.at(scope_commits, rem(index, length(scope_commits)))
            :ok = JidoCode.Knowledge.ChangeFeed.publish(command, receipt)
          end

          {:cont, count + 16}
      end
    end)
  end)

load_revision = JidoCode.Knowledge.StoreServer.summary().dataset_revision
query_errors_before = JidoCode.Product.StreamCoordinator.stats().metrics.query_error
timing_before = JidoCode.Product.StreamCoordinator.stats().metrics
for stage <- stage_names, do: :ets.insert(stage_metrics, {stage, 0, 0, 0})

{load_output, load_result} =
  System.cmd("node", ["scripts/qualify_hui_d4_load.mjs"],
    env: [
      {"HUI_D4_BASE", base},
      {"HUI_D4_LOGIN", "local-proof@example.test"},
      {"HUI_D4_CREDENTIAL", credential}
    ],
    stderr_to_stdout: true
  )

{cpu_after, _} = :erlang.statistics(:runtime)
# Include bounded teardown so late watchdog events cannot escape the snapshot.
true =
  Enum.any?(1..150, fn _ ->
    if JidoCode.Product.StreamCoordinator.stats().connections == 0,
      do: true,
      else:
        (
          Process.sleep(100)
          false
        )
  end)

send(hint_bursts.pid, :stop)
replayed_hints = Task.await(hint_bursts, 5_000)
load_revision_after = JidoCode.Knowledge.StoreServer.summary().dataset_revision
load_stats_after = JidoCode.Product.StreamCoordinator.stats()

for worker <- contenders do
  send(worker.pid, :stop)
  Task.await(worker, 5_000)
end

send(collector.pid, :stop)
peaks = Task.await(collector, 5_000)
IO.write(load_output)

IO.puts(
  Jason.encode!(%{
    qualification: "projection stage totals",
    stages:
      Enum.map(stage_names, fn stage ->
        [{^stage, started, completed, duration}] = :ets.lookup(stage_metrics, stage)
        %{stage: stage, started: started, completed: completed, duration_us: duration}
      end),
    note:
      "Nested durations overlap; unfinished spans can reflect task termination or active work."
  })
)

# Emit only bounded, privacy-safe diagnostics before enforcing acceptance.
# A failed counter assertion must not hide the browser result or resource peaks.
IO.puts(
  Jason.encode!(%{
    qualification: "load diagnostics",
    browser_exit_status: load_result,
    graph_revision_unchanged: load_revision_after == load_revision,
    query_error_delta: load_stats_after.metrics.query_error - query_errors_before,
    stream_stats: load_stats_after,
    peaks: peaks
  })
)

^load_revision = load_revision_after
^query_errors_before = load_stats_after.metrics.query_error
true = load_stats_after.metrics.slow_owner == timing_before.slow_owner
true = load_stats_after.metrics.guard_failure == timing_before.guard_failure

IO.puts(
  Jason.encode!(%{
    peaks: peaks,
    cpu_runtime_ms: cpu_after - cpu_before,
    contention: "two SHA-256 workers, 64 MiB each",
    load_budget_ms: load_budget_ms,
    replayed_committed_hints: replayed_hints,
    counters: JidoCode.Product.StreamCoordinator.stats().metrics,
    schedulers: System.schedulers_online(),
    otp: System.otp_release(),
    elixir: System.version()
  })
)

:ok = JidoCode.LocalDeployment.drain()
Process.sleep(500)
%{connections: 0, queued_payload_bytes: 0} = JidoCode.Product.StreamCoordinator.stats()
{:ok, authentication} = JidoCode.Identity.authenticate("local-proof@example.test", credential)
{:ok, session} = JidoCode.Identity.Sessions.issue(authentication)
before_rollback = JidoCode.Knowledge.StoreServer.summary().dataset_revision
:ok = JidoCode.Product.DeliveryControl.disable()

{native_output, native_result} =
  System.cmd("node", ["scripts/qualify_hui_d4_native.mjs"],
    env: [
      {"HUI_D4_BASE", base},
      {"HUI_D4_LOGIN", "local-proof@example.test"},
      {"HUI_D4_CREDENTIAL", credential}
    ],
    stderr_to_stdout: true
  )

IO.write(native_output)
{:ok, _} = JidoCode.Identity.Sessions.validate(session.session_ref, touch: false)
^before_rollback = JidoCode.Knowledge.StoreServer.summary().dataset_revision
:ok = Application.stop(:jido_code)

exit_code =
  if Enum.all?([result, restarted_result, load_result, native_result], &(&1 == 0)), do: 0, else: 1

IO.puts("Local production qualification exit=#{exit_code}; disposable evidence data: #{root}")
if exit_code != 0, do: System.halt(exit_code)
