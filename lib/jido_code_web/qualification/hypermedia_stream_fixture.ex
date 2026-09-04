defmodule JidoCodeWeb.Qualification.HypermediaStreamFixture do
  @moduledoc """
  Fixed-lifetime Dstar wire fixture for HUI-B3 browser and transport evidence.

  The fixture is deliberately synchronous: each chunk must be accepted before
  the next is produced, so there is no producer queue to outgrow a slow client.
  It carries fixture freshness only and never claims durable progress or truth.
  """

  alias JidoCodeWeb.Qualification.HypermediaStreamCoordinator

  @retry_ms 1_500
  @normal_delay_ms 25
  @slow_delay_ms 125
  @max_lifetime_ms 1_200

  @type scenario :: String.t()

  @spec run(Plug.Conn.t(), reference(), scenario(), atom(), binary()) ::
          {:ok, Plug.Conn.t()} | {:error, term(), Plug.Conn.t()}
  def run(conn, token, scenario, correlation, status_html) do
    deadline = System.monotonic_time(:millisecond) + @max_lifetime_ms
    delay = if scenario == "slow", do: @slow_delay_ms, else: @normal_delay_ms

    events =
      [
        signal_event(
          %{
            _connectionState: "connected",
            _fixtureFreshness: "snapshot",
            _fixtureTruth: "fixture-only",
            _sequence: 1,
            _tabCorrelation: Atom.to_string(correlation),
            _terminal: false
          },
          event_id: "hui-b3-1",
          retry: @retry_ms
        ),
        element_event(status_html, event_id: "hui-b3-2"),
        heartbeat_event(),
        scenario_events(scenario),
        signal_event(%{nudges: %{huiB3Results: 1}}, event_id: "hui-b3-nudge"),
        signal_event(
          %{
            _connectionState: "closed",
            _streamPending: false,
            _terminal: true
          },
          event_id: "hui-b3-complete"
        )
      ]
      |> List.flatten()

    Enum.reduce_while(events, {:ok, conn}, fn event, {:ok, conn} ->
      if System.monotonic_time(:millisecond) > deadline do
        {:halt, {:error, :lifetime_limit, conn}}
      else
        case emit(conn, token, event) do
          {:ok, conn} ->
            Process.sleep(delay)
            {:cont, {:ok, conn}}

          {:error, reason, conn} ->
            {:halt, {:error, reason, conn}}
        end
      end
    end)
  end

  def retry_ms, do: @retry_ms
  def max_lifetime_ms, do: @max_lifetime_ms

  defp scenario_events("duplicate") do
    event = signal_event(hint("duplicate", 3), event_id: "hui-b3-hint-3")
    [event, event]
  end

  defp scenario_events("reorder") do
    [
      signal_event(hint("reordered-later", 4), event_id: "hui-b3-hint-4"),
      signal_event(hint("reordered-earlier", 3), event_id: "hui-b3-hint-3")
    ]
  end

  defp scenario_events("drop") do
    signal_event(hint("dropped-3-through-4", 5), event_id: "hui-b3-hint-5")
  end

  defp scenario_events("sleep_wake") do
    signal_event(
      hint("sleep-wake", 3)
      |> Map.put(:_connectionState, "reconnecting"),
      event_id: "hui-b3-hint-3"
    )
  end

  defp scenario_events("restart") do
    signal_event(
      hint("server-restart", 3)
      |> Map.put(:_connectionState, "reconnecting"),
      event_id: "hui-b3-hint-3",
      retry: @retry_ms
    )
  end

  defp scenario_events("terminal") do
    signal_event(
      hint("terminal-close", 3)
      |> Map.put(:_fixtureFreshness, "stale"),
      event_id: "hui-b3-hint-3"
    )
  end

  defp scenario_events(_normal_or_slow) do
    signal_event(hint("patch", 3), event_id: "hui-b3-hint-3")
  end

  defp hint(name, sequence) do
    %{_fixtureFreshness: "patched", _fixtureHint: name, _sequence: sequence}
  end

  defp signal_event(signals, options) do
    estimate = byte_size(Jason.encode!(signals)) + 256
    %{estimate: estimate, send: &Dstar.patch_signals(&1, signals, options)}
  end

  defp element_event(html, options) do
    estimate = byte_size(html) + 256

    %{
      estimate: estimate,
      send:
        &Dstar.patch_elements(
          &1,
          html,
          Keyword.merge([selector: "#hui-b3-stream-state"], options)
        )
    }
  end

  defp heartbeat_event do
    %{
      estimate: 128,
      send: fn conn ->
        Dstar.SSE.send_event!(
          conn,
          "hui-b3-heartbeat",
          "state alive",
          event_id: "hui-b3-heartbeat"
        )
      end
    }
  end

  defp emit(conn, token, event) do
    with :ok <- HypermediaStreamCoordinator.record_event(token, event.estimate) do
      try do
        {:ok, event.send.(conn)}
      rescue
        error ->
          HypermediaStreamCoordinator.record_send_error(token)
          {:error, {:send_error, error}, conn}
      end
    else
      {:error, reason} -> {:error, reason, conn}
    end
  end
end
