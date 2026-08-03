defmodule JidoCode.Knowledge.Execution.InteractionMessage do
  @moduledoc "Durable, bounded interaction message that can only reference semantic commands."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.Graph
  alias JidoCode.Knowledge.ResourceIdentity

  @intents ~w[proposal clarification steering_request cancellation_request]a
  @classifications ~w[public internal confidential redacted]a
  @enforce_keys [
    :iri,
    :session_iri,
    :sender_iri,
    :audiences,
    :sequence,
    :content,
    :classification,
    :intent,
    :recorded_at,
    :provenance_iri
  ]
  defstruct @enforce_keys ++ [:reply_to_iri, :resulting_command_iri]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:session_iri]),
         :ok <- ResourceIdentity.validate(attributes[:sender_iri]),
         :ok <- ResourceIdentity.validate(attributes[:provenance_iri]),
         :ok <- resource_list(attributes[:audiences], 20),
         :ok <- optional_resource(attributes[:reply_to_iri]),
         :ok <- optional_resource(attributes[:resulting_command_iri]),
         sequence when is_integer(sequence) and sequence >= 0 <- attributes[:sequence],
         classification when classification in @classifications <- attributes[:classification],
         intent when intent in @intents <- attributes[:intent],
         {:ok, content} <- content(attributes[:content], classification),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :interaction_message,
             attributes.session_iri <> "\n" <> Integer.to_string(sequence)
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         session_iri: attributes.session_iri,
         sender_iri: attributes.sender_iri,
         audiences: Enum.sort(attributes.audiences),
         sequence: sequence,
         content: content,
         classification: classification,
         intent: intent,
         recorded_at: DateTime.truncate(recorded_at, :microsecond),
         provenance_iri: attributes.provenance_iri,
         reply_to_iri: attributes[:reply_to_iri],
         resulting_command_iri: attributes[:resulting_command_iri]
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:interaction_message)
    end
  rescue
    _error -> invalid(:interaction_message)
  end

  def new(_attributes), do: invalid(:interaction_message)

  @spec record_command(t(), map(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), message: t()}} | {:error, Error.t()}
  def record_command(message, session_resolution, attributes, options \\ [])

  def record_command(
        %__MODULE__{} = message,
        %{domain: :interaction_session, current_state: :active} = session_resolution,
        attributes,
        options
      )
      when is_map(attributes) and is_list(options) do
    with true <- session_resolution.subject_iri == message.session_iri,
         {:ok, target} <- target(attributes, statements(message)),
         guards = [
           {:transition_endpoint, attributes.graph_iri, message.session_iri,
            session_resolution.current_transition},
           {:subject_absent, attributes.graph_iri, message.iri}
         ],
         {:ok, command} <-
           CommandEnvelope.new(envelope(message, attributes, target, guards), options) do
      {:ok, %{command: command, message: message}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_interaction_message)
    end
  rescue
    _error -> invalid(:record_interaction_message)
  end

  def record_command(_message, _resolution, _attributes, _options),
    do: invalid(:record_interaction_message)

  defp statements(message) do
    [
      {message.iri, @rdf_type, RDF.iri(@jf <> "Message")},
      {message.iri, @jf <> "validFor", RDF.iri(message.session_iri)},
      {message.iri, @prov <> "wasAssociatedWith", RDF.iri(message.sender_iri)},
      {message.iri, @jf <> "sequence", RDF.XSD.NonNegativeInteger.new(message.sequence)},
      {message.iri, @jf <> "content", RDF.XSD.String.new(message.content)},
      {message.iri, @jf <> "contentClassification",
       RDF.iri(@concept <> Macro.camelize(to_string(message.classification)))},
      {message.iri, @jf <> "messageIntent",
       RDF.iri(@concept <> Macro.camelize(to_string(message.intent)))},
      {message.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(message.recorded_at)},
      {message.iri, @prov <> "wasDerivedFrom", RDF.iri(message.provenance_iri)}
    ] ++
      Enum.map(message.audiences, &{message.iri, @jf <> "audience", RDF.iri(&1)}) ++
      optional_statement(message.iri, @jf <> "replyTo", message.reply_to_iri) ++
      optional_statement(message.iri, @jf <> "resultingCommand", message.resulting_command_iri)
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

  defp envelope(message, attributes, target, guards) do
    %{
      command_type: "RecordInteractionMessage",
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
      payload: %{changes: [target], guards: guards, message_iri: message.iri}
    }
  end

  defp content(_content, :redacted), do: {:ok, "[REDACTED]"}

  defp content(value, _classification) when is_binary(value) do
    normalized = value |> String.trim() |> :unicode.characters_to_nfc_binary()

    if normalized != "" and byte_size(normalized) <= 4_096 and not secret_marker?(normalized),
      do: {:ok, normalized},
      else: invalid(:interaction_message_content)
  end

  defp content(_value, _classification), do: invalid(:interaction_message_content)

  defp secret_marker?(value) do
    Regex.match?(
      ~r/(?:BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,})/,
      value
    )
  end

  defp resource_list(values, maximum)
       when is_list(values) and length(values) in 1..maximum//1 do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)), do: :ok, else: :error
  end

  defp resource_list(_values, _maximum), do: :error
  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: ResourceIdentity.validate(value)
  defp optional_statement(_subject, _predicate, nil), do: []
  defp optional_statement(subject, predicate, object), do: [{subject, predicate, RDF.iri(object)}]
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
