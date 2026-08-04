defmodule JidoCodeWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Knowledge substrate metrics use only fixed operation and outcome tags.
      summary("jido_code.knowledge.operation.stop.duration",
        tags: [:operation, :outcome],
        unit: {:native, :millisecond}
      ),
      summary("jido_code.knowledge.operation.stop.queue_duration",
        tags: [:operation, :outcome],
        unit: {:native, :millisecond}
      ),
      sum("jido_code.knowledge.operation.stop.result_count",
        tags: [:operation, :outcome]
      ),

      # Factory metrics intentionally exclude the opaque trace correlation ref.
      summary("jido_code.factory.operation.stop.duration",
        tags: [:stage, :outcome],
        unit: {:native, :millisecond}
      ),
      last_value("jido_code.factory.snapshot.queue_depth", tags: [:kind, :state]),
      sum("jido_code.factory.snapshot.admission_deferred_count", tags: [:kind, :state]),
      last_value("jido_code.factory.snapshot.graph_count", tags: [:kind, :state]),
      last_value("jido_code.factory.snapshot.quad_count", tags: [:kind, :state]),
      last_value("jido_code.factory.snapshot.stale_count", tags: [:kind, :state]),
      last_value("jido_code.factory.snapshot.incomplete_count", tags: [:kind, :state]),
      last_value("jido_code.factory.snapshot.active_lease_count", tags: [:kind, :state]),
      last_value("jido_code.factory.snapshot.active_attempt_count", tags: [:kind, :state]),
      last_value("jido_code.factory.snapshot.decision_pending_count", tags: [:kind, :state]),
      last_value("jido_code.factory.snapshot.cache_entry_count", tags: [:kind, :state]),
      last_value("jido_code.factory.snapshot.pubsub_lag_ms", tags: [:kind, :state]),
      last_value("jido_code.factory.snapshot.backup_age_seconds", tags: [:kind, :state]),
      sum("jido_code.factory.snapshot.projection_error_count", tags: [:kind, :state]),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {JidoCodeWeb, :count_users, []}
    ]
  end
end
