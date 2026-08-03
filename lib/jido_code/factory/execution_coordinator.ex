defmodule JidoCode.Factory.ExecutionCoordinator do
  @moduledoc "Commits attempt authority before dispatching any runtime effect."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.ExecutionRuntime

  @spec start(term(), Request.t(), keyword()) :: tuple()
  def start(command, %Request{} = request, options) when is_list(options) do
    commit = Keyword.get(options, :commit)
    adapter = Keyword.get(options, :adapter)
    failure_recorder = Keyword.get(options, :failure_recorder)
    runtime_options = Keyword.get(options, :runtime_options, [])

    with true <- is_function(commit, 1),
         true <- is_atom(adapter),
         true <- is_function(failure_recorder, 2),
         {:ok, receipt} <- commit.(command),
         true <- effect_authorized?(receipt) do
      case ExecutionRuntime.start(adapter, request, runtime_options) do
        {:ok, event} ->
          {:ok, %{receipt: receipt, event: event}}

        {:error, %AdapterError{kind: :timeout} = error} ->
          {:recover, %{receipt: receipt, error: error, action: :query_runtime_status}}

        {:error, %AdapterError{} = error} ->
          case failure_recorder.(error, receipt) do
            {:ok, failure_receipt} ->
              {:error,
               %{receipt: receipt, runtime_error: error, failure_receipt: failure_receipt}}

            {:error, reason} ->
              {:error, %{receipt: receipt, runtime_error: error, failure_error: reason}}
          end
      end
    else
      {:ok, receipt} -> {:error, %{receipt: receipt, runtime_effect: :not_started}}
      {:error, reason} -> {:error, %{commit_error: reason, runtime_effect: :not_started}}
      _invalid -> {:error, %{operation: :execution_coordinator, runtime_effect: :not_started}}
    end
  rescue
    _error -> {:error, %{operation: :execution_coordinator, runtime_effect: :not_started}}
  catch
    :exit, _reason -> {:error, %{operation: :execution_coordinator, runtime_effect: :not_started}}
  end

  def start(_command, _request, _options),
    do: {:error, %{operation: :execution_coordinator, runtime_effect: :not_started}}

  defp effect_authorized?(%{outcome: outcome}) when outcome in [:committed, :idempotent], do: true
  defp effect_authorized?(_receipt), do: false
end
