defmodule JidoCode.Knowledge.Control.WorkProjection do
  @moduledoc """
  Decodes bounded reviewed-query results into attributable work views.

  The view retains graph and dataset revisions and never becomes an alternate
  persisted work resource.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @queries ~w[
    desired_outcome_description goal_neighborhood task_dag work_blockers
    work_transition_history work_lens plan_context
  ]a
  @hard_max_tasks 100
  @hard_max_history 200
  @hard_max_relations 500

  @spec build(QueryResult.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(%QueryResult{} = result, context) when is_map(context) do
    graph = context[:graph_iri]

    with true <- result.query_name in @queries,
         true <- result.query_version == QueryCatalog.control_loop_version(),
         {:ok, family} <- GraphRegistry.identify(graph),
         true <- family in [:factory_policy, :repository_control],
         true <- Map.keys(result.graph_revisions) == [graph],
         revision when is_integer(revision) and revision > 0 <- result.graph_revisions[graph],
         :ok <- optional_resource(context[:resource_iri]),
         {:ok, limits} <- limits(context),
         {:ok, data} <- decode(result.query_name, result.data, limits),
         true <- json_safe?(data) do
      {:ok,
       %{
         lens: Atom.to_string(result.query_name),
         data: data,
         receipt: %{
           graph_iri: graph,
           graph_revision: revision,
           dataset_revision: result.dataset_revision,
           ontology_version: result.ontology_version,
           query_version: result.query_version,
           complete?: result.completeness.complete?,
           freshness: Atom.to_string(result.freshness),
           truncated?: result.truncated?,
           warnings: Enum.map(result.warnings, &safe_warning/1),
           bounds: limits,
           evaluated_at: DateTime.to_iso8601(result.evaluated_at)
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:work_projection)
    end
  rescue
    _error -> invalid(:work_projection)
  end

  def build(_result, _context), do: invalid(:work_projection)

  defp decode(:task_dag, rows, limits) when is_list(rows) do
    tasks =
      rows
      |> Enum.group_by(&term_value(&1["task"]))
      |> Enum.reject(fn {task, _rows} -> is_nil(task) end)
      |> Enum.map(fn {task, task_rows} ->
        %{
          iri: task,
          kind: one_value(task_rows, "kind"),
          dependencies: values(task_rows, "dependency"),
          blocks: values(task_rows, "blocker"),
          alternatives: values(task_rows, "alternative"),
          capabilities: values(task_rows, "capability"),
          artifacts: values(task_rows, "artifact")
        }
      end)
      |> Enum.sort_by(& &1.iri)

    if length(tasks) <= limits.task_count,
      do: {:ok, %{tasks: tasks, task_count: length(tasks)}},
      else: invalid(:work_projection_task_bound)
  end

  defp decode(:work_transition_history, rows, limits) when is_list(rows) do
    history =
      rows
      |> Enum.map(fn row ->
        %{
          transition_iri: term_value(row["transition"]),
          state_iri: term_value(row["state"]),
          revision: term_value(row["revision"]),
          predecessor_iri: term_value(row["predecessor"]),
          actor_iri: term_value(row["actor"]),
          cause_iri: term_value(row["cause"]),
          reason: term_value(row["reason"]),
          recorded_at: iso_value(row["recorded"])
        }
      end)
      |> Enum.uniq()
      |> Enum.sort_by(& &1.revision)

    with true <- length(history) <= limits.history,
         :ok <- contiguous_history(history) do
      {:ok, history}
    else
      _invalid -> invalid(:work_projection_history)
    end
  end

  defp decode(:work_lens, rows, limits) when is_list(rows) do
    values =
      rows
      |> Enum.filter(&is_nil(term_value(&1["successor"])))
      |> Enum.map(fn row ->
        %{
          work_iri: term_value(row["work"]),
          transition_iri: term_value(row["transition"]),
          revision: term_value(row["revision"]),
          state_iri: term_value(row["state"])
        }
      end)
      |> Enum.uniq()
      |> Enum.sort_by(& &1.work_iri)

    if length(values) <= limits.task_count,
      do: {:ok, values},
      else: invalid(:work_projection_lens)
  end

  defp decode(:plan_context, rows, limits) when is_list(rows) do
    references =
      rows
      |> Enum.map(fn row ->
        %{
          graph_iri: term_value(row["inputGraphIri"]),
          revision: term_value(row["inputRevision"])
        }
      end)
      |> Enum.reject(&is_nil(&1.graph_iri))
      |> Enum.uniq()
      |> Enum.sort_by(& &1.graph_iri)

    if length(references) <= limits.graph_count do
      {:ok,
       %{
         source_graph_iri: one_value(rows, "sourceGraphIri"),
         source_revision: one_value(rows, "sourceRevision"),
         snapshot_iri: one_value(rows, "snapshot"),
         planner_iri: one_value(rows, "planner"),
         planner_version: one_value(rows, "plannerVersion"),
         verification_strategy: one_value(rows, "strategy"),
         assumptions: values(rows, "assumption"),
         expected_effects: values(rows, "effect"),
         input_graph_revisions: references
       }}
    else
      invalid(:work_projection_graph_bound)
    end
  end

  defp decode(name, rows, limits)
       when name in [:desired_outcome_description, :goal_neighborhood, :work_blockers] and
              is_list(rows) do
    projected =
      rows
      |> Enum.map(fn row -> Map.new(row, fn {key, value} -> {key, term_value(value)} end) end)
      |> Enum.uniq()

    if length(projected) <= limits.relations,
      do: {:ok, Enum.sort_by(projected, &:erlang.term_to_binary(&1, [:deterministic]))},
      else: invalid(:work_projection_relation_bound)
  end

  defp decode(_name, _rows, _limits), do: invalid(:work_projection_data)

  defp limits(context) do
    task_count = Map.get(context, :task_limit, @hard_max_tasks)
    history = Map.get(context, :history_limit, @hard_max_history)
    relations = Map.get(context, :relation_limit, @hard_max_relations)
    graph_count = Map.get(context, :graph_limit, 20)

    if task_count in 1..@hard_max_tasks and history in 1..@hard_max_history and
         relations in 1..@hard_max_relations and graph_count in 1..20 do
      {:ok,
       %{task_count: task_count, history: history, relations: relations, graph_count: graph_count}}
    else
      invalid(:work_projection_bounds)
    end
  end

  defp contiguous_history([]), do: :ok

  defp contiguous_history([first | rest]) do
    if first.revision == 0 and is_nil(first.predecessor_iri) and complete_history_row?(first) do
      Enum.reduce_while(rest, {:ok, first}, fn current, {:ok, prior} ->
        if complete_history_row?(current) and current.revision == prior.revision + 1 and
             current.predecessor_iri == prior.transition_iri do
          {:cont, {:ok, current}}
        else
          {:halt, :error}
        end
      end)
      |> case do
        {:ok, _endpoint} -> :ok
        :error -> invalid(:work_projection_history)
      end
    else
      invalid(:work_projection_history)
    end
  end

  defp complete_history_row?(row) do
    is_binary(row.transition_iri) and is_binary(row.state_iri) and is_integer(row.revision) and
      is_binary(row.actor_iri) and is_binary(row.cause_iri) and is_binary(row.reason)
  end

  defp one_value(rows, key) do
    case values(rows, key) do
      [value] -> value
      [] -> nil
      _ambiguous -> :ambiguous
    end
  end

  defp values(rows, key) do
    rows
    |> Enum.map(&term_value(&1[key]))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
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
  defp term_value(value), do: value

  defp iso_value(%{value: %DateTime{} = value}), do: DateTime.to_iso8601(value)
  defp iso_value(%{value: value}), do: value
  defp iso_value(value), do: value

  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: ResourceIdentity.validate(value)

  defp safe_warning(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_warning(value) when is_binary(value), do: value
  defp safe_warning(value), do: inspect(value, limit: 20, printable_limit: 200)

  defp json_safe?(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: true

  defp json_safe?(value) when is_atom(value), do: true
  defp json_safe?(value) when is_list(value), do: Enum.all?(value, &json_safe?/1)

  defp json_safe?(value) when is_map(value) and not is_struct(value),
    do:
      Enum.all?(value, fn {key, item} -> (is_atom(key) or is_binary(key)) and json_safe?(item) end)

  defp json_safe?(_value), do: false
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
