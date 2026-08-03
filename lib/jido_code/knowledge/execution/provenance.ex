defmodule JidoCode.Knowledge.Execution.Provenance do
  @moduledoc "Terminal provenance capture and immutable run-graph closure."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.ExecutionLease
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.Attempt
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.ResourceIdentity

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @terminal_states ~w[completed failed timed_out abandoned cancelled superseded]a
  @sandbox_operations ~w[
    provision materialize execute inspect cancel collect destroy quarantine orphan_cleanup
  ]a
  @sandbox_outcomes ~w[success failure timeout cancelled denied exhausted partial quarantined]a

  @spec finalize_command(Attempt.t(), map(), ExecutionLease.t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def finalize_command(attempt, attempt_resolution, lease, attributes, options \\ [])

  def finalize_command(
        %Attempt{} = attempt,
        %{domain: :execution_attempt, current_state: state} = resolution,
        %ExecutionLease{} = lease,
        attributes,
        options
      )
      when state in @terminal_states and is_map(attributes) and is_list(options) do
    with :ok <- validate(attempt, resolution, lease, attributes),
         {:ok, sandbox_statements, sandbox_iris} <-
           sandbox_statements(attempt, attributes.sandbox_activities),
         completeness_iri <- completeness_iri(attempt),
         statements <-
           provenance_statements(
             attempt,
             resolution,
             attributes,
             completeness_iri,
             sandbox_iris
           ) ++ sandbox_statements,
         {:ok, target} <-
           ExecutionGraph.close_target(
             attributes.run_metadata,
             attributes.repository_scope_iri,
             command_iri(attempt),
             attributes.recorded_at,
             attributes.completeness,
             statements
           ),
         guards = guards(attempt, resolution, lease, attributes),
         {:ok, command} <-
           CommandEnvelope.new(envelope(attempt, attributes, target, guards), options) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:finalize_execution_run)
    end
  rescue
    _error -> invalid(:finalize_execution_run)
  end

  def finalize_command(_attempt, _resolution, _lease, _attributes, _options),
    do: invalid(:finalize_execution_run)

  defp validate(attempt, resolution, lease, attributes) do
    required_lists = ~w[
      tool_invocation_iris artifact_iris required_event_iris missing_outputs limitations
      sandbox_activities
    ]a

    cond do
      resolution.subject_iri != attempt.iri ->
        :error

      lease.iri != attempt.lease_iri or lease.fencing_token != attempt.fencing_token ->
        :error

      attributes[:fencing_token] != attempt.fencing_token ->
        :error

      attributes[:completeness] not in [:complete, :incomplete] ->
        :error

      attributes.completeness == :complete and
          (attributes[:missing_outputs] != [] or resolution.current_state == :abandoned) ->
        :error

      attributes.completeness == :incomplete and
        attributes[:missing_outputs] == [] and resolution.current_state != :abandoned ->
        :error

      not match?(%DateTime{}, attributes[:recorded_at]) ->
        :error

      attributes[:lease_mode] not in [:current, :expired] ->
        :error

      not is_integer(attributes[:terminal_sequence]) or attributes.terminal_sequence < 0 ->
        :error

      not Enum.all?(required_lists, &is_list(attributes[&1])) ->
        :error

      Enum.any?(required_lists, &(length(attributes[&1]) > 100)) ->
        :error

      resources(
        attributes.tool_invocation_iris ++
            attributes.artifact_iris ++
            attributes.required_event_iris
      ) != :ok ->
        :error

      texts(attributes.missing_outputs, 256) != :ok or texts(attributes.limitations, 512) != :ok ->
        :error

      usage(attributes[:usage]) != :ok ->
        :error

      not safe_diagnostic?(attributes[:diagnostic]) ->
        :error

      optional_resource(attributes[:cancellation_iri]) != :ok ->
        :error

      not is_map(attributes[:run_metadata]) ->
        :error

      attributes.run_metadata[:graph_iri] != attempt.run_graph_iri ->
        :error

      true ->
        :ok
    end
  end

  defp provenance_statements(attempt, resolution, attributes, completeness_iri, sandbox_iris) do
    [
      {attempt.iri, @jf <> "enrollment", RDF.iri(attempt.enrollment_iri)},
      {attempt.iri, @jf <> "inScope", RDF.iri(attempt.repository_iri)},
      {attempt.iri, @jf <> "outcomeClass",
       RDF.iri(
         @concept <> "ExecutionAttempt" <> Macro.camelize(to_string(resolution.current_state))
       )},
      {attempt.iri, @jf <> "terminalSequence",
       RDF.XSD.NonNegativeInteger.new(attributes.terminal_sequence)},
      {attempt.iri, @jf <> "provenanceCompleteness", RDF.iri(completeness_iri)},
      {attempt.iri, @jf <> "runtimeCompletion", RDF.iri(@concept <> "OperationalOnly")},
      {completeness_iri, @rdf_type, RDF.iri(@prov <> "Entity")},
      {completeness_iri, @jf <> "about", RDF.iri(attempt.iri)},
      {completeness_iri, @jf <> "completenessState",
       RDF.iri(@concept <> Macro.camelize(to_string(attributes.completeness)))},
      {completeness_iri, @prov <> "generatedAtTime",
       RDF.XSD.DateTime.new(attributes.recorded_at)},
      {completeness_iri, @jf <> "usageDigest", RDF.XSD.String.new(digest(attributes.usage))}
    ] ++
      optional_literal(attempt.iri, @jf <> "diagnostic", attributes.diagnostic) ++
      optional_iri(attempt.iri, @jf <> "cancellationRequest", attributes.cancellation_iri) ++
      usage_statements(completeness_iri, attributes.usage) ++
      refs(attempt.iri, @jf <> "toolInvocation", attributes.tool_invocation_iris) ++
      refs(attempt.iri, @prov <> "generated", attributes.artifact_iris) ++
      refs(attempt.iri, @jf <> "sandboxActivity", sandbox_iris) ++
      literals(completeness_iri, @jf <> "missingOutput", attributes.missing_outputs) ++
      literals(completeness_iri, @jf <> "limitation", attributes.limitations)
  end

  defp sandbox_statements(attempt, activities) do
    activities
    |> Enum.reduce_while({:ok, [], []}, fn activity, {:ok, statements, iris} ->
      with sequence when is_integer(sequence) and sequence >= 0 <- activity[:sequence],
           operation when operation in @sandbox_operations <- activity[:operation],
           outcome when outcome in @sandbox_outcomes <- activity[:outcome],
           %DateTime{} = occurred_at <- activity[:occurred_at],
           provider when is_binary(provider) <- activity[:provider_ref],
           true <- Regex.match?(~r/^[a-f0-9]{64}$/, provider),
           details when is_map(details) <- activity[:details],
           true <- byte_size(:erlang.term_to_binary(details, [:deterministic])) <= 16_384,
           true <- safe_details?(details),
           {:ok, iri} <-
             ResourceIdentity.deterministic(
               :sandbox_activity,
               Enum.join(
                 [attempt.iri, Integer.to_string(sequence), Atom.to_string(operation)],
                 "\n"
               )
             ) do
        current = [
          {iri, @rdf_type, RDF.iri(@prov <> "Activity")},
          {iri, @jf <> "attempts", RDF.iri(attempt.iri)},
          {iri, @jf <> "sandboxOperation",
           RDF.iri(@concept <> Macro.camelize(to_string(operation)))},
          {iri, @jf <> "outcomeClass", RDF.iri(@concept <> Macro.camelize(to_string(outcome)))},
          {iri, @jf <> "providerRef", RDF.XSD.String.new(provider)},
          {iri, @jf <> "detailsDigest", RDF.XSD.String.new(digest(details))},
          {iri, @prov <> "endedAtTime", RDF.XSD.DateTime.new(occurred_at)}
        ]

        {:cont, {:ok, statements ++ current, iris ++ [iri]}}
      else
        _invalid -> {:halt, invalid(:sandbox_provenance)}
      end
    end)
  end

  defp guards(attempt, resolution, lease, attributes) do
    required =
      attributes.tool_invocation_iris ++
        attributes.artifact_iris ++
        attributes.required_event_iris ++ List.wrap(attributes.cancellation_iri)

    [
      {:transition_endpoint, attempt.run_graph_iri, attempt.iri, resolution.current_transition},
      {:current_lease_fence, attributes.control_graph_iri, attempt.task_iri, lease.iri,
       attempt.fencing_token, attributes.recorded_at, attributes.lease_mode}
    ] ++ Enum.map(Enum.uniq(required), &{:subject_present, attempt.run_graph_iri, &1})
  end

  defp envelope(attempt, attributes, target, guards) do
    command = command_iri(attempt)

    %{
      command_type: "FinalizeExecutionRun",
      command_version: "1.6.0",
      command_iri: command,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:repository_scope_iri],
      idempotency_key: command,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: %{
        attempt.run_graph_iri => attributes.expected_run_revision,
        attributes.control_graph_iri => attributes.expected_control_revision
      },
      reason: attributes[:reason],
      payload: %{changes: [target], guards: guards, attempt_iri: attempt.iri}
    }
  end

  defp command_iri(attempt) do
    {:ok, iri} = ResourceIdentity.deterministic(:command_request, attempt.iri <> "\nfinalize-run")
    iri
  end

  defp completeness_iri(attempt) do
    {:ok, iri} =
      ResourceIdentity.deterministic(:run_completeness, attempt.iri <> "\nprovenance")

    iri
  end

  defp usage(value) when is_map(value) and map_size(value) <= 8 do
    if Enum.all?(value, fn {key, amount} ->
         key in ~w[cpu_ms memory_bytes disk_bytes output_bytes input_tokens output_tokens cost_units]a and
           is_integer(amount) and amount >= 0
       end),
       do: :ok,
       else: :error
  end

  defp usage(_value), do: :error

  defp usage_statements(subject, usage) do
    Enum.map(Enum.sort(usage), fn {key, amount} ->
      {subject, @jf <> Macro.camelize(to_string(key)), RDF.XSD.NonNegativeInteger.new(amount)}
    end)
  end

  defp resources(values) when is_list(values) do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)), do: :ok, else: :error
  end

  defp resources(_values), do: :error
  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: ResourceIdentity.validate(value)

  defp texts(values, maximum) when is_list(values) do
    if Enum.all?(values, &(is_binary(&1) and byte_size(&1) in 1..maximum and not secret?(&1))),
      do: :ok,
      else: :error
  end

  defp safe_diagnostic?(nil), do: true

  defp safe_diagnostic?(value) when is_binary(value),
    do: byte_size(value) <= 1_024 and not secret?(value)

  defp safe_diagnostic?(_value), do: false

  defp secret?(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp safe_details?(value) when is_map(value),
    do: Enum.all?(value, fn {key, item} -> safe_details?(key) and safe_details?(item) end)

  defp safe_details?(value) when is_list(value), do: Enum.all?(value, &safe_details?/1)
  defp safe_details?(value) when is_binary(value), do: not secret?(value)
  defp safe_details?(value) when is_atom(value) or is_number(value) or is_boolean(value), do: true
  defp safe_details?(nil), do: true
  defp safe_details?(_value), do: false

  defp refs(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, RDF.iri(&1)})

  defp literals(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, RDF.XSD.String.new(&1)})

  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, object), do: [{subject, predicate, RDF.iri(object)}]
  defp optional_literal(_subject, _predicate, nil), do: []

  defp optional_literal(subject, predicate, value),
    do: [{subject, predicate, RDF.XSD.String.new(value)}]

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
