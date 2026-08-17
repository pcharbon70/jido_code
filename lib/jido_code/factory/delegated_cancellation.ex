defmodule JidoCode.Factory.DelegatedCancellation do
  @moduledoc "Commits cancellation before bounded adapter stop and independent worker destruction."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.ExecutionRuntime

  @spec cancel(term(), Request.t(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def cancel(command, %Request{} = request, cancellation, options)
      when is_map(cancellation) and is_list(options) do
    commit = Keyword.get(options, :commit)

    with true <- is_function(commit, 1),
         {:ok, receipt} <- commit.(command),
         true <- committed?(receipt),
         :ok <- cancellation_matches?(cancellation, request) do
      adapter_stop = bounded_adapter_stop(request, cancellation, options)
      namespace_kill = invoke_outer(:kill_namespace, request, cancellation, options)
      destruction = invoke_outer(:destroy, request, cancellation, options)

      result = %{
        cancellation_receipt: receipt,
        adapter_stop: adapter_stop,
        namespace_kill: namespace_kill,
        destruction: destruction
      }

      if contained?(namespace_kill) and destroyed?(destruction),
        do: {:ok, result},
        else: {:error, result}
    else
      {:error, reason} -> {:error, %{commit_error: reason, runtime_effect: :not_started}}
      _invalid -> {:error, %{operation: :delegated_cancellation, runtime_effect: :not_started}}
    end
  rescue
    _error -> {:error, %{operation: :delegated_cancellation, runtime_effect: :not_started}}
  end

  def cancel(_command, _request, _cancellation, _options),
    do: {:error, %{operation: :delegated_cancellation, runtime_effect: :not_started}}

  defp bounded_adapter_stop(request, cancellation, options) do
    adapter = Keyword.get(options, :adapter)
    runtime_options = Keyword.get(options, :runtime_options, [])
    timeout = Keyword.get(options, :adapter_stop_timeout_ms, 15_000)
    supervisor = Keyword.get(options, :task_supervisor, JidoCode.Factory.Model.StreamSupervisor)

    if is_atom(adapter) and is_integer(timeout) and timeout in 1..30_000 do
      task =
        Task.Supervisor.async_nolink(supervisor, fn ->
          ExecutionRuntime.cancel(adapter, request, cancellation, runtime_options)
        end)

      case Task.yield(task, timeout) do
        {:ok, result} ->
          result

        {:exit, _reason} ->
          {:error, AdapterError.new(:unavailable, :delegated_adapter_stop)}

        nil ->
          _ = Task.shutdown(task, :brutal_kill)
          {:error, AdapterError.new(:timeout, :delegated_adapter_stop)}
      end
    else
      {:error, AdapterError.new(:invalid_input, :delegated_adapter_stop)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :delegated_adapter_stop)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :delegated_adapter_stop)}
  end

  defp invoke_outer(operation, request, cancellation, options) do
    outer_options = Keyword.get(options, :outer_options, [])

    case Keyword.get(options, :outer_worker) do
      {module, worker} when is_atom(module) ->
        if Code.ensure_loaded?(module) and function_exported?(module, operation, 4) do
          case apply(module, operation, [worker, request, cancellation, outer_options]) do
            {:ok, receipt} when is_map(receipt) -> {:ok, receipt}
            {:error, %AdapterError{} = error} -> {:error, error}
            _invalid -> {:error, AdapterError.new(:corrupt, operation)}
          end
        else
          {:error, AdapterError.new(:unavailable, operation)}
        end

      _invalid ->
        {:error, AdapterError.new(:invalid_input, operation)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, operation)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, operation)}
  end

  defp cancellation_matches?(cancellation, request) do
    if cancellation[:attempt_iri] == request.attempt_iri and
         cancellation[:lease_iri] == request.lease_iri and
         cancellation[:fencing_token] == request.fencing_token and
         cancellation[:reason] in [:cancelled, :lease_expired, :superseded] do
      :ok
    else
      :error
    end
  end

  defp committed?(%{outcome: outcome}) when outcome in [:committed, :idempotent], do: true
  defp committed?(_receipt), do: false

  defp contained?({:ok, %{namespace: :terminated, within_bound: true}}), do: true
  defp contained?(_result), do: false
  defp destroyed?({:ok, %{status: :destroyed}}), do: true
  defp destroyed?(_result), do: false
end
