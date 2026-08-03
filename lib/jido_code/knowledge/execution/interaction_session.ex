defmodule JidoCode.Knowledge.Execution.InteractionSession do
  @moduledoc "Graph-native lifecycle for bounded human and agent interaction."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.Graph
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :scope_iri,
    :enrollment_iri,
    :participants,
    :audiences,
    :authority_iri,
    :purpose,
    :opened_at
  ]
  defstruct @enforce_keys ++ [:transition]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:scope_iri]),
         :ok <- ResourceIdentity.validate(attributes[:enrollment_iri]),
         :ok <- ResourceIdentity.validate(attributes[:authority_iri]),
         :ok <- resource_list(attributes[:participants], 20),
         :ok <- resource_list(attributes[:audiences], 20),
         purpose when is_binary(purpose) and byte_size(purpose) in 1..512 <- attributes[:purpose],
         %DateTime{} = opened_at <- attributes[:opened_at],
         key when is_binary(key) and byte_size(key) in 1..256 <- attributes[:idempotency_key],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :interaction_session,
             attributes.scope_iri <> "\n" <> key
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         scope_iri: attributes.scope_iri,
         enrollment_iri: attributes.enrollment_iri,
         participants: Enum.sort(attributes.participants),
         audiences: Enum.sort(attributes.audiences),
         authority_iri: attributes.authority_iri,
         purpose: String.trim(purpose),
         opened_at: DateTime.truncate(opened_at, :microsecond)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:interaction_session)
    end
  rescue
    _error -> invalid(:interaction_session)
  end

  def new(_attributes), do: invalid(:interaction_session)

  @spec open_command(t(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), session: t(), transitions: [Transition.t()]}}
          | {:error, Error.t()}
  def open_command(session, attributes, options \\ [])

  def open_command(%__MODULE__{} = session, attributes, options)
      when is_map(attributes) and is_list(options) do
    with {:ok, proposed} <- transition(session, nil, :proposed, 0, nil, attributes),
         {:ok, active} <- transition(session, :proposed, :active, 1, proposed.iri, attributes),
         transitions = [proposed, active],
         session = %{session | transition: active},
         additions = statements(session) ++ Enum.flat_map(transitions, &Transition.statements/1),
         {:ok, target} <- target(attributes, additions),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "OpenInteractionSession",
               session,
               attributes,
               target,
               [Transition.guard(proposed, attributes.graph_iri)]
             ),
             options
           ) do
      {:ok, %{command: command, session: session, transitions: transitions}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:open_interaction_session)
    end
  rescue
    _error -> invalid(:open_interaction_session)
  end

  def open_command(_session, _attributes, _options), do: invalid(:open_interaction_session)

  @spec transition_command(t(), map(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), transition: Transition.t()}} | {:error, Error.t()}
  def transition_command(session, resolution, attributes, options \\ [])

  def transition_command(
        %__MODULE__{} = session,
        %{domain: :interaction_session, current_state: :active} = resolution,
        %{action: action} = attributes,
        options
      )
      when action in [:close, :cancel] and is_list(options) do
    next_state = if action == :close, do: :closed, else: :cancelled

    with true <- resolution.subject_iri == session.iri,
         {:ok, transition} <-
           transition(
             session,
             :active,
             next_state,
             resolution.current_revision + 1,
             resolution.current_transition,
             attributes
           ),
         {:ok, target} <- target(attributes, Transition.statements(transition)),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "TransitionInteractionSession",
               session,
               attributes,
               target,
               [Transition.guard(transition, attributes.graph_iri)]
             ),
             options
           ) do
      {:ok, %{command: command, transition: transition}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_interaction_session)
    end
  rescue
    _error -> invalid(:transition_interaction_session)
  end

  def transition_command(_session, _resolution, _attributes, _options),
    do: invalid(:transition_interaction_session)

  defp transition(session, prior, next, revision, predecessor, attributes) do
    Transition.new(%{
      subject_iri: session.iri,
      domain: :interaction_session,
      prior_state: prior,
      next_state: next,
      revision: revision,
      expected_predecessor: predecessor,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:causation_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp statements(session) do
    [
      {session.iri, @rdf_type, RDF.iri(@jf <> "InteractionSession")},
      {session.iri, @jf <> "scopedTo", RDF.iri(session.scope_iri)},
      {session.iri, @jf <> "validFor", RDF.iri(session.enrollment_iri)},
      {session.iri, @jf <> "decisionAuthority", RDF.iri(session.authority_iri)},
      {session.iri, @jf <> "purpose", RDF.XSD.String.new(session.purpose)},
      {session.iri, @prov <> "startedAtTime", RDF.XSD.DateTime.new(session.opened_at)},
      {session.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(session.opened_at)}
    ] ++
      Enum.map(session.participants, &{session.iri, @jf <> "participant", RDF.iri(&1)}) ++
      Enum.map(session.audiences, &{session.iri, @jf <> "audience", RDF.iri(&1)})
  end

  defp target(attributes, additions) do
    Graph.append_target(
      attributes.graph_iri,
      attributes.expected_graph_revision,
      attributes.repository_scope_iri,
      attributes.command_iri,
      attributes.recorded_at,
      additions
    )
  end

  defp envelope(type, session, attributes, target, guards) do
    %{
      command_type: type,
      command_version: "1.6.0",
      command_iri: attributes[:command_iri],
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:repository_scope_iri],
      idempotency_key: attributes[:idempotency_key],
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: %{attributes.graph_iri => attributes.expected_graph_revision},
      reason: attributes[:reason],
      payload: %{changes: [target], guards: guards, session_iri: session.iri}
    }
  end

  defp resource_list(values, maximum)
       when is_list(values) and length(values) in 1..maximum//1 do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)), do: :ok, else: :error
  end

  defp resource_list(_values, _maximum), do: :error
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
