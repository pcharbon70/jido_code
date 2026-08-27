defmodule JidoCode.Factory.DelegatedCancellationSequence do
  @moduledoc "Executes the mandatory delegated cancellation order after graph commitment."

  alias JidoCode.Factory.AdapterError

  @steps ~w[permit_revocation adapter_cancel namespace_kill workspace_cleanup late_output_rejection terminal_accounting]a

  @spec execute(term(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def execute(command, correlation, callbacks)
      when is_map(correlation) and is_list(callbacks) do
    commit = Keyword.get(callbacks, :graph_intent)

    with :ok <- correlation(correlation),
         true <- is_function(commit, 1),
         {:ok, graph_receipt} <- safe_call(commit, command),
         true <- graph_receipt[:outcome] in [:committed, :idempotent],
         true <- Enum.all?(@steps, &is_function(Keyword.get(callbacks, &1), 1)) do
      results =
        Enum.reduce(@steps, %{graph_intent: {:ok, graph_receipt}}, fn step, results ->
          Map.put(results, step, safe_call(Keyword.fetch!(callbacks, step), correlation))
        end)

      if complete?(results), do: {:ok, results}, else: {:error, results}
    else
      {:error, reason} ->
        {:error, %{graph_intent: {:error, reason}, runtime_effect: :not_started}}

      _invalid ->
        {:error,
         %{
           graph_intent: {:error, AdapterError.new(:invalid_input, :delegated_cancellation)},
           runtime_effect: :not_started
         }}
    end
  rescue
    _error ->
      {:error,
       %{
         graph_intent: {:error, AdapterError.new(:unavailable, :delegated_cancellation)},
         runtime_effect: :not_started
       }}
  end

  def execute(_command, _correlation, _callbacks),
    do: {:error, %{runtime_effect: :not_started}}

  defp correlation(value) do
    if is_binary(value[:attempt_iri]) and is_binary(value[:lease_iri]) and
         is_integer(value[:fencing_token]) and value.fencing_token > 0,
       do: :ok,
       else: :error
  end

  defp safe_call(callback, value) do
    case callback.(value) do
      {:ok, receipt} when is_map(receipt) -> {:ok, receipt}
      {:error, reason} -> {:error, reason}
      _invalid -> {:error, AdapterError.new(:corrupt, :delegated_cancellation_step)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :delegated_cancellation_step)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :delegated_cancellation_step)}
  end

  defp complete?(results) do
    match?({:ok, %{status: :revoked}}, results.permit_revocation) and
      match?({:ok, _receipt}, results.adapter_cancel) and
      match?({:ok, %{namespace: :terminated}}, results.namespace_kill) and
      match?({:ok, %{status: :destroyed}}, results.workspace_cleanup) and
      match?({:ok, %{late_results: :rejected}}, results.late_output_rejection) and
      match?(
        {:ok, %{outcome: outcome}} when outcome in [:committed, :idempotent],
        results.terminal_accounting
      )
  end
end
