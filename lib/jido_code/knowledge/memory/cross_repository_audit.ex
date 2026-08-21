defmodule JidoCode.Knowledge.Memory.CrossRepositoryAudit do
  @moduledoc "Payload-free audit evidence for cross-repository operations and denials."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @operations ~w[query export omission denial revocation expiry]a
  @statuses ~w[allowed denied omitted revoked expired]a
  @forbidden_keys ~w[payload plaintext exact_content prompt body bytes released_bytes]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"

  @enforce_keys [
    :iri,
    :revision,
    :authorization_iri,
    :actor_iri,
    :operation,
    :status,
    :repository_iris,
    :selected_resource_iris,
    :omitted_count,
    :reason,
    :recorded_at
  ]
  defstruct @enforce_keys

  def new(attributes) when is_map(attributes) do
    with true <- Enum.all?(@forbidden_keys, &(not Map.has_key?(attributes, &1))),
         :ok <- ResourceIdentity.validate(attributes[:authorization_iri]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         true <- attributes[:operation] in @operations,
         true <- attributes[:status] in @statuses,
         {:ok, repositories} <- resources(attributes[:repository_iris], 50),
         {:ok, selected} <- resources(attributes[:selected_resource_iris], 200),
         true <- is_integer(attributes[:omitted_count]) and attributes[:omitted_count] >= 0,
         true <- safe_reason?(attributes[:reason]),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         {:ok, iri} <- identity(attributes, repositories, selected) do
      {:ok,
       struct!(__MODULE__,
         iri: iri,
         revision: @revision,
         authorization_iri: attributes.authorization_iri,
         actor_iri: attributes.actor_iri,
         operation: attributes.operation,
         status: attributes.status,
         repository_iris: repositories,
         selected_resource_iris: selected,
         omitted_count: attributes.omitted_count,
         reason: attributes.reason,
         recorded_at: DateTime.truncate(recorded_at, :microsecond)
       )}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  def statements(%__MODULE__{} = audit) do
    [
      {audit.iri, @rdf_type, RDF.iri(@jf <> "CrossRepositoryAudit")},
      {audit.iri, @jf <> "authorization", RDF.iri(audit.authorization_iri)},
      {audit.iri, @jf <> "actor", RDF.iri(audit.actor_iri)},
      {audit.iri, @jf <> "operation", concept(audit.operation)},
      {audit.iri, @jf <> "status", concept(audit.status)},
      {audit.iri, @jf <> "omittedCount", RDF.XSD.NonNegativeInteger.new(audit.omitted_count)},
      {audit.iri, @jf <> "reason", RDF.XSD.String.new(audit.reason)},
      {audit.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(audit.recorded_at)}
    ] ++
      Enum.map(audit.repository_iris, &{audit.iri, @jf <> "repository", RDF.iri(&1)}) ++
      Enum.map(audit.selected_resource_iris, &{audit.iri, @jf <> "selectedResource", RDF.iri(&1)})
  end

  defp identity(attributes, repositories, selected) do
    ResourceIdentity.deterministic(
      :cross_repository_audit,
      Enum.join(
        [
          attributes.authorization_iri,
          attributes.actor_iri,
          Atom.to_string(attributes.operation),
          Atom.to_string(attributes.status),
          Enum.join(repositories, "\n"),
          Enum.join(selected, "\n"),
          Integer.to_string(attributes.omitted_count),
          attributes.reason,
          DateTime.to_iso8601(attributes.recorded_at)
        ],
        "\n"
      )
    )
  end

  defp resources(values, maximum) when is_list(values) do
    normalized = Enum.uniq(values) |> Enum.sort()

    if length(normalized) <= maximum and
         Enum.all?(normalized, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, normalized},
       else: :error
  end

  defp resources(_values, _maximum), do: :error
  defp safe_reason?(value), do: is_binary(value) and byte_size(value) in 1..512

  defp concept(value),
    do: RDF.iri("https://jido.run/ontology/concept/" <> Macro.camelize(to_string(value)))

  defp invalid, do: {:error, Error.new(:invalid_input, :cross_repository_audit)}
end
