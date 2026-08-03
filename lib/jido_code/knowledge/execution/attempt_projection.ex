defmodule JidoCode.Knowledge.Execution.AttemptProjection do
  @moduledoc "Bounded execution projection that keeps operational completion distinct from evidence."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @queries ~w[
    attempt_status attempt_timeline tool_invocations attempt_artifacts
    cancellation_retry_lineage run_completeness
  ]a
  @states %{
    "ExecutionAttemptPrepared" => :prepared,
    "ExecutionAttemptStarting" => :starting,
    "ExecutionAttemptRunning" => :running,
    "ExecutionAttemptWaitingTool" => :waiting_tool,
    "ExecutionAttemptCancelling" => :cancelling,
    "ExecutionAttemptCancelled" => :cancelled,
    "ExecutionAttemptCompleted" => :completed,
    "ExecutionAttemptFailed" => :failed,
    "ExecutionAttemptTimedOut" => :timed_out,
    "ExecutionAttemptAbandoned" => :abandoned,
    "ExecutionAttemptRecovered" => :recovered,
    "ExecutionAttemptSuperseded" => :superseded
  }
  @terminal ~w[cancelled completed failed timed_out abandoned superseded]a

  @spec build(%{required(atom()) => QueryResult.t()}, map()) ::
          {:ok, map()} | {:error, Error.t()}
  def build(results, context) when is_map(results) and is_map(context) do
    graph = context[:graph_iri]
    attempt = context[:attempt_iri]

    with true <- Map.keys(results) |> Enum.sort() == Enum.sort(@queries),
         {:ok, :run_attempt} <- GraphRegistry.identify(graph),
         :ok <- ResourceIdentity.validate(attempt),
         :ok <- validate_results(results, graph),
         {:ok, status} <- status(results.attempt_status.data),
         {:ok, timeline} <- timeline(results.attempt_timeline.data),
         endpoint when is_map(endpoint) <- List.last(timeline),
         {:ok, tools} <- tools(results.tool_invocations.data),
         {:ok, artifacts} <- artifacts(results.attempt_artifacts.data),
         {:ok, lineage} <- lineage(results.cancellation_retry_lineage.data),
         {:ok, completeness} <- completeness(results.run_completeness.data),
         diagnostic = endpoint.diagnostic || status.diagnostic,
         state = state(endpoint.state_iri),
         true <- state != :unknown and safe?(diagnostic) do
      revision = results.attempt_status.graph_revisions[graph]

      {:ok,
       %{
         attempt_iri: attempt,
         task_iri: status.task_iri,
         goal_iri: status.goal_iri,
         plan_iri: status.plan_iri,
         lease_iri: status.lease_iri,
         enrollment_iri: status.enrollment_iri,
         repository_iri: status.repository_iri,
         source_snapshot_iri: status.snapshot_iri,
         actor_iri: status.actor_iri,
         agent_iri: status.agent_iri,
         capability_iri: status.capability_iri,
         fencing_token: status.fencing_token,
         runtime_version: status.runtime_version,
         context_digest: status.context_digest,
         constraints: status.constraints,
         current_state: state,
         terminal?: state in @terminal,
         terminal_transition_iri: endpoint.transition_iri,
         terminal_revision: endpoint.revision,
         diagnostic: diagnostic,
         last_activity_at: last_activity(timeline),
         timeline: timeline,
         tool_invocations: tools,
         artifacts: artifacts,
         cancellation_retry: lineage,
         run_completeness: completeness,
         operational_completion: if(state in @terminal, do: state, else: :in_progress),
         verification_state: :not_evaluated,
         evidence_state: :not_recorded,
         decision_state: :not_decided,
         receipt: %{
           graph_iri: graph,
           graph_revision: revision,
           dataset_revision: results.attempt_status.dataset_revision,
           query_version: QueryCatalog.execution_version(),
           truncated?: Enum.any?(results, fn {_name, result} -> result.truncated? end),
           warnings:
             results |> Enum.flat_map(fn {_name, result} -> result.warnings end) |> Enum.uniq()
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:attempt_projection)
    end
  rescue
    _error -> invalid(:attempt_projection)
  end

  def build(_results, _context), do: invalid(:attempt_projection)

  defp validate_results(results, graph) do
    values = Map.values(results)

    if Enum.all?(results, fn {name, result} ->
         name in @queries and match?(%QueryResult{}, result) and result.query_name == name and
           result.query_version == QueryCatalog.execution_version() and
           Map.keys(result.graph_revisions) == [graph] and
           is_integer(result.graph_revisions[graph]) and result.graph_revisions[graph] > 0
       end) and
         values |> Enum.map(& &1.dataset_revision) |> Enum.uniq() |> length() == 1 and
         values |> Enum.map(& &1.graph_revisions[graph]) |> Enum.uniq() |> length() == 1,
       do: :ok,
       else: :error
  end

  defp status(rows) when is_list(rows) and length(rows) <= 200 do
    with constraints when is_binary(constraints) <- object(rows, "constraintPayload"),
         {:ok, decoded} when is_map(decoded) <- Jason.decode(constraints),
         fence when is_integer(fence) <- object(rows, "fencingToken"),
         task when is_binary(task) <- object(rows, "executes"),
         goal when is_binary(goal) <- object(rows, "attempts"),
         plan when is_binary(plan) <- object(rows, "derivedFrom"),
         lease when is_binary(lease) <- object(rows, "validFor"),
         snapshot when is_binary(snapshot) <- object(rows, "sourceSnapshot"),
         enrollment when is_binary(enrollment) <- object(rows, "enrollment"),
         repository when is_binary(repository) <- object(rows, "inScope"),
         actor when is_binary(actor) <- object(rows, "wasAssociatedWith"),
         agent when is_binary(agent) <- object(rows, "delegatedAgent"),
         capability when is_binary(capability) <- object(rows, "requiresCapability"),
         runtime_version when is_binary(runtime_version) <- object(rows, "runtimeVersion"),
         context_digest when is_binary(context_digest) <- object(rows, "contextDigest") do
      {:ok,
       %{
         task_iri: task,
         goal_iri: goal,
         plan_iri: plan,
         lease_iri: lease,
         snapshot_iri: snapshot,
         enrollment_iri: enrollment,
         repository_iri: repository,
         actor_iri: actor,
         agent_iri: agent,
         capability_iri: capability,
         fencing_token: fence,
         runtime_version: runtime_version,
         context_digest: context_digest,
         constraints: decoded,
         diagnostic: object(rows, "diagnostic")
       }}
    else
      _invalid -> invalid(:attempt_projection_status)
    end
  end

  defp status(_rows), do: invalid(:attempt_projection_status)

  defp timeline(rows) when is_list(rows) and length(rows) <= 200 do
    timeline =
      Enum.map(rows, fn row ->
        %{
          transition_iri: value(row, "transition"),
          prior_state_iri: value(row, "prior"),
          state_iri: value(row, "state"),
          revision: value(row, "revision"),
          recorded_at: value(row, "recorded"),
          runtime_sequence: value(row, "runtimeSequence"),
          outcome_iri: value(row, "outcome"),
          diagnostic: value(row, "diagnostic")
        }
      end)

    if Enum.all?(timeline, fn entry ->
         is_binary(entry.transition_iri) and is_binary(entry.state_iri) and
           is_integer(entry.revision) and is_binary(entry.recorded_at) and
           safe?(entry.diagnostic)
       end) and
         timeline |> Enum.map(& &1.revision) |> Enum.uniq() |> length() == length(timeline),
       do: {:ok, Enum.sort_by(timeline, & &1.revision)},
       else: invalid(:attempt_projection_timeline)
  end

  defp timeline(_rows), do: invalid(:attempt_projection_timeline)

  defp tools(rows) when is_list(rows) and length(rows) <= 200 do
    tools =
      rows
      |> Enum.group_by(&value(&1, "invocation"))
      |> Enum.reject(fn {iri, _rows} -> is_nil(iri) end)
      |> Enum.map(fn {iri, invocation_rows} ->
        %{
          invocation_iri: iri,
          tool_iri: one(invocation_rows, "tool"),
          tool_version: one(invocation_rows, "version"),
          sequence: one(invocation_rows, "sequence"),
          expected_effect_iri: one(invocation_rows, "effect"),
          started_at: one(invocation_rows, "started"),
          deadline: one(invocation_rows, "deadline"),
          result_iri: one(invocation_rows, "result"),
          status_iri: one(invocation_rows, "status"),
          ended_at: one(invocation_rows, "ended"),
          exit_status: one(invocation_rows, "exitStatus"),
          stdout_digest: one(invocation_rows, "stdoutDigest"),
          stderr_digest: one(invocation_rows, "stderrDigest"),
          usage_digest: one(invocation_rows, "usageDigest"),
          redaction_iri: one(invocation_rows, "redaction"),
          artifact_iris: values(invocation_rows, "artifact")
        }
      end)
      |> Enum.sort_by(&{&1.sequence, &1.invocation_iri})

    if length(tools) <= 100, do: {:ok, tools}, else: invalid(:attempt_projection_tools)
  end

  defp tools(_rows), do: invalid(:attempt_projection_tools)

  defp artifacts(rows) when is_list(rows) and length(rows) <= 200 do
    artifacts =
      rows
      |> Enum.group_by(&value(&1, "artifact"))
      |> Enum.reject(fn {iri, _rows} -> is_nil(iri) end)
      |> Enum.map(fn {iri, artifact_rows} ->
        %{
          artifact_iri: iri,
          kind_iri: one(artifact_rows, "kind"),
          source_snapshot_iri: one(artifact_rows, "snapshot"),
          generator_iri: one(artifact_rows, "generator"),
          content_digest: one(artifact_rows, "digest"),
          media_type: one(artifact_rows, "mediaType"),
          byte_count: one(artifact_rows, "byteCount"),
          storage_iri: one(artifact_rows, "storage"),
          external_uri: one(artifact_rows, "external"),
          affected_paths: values(artifact_rows, "path"),
          affected_symbol_iris: values(artifact_rows, "symbol"),
          proposed_commit_iri: one(artifact_rows, "commit"),
          proposed_tree_iri: one(artifact_rows, "tree")
        }
      end)
      |> Enum.sort_by(& &1.artifact_iri)

    if length(artifacts) <= 100,
      do: {:ok, artifacts},
      else: invalid(:attempt_projection_artifacts)
  end

  defp artifacts(_rows), do: invalid(:attempt_projection_artifacts)

  defp lineage(rows) when is_list(rows) and length(rows) <= 200 do
    {:ok,
     %{
       retry_of_iris: values(rows, "retryOf"),
       retry_iris: values(rows, "retry"),
       cancellation_iris: values(rows, "cancellation"),
       outcome_iris: values(rows, "outcome")
     }}
  end

  defp lineage(_rows), do: invalid(:attempt_projection_lineage)

  defp completeness(rows) when is_list(rows) and length(rows) <= 200 do
    {:ok,
     %{
       lifecycle_iris: values(rows, "lifecycle"),
       state_iris: values(rows, "state"),
       closed_at: one(rows, "closed"),
       assertion_iri: one(rows, "assertion"),
       runtime_completion_iri: one(rows, "runtimeCompletion"),
       missing_outputs: values(rows, "missing"),
       limitations: values(rows, "limitation"),
       usage_digest: one(rows, "usageDigest")
     }}
  end

  defp completeness(_rows), do: invalid(:attempt_projection_completeness)

  defp state(iri) when is_binary(iri), do: Map.get(@states, iri_label(iri), :unknown)
  defp state(_iri), do: :unknown

  defp last_activity([]), do: nil
  defp last_activity(timeline), do: timeline |> List.last() |> Map.get(:recorded_at)

  defp one(rows, key) do
    case values(rows, key) do
      [value] -> value
      [] -> nil
      _many -> :ambiguous
    end
  end

  defp values(rows, key) do
    rows |> Enum.map(&value(&1, key)) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> Enum.sort()
  end

  defp object(rows, predicate) do
    rows
    |> Enum.filter(&(predicate_label(value(&1, "predicate")) == predicate))
    |> one("object")
  end

  defp value(row, key) do
    term = row[key] || row[existing_atom(key)]
    term_value(term)
  end

  defp term_value(%{
         type: :literal,
         value: value,
         datatype: datatype
       })
       when is_binary(value) and
              datatype in [
                "http://www.w3.org/2001/XMLSchema#integer",
                "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
              ] do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _invalid -> value
    end
  end

  defp term_value(%{value: %DateTime{} = value}), do: DateTime.to_iso8601(value)
  defp term_value(%{value: value}), do: value
  defp term_value(value), do: value

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> :__unknown__
  end

  defp iri_label(iri) do
    uri = URI.parse(iri)
    uri.fragment || (uri.path && uri.path |> String.split("/", trim: true) |> List.last()) || iri
  end

  defp predicate_label(iri) when is_binary(iri), do: iri_label(iri)
  defp predicate_label(_iri), do: nil

  defp safe?(nil), do: true

  defp safe?(value) when is_binary(value) do
    byte_size(value) <= 1_024 and
      not Regex.match?(
        ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_|sk-)[A-Za-z0-9_-]{16,}|(?:password|token|secret)\s*[=:]\s*\S+)/i,
        value
      )
  end

  defp safe?(_value), do: false
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
