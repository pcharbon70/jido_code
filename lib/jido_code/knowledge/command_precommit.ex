defmodule JidoCode.Knowledge.CommandPrecommit do
  @moduledoc false

  alias JidoCode.Knowledge.ChangeSet
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Validation.Validator

  @jf "https://jido.run/ontology/factory#"
  @relationship_predicates MapSet.new(~w[
    enrolls manages locatedBy inScope about derivedFrom supports contradicts addresses
    decomposesInto dependsOn blocks requiresCapability governedBy executes evaluates accepts
    rejects waives satisfies supersedes claimedBy validFor sourceActivity graphScope
    epistemicState confidenceBand priorState nextState transitionSubject expectedPredecessor
    cause decisionAuthority ontologyVersion creationActivity ownerScope graphKind lifecycleState
    completenessState sourceRevision parentGraph sourceGraph targetGraph validationReport
    sourceGraphRevision sourceOntologyVersion targetOntologyVersion focusNode resultShape resultPath
    severity ruleSet invalidationState
  ])
  @max_guards 20

  @spec validate(CommandEnvelope.t(), ChangeSet.t(), map(), [RDF.Quad.t()], String.t(), integer()) ::
          {:ok, [map()]} | {:error, Error.t()} | {:error, Error.t(), map()}
  def validate(envelope, change_set, snapshot, audit_additions, audit_graph, deadline) do
    with :ok <- before_deadline(deadline),
         :ok <- revision_preconditions(envelope, snapshot),
         :ok <- target_lifecycle(change_set, snapshot),
         :ok <- topology(change_set),
         :ok <- guards(envelope.payload[:guards] || [], snapshot),
         {:ok, reports} <- validate_targets(change_set, snapshot, deadline),
         {:ok, audit_report} <- validate_audit(snapshot, audit_additions, audit_graph, deadline),
         :ok <- before_deadline(deadline) do
      {:ok, reports ++ [audit_report]}
    end
  end

  defp revision_preconditions(envelope, snapshot) do
    current = Map.take(snapshot.graph_revisions, Map.keys(envelope.expected_graph_revisions))

    if snapshot.dataset_revision == envelope.expected_dataset_revision and
         current == envelope.expected_graph_revisions do
      :ok
    else
      {:error, Error.new(:stale_precondition, :command_revisions), current}
    end
  end

  defp target_lifecycle(change_set, snapshot) do
    Enum.reduce_while(change_set.targets, :ok, fn target, :ok ->
      existing = Map.get(snapshot.graph_metadata, target.graph_iri)
      operation = if target.operation == :maintenance, do: :append, else: target.operation

      valid? =
        case operation do
          :create ->
            is_nil(existing) and GraphRegistry.write_allowed?(target.family, :create)

          :append ->
            not is_nil(existing) and
              GraphRegistry.write_allowed?(target.family, :append, existing)

          :replace ->
            not is_nil(existing) and
              GraphRegistry.write_allowed?(target.family, :replace, existing)
        end

      if valid?, do: {:cont, :ok}, else: {:halt, {:error, Error.new(:conflict, :graph_lifecycle)}}
    end)
  end

  defp topology(change_set) do
    Enum.reduce_while(change_set.additions, :ok, fn quad, :ok ->
      case quad do
        {_subject, %RDF.IRI{value: @jf <> local}, %RDF.IRI{value: object}, graph}
        when is_binary(object) ->
          if MapSet.member?(@relationship_predicates, local) and
               String.starts_with?(object, "https://jido.run/graph/") do
            with {:ok, source_family} <- GraphRegistry.identify(RDF.IRI.to_string(graph)),
                 {:ok, target_family} <- GraphRegistry.identify(object),
                 true <- GraphRegistry.allowed_link?(source_family, target_family) do
              {:cont, :ok}
            else
              _invalid -> {:halt, {:error, Error.new(:invalid_input, :cross_graph_link)}}
            end
          else
            {:cont, :ok}
          end

        _other ->
          {:cont, :ok}
      end
    end)
  end

  defp guards(guards, snapshot) when is_list(guards) and length(guards) <= @max_guards do
    Enum.reduce_while(guards, :ok, fn guard, :ok ->
      if guard_satisfied?(guard, snapshot.dataset),
        do: {:cont, :ok},
        else: {:halt, {:error, Error.new(:stale_precondition, :command_guard)}}
    end)
  end

  defp guards(_guards, _snapshot), do: {:error, Error.new(:invalid_input, :command_guards)}

  defp guard_satisfied?({:subject_present, graph, subject}, dataset) do
    Enum.any?(graph_quads(dataset, graph), fn {stored, _, _, _} ->
      term_equal?(stored, subject)
    end)
  end

  defp guard_satisfied?({:subject_absent, graph, subject}, dataset) do
    not guard_satisfied?({:subject_present, graph, subject}, dataset)
  end

  defp guard_satisfied?({:triple_present, graph, subject, predicate, object}, dataset) do
    {expected_subject, expected_predicate, expected_object} =
      RDF.Triple.new({subject, predicate, object})

    Enum.any?(graph_quads(dataset, graph), fn {s, p, o, _g} ->
      RDF.Term.equal_value?(s, expected_subject) and
        RDF.Term.equal_value?(p, expected_predicate) and
        RDF.Term.equal_value?(o, expected_object)
    end)
  rescue
    _error -> false
  end

  defp guard_satisfied?(_guard, _dataset), do: false

  defp validate_targets(change_set, snapshot, deadline) do
    Enum.reduce_while(change_set.targets, {:ok, []}, fn target, {:ok, reports} ->
      existing_metadata = Map.get(snapshot.graph_metadata, target.graph_iri)

      metadata =
        if target.operation == :replace,
          do: target.metadata,
          else: existing_metadata || target.metadata

      operation = if target.operation == :maintenance, do: :append, else: target.operation

      existing =
        if target.operation == :replace,
          do: [],
          else: graph_quads(snapshot.dataset, target.graph_iri)

      result =
        Validator.validate(
          %{
            operation: operation,
            family: target.family,
            graph_iri: target.graph_iri,
            metadata: metadata,
            existing_metadata: existing_metadata,
            additions: target.additions,
            existing: existing,
            shape_version: change_set.shape_version
          },
          deadline_monotonic_ms: deadline
        )

      case result do
        {:ok, report} -> {:cont, {:ok, [report | reports]}}
        {:error, %Error{} = error, report} -> {:halt, {:error, error, report}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, reports} -> {:ok, Enum.reverse(reports)}
      error -> error
    end
  end

  defp validate_audit(snapshot, additions, graph, deadline) do
    metadata = Map.get(snapshot.graph_metadata, graph)

    if is_map(metadata) do
      Validator.validate(
        %{
          operation: :append,
          family: :security_audit,
          graph_iri: graph,
          metadata: metadata,
          existing_metadata: metadata,
          additions: additions,
          existing: graph_quads(snapshot.dataset, graph),
          shape_version: "1.0.0"
        },
        deadline_monotonic_ms: deadline
      )
    else
      {:error, Error.new(:unavailable, :audit_graph_required)}
    end
  end

  defp graph_quads(dataset, graph) do
    case RDF.Dataset.graph(dataset, RDF.iri(graph)) do
      nil -> []
      graph_data -> RDF.Graph.quads(graph_data)
    end
  end

  defp term_equal?(stored, expected) do
    RDF.Term.equal_value?(stored, RDF.iri(expected))
  rescue
    _error -> false
  end

  defp before_deadline(deadline) when is_integer(deadline) do
    if System.monotonic_time(:millisecond) < deadline,
      do: :ok,
      else: {:error, Error.new(:timeout, :command_precommit)}
  end

  defp before_deadline(_deadline), do: {:error, Error.new(:invalid_input, :command_deadline)}
end
