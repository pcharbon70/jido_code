defmodule JidoCode.Knowledge.Execution.ImmutableEvent do
  @moduledoc """
  Type-specific resources recorded on the shared segmented attempt sequence.

  Starts and outcomes are distinct immutable resources. Every resource binds
  the exact attempt, lease, fence, context and predecessor head. Tool starts
  additionally bind capability, approval and effect journal while proving the
  invocation is recorded before dispatch.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :event_type,
    :command_type,
    :role,
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :context_iri,
    :context_revision,
    :predecessor_head_iri,
    :semantic_digest,
    :resource_revision,
    :occurred_at
  ]
  defstruct @enforce_keys ++
              [
                :subject_iri,
                :start_iri,
                :capability_iri,
                :approval_iri,
                :effect_journal_iri,
                :provider_source_iri,
                :provider_source_order,
                :attribution_iri,
                :related_role,
                :related_resource_iri,
                :related_graph_iri
              ]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @definitions %{
    model_start: %{command: "RecordModelInvocationStart", role: :start, class: "ModelInvocation"},
    model_outcome: %{
      command: "RecordModelInvocationOutcome",
      role: :outcome,
      class: "ModelInvocationOutcome"
    },
    tool_start: %{command: "RecordToolInvocationStart", role: :start, class: "ToolInvocation"},
    tool_outcome: %{command: "RecordToolOutcome", role: :outcome, class: "ToolInvocationOutcome"},
    transition: %{command: "RecordAttemptTransition", role: :transition, class: "StateTransition"},
    proposal: %{command: "RecordActionProposal", role: :observation, class: "ActionProposal"},
    sandbox: %{command: "RecordSandboxEvent", role: :observation, class: "SandboxEvent"},
    artifact: %{command: "RecordExecutionArtifact", role: :artifact, class: "Artifact"},
    message: %{command: "RecordExecutionMessage", role: :message, class: "Message"},
    cancellation: %{
      command: "RecordCancellationObservation",
      role: :observation,
      class: "CancellationObservation"
    },
    retry: %{command: "RecordRetryObservation", role: :observation, class: "RetryObservation"},
    terminal: %{
      command: "RecordTerminalObservation",
      role: :terminal,
      class: "TerminalObservation"
    },
    provider_observation: %{
      command: "RecordProviderObservation",
      role: :observation,
      class: "ProviderObservation"
    },
    lifecycle_observation: %{
      command: "RecordLifecycleObservation",
      role: :observation,
      class: "LifecycleObservation"
    }
  }
  @accepted_related_families %{
    verification: :evidence,
    decision: :repository_control,
    publication: :repository_control,
    deployment: :evidence,
    incident: :evidence,
    delayed_review: :evidence
  }

  @spec types() :: [atom()]
  def types, do: @definitions |> Map.keys() |> Enum.sort()

  @spec new(map(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(authority, attributes) when is_map(authority) and is_map(attributes) do
    type = attributes[:event_type]

    with {:ok, definition} <- definition(type),
         :ok <- authority(authority),
         true <- attributes[:attempt_iri] == authority.attempt_iri,
         true <- attributes[:lease_iri] == authority.lease_iri,
         true <- attributes[:fencing_token] == authority.fencing_token,
         true <- attributes[:context_iri] == authority.context_iri,
         true <- attributes[:context_revision] == authority.context_revision,
         :ok <- ResourceIdentity.validate(attributes[:predecessor_head_iri]),
         true <- digest?(attributes[:semantic_digest]),
         true <- safe_revision?(attributes[:resource_revision]),
         true <- match?(%DateTime{}, attributes[:occurred_at]),
         :ok <- type_contract(type, attributes),
         :ok <- related_contract(attributes[:related]),
         {:ok, iri} <- identity(authority.attempt_iri, type, attributes) do
      related = attributes[:related] || %{}

      {:ok,
       %__MODULE__{
         iri: iri,
         event_type: type,
         command_type: definition.command,
         role: definition.role,
         attempt_iri: authority.attempt_iri,
         lease_iri: authority.lease_iri,
         fencing_token: authority.fencing_token,
         context_iri: authority.context_iri,
         context_revision: authority.context_revision,
         predecessor_head_iri: attributes.predecessor_head_iri,
         semantic_digest: attributes.semantic_digest,
         resource_revision: attributes.resource_revision,
         occurred_at: DateTime.truncate(attributes.occurred_at, :microsecond),
         subject_iri: attributes[:subject_iri],
         start_iri: attributes[:start_iri],
         capability_iri: attributes[:capability_iri],
         approval_iri: attributes[:approval_iri],
         effect_journal_iri: attributes[:effect_journal_iri],
         provider_source_iri: attributes[:provider_source_iri],
         provider_source_order: attributes[:provider_source_order],
         attribution_iri: attributes[:attribution_iri],
         related_role: related[:role],
         related_resource_iri: related[:resource_iri],
         related_graph_iri: related[:graph_iri]
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      :error -> invalid(:immutable_execution_event_type)
      _invalid -> invalid(:immutable_execution_event)
    end
  rescue
    _error -> invalid(:immutable_execution_event)
  end

  def new(_authority, _attributes), do: invalid(:immutable_execution_event)

  @spec event_attributes(t()) :: map()
  def event_attributes(%__MODULE__{} = event) do
    %{
      command_type: event.command_type,
      event_type: event.event_type,
      role: event.role,
      resource_iris: [event.iri],
      resource_statements: statements(event),
      opens_effect_iris: if(event.role == :start, do: [event.iri], else: []),
      closes_effect_iris: if(event.role == :outcome, do: [event.start_iri], else: []),
      occurred_at: event.occurred_at,
      source_order: event.provider_source_order,
      source_iri: event.provider_source_iri
    }
  end

  @spec record_command(t(), EventSegment.t(), map(), keyword()) ::
          {:ok, %{segment: EventSegment.t(), command: struct()}} | {:error, Error.t()}
  def record_command(%__MODULE__{} = event, %EventSegment{} = segment, attributes, options \\ []) do
    if event.attempt_iri == segment.attempt_iri and
         event.predecessor_head_iri == segment.head_iri and provider_order_valid?(event, segment) do
      EventSegment.append_command(
        segment,
        event.predecessor_head_iri,
        event_attributes(event),
        attributes,
        options
      )
    else
      conflict(:immutable_event_predecessor)
    end
  end

  defp provider_order_valid?(%{event_type: :provider_observation} = event, segment) do
    prior_orders =
      segment.events
      |> Enum.filter(
        &(&1.event_type == :provider_observation and &1.source_iri == event.provider_source_iri)
      )
      |> Enum.map(& &1.source_order)
      |> Enum.reject(&is_nil/1)

    prior_orders == [] or event.provider_source_order == Enum.max(prior_orders) + 1
  end

  defp provider_order_valid?(_event, _segment), do: true

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = event) do
    definition = Map.fetch!(@definitions, event.event_type)

    [
      {event.iri, @rdf_type, RDF.iri(@jf <> definition.class)},
      {event.iri, @jf <> "attempts", RDF.iri(event.attempt_iri)},
      {event.iri, @jf <> "validFor", RDF.iri(event.lease_iri)},
      {event.iri, @jf <> "fencingToken", RDF.XSD.NonNegativeInteger.new(event.fencing_token)},
      {event.iri, @jf <> "hasContextManifest", RDF.iri(event.context_iri)},
      {event.iri, @jf <> "contextRevision",
       RDF.XSD.NonNegativeInteger.new(event.context_revision)},
      {event.iri, @jf <> "eventPredecessorHead", RDF.iri(event.predecessor_head_iri)},
      {event.iri, @jf <> "resourceRevision", RDF.XSD.String.new(event.resource_revision)},
      {event.iri, @jf <> "semanticDigest", RDF.XSD.String.new(event.semantic_digest)},
      {event.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(event.occurred_at)}
    ] ++
      optional_iri(event.iri, @jf <> "executes", event.subject_iri) ++
      optional_iri(event.iri, @jf <> "outcomeOf", event.start_iri) ++
      optional_iri(event.iri, @jf <> "requiresCapability", event.capability_iri) ++
      optional_iri(event.iri, @jf <> "authorizedBy", event.approval_iri) ++
      optional_iri(event.iri, @jf <> "effectJournal", event.effect_journal_iri) ++
      optional_iri(event.iri, @jf <> "providerSource", event.provider_source_iri) ++
      optional_integer(event.iri, @jf <> "sourceOrder", event.provider_source_order) ++
      optional_iri(event.iri, @jf <> "attributedBy", event.attribution_iri) ++
      related_statements(event)
  end

  defp type_contract(type, attributes) when type in [:model_start, :tool_start] do
    with :ok <- ResourceIdentity.validate(attributes[:subject_iri]),
         true <- is_nil(attributes[:start_iri]),
         :ok <- start_contract(type, attributes) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_start_event)
    end
  end

  defp type_contract(type, attributes) when type in [:model_outcome, :tool_outcome] do
    with :ok <- ResourceIdentity.validate(attributes[:start_iri]),
         true <- is_nil(attributes[:subject_iri]) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_outcome_event)
    end
  end

  defp type_contract(:provider_observation, attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:provider_source_iri]),
         source_order when is_integer(source_order) and source_order >= 0 <-
           attributes[:provider_source_order],
         :ok <- ResourceIdentity.validate(attributes[:attribution_iri]) do
      :ok
    else
      _invalid -> invalid(:provider_observation_event)
    end
  end

  defp type_contract(_type, attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:subject_iri]),
         true <- is_nil(attributes[:start_iri]) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_observation_event)
    end
  end

  defp start_contract(:model_start, attributes) do
    if is_nil(attributes[:capability_iri]) and is_nil(attributes[:approval_iri]) and
         is_nil(attributes[:effect_journal_iri]),
       do: :ok,
       else: invalid(:model_start_authority)
  end

  defp start_contract(:tool_start, attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:capability_iri]),
         :ok <- ResourceIdentity.validate(attributes[:approval_iri]),
         :ok <- ResourceIdentity.validate(attributes[:effect_journal_iri]),
         true <- attributes[:dispatch_state] == :not_dispatched do
      :ok
    else
      _invalid -> invalid(:tool_start_authority)
    end
  end

  defp related_contract(nil), do: :ok

  defp related_contract(%{role: role, resource_iri: resource, graph_iri: graph}) do
    with {:ok, expected_family} <- Map.fetch(@accepted_related_families, role),
         :ok <- ResourceIdentity.validate(resource),
         {:ok, ^expected_family} <- GraphRegistry.identify(graph) do
      :ok
    else
      _invalid -> invalid(:immutable_event_related_family)
    end
  end

  defp related_contract(_related), do: invalid(:immutable_event_related_family)

  defp related_statements(%{related_role: nil}), do: []

  defp related_statements(event) do
    [
      {event.iri, @jf <> "relatedEvent", RDF.iri(event.related_resource_iri)},
      {event.iri, @jf <> "relatedEventRole",
       RDF.iri(@concept <> Macro.camelize(to_string(event.related_role)))},
      {event.iri, @jf <> "acceptedGraph", RDF.iri(event.related_graph_iri)}
    ]
  end

  defp authority(authority) do
    with :ok <- ResourceIdentity.validate(authority[:attempt_iri]),
         :ok <- ResourceIdentity.validate(authority[:lease_iri]),
         fence when is_integer(fence) and fence > 0 <- authority[:fencing_token],
         :ok <- ResourceIdentity.validate(authority[:context_iri]),
         revision when is_integer(revision) and revision >= 0 <- authority[:context_revision] do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:immutable_event_authority)
    end
  end

  defp definition(type) do
    case Map.fetch(@definitions, type) do
      {:ok, definition} -> {:ok, definition}
      :error -> :error
    end
  end

  defp identity(attempt_iri, type, attributes) do
    ResourceIdentity.deterministic(
      :execution_event,
      Enum.join(
        [
          "resource",
          attempt_iri,
          type,
          attributes.predecessor_head_iri,
          attributes.semantic_digest,
          attributes.resource_revision
        ],
        "\n"
      )
    )
  end

  defp safe_revision?(value) do
    is_binary(value) and byte_size(value) in 1..128 and
      not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
  end

  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, value), do: [{subject, predicate, RDF.iri(value)}]
  defp optional_integer(_subject, _predicate, nil), do: []

  defp optional_integer(subject, predicate, value),
    do: [{subject, predicate, RDF.XSD.NonNegativeInteger.new(value)}]

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, Error.new(:conflict, operation)}
end
