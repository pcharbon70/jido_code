defmodule JidoCode.Knowledge.Memory.Retrieval do
  @moduledoc "Bounded deterministic retrieval from an authorized reviewed memory query."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.StateTransition
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @queries ~w[
    knowledge_by_scope knowledge_by_goal knowledge_by_task knowledge_by_source knowledge_by_policy
    knowledge_by_classification knowledge_by_validity knowledge_neighborhood
  ]a
  @max_rows 500
  @max_results 100

  @spec build(QueryResult.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(%QueryResult{} = result, context) when is_map(context) do
    graph = context[:memory_graph_iri]

    with true <- result.query_name in @queries,
         true <- result.query_version == QueryCatalog.knowledge_version(),
         {:ok, :memory} <- GraphRegistry.identify(graph),
         true <- map_size(result.graph_revisions) == 1,
         revision when is_integer(revision) and revision > 0 <- result.graph_revisions[graph],
         true <- revision == context[:expected_memory_revision],
         true <- result.evaluated_at == context[:evaluated_at],
         :ok <- ResourceIdentity.validate(context[:execution_context_iri]),
         {:ok, scopes} <- resources(context[:allowed_scope_iris], 50, false),
         {:ok, relevant} <- resources(context[:relevant_resource_iris], 100, true),
         {:ok, classifications} <- classifications(context[:allowed_classifications]),
         true <- is_map(context[:current_source_graph_revisions]),
         historical? when is_boolean(historical?) <- context[:historical?],
         limit when is_integer(limit) and limit in 1..@max_results <- context[:max_results],
         true <- no_prompt_memory?(context),
         rows when is_list(rows) and length(rows) <= @max_rows <- result.data do
      candidates =
        rows
        |> Enum.group_by(&value(&1, "assertion"))
        |> Enum.reject(fn {iri, _rows} -> is_nil(iri) end)
        |> Enum.map(fn {_iri, assertion_rows} ->
          candidate(assertion_rows, context, scopes, relevant, classifications)
        end)
        |> Enum.filter(&authorized?(&1, historical?))
        |> Enum.sort_by(fn assertion ->
          {-assertion.rank.score, -assertion.rank.recorded_unix, assertion.iri}
        end)

      selected = Enum.take(candidates, limit)

      {:ok,
       %{
         execution_context_iri: context.execution_context_iri,
         assertions: Enum.map(selected, &Map.drop(&1, [:authorized?, :visible?])),
         selection_policy: %{name: "knowledge-retrieval", version: "1.0.0"},
         prompt_context_persisted?: false,
         receipt: %{
           graph_iri: graph,
           graph_revision: revision,
           dataset_revision: result.dataset_revision,
           query_name: Atom.to_string(result.query_name),
           query_version: result.query_version,
           evaluated_at: DateTime.to_iso8601(result.evaluated_at),
           complete?: result.completeness.complete?,
           freshness: Atom.to_string(result.freshness),
           source_row_count: length(rows),
           candidate_count: length(candidates),
           returned_count: length(selected),
           truncated?: result.truncated? or length(candidates) > limit,
           warnings: result.warnings
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:knowledge_retrieval)
    end
  rescue
    _error -> invalid(:knowledge_retrieval)
  end

  def build(_result, _context), do: invalid(:knowledge_retrieval)

  defp candidate(rows, context, scopes, relevant, classifications) do
    latest_revision = rows |> Enum.map(&integer(value(&1, "stateRevision"))) |> Enum.max()
    rows = Enum.filter(rows, &(integer(value(&1, "stateRevision")) == latest_revision))
    first = List.first(rows)
    valid_from = datetime(value(first, "validFrom"))
    valid_to = datetime(value(first, "validTo"))
    recorded = datetime(value(first, "recorded"))
    state = state(value(first, "state"))
    classification = value(first, "classification")
    scope = value(first, "scope")
    related = values(rows, "related")
    supports = values(rows, "support")
    contradictions = values(rows, "contradiction")
    evidence = values(rows, "evidence")
    source_revisions = source_revisions(rows)
    stale_sources = stale_sources(source_revisions, context.current_source_graph_revisions)
    valid? = valid_at?(valid_from, valid_to, context.evaluated_at)
    scope_allowed? = scope in scopes
    classification_allowed? = classifications == :all or classification in classifications

    relevant_count =
      MapSet.intersection(MapSet.new(related), MapSet.new(relevant)) |> MapSet.size()

    current? = state == :still_valid and valid? and stale_sources == [] and contradictions == []

    score =
      scope_score(scope, context) +
        if(valid?, do: 100, else: 0) +
        min(length(supports), 10) * 20 +
        min(length(evidence), 10) * 10 +
        relevant_count * 30 -
        min(length(contradictions), 10) * 100

    %{
      iri: value(first, "assertion"),
      proposition: %{
        subject: value(first, "subject"),
        predicate: value(first, "predicate"),
        object: value(first, "object")
      },
      classification: classification,
      scope_iri: scope,
      state: state,
      state_revision: integer(value(first, "stateRevision")),
      state_transition_iri: value(first, "stateTransition"),
      confidence: integer(value(first, "confidence")),
      valid_from: iso8601(valid_from),
      valid_to: iso8601(valid_to),
      recorded_at: iso8601(recorded),
      adoption_actor_iri: value(first, "actor"),
      policy_iri: value(first, "policy"),
      policy_version: value(first, "policyVersion"),
      decision_iris: values(rows, "decision"),
      source_claim_iris: values(rows, "claim"),
      evidence_iris: evidence,
      source_snapshot_iris: values(rows, "snapshot"),
      related_resource_iris: related,
      supporting_assertion_iris: supports,
      contradiction_iris: contradictions,
      superseded_by_iris: values(rows, "superseded"),
      limitations: values(rows, "limitation"),
      source_graph_revisions: source_revisions,
      stale_source_graphs: stale_sources,
      selection_explanation:
        explanation(scope, context, valid?, state, stale_sources, contradictions, relevant_count),
      rank: %{score: score, recorded_unix: unix(recorded)},
      visible?: scope_allowed? and classification_allowed?,
      authorized?: scope_allowed? and classification_allowed? and current?
    }
  end

  defp authorized?(assertion, false), do: assertion.authorized?

  defp authorized?(assertion, true) do
    assertion.visible?
  end

  defp explanation(scope, context, valid?, state, stale, contradictions, relevant_count) do
    []
    |> add(:repository_scope, scope == context[:repository_scope_iri])
    |> add(:cohort_scope, scope != context[:repository_scope_iri])
    |> add(:currently_valid, valid?)
    |> add(:current_state, state == :still_valid)
    |> add(:source_revisions_exact, stale == [])
    |> add(:no_known_contradiction, contradictions == [])
    |> add(:task_or_goal_relevant, relevant_count > 0)
    |> Enum.reverse()
  end

  defp add(values, _code, false), do: values
  defp add(values, code, true), do: [code | values]

  defp scope_score(scope, context) do
    if scope == context[:repository_scope_iri], do: 400, else: 200
  end

  defp source_revisions(rows) do
    rows
    |> Enum.reduce(%{}, fn row, acc ->
      graph = value(row, "sourceGraphIri")
      revision = integer(value(row, "sourceRevision"))

      if is_binary(graph) and is_integer(revision), do: Map.put(acc, graph, revision), else: acc
    end)
  end

  defp stale_sources(source, current) do
    source
    |> Enum.filter(fn {graph, revision} -> current[graph] != revision end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  defp values(rows, key),
    do: rows |> Enum.map(&value(&1, key)) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort()

  defp value(row, key) do
    case row[key] do
      %{value: value} -> value
      value -> value
    end
  end

  defp state(iri) do
    Enum.find(StateTransition.states(), fn state -> StateTransition.state_iri(state) == iri end)
  end

  defp datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _invalid -> nil
    end
  end

  defp datetime(_value), do: nil
  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      _invalid -> nil
    end
  end

  defp integer(_value), do: nil
  defp iso8601(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso8601(_value), do: nil
  defp unix(%DateTime{} = value), do: DateTime.to_unix(value, :microsecond)
  defp unix(_value), do: 0

  defp valid_at?(%DateTime{} = from, %DateTime{} = to, %DateTime{} = at),
    do: DateTime.compare(from, at) in [:lt, :eq] and DateTime.compare(at, to) == :lt

  defp valid_at?(_from, _to, _at), do: false

  defp classifications(nil), do: {:ok, :all}

  defp classifications(values) when is_list(values) and length(values) <= 10 do
    iris = Enum.map(values, &JidoCode.Knowledge.Memory.Assertion.classification_iri/1)

    if Enum.all?(values, &(&1 in JidoCode.Knowledge.Memory.Assertion.classifications())),
      do: {:ok, iris},
      else: :error
  rescue
    _error -> :error
  end

  defp classifications(_values), do: :error

  defp resources(values, maximum, allow_empty?)
       when is_list(values) and length(values) <= maximum do
    values = values |> Enum.uniq() |> Enum.sort()

    if (allow_empty? or values != []) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, values},
       else: :error
  end

  defp resources(_values, _maximum, _allow_empty?), do: :error

  defp no_prompt_memory?(context) do
    Enum.all?([:prompt, :messages, :transcript, :tool_output], &(not Map.has_key?(context, &1)))
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
