defmodule JidoCode.Orchestration.RunPubSub do
  @moduledoc """
  PubSub helpers for workflow run events.

  Topic:
  - `"jido_code:run:<run_id>"` - Per-run lifecycle and step events
  """

  require Logger

  @pubsub JidoCode.PubSub
  @default_broadcaster Phoenix.PubSub

  @type typed_event_channel_diagnostic :: %{required(String.t()) => term()}

  @spec run_topic(term()) :: String.t()
  def run_topic(run_id) do
    "jido_code:run:#{run_id}"
  end

  @spec subscribe_run(term()) :: :ok | {:error, term()}
  def subscribe_run(run_id) do
    Phoenix.PubSub.subscribe(@pubsub, run_topic(run_id))
  end

  @spec unsubscribe_run(term()) :: :ok
  def unsubscribe_run(run_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, run_topic(run_id))
  end

  @spec broadcast_run_event(term(), map()) :: :ok | {:error, typed_event_channel_diagnostic()}
  def broadcast_run_event(run_id, payload) when is_map(payload) do
    topic = run_topic(run_id)
    event_name = payload |> Map.get("event", "unknown") |> normalize_event_name()

    case broadcaster().broadcast(@pubsub, topic, {:run_event, payload}) do
      :ok ->
        :ok

      {:error, reason} ->
        typed_diagnostic = typed_diagnostic(topic, event_name, reason)
        emit_publication_failure(typed_diagnostic)
        {:error, typed_diagnostic}

      other ->
        typed_diagnostic = typed_diagnostic(topic, event_name, %{error_type: inspect(other)})
        emit_publication_failure(typed_diagnostic)
        {:error, typed_diagnostic}
    end
  end

  def broadcast_run_event(_run_id, _payload) do
    {:error,
     typed_diagnostic(
       "jido_code:run:unknown",
       "unknown",
       %{error_type: "event_payload_invalid"}
     )}
  end

  defp broadcaster do
    Application.get_env(:jido_code, :workflow_run_event_broadcaster, @default_broadcaster)
  end

  defp typed_diagnostic(topic, event_name, reason) do
    %{
      "error_type" => "workflow_run_event_publication_failed",
      "channel" => "run_topic",
      "operation" => "broadcast_run_event",
      "topic" => topic,
      "event" => event_name,
      "reason_type" => reason_type(reason),
      "message" => "Run topic event publication failed.",
      "timestamp" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }
  end

  defp emit_publication_failure(typed_diagnostic) do
    Logger.error(
      "event_channel_diagnostic error_type=#{typed_diagnostic["error_type"]} channel=#{typed_diagnostic["channel"]} operation=#{typed_diagnostic["operation"]} event=#{typed_diagnostic["event"]} reason_type=#{typed_diagnostic["reason_type"]}"
    )
  end

  defp normalize_event_name(value) when is_binary(value) and value != "", do: value

  defp normalize_event_name(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_event_name()

  defp normalize_event_name(_value), do: "unknown"

  defp reason_type(%{error_type: error_type}) when is_binary(error_type),
    do: sanitize_reason_type(error_type)

  defp reason_type(%{"error_type" => error_type}) when is_binary(error_type),
    do: sanitize_reason_type(error_type)

  defp reason_type(reason) when is_atom(reason),
    do: reason |> Atom.to_string() |> sanitize_reason_type()

  defp reason_type(reason) when is_binary(reason), do: sanitize_reason_type(reason)
  defp reason_type(_reason), do: "unknown"

  defp sanitize_reason_type(type) do
    String.replace(type, ~r/[^a-zA-Z0-9._-]/, "_")
  end
end
