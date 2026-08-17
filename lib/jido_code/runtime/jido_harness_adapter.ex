defmodule JidoCode.Runtime.JidoHarnessAdapter do
  @moduledoc """
  Delegated JidoHarness execution behind the existing execution-runtime port.

  The adapter owns no graph access. JidoHarness and provider identifiers are
  retained only in the ephemeral run registry and are never restart inputs.
  """

  @behaviour JidoCode.Factory.Ports.ExecutionRuntime

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Execution.RuntimeEvent
  alias JidoCode.Runtime.JidoHarness.Adoption
  alias JidoCode.Runtime.JidoHarness.Recovery
  alias JidoCode.Runtime.JidoHarness.RunRecord
  alias JidoCode.Runtime.JidoHarness.RunRegistry

  @terminal_states ~w[completed failed cancelled timed_out]a

  @impl true
  def prepare(%Request{} = request, options) when is_list(options) do
    with {:ok, profile} <- profile(options),
         {:ok, record} <- RunRegistry.prepare(registry(options), request, profile) do
      event(request, record, :prepared, :pending, options)
    end
  end

  def prepare(_request, _options), do: invalid(:prepare)

  @impl true
  def start(%Request{} = request, options) when is_list(options) do
    with {:ok, profile} <- profile(options),
         {:ok, prompt} <- prompt(options),
         {:ok, record} <- RunRegistry.prepare(registry(options), request, profile) do
      start_record(request, record, profile, prompt, options)
    end
  end

  def start(_request, _options), do: invalid(:start)

  @impl true
  def signal(%Request{} = request, %RuntimeEvent{} = incoming, options)
      when is_list(options) do
    with {:ok, prompt} <- prompt(options),
         {:ok, record} <- running_record(request, options),
         {:ok, receipt} <-
           invoke_runner(:signal, options, [
             handle(record),
             %{prompt: prompt, sequence: incoming.sequence}
           ]),
         {:ok, updated} <- adopt_receipt(request, record, receipt, options) do
      event(request, updated, type_for(updated.state), outcome_for(updated.state), options)
    end
  end

  def signal(_request, _incoming, _options), do: invalid(:signal)

  @impl true
  def status(%Request{} = request, options) when is_list(options) do
    case RunRegistry.fetch(registry(options), request) do
      {:ok, %RunRecord{} = record} -> status_record(request, record, options)
      :error -> missing_event(request, options)
    end
  end

  def status(_request, _options), do: invalid(:status)

  @impl true
  def cancel(%Request{} = request, cancellation, options)
      when is_map(cancellation) and is_list(options) do
    case RunRegistry.fetch(registry(options), request) do
      {:ok, %RunRecord{} = record} ->
        with {:ok, receipt} <-
               invoke_runner(:cancel, options, [handle(record), bounded_reason(cancellation)]),
             {:ok, updated} <- adopt_terminal(request, record, :cancelled, receipt, options) do
          event(request, updated, :cancelled, :cancelled, options)
        end

      :error ->
        missing_event(
          request,
          Keyword.put(options, :recovery_context, %{cancellation_committed: true})
        )
    end
  end

  def cancel(_request, _cancellation, _options), do: invalid(:cancel)

  @impl true
  def terminate(%Request{} = request, reason, options)
      when is_map(reason) and is_list(options) do
    case RunRegistry.fetch(registry(options), request) do
      {:ok, %RunRecord{} = record} ->
        result = invoke_runner(:terminate, options, [handle(record), bounded_reason(reason)])

        with {:ok, receipt} <- normalize_termination(result),
             {:ok, updated} <- adopt_terminal(request, record, :terminated, receipt, options),
             :ok <- RunRegistry.delete(registry(options), request) do
          event(request, updated, :cancelled, :cancelled, options)
        end

      :error ->
        missing_event(request, options)
    end
  end

  def terminate(_request, _reason, _options), do: invalid(:terminate)

  defp start_record(request, %RunRecord{state: :prepared}, profile, prompt, options) do
    launch = %{
      prompt: prompt,
      attempt_iri: request.attempt_iri,
      snapshot_iri: request.snapshot_iri,
      context_digest: request.context_digest,
      fencing_token: request.fencing_token
    }

    with {:ok, receipt} <- invoke_runner(:start, options, [profile, launch]),
         {:ok, updated} <- RunRegistry.started(registry(options), request, receipt),
         {:ok, observed} <-
           adopt_observations(request, updated, Map.get(receipt, :observations, []), options) do
      event(request, observed, :started, :pending, options)
    end
  end

  defp start_record(request, %RunRecord{state: :running} = record, _profile, _prompt, options),
    do: event(request, record, :started, :pending, options)

  defp start_record(request, %RunRecord{} = record, _profile, _prompt, options) do
    event(request, record, type_for(record.state), outcome_for(record.state), options)
  end

  defp status_record(request, %RunRecord{} = record, options) do
    if RunRecord.terminal?(record) do
      event(request, record, type_for(record.state), outcome_for(record.state), options)
    else
      case invoke_runner(:status, options, [handle(record)]) do
        {:ok, receipt} ->
          with {:ok, updated} <- adopt_receipt(request, record, receipt, options) do
            event(request, updated, type_for(updated.state), outcome_for(updated.state), options)
          end

        {:error, reason} when reason in [:not_found, :missing] ->
          missing_event(request, options)

        {:error, %AdapterError{} = error} ->
          {:error, error}

        {:error, _reason} ->
          unavailable(:status)
      end
    end
  end

  defp adopt_receipt(request, record, receipt, options) when is_map(receipt) do
    state = Map.get(receipt, :state, :running)

    with true <- state in [:running | @terminal_states],
         {:ok, observed} <-
           adopt_observations(request, record, Map.get(receipt, :observations, []), options) do
      if state in @terminal_states do
        adopt_terminal(request, observed, state, receipt, options)
      else
        {:ok, observed}
      end
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:jido_harness_runner_receipt)
    end
  end

  defp adopt_receipt(_request, _record, _receipt, _options),
    do: invalid(:jido_harness_runner_receipt)

  defp adopt_observations(request, record, observations, options) when is_list(observations) do
    if observations == [] do
      {:ok, record}
    else
      RunRegistry.observe(registry(options), request, observations)
    end
  end

  defp adopt_observations(_request, _record, _observations, _options),
    do: invalid(:jido_harness_observations)

  defp adopt_terminal(request, record, state, receipt, options) when is_map(receipt) do
    final = %{
      workspace_digest: receipt[:workspace_digest],
      candidate_diff_digest: receipt[:candidate_diff_digest],
      artifact_iris: Map.get(receipt, :artifact_iris, []),
      usage: Map.get(receipt, :usage, %{})
    }

    if RunRecord.terminal?(record) do
      {:ok, record}
    else
      RunRegistry.finish(registry(options), request, state, final)
    end
  end

  defp running_record(request, options) do
    case RunRegistry.fetch(registry(options), request) do
      {:ok, %RunRecord{state: :running} = record} -> {:ok, record}
      _missing -> unavailable(:jido_harness_run)
    end
  end

  defp missing_event(request, options) do
    context =
      Keyword.get(options, :recovery_context, %{
        lease_state: :active,
        runtime_compatible: true,
        cancellation_committed: false,
        terminal_callback_proven: false
      })

    with {:ok, classification} <- Recovery.classify(context) do
      RuntimeEvent.new(%{
        attempt_iri: request.attempt_iri,
        sequence: 0,
        type: :heartbeat,
        occurred_at: clock(options).(),
        outcome_class: :unknown,
        usage: %{},
        diagnostic: "runtime_missing:" <> Atom.to_string(classification)
      })
    else
      _invalid -> invalid(:status)
    end
  end

  defp event(request, record, type, outcome, options) do
    RuntimeEvent.new(%{
      attempt_iri: request.attempt_iri,
      sequence: record.sequence,
      type: type,
      occurred_at: clock(options).(),
      outcome_class: outcome,
      usage: usage(record),
      payload_digest: record_digest(record)
    })
  end

  defp usage(%RunRecord{final: %{usage: usage}}), do: usage
  defp usage(_record), do: %{}

  defp record_digest(record) do
    %{
      attempt_iri: record.attempt_iri,
      profile_name: record.profile_name,
      state: record.state,
      sequence: record.sequence,
      event_cursor: record.event_cursor,
      versions: record.versions,
      observations: record.observations,
      final: record.final
    }
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp handle(record) do
    %{
      run_id: record.run_id,
      runtime_ref: record.runtime_ref,
      session_ref: record.session_ref,
      provider_session_ref: record.provider_session_ref,
      event_cursor: record.event_cursor
    }
  end

  defp invoke_runner(operation, options, arguments) do
    runner = Keyword.get(options, :runner)
    runner_options = Keyword.get(options, :runner_options, [])

    if is_atom(runner) and Code.ensure_loaded?(runner) and
         function_exported?(runner, operation, length(arguments) + 1) do
      case apply(runner, operation, arguments ++ [runner_options]) do
        {:ok, receipt} when is_map(receipt) -> {:ok, receipt}
        {:error, %AdapterError{} = error} -> {:error, error}
        {:error, reason} -> {:error, reason}
        _invalid -> invalid(operation)
      end
    else
      unavailable(operation)
    end
  rescue
    _error -> unavailable(operation)
  catch
    :exit, _reason -> unavailable(operation)
  end

  defp normalize_termination({:ok, receipt}), do: {:ok, receipt}
  defp normalize_termination({:error, :not_found}), do: {:ok, %{state: :terminated}}
  defp normalize_termination({:error, %AdapterError{} = error}), do: {:error, error}
  defp normalize_termination(_result), do: unavailable(:terminate)

  defp profile(options) do
    options |> Keyword.get(:profile, :pi_rpc_deny_all) |> Adoption.profile()
  end

  defp prompt(options) do
    case Keyword.get(options, :prompt) do
      value when is_binary(value) and byte_size(value) in 1..16_384 ->
        if String.trim(value) == "", do: invalid(:jido_harness_prompt), else: {:ok, value}

      _invalid ->
        invalid(:jido_harness_prompt)
    end
  end

  defp bounded_reason(value) do
    value
    |> Map.take([:reason, :committed_at, :fencing_token])
    |> Map.reject(fn {_key, item} -> is_binary(item) and byte_size(item) > 256 end)
  end

  defp type_for(:prepared), do: :prepared
  defp type_for(:running), do: :progress
  defp type_for(:completed), do: :completed
  defp type_for(:failed), do: :failed
  defp type_for(:cancelled), do: :cancelled
  defp type_for(:timed_out), do: :timed_out
  defp type_for(:terminated), do: :cancelled

  defp outcome_for(state) when state in [:prepared, :running], do: :pending
  defp outcome_for(:completed), do: :success
  defp outcome_for(:failed), do: :failure
  defp outcome_for(:cancelled), do: :cancelled
  defp outcome_for(:timed_out), do: :timeout
  defp outcome_for(:terminated), do: :cancelled

  defp registry(options), do: Keyword.get(options, :registry, RunRegistry)
  defp clock(options), do: Keyword.get(options, :clock, &DateTime.utc_now/0)
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
