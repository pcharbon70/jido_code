defmodule JidoCode.Knowledge.Memory.ContentAccessPermit do
  @moduledoc "Purpose-bound, expiring, single-use authorization for exact content release."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @enforce_keys [
    :iri,
    :revision,
    :actor_iri,
    :purpose,
    :task_iri,
    :scope_iri,
    :authorization_iri,
    :authorization_revision,
    :reviewed_query,
    :query_version,
    :parameters_digest,
    :content_iri,
    :content_version,
    :representation,
    :byte_range,
    :sink,
    :destination,
    :method,
    :expires_at,
    :issued_at,
    :data_ceiling,
    :state,
    :agent_context
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @revision "1.0.0"
  @purposes ~w[managed_continuity failure_recovery incident_response evaluation]a
  @sinks ~w[agent_context bounded_artifact approved_export authorized_ui]a
  @methods ~w[read stream]a
  @representations ~w[exact_content exact_text exact_binary]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  def revision, do: @revision

  def new(attributes) when is_map(attributes) do
    with :ok <-
           resources(
             attributes,
             ~w[actor_iri task_iri scope_iri authorization_iri content_iri]a
           ),
         true <- attributes[:purpose] in @purposes,
         true <- positive_integer?(attributes[:authorization_revision]),
         true <- query?(attributes[:reviewed_query], attributes[:query_version]),
         true <- is_map(attributes[:parameters]),
         true <- version?(attributes[:content_version]),
         true <- attributes[:representation] in @representations,
         true <- byte_range?(attributes[:byte_range]),
         true <- attributes[:sink] in @sinks,
         true <- text?(attributes[:destination], 512),
         true <- attributes[:method] in @methods,
         true <- attributes[:data_ceiling] in DataPolicy.classifications(),
         %DateTime{} = issued_at <- attributes[:issued_at],
         %DateTime{} = expires_at <- attributes[:expires_at],
         true <- DateTime.compare(issued_at, expires_at) == :lt,
         true <- DateTime.diff(expires_at, issued_at, :second) in 1..900,
         {:ok, agent_context} <- agent_context(attributes[:sink], attributes[:agent_context]),
         parameters_digest = digest_term(attributes.parameters),
         {:ok, iri} <- identity(attributes, parameters_digest, agent_context) do
      {:ok,
       %__MODULE__{
         iri: iri,
         revision: @revision,
         actor_iri: attributes.actor_iri,
         purpose: attributes.purpose,
         task_iri: attributes.task_iri,
         scope_iri: attributes.scope_iri,
         authorization_iri: attributes.authorization_iri,
         authorization_revision: attributes.authorization_revision,
         reviewed_query: attributes.reviewed_query,
         query_version: attributes.query_version,
         parameters_digest: parameters_digest,
         content_iri: attributes.content_iri,
         content_version: attributes.content_version,
         representation: attributes.representation,
         byte_range: attributes.byte_range,
         sink: attributes.sink,
         destination: attributes.destination,
         method: attributes.method,
         expires_at: expires_at,
         issued_at: issued_at,
         data_ceiling: attributes.data_ceiling,
         state: :authorized,
         agent_context: agent_context
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :content_access_permit)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :content_access_permit)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :content_access_permit)}

  def recheck(%__MODULE__{} = permit, context) when is_map(context) do
    checks = [
      permit.state == :authorized,
      context[:permit_consumed?] == false,
      context[:authorization_decision] == :allowed,
      context[:authorization_iri] == permit.authorization_iri,
      context[:authorization_revision] == permit.authorization_revision,
      context[:authorization_revoked?] == false,
      context[:actor_iri] == permit.actor_iri,
      context[:scope_iri] == permit.scope_iri,
      context[:purpose] == permit.purpose,
      context[:content_iri] == permit.content_iri,
      context[:content_version] == permit.content_version,
      context[:representation] == permit.representation,
      context[:byte_range] == permit.byte_range,
      context[:sink] == permit.sink,
      context[:destination] == permit.destination,
      context[:method] == permit.method,
      context[:data_ceiling] == permit.data_ceiling,
      context[:lifecycle_state] in [:active, :cold],
      context[:hold_access_allowed?] == true,
      match?(%DateTime{}, context[:now]) and
        DateTime.compare(context.now, permit.expires_at) == :lt,
      context[:maximum_release_bytes] >= permit.byte_range.length,
      agent_context_current?(permit.agent_context, context[:agent_context])
    ]

    if Enum.all?(checks), do: :ok, else: {:error, Error.new(:unauthorized, :content_access)}
  rescue
    _error -> {:error, Error.new(:unauthorized, :content_access)}
  end

  def recheck(_permit, _context), do: {:error, Error.new(:unauthorized, :content_access)}

  def statements(%__MODULE__{} = permit) do
    [
      {permit.iri, @rdf_type, RDF.iri(@jf <> "ContentAccessPermit")},
      {permit.iri, @jf <> "authorizedActor", RDF.iri(permit.actor_iri)},
      {permit.iri, @jf <> "purpose", RDF.XSD.String.new(to_string(permit.purpose))},
      {permit.iri, @jf <> "task", RDF.iri(permit.task_iri)},
      {permit.iri, @jf <> "scope", RDF.iri(permit.scope_iri)},
      {permit.iri, @jf <> "authorization", RDF.iri(permit.authorization_iri)},
      {permit.iri, @jf <> "authorizationRevision",
       RDF.XSD.NonNegativeInteger.new(permit.authorization_revision)},
      {permit.iri, @jf <> "reviewedQuery", RDF.XSD.String.new(to_string(permit.reviewed_query))},
      {permit.iri, @jf <> "queryVersion", RDF.XSD.String.new(permit.query_version)},
      {permit.iri, @jf <> "parametersDigest", RDF.XSD.String.new(permit.parameters_digest)},
      {permit.iri, @jf <> "selectedContent", RDF.iri(permit.content_iri)},
      {permit.iri, @jf <> "contentVersion", RDF.XSD.String.new(permit.content_version)},
      {permit.iri, @jf <> "representation",
       RDF.iri(@concept <> Macro.camelize(to_string(permit.representation)))},
      {permit.iri, @jf <> "rangeOffset",
       RDF.XSD.NonNegativeInteger.new(permit.byte_range.offset)},
      {permit.iri, @jf <> "rangeLength",
       RDF.XSD.NonNegativeInteger.new(permit.byte_range.length)},
      {permit.iri, @jf <> "sink", RDF.XSD.String.new(to_string(permit.sink))},
      {permit.iri, @jf <> "destination", RDF.XSD.String.new(permit.destination)},
      {permit.iri, @jf <> "accessMethod", RDF.XSD.String.new(to_string(permit.method))},
      {permit.iri, @jf <> "dataCeiling", RDF.XSD.String.new(to_string(permit.data_ceiling))},
      {permit.iri, @jf <> "issuedAt", RDF.XSD.DateTime.new(permit.issued_at)},
      {permit.iri, @jf <> "expiresAt", RDF.XSD.DateTime.new(permit.expires_at)},
      {permit.iri, @jf <> "permitState", RDF.iri(@concept <> "Authorized")}
    ] ++ agent_statements(permit)
  end

  defp identity(attributes, parameters_digest, agent_context) do
    material =
      attributes
      |> Map.drop([:parameters, :agent_context])
      |> Map.put(:parameters_digest, parameters_digest)
      |> Map.put(:agent_context, agent_context)

    ResourceIdentity.deterministic(
      :content_access_permit,
      :erlang.term_to_binary(material, [:deterministic])
    )
  end

  defp agent_context(:agent_context, value) when is_map(value) do
    keys = ~w[attempt_iri lease_iri context_iri invocation_iri model_access_profile_iri]a

    with true <- Enum.all?(keys, &(ResourceIdentity.validate(value[&1]) == :ok)),
         true <- is_integer(value[:fence]) and value.fence >= 0 do
      {:ok, Map.take(value, keys ++ [:fence])}
    else
      _invalid -> {:error, Error.new(:invalid_input, :content_access_agent_context)}
    end
  end

  defp agent_context(:agent_context, _value),
    do: {:error, Error.new(:invalid_input, :content_access_agent_context)}

  defp agent_context(_sink, nil), do: {:ok, nil}

  defp agent_context(_sink, _value),
    do: {:error, Error.new(:invalid_input, :content_access_agent_context)}

  defp agent_context_current?(nil, nil), do: true
  defp agent_context_current?(expected, current), do: expected == current

  defp agent_statements(%{agent_context: nil}), do: []

  defp agent_statements(permit) do
    context = permit.agent_context

    [
      {permit.iri, @jf <> "attempt", RDF.iri(context.attempt_iri)},
      {permit.iri, @jf <> "lease", RDF.iri(context.lease_iri)},
      {permit.iri, @jf <> "fence", RDF.XSD.NonNegativeInteger.new(context.fence)},
      {permit.iri, @jf <> "executionContext", RDF.iri(context.context_iri)},
      {permit.iri, @jf <> "modelInvocation", RDF.iri(context.invocation_iri)},
      {permit.iri, @jf <> "modelAccessProfile", RDF.iri(context.model_access_profile_iri)}
    ]
  end

  defp resources(attributes, keys),
    do:
      if(Enum.all?(keys, &(ResourceIdentity.validate(attributes[&1]) == :ok)),
        do: :ok,
        else: :error
      )

  defp query?(name, version), do: is_atom(name) and version?(version)
  defp version?(value), do: is_binary(value) and Regex.match?(~r/^\d+\.\d+\.\d+$/, value)

  defp byte_range?(%{offset: offset, length: length}),
    do: is_integer(offset) and offset >= 0 and is_integer(length) and length > 0

  defp byte_range?(_value), do: false
  defp positive_integer?(value), do: is_integer(value) and value > 0
  defp text?(value, max), do: is_binary(value) and byte_size(value) in 1..max

  defp digest_term(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
