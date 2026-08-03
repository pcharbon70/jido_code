defmodule JidoCode.Integrations.MemorySandbox do
  @moduledoc """
  Disposable reference sandbox with no host filesystem or network access.

  Tool implementations are injected functions and all work material remains in
  the adapter process. This adapter is suitable for deterministic workflows and
  tests; host command execution belongs in a separately hardened adapter.
  """

  @behaviour JidoCode.Factory.Ports.Sandbox

  use Agent

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.Sandbox.Event
  alias JidoCode.Factory.Sandbox.Request

  @type runner :: (map(), map() -> map())

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(options \\ []) do
    runners = Keyword.get(options, :runners, %{})
    clock = Keyword.get(options, :clock, &DateTime.utc_now/0)
    Agent.start_link(fn -> %{clock: clock, runners: runners, sandboxes: %{}} end)
  end

  @impl true
  def provision(adapter, %Request{} = request, _options) do
    update(adapter, request, :provision, fn state, key ->
      if Map.has_key?(state.sandboxes, key) do
        {:ok, state, %{status: :ready, replayed?: true}}
      else
        sandbox = %{status: :ready, files: %{}, output_bytes: 0, cancelled?: false}
        {:ok, put_in(state, [:sandboxes, key], sandbox), %{status: :ready, replayed?: false}}
      end
    end)
  end

  @impl true
  def materialize(adapter, %Request{} = request, snapshot, _options) when is_map(snapshot) do
    update(adapter, request, :materialize, fn state, key ->
      with %{status: :ready} = sandbox <- get_in(state, [:sandboxes, key]),
           true <- snapshot[:snapshot_iri] == request.base_snapshot_iri,
           files when is_map(files) <- snapshot[:files],
           :ok <- validate_files(files, request, :materialize),
           true <- total_bytes(files) <= request.limits.disk_bytes do
        updated = %{sandbox | files: files}

        {:ok, put_in(state, [:sandboxes, key], updated),
         %{status: :materialized, file_count: map_size(files), content_digest: digest(files)}}
      else
        nil -> {:error, state, AdapterError.new(:conflict, :materialize)}
        false -> {:error, state, AdapterError.new(:unauthorized, :materialize)}
        {:error, %AdapterError{} = error} -> {:error, state, error}
        _invalid -> {:error, state, AdapterError.new(:invalid_input, :materialize)}
      end
    end)
  end

  def materialize(_adapter, _request, _snapshot, _options),
    do: {:error, AdapterError.new(:invalid_input, :materialize)}

  @impl true
  def execute(adapter, %Request{} = request, command, _options) when is_map(command) do
    with :ok <- validate_command(command, request),
         {:ok, runner} <- runner(adapter, command.name),
         {:ok, sandbox} <- sandbox(adapter, request),
         false <- sandbox.cancelled?,
         {:ok, result} <- run(runner, command, sandbox.files, request.limits.timeout_ms),
         {:ok, normalized} <- normalize_result(result, request),
         :ok <- validate_files(normalized.writes, request, :execute),
         files = Map.merge(sandbox.files, normalized.writes),
         true <- total_bytes(files) <= request.limits.disk_bytes,
         :ok <- store_result(adapter, request, files, normalized) do
      event(adapter, request, :execute, normalized.outcome, %{
        status: normalized.status,
        exit_status: normalized.exit_status,
        stdout: normalized.stdout,
        stderr: normalized.stderr,
        usage: normalized.usage,
        content_digest: digest(files)
      })
    else
      true -> {:error, AdapterError.new(:conflict, :execute)}
      false -> {:error, AdapterError.new(:unavailable, :execute)}
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:invalid_input, :execute)}
    end
  end

  def execute(_adapter, _request, _command, _options),
    do: {:error, AdapterError.new(:invalid_input, :execute)}

  @impl true
  def inspect(adapter, %Request{} = request, _options) do
    with {:ok, sandbox} <- sandbox(adapter, request) do
      event(adapter, request, :inspect, :success, %{
        status: sandbox.status,
        file_count: map_size(sandbox.files),
        cancelled?: sandbox.cancelled?
      })
    end
  end

  @impl true
  def cancel(adapter, %Request{} = request, _options) do
    update(adapter, request, :cancel, fn state, key ->
      case get_in(state, [:sandboxes, key]) do
        nil ->
          {:error, state, AdapterError.new(:conflict, :cancel)}

        sandbox ->
          updated = %{sandbox | cancelled?: true, status: :cancelled}
          {:ok, put_in(state, [:sandboxes, key], updated), %{status: :cancelled}}
      end
    end)
  end

  @impl true
  def collect(adapter, %Request{} = request, _options) do
    with {:ok, sandbox} <- sandbox(adapter, request) do
      event(adapter, request, :collect, :success, %{
        status: sandbox.status,
        file_count: map_size(sandbox.files),
        byte_count: total_bytes(sandbox.files),
        content_digest: digest(sandbox.files)
      })
    end
  end

  @impl true
  def destroy(adapter, %Request{} = request, _options) do
    update(adapter, request, :destroy, fn state, key ->
      {:ok, update_in(state, [:sandboxes], &Map.delete(&1, key)), %{status: :destroyed}}
    end)
  end

  defp validate_command(command, request) do
    args = command[:args]
    environment = command[:environment]

    cond do
      command[:name] not in request.command_allowlist ->
        {:error, AdapterError.new(:unauthorized, :execute)}

      command[:network] == true and request.limits.network == :deny ->
        {:error, AdapterError.new(:unauthorized, :execute)}

      not is_list(args) or length(args) > 100 or
          not Enum.all?(args, &(is_binary(&1) and byte_size(&1) <= 1_024)) ->
        {:error, AdapterError.new(:invalid_input, :execute)}

      not is_map(environment) or map_size(environment) > 100 or
          not Enum.all?(environment, fn {key, value} ->
            key in request.environment_allowlist and is_binary(value) and
                byte_size(value) <= 4_096
          end) ->
        {:error, AdapterError.new(:unauthorized, :execute)}

      Map.has_key?(command, :secret_values) ->
        {:error, AdapterError.new(:unauthorized, :execute)}

      true ->
        :ok
    end
  end

  defp validate_files(files, request, operation) do
    if map_size(files) <= 1_000 and
         Enum.all?(files, fn {path, content} ->
           allowed_path?(path, request.allowed_write_paths) and is_binary(content)
         end) do
      :ok
    else
      {:error, AdapterError.new(:unauthorized, operation)}
    end
  end

  defp allowed_path?(path, allowed) when is_binary(path) do
    normalized = String.replace(path, "\\", "/")

    normalized != "" and not String.starts_with?(normalized, "/") and
      not Enum.any?(String.split(normalized, "/"), &(&1 in ["", ".", ".."])) and
      Enum.any?(allowed, &(normalized == &1 or String.starts_with?(normalized, &1 <> "/")))
  end

  defp allowed_path?(_path, _allowed), do: false

  defp runner(adapter, name) do
    Agent.get(adapter, fn state -> Map.fetch(state.runners, name) end)
    |> case do
      {:ok, runner} when is_function(runner, 2) -> {:ok, runner}
      _missing -> {:error, AdapterError.new(:unavailable, :execute)}
    end
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :execute)}
  end

  defp sandbox(adapter, request) do
    Agent.get(adapter, &get_in(&1, [:sandboxes, runtime_key(request)]))
    |> case do
      nil -> {:error, AdapterError.new(:conflict, :sandbox_status)}
      sandbox -> {:ok, sandbox}
    end
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :sandbox_status)}
  end

  defp run(runner, command, files, timeout) do
    task = Task.async(fn -> runner.(Map.drop(command, [:secret_values]), files) end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} when is_map(result) -> {:ok, result}
      nil -> {:error, AdapterError.new(:timeout, :execute)}
      _failure -> {:error, AdapterError.new(:unavailable, :execute)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :execute)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :execute)}
  end

  defp normalize_result(result, request) do
    stdout = result[:stdout] || ""
    stderr = result[:stderr] || ""
    writes = result[:writes] || %{}
    usage = result[:usage] || %{}
    exit_status = result[:exit_status]

    with true <- is_binary(stdout) and is_binary(stderr),
         true <- byte_size(stdout) + byte_size(stderr) <= request.limits.output_bytes,
         false <- secret?(stdout) or secret?(stderr),
         true <- is_map(writes) and is_map(usage),
         true <- byte_size(:erlang.term_to_binary(usage, [:deterministic])) <= 4_096,
         true <- within_resource_limits?(usage, request.limits),
         status when is_integer(status) and status in 0..255 <- exit_status do
      {:ok,
       %{
         stdout: stdout,
         stderr: stderr,
         writes: writes,
         usage: usage,
         exit_status: status,
         status: if(status == 0, do: :completed, else: :failed),
         outcome: if(status == 0, do: :success, else: :failure)
       }}
    else
      false -> {:error, AdapterError.new(:corrupt, :execute)}
      _invalid -> {:error, AdapterError.new(:invalid_input, :execute)}
    end
  end

  defp store_result(adapter, request, files, result) do
    Agent.update(adapter, fn state ->
      key = runtime_key(request)
      sandbox = get_in(state, [:sandboxes, key])

      put_in(state, [:sandboxes, key], %{
        sandbox
        | files: files,
          status: result.status,
          output_bytes: byte_size(result.stdout) + byte_size(result.stderr)
      })
    end)
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :execute)}
  end

  defp update(adapter, request, operation, callback) do
    result =
      Agent.get_and_update(adapter, fn state ->
        case callback.(state, runtime_key(request)) do
          {:ok, updated, details} -> {{:ok, details, state.clock}, updated}
          {:error, updated, error} -> {{:error, error}, updated}
        end
      end)

    case result do
      {:ok, details, clock} -> build_event(request, operation, :success, details, clock)
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, operation)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, operation)}
  end

  defp event(adapter, request, operation, outcome, details) do
    clock = Agent.get(adapter, & &1.clock)
    build_event(request, operation, outcome, details, clock)
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, operation)}
  end

  defp build_event(request, operation, outcome, details, clock) do
    Event.new(%{
      attempt_iri: request.execution.attempt_iri,
      operation: operation,
      outcome: outcome,
      occurred_at: clock.(),
      provider_ref: runtime_key(request),
      details: details
    })
  end

  defp runtime_key(%Request{execution: %ExecutionRequest{} = request}),
    do: ExecutionRequest.runtime_key(request)

  defp total_bytes(files),
    do:
      Enum.reduce(files, 0, fn {path, content}, total ->
        total + byte_size(path) + byte_size(content)
      end)

  defp within_resource_limits?(usage, limits) do
    with cpu when is_integer(cpu) and cpu >= 0 <- usage[:cpu_ms],
         memory when is_integer(memory) and memory >= 0 <- usage[:memory_bytes],
         true <- cpu <= limits.cpu_ms,
         true <- memory <= limits.memory_bytes,
         disk when is_nil(disk) or (is_integer(disk) and disk >= 0) <- usage[:disk_bytes],
         true <- is_nil(disk) or disk <= limits.disk_bytes do
      true
    else
      _invalid -> false
    end
  end

  defp secret?(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
