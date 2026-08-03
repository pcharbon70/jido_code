defmodule JidoCode.Knowledge.Queries.ExecutionRecovery do
  @moduledoc "Public decoder for bounded execution recovery discovery results."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult

  @lease_executing "https://jido.run/ontology/concept/LeaseExecuting"

  @spec candidates(term(), String.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def candidates(%QueryResult{data: rows} = result, graph)
      when is_binary(graph) and is_list(rows) and length(rows) <= 200 do
    with {:ok, :repository_control} <- GraphRegistry.identify(graph),
         true <- result.query_name == :active_attempts,
         true <- result.query_version == QueryCatalog.execution_version(),
         true <- result.truncated? == false,
         true <- Map.keys(result.graph_revisions) == [graph],
         revision when is_integer(revision) and revision > 0 <- result.graph_revisions[graph] do
      decode_rows(rows)
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def candidates(_result, _graph), do: invalid()

  defp decode_rows(rows) do
    decoded = Enum.map(rows, &candidate/1)

    if Enum.all?(decoded, &match?({:ok, _}, &1)) do
      candidates = decoded |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
      {:ok, candidates}
    else
      invalid()
    end
  end

  defp candidate(row) when is_map(row) do
    with attempt when is_binary(attempt) <- value(row, "attempt"),
         lease when is_binary(lease) <- value(row, "lease"),
         task when is_binary(task) <- value(row, "task"),
         @lease_executing <- value(row, "state"),
         fence when is_integer(fence) and fence > 0 <- value(row, "fence"),
         {:ok, valid_to} <- date_time(value(row, "validTo")),
         successor <- value(row, "successor"),
         true <- is_nil(successor) or is_binary(successor),
         successor_state <- value(row, "successorState"),
         true <- is_nil(successor_state) or is_binary(successor_state),
         {:ok, run_graph} <- ExecutionGraph.run_graph(attempt) do
      {:ok,
       %{
         attempt_iri: attempt,
         lease_iri: lease,
         task_iri: task,
         fencing_token: fence,
         valid_to: valid_to,
         lease_current?: is_nil(successor),
         lease_successor_iri: successor,
         lease_successor_state_iri: successor_state,
         run_graph_iri: run_graph
       }}
    else
      _invalid -> invalid()
    end
  end

  defp candidate(_row), do: invalid()

  defp value(row, key) do
    term = row[key] || row[existing_atom(key)]
    term_value(term)
  end

  defp term_value(%{
         type: :literal,
         value: value,
         datatype: "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
       })
       when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer >= 0 -> integer
      _invalid -> value
    end
  end

  defp term_value(%{value: value}), do: value
  defp term_value(value), do: value

  defp date_time(%DateTime{} = value), do: {:ok, value}

  defp date_time(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, instant, _offset} -> {:ok, instant}
      _invalid -> :error
    end
  end

  defp date_time(_value), do: :error

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> :__unknown__
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :execution_recovery_candidates)}
end
