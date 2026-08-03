defmodule JidoCode.Knowledge.Control.ReconciliationDiscovery do
  @moduledoc """
  Reviewed-query discovery of graph-visible reconciliation candidates.
  """

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Control.ReconciliationProjection
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Repositories.EnrollmentTransition

  @spec active_scopes(AuthorityContext.t(), String.t(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def active_scopes(authority, factory_scope, catalog_graph, options \\ [])

  def active_scopes(%AuthorityContext{} = authority, factory_scope, catalog_graph, options) do
    query_runner = Keyword.get(options, :query_runner, QueryRunner)

    with {:ok, result} <-
           QueryRunner.execute(
             :active_reconciliation_scopes,
             QueryCatalog.reconciliation_version(),
             %{graph: catalog_graph},
             authority,
             factory_scope,
             server: query_runner,
             evaluated_at: Keyword.get(options, :evaluated_at, DateTime.utc_now())
           ),
         {:ok, projection} <-
           ReconciliationProjection.build(result, %{graph_iri: catalog_graph}) do
      resolve_active(
        projection.data,
        authority,
        factory_scope,
        catalog_graph,
        query_runner,
        Keyword.get(options, :evaluated_at, DateTime.utc_now())
      )
    end
  end

  def active_scopes(_authority, _factory_scope, _catalog_graph, _options),
    do: {:error, Error.new(:invalid_input, :reconciliation_discovery)}

  defp resolve_active(candidates, authority, scope, graph, query_runner, evaluated_at) do
    results =
      Task.async_stream(
        candidates,
        &resolve_candidate(&1, authority, scope, graph, query_runner, evaluated_at),
        max_concurrency: 8,
        ordered: true,
        timeout: :infinity
      )
      |> Enum.to_list()

    if Enum.all?(results, &(match?({:ok, {:ok, _candidate}}, &1) or match?({:ok, :inactive}, &1))) do
      active =
        results
        |> Enum.flat_map(fn
          {:ok, {:ok, candidate}} -> [candidate]
          {:ok, :inactive} -> []
        end)

      {:ok, active}
    else
      {:error, Error.new(:unavailable, :reconciliation_discovery)}
    end
  end

  defp resolve_candidate(candidate, authority, scope, graph, query_runner, evaluated_at) do
    with {:ok, history} <-
           QueryRunner.execute(
             :enrollment_history,
             QueryCatalog.reconciliation_version(),
             %{graph: graph, resource: candidate.enrollment_iri},
             authority,
             scope,
             server: query_runner,
             evaluated_at: evaluated_at
           ),
         {:ok, endpoint} <- history_endpoint(history.data) do
      if endpoint.state == :active,
        do: {:ok, Map.merge(candidate, endpoint)},
        else: :inactive
    end
  end

  defp history_endpoint(rows) when is_list(rows) and rows != [] do
    transitions =
      rows
      |> Enum.map(fn row ->
        with transition when is_binary(transition) <- term_value(row["transition"]),
             state_iri when is_binary(state_iri) <- term_value(row["state"]),
             {:ok, state} <- EnrollmentTransition.state_from_iri(state_iri),
             revision when is_integer(revision) <- term_value(row["revision"]) do
          {:ok,
           %{
             transition_iri: transition,
             state: state,
             revision: revision,
             predecessor_iri: term_value(row["predecessor"])
           }}
        else
          _invalid -> :error
        end
      end)
      |> Enum.uniq()

    with true <- Enum.all?(transitions, &match?({:ok, _transition}, &1)),
         ordered <-
           transitions |> Enum.map(fn {:ok, value} -> value end) |> Enum.sort_by(& &1.revision),
         :ok <- contiguous?(ordered) do
      {:ok, List.last(ordered)}
    else
      _invalid -> {:error, Error.new(:corrupt, :reconciliation_enrollment_history)}
    end
  end

  defp history_endpoint(_rows),
    do: {:error, Error.new(:corrupt, :reconciliation_enrollment_history)}

  defp contiguous?([first | rest]) do
    if first.revision == 0 and first.state == :proposed and is_nil(first.predecessor_iri) do
      Enum.reduce_while(rest, {:ok, first}, fn current, {:ok, prior} ->
        if current.revision == prior.revision + 1 and
             current.predecessor_iri == prior.transition_iri do
          {:cont, {:ok, current}}
        else
          {:halt, :error}
        end
      end)
      |> case do
        {:ok, _endpoint} -> :ok
        :error -> :error
      end
    else
      :error
    end
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
  defp term_value(nil), do: nil
end
