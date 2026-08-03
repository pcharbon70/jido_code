defmodule JidoCode.Factory.Recovery.Decision do
  @moduledoc "Pure recovery policy over graph projection and adapter observations."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.RuntimeEvent

  @terminal ~w[cancelled completed failed timed_out abandoned superseded]a
  @terminal_events ~w[cancelled completed failed timed_out]a

  @spec evaluate(map(), map(), term(), term(), DateTime.t(), keyword()) ::
          {:ok, atom() | tuple()} | {:error, AdapterError.t()}
  def evaluate(projection, candidate, runtime_status, sandbox_status, %DateTime{} = now, options)
      when is_map(projection) and is_map(candidate) and is_list(options) do
    available_versions = Keyword.get(options, :available_runtime_versions, [])
    current_snapshot = Keyword.get(options, :current_snapshot_iri, projection.source_snapshot_iri)
    policy_current? = Keyword.get(options, :policy_current?, true)
    resume? = Keyword.get(options, :resume?, true)

    cond do
      projection.current_state in @terminal ->
        {:ok, :ignore_terminal}

      projection.runtime_version not in available_versions ->
        {:ok, {:supersede, :runtime_version_unavailable}}

      projection.source_snapshot_iri != current_snapshot ->
        {:ok, {:supersede, :source_snapshot_changed}}

      policy_current? != true ->
        {:ok, {:supersede, :policy_changed}}

      candidate[:lease_current?] == false ->
        {:ok, {:abandon, :lease_inactive}}

      expired?(candidate[:valid_to], now) ->
        {:ok, {:abandon, :lease_expired}}

      stale_event?(runtime_status, projection) ->
        {:ok, :reject_stale_event}

      match?({:ok, %RuntimeEvent{type: type}} when type in @terminal_events, runtime_status) ->
        {:ok, {:recover_terminal, runtime_status |> elem(1) |> Map.fetch!(:type)}}

      projection.current_state == :cancelling ->
        {:ok, :propagate_cancellation}

      match?({:error, %AdapterError{}}, sandbox_status) ->
        {:ok, :retry_later}

      match?({:ok, %RuntimeEvent{type: :crashed}}, runtime_status) and resume? ->
        {:ok, :resume}

      match?({:error, %AdapterError{}}, runtime_status) ->
        {:ok, :retry_later}

      match?({:ok, %RuntimeEvent{}}, runtime_status) ->
        {:ok, :observe}

      true ->
        {:error, AdapterError.new(:corrupt, :recovery_decision)}
    end
  rescue
    _error -> {:error, AdapterError.new(:corrupt, :recovery_decision)}
  end

  def evaluate(_projection, _candidate, _runtime, _sandbox, _now, _options),
    do: {:error, AdapterError.new(:invalid_input, :recovery_decision)}

  defp expired?(%DateTime{} = valid_to, now), do: DateTime.compare(now, valid_to) != :lt
  defp expired?(_valid_to, _now), do: true

  defp stale_event?({:ok, %RuntimeEvent{} = event}, projection) do
    event.attempt_iri != projection.attempt_iri or
      event.sequence < last_sequence(projection.timeline)
  end

  defp stale_event?(_status, _projection), do: false

  defp last_sequence(timeline) do
    timeline
    |> Enum.map(& &1.runtime_sequence)
    |> Enum.filter(&is_integer/1)
    |> Enum.max(fn -> 0 end)
  end
end
