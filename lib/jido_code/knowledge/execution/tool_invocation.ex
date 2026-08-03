defmodule JidoCode.Knowledge.Execution.ToolInvocation do
  @moduledoc "Graph-native identity and replay-safe event capture for governed tool effects."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.ExecutionLease
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.Attempt
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :attempt_iri,
    :tool_iri,
    :capability_iri,
    :tool_version,
    :actor_iri,
    :agent_iri,
    :lease_iri,
    :fencing_token,
    :input_refs,
    :input_digests,
    :sequence,
    :deadline,
    :expected_effect
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @statuses ~w[completed failed timed_out cancelled rejected]a

  @spec new(Attempt.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(%Attempt{} = attempt, attributes) when is_map(attributes) do
    with :ok <- resource(attributes[:tool_iri]),
         :ok <- resource(attributes[:capability_iri]),
         true <- attributes[:capability_iri] == attempt.capability_iri,
         version when is_binary(version) and byte_size(version) in 1..128 <-
           attributes[:tool_version],
         sequence when is_integer(sequence) and sequence >= 0 <- attributes[:sequence],
         %DateTime{} = deadline <- attributes[:deadline],
         :ok <- resource(attributes[:expected_effect]),
         :ok <- resources(attributes[:input_refs]),
         :ok <- digests(attributes[:input_digests]),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :tool_invocation,
             Enum.join(
               [attempt.iri, Integer.to_string(sequence), attributes.tool_iri, version],
               "\n"
             )
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         attempt_iri: attempt.iri,
         tool_iri: attributes.tool_iri,
         capability_iri: attributes.capability_iri,
         tool_version: version,
         actor_iri: attempt.actor_iri,
         agent_iri: attempt.agent_iri,
         lease_iri: attempt.lease_iri,
         fencing_token: attempt.fencing_token,
         input_refs: Enum.sort(attributes.input_refs),
         input_digests: attributes.input_digests,
         sequence: sequence,
         deadline: DateTime.truncate(deadline, :microsecond),
         expected_effect: attributes.expected_effect
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:tool_invocation)
    end
  rescue
    _error -> invalid(:tool_invocation)
  end

  def new(_attempt, _attributes), do: invalid(:tool_invocation)

  @spec start_command(t(), Attempt.t(), map(), ExecutionLease.t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def start_command(invocation, attempt, attempt_resolution, lease, attributes, options \\ [])

  def start_command(
        %__MODULE__{} = invocation,
        %Attempt{} = attempt,
        %{domain: :execution_attempt} = attempt_resolution,
        %ExecutionLease{} = lease,
        attributes,
        options
      )
      when is_map(attributes) and is_list(options) do
    with :ok <- validate_authority(invocation, attempt, attempt_resolution, lease, attributes),
         {:ok, target} <-
           ExecutionGraph.append_target(
             attempt.run_graph_iri,
             attributes.expected_run_revision,
             attributes.repository_scope_iri,
             command_iri(invocation, :start),
             attributes.recorded_at,
             start_statements(invocation, attributes.recorded_at)
           ),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RecordToolInvocation",
               invocation,
               attempt,
               attributes,
               target,
               start_guards(invocation, attempt, attempt_resolution, lease, attributes),
               :start
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:start_tool_invocation)
    end
  rescue
    _error -> invalid(:start_tool_invocation)
  end

  def start_command(_invocation, _attempt, _resolution, _lease, _attributes, _options),
    do: invalid(:start_tool_invocation)

  @spec outcome_command(t(), Attempt.t(), map(), ExecutionLease.t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def outcome_command(invocation, attempt, attempt_resolution, lease, attributes, options \\ [])

  def outcome_command(
        %__MODULE__{} = invocation,
        %Attempt{} = attempt,
        %{domain: :execution_attempt} = attempt_resolution,
        %ExecutionLease{} = lease,
        attributes,
        options
      )
      when is_map(attributes) and is_list(options) do
    with :ok <- validate_authority(invocation, attempt, attempt_resolution, lease, attributes),
         {:ok, event_iri} <- outcome_event_iri(invocation),
         {:ok, statements} <- outcome_statements(invocation, event_iri, attributes),
         {:ok, target} <-
           ExecutionGraph.append_target(
             attempt.run_graph_iri,
             attributes.expected_run_revision,
             attributes.repository_scope_iri,
             command_iri(invocation, :outcome),
             attributes.recorded_at,
             statements
           ),
         guards =
           authority_guards(attempt, attempt_resolution, lease, attributes) ++
             [{:subject_absent, attempt.run_graph_iri, event_iri}],
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RecordToolOutcome",
               invocation,
               attempt,
               attributes,
               target,
               guards,
               :outcome
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_tool_outcome)
    end
  rescue
    _error -> invalid(:record_tool_outcome)
  end

  def outcome_command(_invocation, _attempt, _resolution, _lease, _attributes, _options),
    do: invalid(:record_tool_outcome)

  defp validate_authority(invocation, attempt, resolution, lease, attributes) do
    cond do
      invocation.attempt_iri != attempt.iri or invocation.lease_iri != lease.iri -> :error
      invocation.fencing_token != lease.fencing_token -> :error
      resolution.subject_iri != attempt.iri -> :error
      resolution.current_state not in [:running, :waiting_tool] -> :error
      not match?(%DateTime{}, attributes[:recorded_at]) -> :error
      DateTime.compare(attributes.recorded_at, invocation.deadline) == :gt -> :error
      attributes[:fencing_token] != invocation.fencing_token -> :error
      true -> :ok
    end
  end

  defp start_statements(invocation, recorded_at) do
    [
      {invocation.iri, @rdf_type, RDF.iri(@jf <> "ToolInvocation")},
      {invocation.iri, @jf <> "executes", RDF.iri(invocation.tool_iri)},
      {invocation.iri, @jf <> "attempts", RDF.iri(invocation.attempt_iri)},
      {invocation.iri, @jf <> "requiresCapability", RDF.iri(invocation.capability_iri)},
      {invocation.iri, @jf <> "validFor", RDF.iri(invocation.lease_iri)},
      {invocation.iri, @prov <> "wasAssociatedWith", RDF.iri(invocation.actor_iri)},
      {invocation.iri, @jf <> "delegatedAgent", RDF.iri(invocation.agent_iri)},
      {invocation.iri, @jf <> "toolVersion", RDF.XSD.String.new(invocation.tool_version)},
      {invocation.iri, @jf <> "fencingToken",
       RDF.XSD.NonNegativeInteger.new(invocation.fencing_token)},
      {invocation.iri, @jf <> "invocationSequence",
       RDF.XSD.NonNegativeInteger.new(invocation.sequence)},
      {invocation.iri, @jf <> "expectedEffect", RDF.iri(invocation.expected_effect)},
      {invocation.iri, @jf <> "deadline", RDF.XSD.DateTime.new(invocation.deadline)},
      {invocation.iri, @prov <> "startedAtTime", RDF.XSD.DateTime.new(recorded_at)}
    ] ++
      Enum.map(invocation.input_refs, fn ref ->
        {invocation.iri, @prov <> "used", RDF.iri(ref)}
      end) ++
      Enum.map(Enum.sort(invocation.input_digests), fn {name, digest} ->
        {invocation.iri, @jf <> "inputDigest", RDF.XSD.String.new(name <> "=" <> digest)}
      end)
  end

  defp outcome_statements(invocation, event_iri, attributes) do
    with status when status in @statuses <- attributes[:status],
         :ok <- exit_status(attributes[:exit_status]),
         stdout when is_binary(stdout) <- attributes[:stdout],
         stderr when is_binary(stderr) <- attributes[:stderr],
         true <- byte_size(stdout) + byte_size(stderr) <= 65_536,
         :ok <- resources(attributes[:external_output_iris]),
         :ok <- resources(attributes[:artifact_iris]),
         usage when is_map(usage) <- attributes[:usage],
         :ok <- usage(usage),
         redaction when redaction in [:none, :applied, :fully_redacted] <- attributes[:redaction] do
      {:ok,
       [
         {invocation.iri, @jf <> "result", RDF.iri(event_iri)},
         {event_iri, @rdf_type, RDF.iri(@prov <> "Activity")},
         {event_iri, @jf <> "outcomeClass",
          RDF.iri(@concept <> Macro.camelize(to_string(status)))},
         {event_iri, @jf <> "redactionResult",
          RDF.iri(@concept <> Macro.camelize(to_string(redaction)))},
         {event_iri, @prov <> "endedAtTime", RDF.XSD.DateTime.new(attributes.recorded_at)},
         {event_iri, @jf <> "stdout", RDF.XSD.String.new(stdout)},
         {event_iri, @jf <> "stderr", RDF.XSD.String.new(stderr)},
         {event_iri, @jf <> "stdoutDigest", RDF.XSD.String.new(digest(stdout))},
         {event_iri, @jf <> "stderrDigest", RDF.XSD.String.new(digest(stderr))},
         {event_iri, @jf <> "usageDigest", RDF.XSD.String.new(digest(usage))}
       ] ++
         optional_integer(event_iri, @jf <> "exitStatus", attributes.exit_status) ++
         usage_statements(event_iri, usage) ++
         Enum.map(attributes.external_output_iris, fn iri ->
           {event_iri, @jf <> "externalOutput", RDF.iri(iri)}
         end) ++
         Enum.map(attributes.artifact_iris, fn iri ->
           {event_iri, @prov <> "generated", RDF.iri(iri)}
         end)}
    else
      _invalid -> invalid(:tool_outcome)
    end
  end

  defp start_guards(invocation, attempt, resolution, lease, attributes) do
    [
      {:subject_absent, attempt.run_graph_iri, invocation.iri}
      | authority_guards(attempt, resolution, lease, attributes)
    ]
  end

  defp authority_guards(attempt, resolution, lease, attributes) do
    [
      {:transition_endpoint, attempt.run_graph_iri, attempt.iri, resolution.current_transition},
      ExecutionLease.execution_guard(
        lease,
        attributes.control_graph_iri,
        attempt.fencing_token,
        attributes.recorded_at
      )
    ]
  end

  defp envelope(type, invocation, attempt, attributes, target, guards, event) do
    command = command_iri(invocation, event)

    %{
      command_type: type,
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
      payload: %{changes: [target], guards: guards, invocation_iri: invocation.iri}
    }
  end

  defp command_iri(invocation, event) do
    {:ok, iri} =
      ResourceIdentity.deterministic(
        :command_request,
        invocation.iri <> "\n" <> Atom.to_string(event)
      )

    iri
  end

  defp outcome_event_iri(invocation),
    do: ResourceIdentity.deterministic(:tool_invocation_event, invocation.iri <> "\noutcome")

  defp exit_status(nil), do: :ok
  defp exit_status(status) when is_integer(status) and status in 0..255, do: :ok
  defp exit_status(_status), do: :error

  defp usage(usage) do
    allowed = ~w[cpu_ms memory_bytes output_bytes disk_bytes]a

    if map_size(usage) <= 4 and
         Enum.all?(usage, fn {key, value} ->
           key in allowed and is_integer(value) and value >= 0
         end),
       do: :ok,
       else: :error
  end

  defp usage_statements(subject, usage) do
    Enum.map(Enum.sort(usage), fn {key, value} ->
      {subject, @jf <> Macro.camelize(to_string(key)), RDF.XSD.NonNegativeInteger.new(value)}
    end)
  end

  defp resources(values) when is_list(values) and length(values) <= 100 do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)), do: :ok, else: :error
  end

  defp resources(_values), do: :error

  defp resource(value), do: ResourceIdentity.validate(value)

  defp digests(values) when is_map(values) and map_size(values) <= 100 do
    if Enum.all?(values, fn {name, value} ->
         is_binary(name) and byte_size(name) in 1..256 and is_binary(value) and
           Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)
       end),
       do: :ok,
       else: :error
  end

  defp digests(_values), do: :error

  defp optional_integer(_subject, _predicate, nil), do: []

  defp optional_integer(subject, predicate, value),
    do: [{subject, predicate, RDF.XSD.NonNegativeInteger.new(value)}]

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
