defmodule JidoCode.Knowledge.Control.ToolDefinition do
  @moduledoc """
  Closed, versioned model-facing tool contracts pinned by schema and
  supply-chain digests.

  A tool definition records the tool's stable name and version, input and
  output schema digests, effect class, adapter identity digest, approval
  requirement, and bounded timeout. It contains no executable content and no
  raw arguments; effects are authorized separately through the reference
  monitor from the lease-derived capability.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :tool_name,
    :tool_version,
    :input_schema_digest,
    :output_schema_digest,
    :effect_class,
    :adapter_digest,
    :approval_required,
    :timeout_ms
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @effect_classes ~w[read write external publish]a
  @name_format ~r/^[a-z][a-z0-9_]*$/
  @version_format ~r/^[0-9]+\.[0-9]+\.[0-9]+$/
  @digest ~r/^sha256:[a-f0-9]{64}$/

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with tool_name when is_binary(tool_name) and byte_size(tool_name) in 1..64 <-
           attributes[:tool_name],
         true <- Regex.match?(@name_format, tool_name),
         tool_version when is_binary(tool_version) and byte_size(tool_version) in 1..32 <-
           attributes[:tool_version],
         true <- Regex.match?(@version_format, tool_version),
         true <- digest?(attributes[:input_schema_digest]),
         true <- digest?(attributes[:output_schema_digest]),
         effect_class when effect_class in @effect_classes <- attributes[:effect_class],
         true <- digest?(attributes[:adapter_digest]),
         approval_required when is_boolean(approval_required) <-
           attributes[:approval_required],
         timeout_ms when is_integer(timeout_ms) and timeout_ms in 1..3_600_000 <-
           attributes[:timeout_ms],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :tool_definition_revision,
             tool_name <> "\n" <> tool_version
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         tool_name: tool_name,
         tool_version: tool_version,
         input_schema_digest: attributes.input_schema_digest,
         output_schema_digest: attributes.output_schema_digest,
         effect_class: effect_class,
         adapter_digest: attributes.adapter_digest,
         approval_required: approval_required,
         timeout_ms: timeout_ms
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:tool_definition)
    end
  rescue
    _error -> invalid(:tool_definition)
  end

  def new(_attributes), do: invalid(:tool_definition)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = definition) do
    [
      {definition.iri, @rdf_type, RDF.iri(@jf <> "ToolDefinitionRevision")},
      {definition.iri, @jf <> "toolName", RDF.XSD.String.new(definition.tool_name)},
      {definition.iri, @jf <> "toolVersion", RDF.XSD.String.new(definition.tool_version)},
      {definition.iri, @jf <> "inputSchemaDigest",
       RDF.XSD.String.new(definition.input_schema_digest)},
      {definition.iri, @jf <> "outputSchemaDigest",
       RDF.XSD.String.new(definition.output_schema_digest)},
      {definition.iri, @jf <> "effectClass",
       RDF.iri(@concept <> Macro.camelize(to_string(definition.effect_class)))},
      {definition.iri, @jf <> "adapterDigest", RDF.XSD.String.new(definition.adapter_digest)},
      {definition.iri, @jf <> "approvalRequired",
       RDF.XSD.Boolean.new(definition.approval_required)},
      {definition.iri, @jf <> "toolTimeoutMs",
       RDF.XSD.NonNegativeInteger.new(definition.timeout_ms)}
    ]
  end

  @spec publish_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def publish_command(definition, attributes, options \\ [])

  def publish_command(%__MODULE__{} = definition, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <-
           is_integer(attributes[:expected_policy_revision]) and
             attributes[:expected_policy_revision] > 0,
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, definition.iri <> "\npublish"),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope("PublishToolDefinition", command_iri, definition, attributes, graph, [
               %{
                 family: :factory_policy,
                 graph_iri: graph,
                 operation: :append,
                 metadata: %{lifecycle_state: :open},
                 additions: statements(definition),
                 supersessions: [],
                 invalidations: [],
                 removals: []
               }
             ]),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:publish_tool_definition)
    end
  end

  def publish_command(_definition, _attributes, _options),
    do: invalid(:publish_tool_definition)

  defp envelope(type, command_iri, definition, attributes, graph, changes) do
    %{
      command_type: type,
      command_version: "1.8.0",
      command_iri: command_iri,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:scope_iri],
      idempotency_key: command_iri,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: %{graph => attributes[:expected_policy_revision]},
      reason: attributes[:reason],
      payload: %{changes: changes, guards: [{:subject_absent, graph, definition.iri}]}
    }
  end

  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
