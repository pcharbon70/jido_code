defmodule JidoCode.Runtime.JidoHarness.CodexProcessRunner do
  @moduledoc "Protected Codex finite-run execution through the pinned JidoHarness Process API."

  @behaviour JidoCode.Runtime.JidoHarness.Runner

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Runtime.JidoHarness.CodexEventMapper
  alias JidoCode.Runtime.JidoHarness.CodexRelease
  alias JidoCode.Runtime.JidoHarness.JidoHarnessProcessAPI
  alias JidoCode.Runtime.JidoHarness.MemoryOnlyRetention
  alias JidoCode.Runtime.JidoHarness.ProcessRunner

  @architecture_file_role :temporary
  @max_prompt_bytes 65_536
  @environment_names ~w[PATH HOME TMPDIR LANG LC_ALL CODEX_HOME]
  @launch_keys ~w[
    deployment_class explicit_opt_in managed_eligible prompt run_id workspace_path executable
    executable_digest environment limits cli_version provider_version context_digest occurred_at
  ]a

  @impl true
  def start(profile, launch, options) when is_map(profile) and is_map(launch) do
    with {:ok, ^profile} <- CodexRelease.validate_runtime_profile(profile),
         :ok <- validate_launch(launch),
         {:ok, retention} <-
           MemoryOnlyRetention.prepare(
             retention_base(options),
             retention_key(launch.run_id),
             profile.journal
           ),
         {:ok, schema} <- write_schema(retention, profile),
         spec = process_spec(profile, launch, retention, schema) do
      start_process(launch, spec, retention, schema, options)
    else
      :error -> invalid(:codex_process_profile)
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:codex_process_start)
    end
  rescue
    _error -> unavailable(:codex_process_start)
  end

  def start(_profile, _launch, _options), do: invalid(:codex_process_start)

  @impl true
  def signal(_handle, _signal, _options),
    do: {:error, AdapterError.new(:conflict, :codex_live_signal)}

  @impl true
  def status(handle, options) do
    with :ok <- valid_handle(handle),
         {:ok, info} <- api(options).info(handle.runtime_ref, api_options(options)),
         {:ok, events} <-
           api(options).replay(
             handle.runtime_ref,
             [cursor: handle.event_cursor, limit: 100],
             api_options(options)
           ),
         {:ok, normalized} <- CodexEventMapper.normalize(events, clock(options).()) do
      receipt(info, normalized)
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, %AdapterError{} = error} -> {:error, error}
      {:error, _reason} -> unavailable(:codex_process_status)
      _invalid -> invalid(:codex_process_status)
    end
  rescue
    _error -> unavailable(:codex_process_status)
  end

  @impl true
  def cancel(handle, cancellation, options),
    do: ProcessRunner.cancel(handle, cancellation, options)

  @impl true
  def terminate(handle, reason, options),
    do: ProcessRunner.terminate(handle, reason, options)

  @doc false
  def architecture_file_role, do: @architecture_file_role

  defp start_process(launch, spec, retention, schema, options) do
    case api(options).start(spec, api_options(options)) do
      {:ok, process_id} ->
        with :ok <-
               api(options).send_input(process_id, launch.prompt <> "\n", api_options(options)),
             :ok <- api(options).close_input(process_id, api_options(options)) do
          {:ok,
           %{
             runtime_ref: process_id,
             session_ref: launch.run_id,
             provider_session_ref: nil,
             versions: %{
               jido_harness: "2.0.0@" <> CodexRelease.manifest().jido_harness.revision,
               cli: "codex-cli/" <> CodexRelease.cli_version(),
               model: CodexRelease.model(),
               adapter: CodexRelease.digest()
             },
             observations: [
               observation(1, :started, launch.occurred_at, %{process_id: process_id})
             ],
             launch_digest: launch_digest(spec, schema)
           }}
        else
          {:error, reason} -> stop_failed_start(process_id, retention, reason, options)
        end

      {:error, reason} ->
        _ = MemoryOnlyRetention.cleanup(retention)
        {:error, reason}
    end
  end

  defp stop_failed_start(process_id, retention, reason, options) do
    _ = api(options).kill(process_id, api_options(options))
    _ = api(options).prune(process_id, api_options(options))
    _ = MemoryOnlyRetention.cleanup(retention)
    {:error, reason}
  end

  defp process_spec(profile, launch, retention, schema) do
    %{
      executable: launch.executable,
      argv: profile.argv ++ ["--output-schema", schema.path, "-"],
      cwd: launch.workspace_path,
      env: launch.environment,
      env_mode: :replace,
      stdin: true,
      pty: false,
      runtime_timeout_ms: launch.limits.wall_ms,
      idle_timeout_ms: launch.limits.idle_ms,
      metadata: %{
        run_id: launch.run_id,
        provider: :codex,
        deployment_class: :developer_local,
        context_digest: launch.context_digest,
        output_schema_digest: schema.digest,
        adapter_release_digest: CodexRelease.digest()
      },
      retention: retention.retention
    }
  end

  defp validate_launch(launch) do
    with true <- Map.keys(launch) |> Enum.sort() == Enum.sort(@launch_keys),
         :developer_local <- launch[:deployment_class],
         true <- launch[:explicit_opt_in] == true,
         false <- launch[:managed_eligible],
         true <- bounded_prompt?(launch[:prompt]),
         true <- is_binary(launch[:run_id]) and byte_size(launch.run_id) in 1..128,
         true <- is_binary(launch[:workspace_path]) and File.dir?(launch.workspace_path),
         true <- is_binary(launch[:executable]) and Path.type(launch.executable) == :absolute,
         true <- launch[:executable_digest] == "sha256:" <> CodexRelease.executable_sha256(),
         :ok <- validate_environment(launch[:environment], launch.prompt),
         :ok <- validate_limits(launch[:limits]),
         true <- launch[:cli_version] == CodexRelease.cli_version(),
         true <- launch[:provider_version] == CodexRelease.model(),
         true <- valid_digest?(launch[:context_digest]),
         %DateTime{} <- launch[:occurred_at] do
      :ok
    else
      _invalid -> invalid(:codex_process_launch)
    end
  end

  defp bounded_prompt?(prompt)
       when is_binary(prompt) and byte_size(prompt) in 1..@max_prompt_bytes,
       do: String.trim(prompt) != "" and not secret?(prompt)

  defp bounded_prompt?(_prompt), do: false

  defp validate_environment(environment, prompt) when is_map(environment) do
    if map_size(environment) > 0 and
         Enum.all?(environment, fn {name, value} ->
           is_binary(name) and name in @environment_names and is_binary(value) and
             byte_size(value) in 1..1_024 and not String.contains?(value, prompt) and
             not secret?(value)
         end) and Map.has_key?(environment, "PATH") and Map.has_key?(environment, "HOME") and
         Map.has_key?(environment, "TMPDIR") do
      :ok
    else
      :error
    end
  end

  defp validate_environment(_environment, _prompt), do: :error

  defp validate_limits(%{wall_ms: wall_ms, idle_ms: idle_ms})
       when wall_ms in 1..3_600_000 and idle_ms in 1..3_600_000 and idle_ms <= wall_ms,
       do: :ok

  defp validate_limits(_limits), do: :error

  defp write_schema(retention, profile) do
    path = Path.join(retention.root, "codex-output.schema.json")
    encoded = Jason.encode!(profile.output_schema)
    digest = CodexRelease.output_schema_digest()

    with true <- digest == profile.output_schema_digest,
         :ok <- File.write(path, encoded <> "\n", [:binary, :exclusive]),
         :ok <- File.chmod(path, 0o600) do
      {:ok, %{path: path, digest: digest}}
    else
      _invalid -> invalid(:codex_output_schema)
    end
  rescue
    _error -> invalid(:codex_output_schema)
  end

  defp receipt(info, normalized) do
    state = normalized_state(info[:state], normalized)
    result = normalized.result

    {:ok,
     %{
       state: state,
       observations: normalized.observations,
       usage:
         normalized.usage
         |> Map.put(:observation_completeness, :partial)
         |> maybe_put_result(result),
       workspace_digest: nil,
       candidate_diff_digest: nil,
       artifact_iris: []
     }}
  end

  defp normalized_state(state, normalized) when state in [:starting, :running, :stopping],
    do: if(normalized.failed?, do: :failed, else: :running)

  defp normalized_state(:exited, %{failed?: true}), do: :failed
  defp normalized_state(:exited, %{result: %{classification: :failure}}), do: :failed
  defp normalized_state(:exited, %{result: nil}), do: :failed
  defp normalized_state(:exited, _normalized), do: :completed

  defp normalized_state(state, _normalized) when state in [:failed, :cancelled, :timed_out],
    do: state

  defp normalized_state(_state, _normalized), do: :failed

  defp maybe_put_result(usage, nil), do: usage

  defp maybe_put_result(usage, result) do
    usage
    |> Map.put(:result_classification, result.classification)
    |> Map.put(:summary_digest, result.summary_digest)
  end

  defp valid_handle(%{run_id: run_id, runtime_ref: process_id, event_cursor: cursor})
       when is_binary(run_id) and is_binary(process_id) and is_integer(cursor) and cursor >= 0,
       do: :ok

  defp valid_handle(_handle), do: :error

  defp observation(sequence, type, occurred_at, payload) do
    %{
      sequence: sequence,
      type: type,
      occurred_at: occurred_at,
      payload_digest: digest(payload),
      tool_ref: nil
    }
  end

  defp launch_digest(spec, schema) do
    spec
    |> Map.drop([:env])
    |> Map.put(:environment_names, spec.env |> Map.keys() |> Enum.sort())
    |> Map.put(:output_schema_digest, schema.digest)
    |> digest()
  end

  defp retention_key(run_id), do: sha256(run_id)
  defp retention_base(options), do: Keyword.get(options, :retention_base, System.tmp_dir!())
  defp api(options), do: Keyword.get(options, :process_api, JidoHarnessProcessAPI)
  defp api_options(options), do: Keyword.get(options, :process_api_options, [])
  defp clock(options), do: Keyword.get(options, :clock, &DateTime.utc_now/0)

  defp valid_digest?(value) when is_binary(value), do: Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp valid_digest?(_value), do: false

  defp secret?(value) when is_binary(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp secret?(_value), do: false

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
