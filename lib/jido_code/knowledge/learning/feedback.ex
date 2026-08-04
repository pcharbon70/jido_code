defmodule JidoCode.Knowledge.Learning.Feedback do
  @moduledoc "Exact-version feedback packages for reconciliation, execution, and outcome measurement."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @spec build_inputs(map(), map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build_inputs(retrieval, reasoning, attributes)
      when is_map(retrieval) and is_map(reasoning) and is_map(attributes) do
    with true <- retrieval[:prompt_context_persisted?] == false,
         memory_revision when is_integer(memory_revision) and memory_revision > 0 <-
           get_in(retrieval, [:receipt, :graph_revision]),
         true <- memory_revision == attributes[:expected_memory_revision],
         derived_revision when is_integer(derived_revision) and derived_revision > 0 <-
           reasoning_revision(reasoning),
         true <- derived_revision == attributes[:expected_derived_revision],
         true <- reasoning[:acceptance_authority?] == false,
         true <- reasoning[:command_authority?] == false,
         source_revisions when is_map(source_revisions) and map_size(source_revisions) > 0 <-
           reasoning[:source_graph_revisions],
         classifications when is_list(classifications) <- reasoning[:derived_classifications],
         true <- Enum.all?(classifications, &valid_classification?(&1, reasoning)),
         :ok <- ResourceIdentity.validate(attributes[:reconciliation_context_iri]),
         :ok <- ResourceIdentity.validate(attributes[:execution_context_iri]),
         {:ok, budget} <- budget(attributes[:budget]),
         assertions when is_list(assertions) <- retrieval[:assertions],
         true <- Enum.all?(assertions, &current_assertion?/1),
         {:ok, execution_items, omissions} <- execution_items(assertions, budget),
         revisions =
           source_revisions
           |> Map.put(retrieval.receipt.graph_iri, memory_revision)
           |> Map.put(reasoning.target_graph_iri, derived_revision),
         token <- digest({revisions, retrieval.receipt.query_version, reasoning.rule_revision}) do
      {:ok,
       %{
         reconciliation: %{
           context_iri: attributes.reconciliation_context_iri,
           accepted_knowledge_iris: Enum.map(assertions, & &1.iri),
           knowledge: assertions,
           derived_classifications: classifications,
           derived_graph_iri: reasoning.target_graph_iri,
           reasoning_activity_iri: reasoning.activity_iri,
           contradiction_state: :current_assertions_only,
           source_graph_revisions: revisions,
           query_version: retrieval.receipt.query_version,
           rule_revision: reasoning.rule_revision,
           invalidation_token: token
         },
         execution: %{
           context_iri: attributes.execution_context_iri,
           knowledge_items: execution_items,
           omissions: omissions,
           budget: budget,
           source_graph_revisions: revisions,
           selection_policy: retrieval.selection_policy,
           invalidation_token: token,
           prompt_context_persisted?: false
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:learning_feedback)
    end
  rescue
    _error -> invalid(:learning_feedback)
  end

  def build_inputs(_retrieval, _reasoning, _attributes), do: invalid(:learning_feedback)

  @spec stale?(map(), map()) :: boolean()
  def stale?(package, current_revisions) when is_map(package) and is_map(current_revisions) do
    package[:source_graph_revisions] !=
      Map.take(current_revisions, Map.keys(package[:source_graph_revisions] || %{}))
  end

  def stale?(_package, _current_revisions), do: true

  @spec measurement(map()) :: {:ok, map()} | {:error, Error.t()}
  def measurement(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:knowledge_assertion_iri]),
         {:ok, prior} <- resources(attributes[:prior_evidence_iris], 20, false),
         {:ok, outcome} <- resources(attributes[:outcome_evidence_iris], 20, false),
         true <- MapSet.disjoint?(MapSet.new(prior), MapSet.new(outcome)),
         metrics when is_map(metrics) and map_size(metrics) in 1..20 <- attributes[:metrics],
         true <-
           Enum.all?(metrics, fn {key, value} ->
             is_atom(key) and (is_integer(value) or is_float(value) or is_boolean(value))
           end),
         measured_at when is_struct(measured_at, DateTime) <- attributes[:measured_at],
         {:ok, iri} <- measurement_iri(attributes, prior, outcome, metrics) do
      {:ok,
       %{
         iri: iri,
         state: :observed,
         knowledge_assertion_iri: attributes.knowledge_assertion_iri,
         prior_evidence_iris: prior,
         outcome_evidence_iris: outcome,
         metrics: metrics,
         measured_at: measured_at,
         confidence_mutated?: false,
         adoption_mutated?: false
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:learning_measurement)
    end
  rescue
    _error -> invalid(:learning_measurement)
  end

  def measurement(_attributes), do: invalid(:learning_measurement)

  defp execution_items(assertions, budget) do
    Enum.reduce_while(assertions, {:ok, [], [], 0, 0}, fn assertion,
                                                          {:ok, selected, omitted, bytes, tokens} ->
      item = %{
        iri: assertion.iri,
        classification: assertion.classification,
        proposition: assertion.proposition,
        selection_explanation: assertion.selection_explanation,
        evidence_iris: assertion.evidence_iris,
        decision_iris: assertion.decision_iris,
        validity: %{from: assertion.valid_from, to: assertion.valid_to}
      }

      item_bytes = :erlang.external_size(item)
      item_tokens = div(item_bytes + 3, 4)

      if length(selected) < budget.max_items and bytes + item_bytes <= budget.max_bytes and
           tokens + item_tokens <= budget.max_tokens do
        {:cont, {:ok, selected ++ [item], omitted, bytes + item_bytes, tokens + item_tokens}}
      else
        omission = %{iri: assertion.iri, reason: :prompt_budget}
        {:cont, {:ok, selected, omitted ++ [omission], bytes, tokens}}
      end
    end)
    |> case do
      {:ok, selected, omissions, _bytes, _tokens} -> {:ok, selected, omissions}
    end
  end

  defp current_assertion?(assertion),
    do: assertion[:state] == :still_valid and assertion[:contradiction_iris] == []

  defp valid_classification?(classification, reasoning) do
    classification[:graph_iri] == reasoning[:target_graph_iri] and
      classification[:activity_iri] == reasoning[:activity_iri] and
      classification[:rule_revision] == reasoning[:rule_revision] and
      classification[:source_graph_revisions] == reasoning[:source_graph_revisions] and
      classification[:state] == :current and classification[:authority?] == false and
      ResourceIdentity.validate(classification[:subject_iri]) == :ok and
      RDF.IRI.valid?(classification[:class_iri])
  end

  defp budget(value) when is_map(value) do
    with max_items when is_integer(max_items) and max_items in 1..100 <- value[:max_items],
         max_bytes when is_integer(max_bytes) and max_bytes in 256..100_000 <- value[:max_bytes],
         max_tokens when is_integer(max_tokens) and max_tokens in 64..25_000 <- value[:max_tokens] do
      {:ok, %{max_items: max_items, max_bytes: max_bytes, max_tokens: max_tokens}}
    else
      _invalid -> invalid(:learning_feedback_budget)
    end
  end

  defp budget(_value), do: invalid(:learning_feedback_budget)

  defp reasoning_revision(reasoning) do
    get_in(reasoning, [
      Access.key(:receipt),
      Access.key(:graph_revisions),
      reasoning.target_graph_iri,
      Access.key(:new)
    ])
  rescue
    _error -> nil
  end

  defp measurement_iri(attributes, prior, outcome, metrics) do
    material =
      {attributes.knowledge_assertion_iri, prior, outcome, metrics, attributes[:measured_at]}
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ResourceIdentity.deterministic(:learning_measurement, material)
  end

  defp resources(values, maximum, allow_empty?)
       when is_list(values) and length(values) <= maximum do
    values = values |> Enum.uniq() |> Enum.sort()

    if (allow_empty? or values != []) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, values},
       else: invalid(:learning_measurement)
  end

  defp resources(_values, _maximum, _allow_empty?), do: invalid(:learning_measurement)

  defp digest(value),
    do: :crypto.hash(:sha256, :erlang.term_to_binary(value)) |> Base.encode16(case: :lower)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
