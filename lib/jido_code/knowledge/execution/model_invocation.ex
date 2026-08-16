defmodule JidoCode.Knowledge.Execution.ModelInvocation do
  @moduledoc """
  Graph-native identity and replay-safe capture for governed model calls.

  Each host-controlled model interaction becomes one `ModelInvocation`
  resource in the run graph: its start is committed before provider dispatch
  with an immutable context-manifest reference, and its outcome closes the
  invocation under the next expected sequence. Ambiguous outcomes are an
  explicit terminal class, never overwritten history.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.ExecutionLease
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.Attempt
  alias JidoCode.Knowledge.Execution.ContextManifest
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :attempt_iri,
    :profile_iri,
    :model_version,
    :actor_iri,
    :agent_iri,
    :lease_iri,
    :fencing_token,
    :context_manifest_iri,
    :sequence,
    :deadline
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @statuses ~w[completed failed timed_out cancelled ambiguous]a
  @usage_keys ~w[input_tokens output_tokens cost_units cpu_ms memory_bytes]a

  @spec new(Attempt.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(%Attempt{} = attempt, attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:profile_iri]),
         version when is_binary(version) and byte_size(version) in 1..128 <-
           attributes[:model_version],
         sequence when is_integer(sequence) and sequence >= 0 <- attributes[:sequence],
         %DateTime{} = deadline <- attributes[:deadline],
         :ok <- ResourceIdentity.validate(attributes[:context_manifest_iri]),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :model_invocation,
             Enum.join(
               [attempt.iri, Integer.to_string(sequence), attributes.profile_iri, version],
               "\n"
             )
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         attempt_iri: attempt.iri,
         profile_iri: attributes.profile_iri,
         model_version: version,
         actor_iri: attempt.actor_iri,
         agent_iri: attempt.agent_iri,
         lease_iri: attempt.lease_iri,
         fencing_token: attempt.fencing_token,
         context_manifest_iri: attributes.context_manifest_iri,
         sequence: sequence,
         deadline: DateTime.truncate(deadline, :microsecond)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:model_invocation)
    end
  rescue
    _error -> invalid(:model_invocation)
  end

  def new(_attempt, _attributes), do: invalid(:model_invocation)

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
         {:ok, manifest_statements, manifest_guards} <-
           manifest_context(invocation, attempt, attributes),
         {:ok, target} <-
           ExecutionGraph.append_target(
             attempt.run_graph_iri,
             attributes.expected_run_revision,
             attributes.repository_scope_iri,
             command_iri(invocation, :start),
             attributes.recorded_at,
             start_statements(invocation, attributes.recorded_at) ++ manifest_statements
           ),
         guards =
           [{:subject_absent, attempt.run_graph_iri, invocation.iri}] ++
             manifest_guards ++ authority_guards(attempt, attempt_resolution, lease, attributes),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RecordModelInvocationStart",
               invocation,
               attempt,
               attributes,
               target,
               guards,
               :start
             ),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:start_model_invocation)
    end
  rescue
    _error -> invalid(:start_model_invocation)
  end

  def start_command(_invocation, _attempt, _resolution, _lease, _attributes, _options),
    do: invalid(:start_model_invocation)

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
           [{:subject_present, attempt.run_graph_iri, invocation.iri}] ++
             authority_guards(attempt, attempt_resolution, lease, attributes),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "RecordModelInvocationOutcome",
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
      _invalid -> invalid(:record_model_outcome)
    end
  rescue
    _error -> invalid(:record_model_outcome)
  end

  def outcome_command(_invocation, _attempt, _resolution, _lease, _attributes, _options),
    do: invalid(:record_model_outcome)

  defp validate_authority(invocation, attempt, resolution, lease, attributes) do
    cond do
      invocation.attempt_iri != attempt.iri or invocation.lease_iri != lease.iri -> :error
      invocation.fencing_token != lease.fencing_token -> :error
      resolution.subject_iri != attempt.iri -> :error
      resolution.current_state not in [:running, :waiting_tool] -> :error
      not match?(%DateTime{}, attributes[:recorded_at]) -> :error
      DateTime.compare(attributes.recorded_at, invocation.deadline) == :gt -> :error
      DateTime.compare(attributes.recorded_at, lease.expires_at) == :gt -> :error
      attributes[:fencing_token] != invocation.fencing_token -> :error
      true -> :ok
    end
  end

  defp manifest_context(invocation, attempt, attributes) do
    case attributes[:next_manifest] do
      nil ->
        with {:ok, _index_zero} <- ContextManifest.first_manifest_iri(attempt.iri) do
          {:ok, [],
           [
             {:subject_present, attempt.run_graph_iri, invocation.context_manifest_iri}
           ]}
        else
          {:error, %Error{} = error} -> {:error, error}
          _invalid -> invalid(:model_invocation_manifest)
        end

      %ContextManifest{} = manifest ->
        cond do
          manifest.attempt_iri != attempt.iri ->
            invalid(:model_invocation_manifest)

          manifest.index <= 0 ->
            invalid(:model_invocation_manifest)

          true ->
            {:ok, ContextManifest.statements(manifest),
             [{:subject_absent, attempt.run_graph_iri, manifest.iri}]}
        end

      _invalid_manifest ->
        invalid(:model_invocation_manifest)
    end
  end

  defp start_statements(invocation, recorded_at) do
    [
      {invocation.iri, @rdf_type, RDF.iri(@jf <> "ModelInvocation")},
      {invocation.iri, @jf <> "usesModelAccessProfile", RDF.iri(invocation.profile_iri)},
      {invocation.iri, @jf <> "attempts", RDF.iri(invocation.attempt_iri)},
      {invocation.iri, @jf <> "validFor", RDF.iri(invocation.lease_iri)},
      {invocation.iri, @prov <> "wasAssociatedWith", RDF.iri(invocation.actor_iri)},
      {invocation.iri, @jf <> "delegatedAgent", RDF.iri(invocation.agent_iri)},
      {invocation.iri, @jf <> "modelVersion", RDF.XSD.String.new(invocation.model_version)},
      {invocation.iri, @jf <> "fencingToken",
       RDF.XSD.NonNegativeInteger.new(invocation.fencing_token)},
      {invocation.iri, @jf <> "invocationSequence",
       RDF.XSD.NonNegativeInteger.new(invocation.sequence)},
      {invocation.iri, @jf <> "hasContextManifest", RDF.iri(invocation.context_manifest_iri)},
      {invocation.iri, @jf <> "deadline", RDF.XSD.DateTime.new(invocation.deadline)},
      {invocation.iri, @prov <> "startedAtTime", RDF.XSD.DateTime.new(recorded_at)}
    ]
  end

  defp outcome_statements(invocation, event_iri, attributes) do
    with status when status in @statuses <- attributes[:status],
         true <- safe_ref?(attributes[:model_call_ref]),
         usage when is_map(usage) <- attributes[:usage],
         :ok <- usage(usage),
         true <- safe_diagnostic?(attributes[:diagnostic]) do
      {:ok,
       [
         {invocation.iri, @jf <> "result", RDF.iri(event_iri)},
         {event_iri, @rdf_type, RDF.iri(@prov <> "Activity")},
         {event_iri, @jf <> "outcomeClass",
          RDF.iri(@concept <> Macro.camelize(to_string(status)))},
         {event_iri, @prov <> "endedAtTime", RDF.XSD.DateTime.new(attributes.recorded_at)},
         {event_iri, @jf <> "usageDigest", RDF.XSD.String.new(digest(usage))}
       ] ++
         optional_literal(event_iri, @jf <> "modelCallRef", attributes.model_call_ref) ++
         optional_literal(event_iri, @jf <> "diagnostic", attributes.diagnostic) ++
         usage_statements(event_iri, usage)}
    else
      _invalid -> invalid(:model_outcome)
    end
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
      command_version: "1.8.0",
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
    do: ResourceIdentity.deterministic(:model_invocation_event, invocation.iri <> "\noutcome")

  defp usage(usage) do
    if map_size(usage) <= 8 and
         Enum.all?(usage, fn {key, value} ->
           key in @usage_keys and is_integer(value) and value >= 0
         end),
       do: :ok,
       else: :error
  end

  defp usage_statements(subject, usage) do
    Enum.map(Enum.sort(usage), fn {key, value} ->
      {subject, @jf <> Macro.camelize(to_string(key)), RDF.XSD.NonNegativeInteger.new(value)}
    end)
  end

  defp safe_ref?(nil), do: true

  defp safe_ref?(value) when is_binary(value),
    do: byte_size(value) <= 256 and not secret?(value)

  defp safe_ref?(_value), do: false

  defp safe_diagnostic?(nil), do: true

  defp safe_diagnostic?(value) when is_binary(value),
    do: byte_size(value) <= 1_024 and not secret?(value)

  defp safe_diagnostic?(_value), do: false

  defp optional_literal(_subject, _predicate, nil), do: []

  defp optional_literal(subject, predicate, value),
    do: [{subject, predicate, RDF.XSD.String.new(value)}]

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp secret?(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
