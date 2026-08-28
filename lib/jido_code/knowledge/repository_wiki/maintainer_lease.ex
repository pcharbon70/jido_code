defmodule JidoCode.Knowledge.RepositoryWiki.MaintainerLease do
  @moduledoc "Graph-authoritative wiki maintainer lease and monotonically increasing fence."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Command
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :repository_iri,
    :tenant_iri,
    :holder_iri,
    :profile_digest,
    :enrollment_revision,
    :cancellation_generation,
    :generation,
    :fence,
    :state,
    :acquired_at,
    :heartbeat_at,
    :expires_at,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec acquire(map(), t() | nil) :: {:ok, t()} | {:duplicate, t()} | {:error, atom()}
  def acquire(attributes, current \\ nil)

  def acquire(attributes, nil) when is_map(attributes), do: build(attributes, 1)

  def acquire(attributes, %__MODULE__{} = current) when is_map(attributes) do
    cond do
      current.holder_iri == attributes[:holder_iri] and current.state == :active and
        current.enrollment_revision == attributes[:enrollment_revision] and
        current.cancellation_generation == attributes[:cancellation_generation] and
          DateTime.compare(attributes[:acquired_at], current.expires_at) == :lt ->
        {:duplicate, current}

      current.state == :active and
          DateTime.compare(attributes[:acquired_at], current.expires_at) == :lt ->
        {:error, :owned}

      true ->
        build(attributes, current.generation + 1)
    end
  end

  def acquire(_attributes, _current), do: {:error, :invalid}

  @spec renew(t(), map()) :: {:ok, t()} | {:error, atom()}
  def renew(%__MODULE__{state: :active} = lease, attributes) when is_map(attributes) do
    with true <- lease.holder_iri == attributes[:holder_iri],
         true <- lease.generation == attributes[:generation],
         true <- lease.fence == attributes[:fence],
         true <- lease.enrollment_revision == attributes[:enrollment_revision],
         true <- lease.profile_digest == attributes[:profile_digest],
         true <- lease.cancellation_generation == attributes[:cancellation_generation],
         %DateTime{} = heartbeat <- attributes[:heartbeat_at],
         %DateTime{} = expires <- attributes[:expires_at],
         true <- DateTime.compare(heartbeat, lease.expires_at) == :lt,
         true <- DateTime.compare(heartbeat, expires) == :lt do
      value = %{lease | heartbeat_at: heartbeat, expires_at: expires}
      {:ok, %{value | digest: lease_digest(value)}}
    else
      _invalid -> {:error, :stale}
    end
  end

  def renew(%__MODULE__{}, _attributes), do: {:error, :inactive}
  def renew(_lease, _attributes), do: {:error, :invalid}

  @spec revoke(t(), non_neg_integer(), DateTime.t()) :: {:ok, t()} | {:error, atom()}
  def revoke(%__MODULE__{state: :active} = lease, cancellation_generation, %DateTime{} = at)
      when is_integer(cancellation_generation) and
             cancellation_generation > lease.cancellation_generation do
    value = %{
      lease
      | state: :revoked,
        cancellation_generation: cancellation_generation,
        heartbeat_at: at,
        expires_at: at
    }

    {:ok, %{value | digest: lease_digest(value)}}
  end

  def revoke(%__MODULE__{}, _generation, %DateTime{}), do: {:error, :stale_cancellation}
  def revoke(_lease, _generation, _at), do: {:error, :invalid}

  @spec current?(t(), map(), DateTime.t()) :: boolean()
  def current?(%__MODULE__{} = lease, context, %DateTime{} = at) when is_map(context) do
    lease.state == :active and DateTime.compare(at, lease.expires_at) == :lt and
      lease.enrollment_revision == context[:enrollment_revision] and
      lease.profile_digest == context[:profile_digest] and
      lease.cancellation_generation == context[:cancellation_generation]
  end

  @spec acquire_command(t(), map(), keyword()) ::
          {:ok, JidoCode.Knowledge.CommandEnvelope.t()} | {:error, Error.t()}
  def acquire_command(lease, attributes, options \\ [])

  def acquire_command(%__MODULE__{state: :active} = lease, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:control_graph_iri]
    revision = attributes[:expected_control_revision]

    with {:ok, :repository_control} <- GraphRegistry.identify(graph),
         true <- is_integer(revision) and revision > 0,
         target = %{
           family: :repository_control,
           graph_iri: graph,
           operation: :append,
           metadata: %{lifecycle_state: :open},
           additions: statements(lease),
           supersessions: [],
           invalidations: [],
           removals: []
         },
         guards = [
           {:subject_absent, graph, lease.iri},
           {:predicate_absent, graph, lease.repository_iri,
            "https://jido.run/ontology/factory#currentWikiMaintainerFence"}
         ],
         command_attributes <-
           attributes
           |> Map.put(:command_version, Protocol.runtime_semantic_version())
           |> Map.put(:repository_iri, lease.repository_iri)
           |> Map.put(:expected_graph_revisions, %{graph => revision}),
         {:ok, command} <-
           Command.build(
             "AcquireWikiMaintainerLease",
             lease.digest,
             [target],
             guards,
             command_attributes,
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :acquire_wiki_maintainer_lease)}
    end
  end

  def acquire_command(_lease, _attributes, _options),
    do: {:error, Error.new(:invalid_input, :acquire_wiki_maintainer_lease)}

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = lease) do
    jf = "https://jido.run/ontology/factory#"
    {:ok, wiki_iri} = ResourceIdentity.repository_wiki(lease.repository_iri)

    [
      {lease.iri, RDF.type(), RDF.iri(jf <> "WikiMaintainer")},
      {lease.iri, jf <> "repositoryScope", RDF.iri(lease.repository_iri)},
      {lease.iri, jf <> "tenantScope", RDF.iri(lease.tenant_iri)},
      {lease.iri, jf <> "repositoryWiki", RDF.iri(wiki_iri)},
      {lease.iri, jf <> "profileRevision", RDF.XSD.NonNegativeInteger.new(lease.generation)},
      {lease.iri, jf <> "profileDigest", RDF.XSD.String.new(lease.profile_digest)},
      {lease.iri, jf <> "maintainerState", RDF.iri(Contract.concept(:wiki_maintainer_active))},
      {lease.iri, jf <> "generatedAtTime", RDF.XSD.DateTime.new(lease.acquired_at)},
      {lease.iri, jf <> "expiresAt", RDF.XSD.DateTime.new(lease.expires_at)}
    ]
  end

  defp build(attributes, generation) do
    with :ok <- resources(attributes),
         true <- Contract.digest?(attributes[:profile_digest]),
         revision when is_integer(revision) and revision >= 0 <- attributes[:enrollment_revision],
         cancellation when is_integer(cancellation) and cancellation >= 0 <-
           attributes[:cancellation_generation],
         %DateTime{} = acquired_at <- attributes[:acquired_at],
         %DateTime{} = expires_at <- attributes[:expires_at],
         true <- DateTime.compare(acquired_at, expires_at) == :lt,
         fence <-
           Contract.digest(%{repository: attributes.repository_iri, generation: generation}),
         material <- %{
           repository_iri: attributes.repository_iri,
           tenant_iri: attributes.tenant_iri,
           holder_iri: attributes.holder_iri,
           profile_digest: attributes.profile_digest,
           enrollment_revision: revision,
           cancellation_generation: cancellation,
           generation: generation,
           fence: fence,
           state: :active,
           acquired_at: DateTime.truncate(acquired_at, :microsecond),
           heartbeat_at: DateTime.truncate(acquired_at, :microsecond),
           expires_at: expires_at
         },
         digest <- Contract.digest(material),
         {:ok, iri} <- ResourceIdentity.deterministic(:wiki_maintainer, digest) do
      {:ok, struct!(__MODULE__, material |> Map.put(:iri, iri) |> Map.put(:digest, digest))}
    else
      {:error, %Error{}} -> {:error, :invalid}
      _invalid -> {:error, :invalid}
    end
  rescue
    _error -> {:error, :invalid}
  end

  defp resources(attributes) do
    Enum.reduce_while(~w[repository_iri tenant_iri holder_iri]a, :ok, fn key, :ok ->
      case Contract.resource(attributes[key]) do
        :ok -> {:cont, :ok}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp lease_digest(lease),
    do: lease |> Map.from_struct() |> Map.delete(:digest) |> Contract.digest()
end
