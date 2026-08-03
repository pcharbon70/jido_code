defmodule JidoCode.TestSupport.FakeExecutionRuntime do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ExecutionRuntime

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.RuntimeEvent

  @impl true
  def prepare(request, options), do: event(request, :prepared, :pending, 0, options)

  @impl true
  def start(request, options) do
    case Keyword.get(options, :scenario, :success) do
      :success -> event(request, :started, :pending, 1, options)
      :tool_use -> event(request, :waiting_tool, :pending, 1, options)
      :timeout -> event(request, :timed_out, :timeout, 1, options)
      :cancellation -> event(request, :cancelling, :pending, 1, options)
      :crash -> {:error, AdapterError.new(:unavailable, :start)}
      :lost_response -> {:error, AdapterError.new(:timeout, :start)}
      :duplicate_event -> event(request, :started, :pending, 1, options)
      :stale_lease -> event(request, :stale_lease, :rejected, 1, options)
    end
  end

  @impl true
  def signal(request, incoming, options) do
    event(request, :tool_result, incoming.outcome_class, incoming.sequence, options)
  end

  @impl true
  def cancel(request, _cancellation, options),
    do: event(request, :cancelled, :cancelled, 2, options)

  @impl true
  def status(request, options), do: event(request, :heartbeat, :pending, 2, options)

  @impl true
  def terminate(request, _reason, options),
    do: event(request, :cancelled, :cancelled, 3, options)

  defp event(request, type, outcome, sequence, options) do
    clock = Keyword.get(options, :clock, fn -> ~U[2026-08-03 14:00:00Z] end)

    RuntimeEvent.new(%{
      attempt_iri: request.attempt_iri,
      sequence: sequence,
      type: type,
      occurred_at: clock.(),
      outcome_class: outcome,
      usage: %{input_tokens: 10, output_tokens: 5}
    })
  end
end
