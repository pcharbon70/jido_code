defmodule JidoCode.Runtime.JidoHarness.ProcessRunner do
  @moduledoc "Runs the protected Pi RPC profile through JidoHarness managed processes."

  @behaviour JidoCode.Runtime.JidoHarness.Runner

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Runtime.JidoHarness.JidoHarnessProcessAPI
  alias JidoCode.Runtime.JidoHarness.MemoryOnlyRetention

  @architecture_file_role :temporary

  @impl true
  def start(profile, launch, options) when is_map(profile) and is_map(launch) do
    with :ok <- validate_launch(profile, launch),
         {:ok, retention} <-
           MemoryOnlyRetention.prepare(
             retention_base(options),
             retention_key(launch.run_id),
             profile.journal
           ),
         spec = process_spec(profile, launch, retention) do
      start_with_retention(launch, spec, retention, options)
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      {:error, reason} -> {:error, reason}
      _invalid -> invalid(:jido_harness_process_start)
    end
  rescue
    _error -> unavailable(:jido_harness_process_start)
  end

  def start(_profile, _launch, _options), do: invalid(:jido_harness_process_start)

  @impl true
  def signal(handle, %{prompt: prompt}, options) do
    with :ok <- valid_handle(handle),
         true <- is_binary(prompt) and byte_size(prompt) in 1..16_384,
         :ok <-
           api(options).send_input(
             handle.runtime_ref,
             prompt_command(prompt),
             api_options(options)
           ) do
      {:ok, %{state: :running, observations: []}}
    else
      {:error, reason} -> {:error, reason}
      _invalid -> invalid(:jido_harness_process_signal)
    end
  end

  def signal(_handle, _signal, _options), do: invalid(:jido_harness_process_signal)

  @impl true
  def status(handle, options) do
    with :ok <- valid_handle(handle),
         {:ok, info} <- api(options).info(handle.runtime_ref, api_options(options)),
         {:ok, events} <-
           api(options).replay(
             handle.runtime_ref,
             [cursor: handle.event_cursor, limit: 100],
             api_options(options)
           ) do
      state = normalize_state(info.state)

      {:ok,
       %{
         state: state,
         observations: normalize_events(events),
         usage: %{},
         workspace_digest: nil,
         candidate_diff_digest: nil,
         artifact_iris: []
       }}
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
      _invalid -> invalid(:jido_harness_process_status)
    end
  end

  @impl true
  def cancel(handle, _cancellation, options) do
    with :ok <- valid_handle(handle),
         {:ok, proof} <- bounded_cancel(handle.runtime_ref, options) do
      {:ok,
       %{
         state: :cancelled,
         observations: [],
         usage: %{
           cancellation: proof,
           cancellation_bound_ms: cancellation_bound(options),
           enforcement: :hard
         }
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      {:error, reason} -> {:error, reason}
      _invalid -> invalid(:jido_harness_process_cancel)
    end
  end

  @impl true
  def terminate(handle, _reason, options) do
    with :ok <- valid_handle(handle),
         :ok <- force_stop(handle.runtime_ref, options),
         :ok <- normalize_missing(api(options).prune(handle.runtime_ref, api_options(options))),
         :ok <- cleanup_retention(handle.run_id, options) do
      {:ok, %{state: :terminated, observations: []}}
    else
      {:error, reason} -> {:error, reason}
      _invalid -> unavailable(:jido_harness_process_terminate)
    end
  end

  @doc false
  def architecture_file_role, do: @architecture_file_role

  defp process_spec(profile, launch, retention) do
    %{
      executable: launch.executable,
      argv: profile.argv,
      cwd: launch.workspace_path,
      env: launch.environment,
      env_mode: :replace,
      stdin: true,
      pty: false,
      runtime_timeout_ms: launch.limits.wall_ms,
      idle_timeout_ms: launch.limits.idle_ms,
      metadata: %{
        run_id: launch.run_id,
        provider: profile.provider,
        deployment_class: :developer_local_cli
      },
      retention: retention.retention
    }
  end

  defp start_with_retention(launch, spec, retention, options) do
    case api(options).start(spec, api_options(options)) do
      {:ok, process_id} ->
        case api(options).send_input(
               process_id,
               prompt_command(launch.prompt),
               api_options(options)
             ) do
          :ok ->
            {:ok,
             %{
               runtime_ref: process_id,
               session_ref: launch.run_id,
               versions: %{
                 jido_harness: "2.0.0@" <> JidoCode.Runtime.JidoHarness.Adoption.revision(),
                 cli: launch.cli_version,
                 provider: launch.provider_version
               },
               observations: [observation(1, :started, launch, %{process_id: process_id})]
             }}

          {:error, reason} ->
            _ = api(options).kill(process_id, api_options(options))
            _ = api(options).prune(process_id, api_options(options))
            _ = MemoryOnlyRetention.cleanup(retention)
            {:error, reason}
        end

      {:error, reason} ->
        _ = MemoryOnlyRetention.cleanup(retention)
        {:error, reason}
    end
  end

  defp validate_launch(profile, launch) do
    with :developer_local_cli <- launch[:deployment_class],
         true <- launch[:explicit_opt_in] == true,
         false <- launch[:managed_eligible],
         :stdin_jsonl <- profile[:prompt_transport],
         :replace <- launch[:env_mode],
         true <- is_binary(launch[:prompt]) and byte_size(launch.prompt) in 1..16_384,
         true <- is_binary(launch[:run_id]) and byte_size(launch.run_id) in 1..128,
         true <- is_binary(launch[:workspace_path]) and File.dir?(launch.workspace_path),
         true <- is_binary(launch[:executable]) and Path.type(launch.executable) == :absolute,
         true <- is_map(launch[:environment]),
         true <- is_map(launch[:limits]),
         true <- is_binary(launch[:cli_version]) and byte_size(launch.cli_version) in 1..128,
         true <-
           is_binary(launch[:provider_version]) and byte_size(launch.provider_version) in 1..128 do
      :ok
    else
      _invalid -> invalid(:jido_harness_process_launch)
    end
  end

  defp prompt_command(prompt),
    do: Jason.encode!(%{"type" => "prompt", "message" => prompt}) <> "\n"

  defp normalize_events(events) do
    Enum.flat_map(events, fn event ->
      case normalize_event_type(event.type) do
        nil -> []
        type -> [observation(event.sequence, type, nil, event.data)]
      end
    end)
  end

  defp observation(sequence, type, launch, payload) do
    occurred_at = if launch, do: launch.occurred_at, else: DateTime.utc_now()

    %{
      sequence: sequence,
      type: type,
      occurred_at: occurred_at,
      payload_digest: digest(payload),
      tool_ref: nil
    }
  end

  defp normalize_event_type(:started), do: :started
  defp normalize_event_type(:stdout), do: :provider_event
  defp normalize_event_type(:stderr), do: :provider_event
  defp normalize_event_type(:exited), do: :completed
  defp normalize_event_type(:failed), do: :failed
  defp normalize_event_type(:cancelled), do: :cancelled
  defp normalize_event_type(:timed_out), do: :timed_out
  defp normalize_event_type(_type), do: nil

  defp normalize_state(state) when state in [:starting, :running, :stopping], do: :running
  defp normalize_state(:exited), do: :completed
  defp normalize_state(:failed), do: :failed
  defp normalize_state(:cancelled), do: :cancelled
  defp normalize_state(:timed_out), do: :timed_out

  defp valid_handle(%{run_id: run_id, runtime_ref: process_id})
       when is_binary(run_id) and is_binary(process_id),
       do: :ok

  defp valid_handle(_handle), do: :error

  defp bounded_cancel(process_id, options) do
    with :ok <- api(options).cancel(process_id, api_options(options)) do
      case api(options).await(process_id, cancellation_bound(options), api_options(options)) do
        {:ok, info} ->
          if terminal_info?(info),
            do: {:ok, :graceful_process_group},
            else: force_cancel(process_id, options)

        {:error, :timeout} ->
          force_cancel(process_id, options)

        {:error, :not_found} ->
          {:ok, :already_absent}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp force_cancel(process_id, options) do
    with :ok <- normalize_missing(api(options).kill(process_id, api_options(options))),
         :ok <- await_forced_stop(process_id, options) do
      {:ok, :forced_process_group}
    end
  end

  defp force_stop(process_id, options) do
    with :ok <- normalize_missing(api(options).kill(process_id, api_options(options))),
         :ok <- await_forced_stop(process_id, options) do
      :ok
    end
  end

  defp await_forced_stop(process_id, options) do
    case api(options).await(process_id, kill_bound(options), api_options(options)) do
      {:ok, info} ->
        if terminal_info?(info), do: :ok, else: unavailable(:jido_harness_process_group)

      {:error, :not_found} ->
        :ok

      {:error, _reason} ->
        unavailable(:jido_harness_process_group)
    end
  end

  defp terminal_info?(%{state: state}),
    do: state in [:exited, :failed, :cancelled, :timed_out]

  defp terminal_info?(_info), do: false

  defp cleanup_retention(run_id, options) do
    key = retention_key(run_id)
    root = Path.join(retention_base(options), "jido-code-harness-" <> key)

    retention = %MemoryOnlyRetention{
      root: root,
      journal_barrier: Path.join(root, "memory-only-journal-barrier"),
      retention: %{}
    }

    if File.exists?(root), do: MemoryOnlyRetention.cleanup(retention), else: :ok
  end

  defp retention_key(run_id) do
    :crypto.hash(:sha256, run_id)
    |> Base.encode16(case: :lower)
  end

  defp retention_base(options), do: Keyword.get(options, :retention_base, System.tmp_dir!())
  defp cancellation_bound(options), do: bounded_timeout(options, :cancellation_bound_ms, 12_000)
  defp kill_bound(options), do: bounded_timeout(options, :kill_bound_ms, 2_000)

  defp bounded_timeout(options, key, default) do
    case Keyword.get(options, key, default) do
      value when is_integer(value) and value in 1..30_000 -> value
      _invalid -> default
    end
  end

  defp api(options), do: Keyword.get(options, :process_api, JidoHarnessProcessAPI)
  defp api_options(options), do: Keyword.get(options, :process_api_options, [])
  defp normalize_missing(:ok), do: :ok
  defp normalize_missing({:error, :not_found}), do: :ok
  defp normalize_missing(error), do: error

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
