defmodule JidoCode.Knowledge.Repositories.Projection do
  @moduledoc """
  Coherent repository catalog projection assembled from reviewed query results.

  The projection preserves all locator and transition observations. It blocks
  admission when the accepted transition chain is missing or ambiguous rather
  than flattening contradictory graph facts into one mutable record.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.Repositories.EnrollmentTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @jf "https://jido.run/ontology/factory#"
  @max_results 250

  @spec build(String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(repository_iri, results) when is_map(results) do
    repository = results[:repository]
    enrollments = results[:enrollments]
    histories = Map.get(results, :histories, [])
    locators = Map.get(results, :locators, [])
    all_results = [repository, enrollments | histories ++ locators]

    with :ok <- ResourceIdentity.validate(repository_iri),
         true <- match?(%QueryResult{query_name: :repository_description}, repository),
         true <- match?(%QueryResult{query_name: :active_enrollment}, enrollments),
         true <- Enum.all?(histories, &match?(%QueryResult{query_name: :enrollment_history}, &1)),
         true <-
           Enum.all?(locators, &match?(%QueryResult{query_name: :repository_description}, &1)),
         true <- length(all_results) <= @max_results,
         {:ok, revision} <- coherent_revision(all_results),
         {:ok, graph_revisions} <- coherent_graph_revisions(all_results) do
      locator_iris = relation_objects(repository.data, repository_iri, @jf <> "locatedBy")
      enrollment_rows = group_rows(enrollments.data, "enrollment")
      history_rows = histories |> Enum.flat_map(& &1.data) |> group_rows("enrollment")

      projected_enrollments =
        enrollment_rows
        |> Enum.map(fn {enrollment_iri, rows} ->
          project_enrollment(enrollment_iri, rows, Map.get(history_rows, enrollment_iri, []))
        end)
        |> Enum.sort_by(& &1.iri)

      warnings =
        all_results
        |> Enum.flat_map(& &1.warnings)
        |> Enum.map(&safe_warning/1)
        |> Kernel.++(Enum.flat_map(projected_enrollments, & &1.warnings))
        |> Enum.uniq()

      {:ok,
       %{
         repository_iri: repository_iri,
         locators: project_locators(locator_iris, locators),
         enrollments: projected_enrollments,
         latest_snapshot_refs: [],
         warnings: warnings,
         receipt: %{
           query_version: repository.query_version,
           dataset_revision: revision,
           graph_revisions: graph_revisions,
           ontology_version: repository.ontology_version,
           evaluated_at: DateTime.to_iso8601(repository.evaluated_at),
           complete?: Enum.all?(all_results, & &1.completeness.complete?),
           truncated?: Enum.any?(all_results, & &1.truncated?)
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_projection)
    end
  rescue
    _error -> invalid(:repository_projection)
  end

  def build(_repository_iri, _results), do: invalid(:repository_projection)

  defp project_enrollment(enrollment_iri, rows, history_rows) do
    policy_refs =
      rows
      |> Enum.flat_map(&iri_values(&1, "policy"))
      |> Kernel.++(Enum.flat_map(history_rows, &iri_values(&1, "policy")))
      |> Enum.uniq()
      |> Enum.sort()

    locator_refs =
      rows
      |> Enum.flat_map(&iri_values(&1, "locator"))
      |> Kernel.++(Enum.flat_map(history_rows, &iri_values(&1, "locator")))
      |> Enum.uniq()
      |> Enum.sort()

    case resolve_history(history_rows) do
      {:ok, current} ->
        %{
          iri: enrollment_iri,
          state: Atom.to_string(current.state),
          state_iri: EnrollmentTransition.state_iri(current.state),
          revision: current.revision,
          transition_iri: current.transition_iri,
          admission: current.state == :active,
          policy_refs: policy_refs,
          locator_refs: locator_refs,
          validity: validity(rows),
          history: history_projection(history_rows),
          warnings: []
        }

      {:error, warning} ->
        %{
          iri: enrollment_iri,
          state: "ambiguous",
          state_iri: nil,
          revision: nil,
          transition_iri: nil,
          admission: false,
          policy_refs: policy_refs,
          locator_refs: locator_refs,
          validity: validity(rows),
          history: history_projection(history_rows),
          warnings: [warning]
        }
    end
  end

  defp project_locators(locator_iris, results) do
    facts = results |> Enum.flat_map(& &1.data) |> Enum.group_by(&term_value(&1.subject))

    locator_iris
    |> Enum.map(fn iri ->
      statements = Map.get(facts, iri, [])

      %{
        iri: iri,
        canonical_values: predicate_values(statements, @jf <> "canonicalLocator"),
        observed_addresses: predicate_values(statements, @jf <> "locatorAddress"),
        states: predicate_values(statements, @jf <> "locatorState"),
        observed_at: predicate_values(statements, @jf <> "sourceObservedAt"),
        relationships:
          Enum.flat_map(statements, fn statement ->
            predicate = term_value(statement.predicate)

            if predicate in [
                 "http://www.w3.org/ns/prov#alternateOf",
                 "http://www.w3.org/ns/prov#wasDerivedFrom",
                 "http://www.w3.org/ns/prov#wasRevisionOf"
               ] do
              [%{predicate: predicate, object: term_value(statement.object)}]
            else
              []
            end
          end)
      }
    end)
    |> Enum.sort_by(& &1.iri)
  end

  defp resolve_history(rows) when rows != [] do
    transitions =
      Enum.map(rows, fn row ->
        with {:ok, state} <- state(row),
             {:ok, revision} <- revision(row),
             [transition_iri] <- iri_values(row, "transition") do
          {:ok,
           %{
             state: state,
             revision: revision,
             transition_iri: transition_iri,
             predecessor: row |> iri_values("predecessor") |> List.first()
           }}
        else
          _invalid -> :error
        end
      end)

    with true <- Enum.all?(transitions, &match?({:ok, _}, &1)),
         values <- Enum.map(transitions, fn {:ok, value} -> value end),
         true <- unique_transition_rows?(values),
         ordered <- Enum.sort_by(values, & &1.revision),
         :ok <- valid_chain(ordered) do
      {:ok, List.last(ordered)}
    else
      _invalid -> {:error, "ambiguous_enrollment_transition_chain"}
    end
  end

  defp resolve_history(_rows), do: {:error, "missing_enrollment_transition_history"}

  defp valid_chain([first | rest]) do
    with true <- first.revision == 0,
         true <- first.state == :proposed,
         true <- is_nil(first.predecessor) do
      Enum.reduce_while(rest, {:ok, first}, fn current, {:ok, previous} ->
        if current.revision == previous.revision + 1 and
             current.predecessor == previous.transition_iri and
             allowed_edge?(previous.state, current.state) do
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
      _invalid -> :error
    end
  end

  defp allowed_edge?(:proposed, next), do: next in [:active, :retired, :invalidated]
  defp allowed_edge?(:active, next), do: next in [:active, :suspended, :retiring, :invalidated]
  defp allowed_edge?(:suspended, next), do: next in [:active, :suspended, :retiring, :invalidated]
  defp allowed_edge?(:retiring, next), do: next in [:retired, :invalidated]
  defp allowed_edge?(_prior, _next), do: false

  defp unique_transition_rows?(values) do
    pairs = Enum.map(values, &{&1.revision, &1.transition_iri})

    length(pairs) == length(Enum.uniq(pairs)) and
      length(Enum.map(values, & &1.revision)) ==
        length(Enum.uniq(Enum.map(values, & &1.revision)))
  end

  defp history_projection(rows) do
    rows
    |> Enum.map(fn row ->
      %{
        transition_iri: row |> iri_values("transition") |> List.first(),
        state_iri: row |> iri_values("state") |> List.first(),
        revision: row |> literal_values("revision") |> List.first(),
        predecessor_iri: row |> iri_values("predecessor") |> List.first(),
        actor_iri: row |> iri_values("actor") |> List.first(),
        cause_iri: row |> iri_values("cause") |> List.first(),
        policy_ref: row |> iri_values("policy") |> List.first(),
        locator_ref: row |> iri_values("locator") |> List.first()
      }
    end)
    |> Enum.sort_by(&{&1.revision || -1, &1.transition_iri || ""})
  end

  defp validity(rows) do
    %{
      valid_from: rows |> Enum.flat_map(&literal_values(&1, "validFrom")) |> Enum.uniq(),
      valid_to: rows |> Enum.flat_map(&literal_values(&1, "validTo")) |> Enum.uniq()
    }
  end

  defp state(row) do
    case iri_values(row, "state") do
      [iri] -> EnrollmentTransition.state_from_iri(iri)
      _invalid -> invalid(:repository_projection_state)
    end
  end

  defp revision(row) do
    case literal_values(row, "revision") do
      [value] when is_integer(value) and value >= 0 -> {:ok, value}
      [value] when is_binary(value) -> parse_revision(value)
      _invalid -> invalid(:repository_projection_revision)
    end
  end

  defp parse_revision(value) do
    case Integer.parse(value) do
      {revision, ""} when revision >= 0 -> {:ok, revision}
      _invalid -> invalid(:repository_projection_revision)
    end
  end

  defp group_rows(rows, key) do
    rows
    |> Enum.flat_map(fn row -> Enum.map(iri_values(row, key), &{&1, row}) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp relation_objects(triples, subject, predicate) do
    triples
    |> Enum.filter(fn triple ->
      term_value(triple.subject) == subject and term_value(triple.predicate) == predicate
    end)
    |> Enum.map(&term_value(&1.object))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp predicate_values(statements, predicate) do
    statements
    |> Enum.filter(&(term_value(&1.predicate) == predicate))
    |> Enum.map(&term_value(&1.object))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp iri_values(row, key) do
    case Map.get(row, key) do
      %{type: :iri, value: value} when is_binary(value) -> [value]
      _missing -> []
    end
  end

  defp literal_values(row, key) do
    case Map.get(row, key) do
      %{type: :literal, value: value} -> [value]
      _missing -> []
    end
  end

  defp term_value(%{value: value}), do: value
  defp term_value(_term), do: nil

  defp coherent_revision(results) do
    case results |> Enum.map(& &1.dataset_revision) |> Enum.uniq() do
      [revision] -> {:ok, revision}
      _revisions -> {:error, Error.new(:stale_precondition, :repository_projection_revision)}
    end
  end

  defp coherent_graph_revisions(results) do
    Enum.reduce_while(results, {:ok, %{}}, fn result, {:ok, acc} ->
      Enum.reduce_while(result.graph_revisions, {:ok, acc}, fn {graph, revision}, {:ok, inner} ->
        case Map.fetch(inner, graph) do
          :error -> {:cont, {:ok, Map.put(inner, graph, revision)}}
          {:ok, ^revision} -> {:cont, {:ok, inner}}
          {:ok, _other} -> {:halt, :conflict}
        end
      end)
      |> case do
        {:ok, merged} -> {:cont, {:ok, merged}}
        :conflict -> {:halt, invalid(:repository_projection_graph_revision)}
      end
    end)
  end

  defp safe_warning(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_warning({kind, detail}), do: %{kind: safe_warning(kind), detail: safe_warning(detail)}
  defp safe_warning(value) when is_binary(value), do: value
  defp safe_warning(value), do: inspect(value, limit: 20, printable_limit: 200)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
