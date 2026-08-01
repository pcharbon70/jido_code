defmodule JidoCode.Knowledge.DerivedGraphManager do
  @moduledoc """
  Governed lifecycle for rebuildable derived named graphs.

  Publication verifies exact source revisions, builds and validates an isolated
  complete replacement, then commits through the semantic command pipeline.
  """

  alias JidoCode.Knowledge.ChangeFeed
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandPipeline
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.DerivationRequest
  alias JidoCode.Knowledge.DerivedAuthority
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Validation.Validator
  alias JidoCode.Knowledge.Writer

  @jf "https://jido.run/ontology/factory#"
  @spec publish(map(), keyword()) :: {:ok, CommandReceipt.t()} | {:error, Error.t()}
  def publish(attributes, options \\ [])

  def publish(attributes, options) when is_map(attributes) do
    writer = Keyword.get(options, :writer, Writer)

    with {:ok, request} <- DerivationRequest.new(attributes) do
      Writer.publish_derived(writer, request, options)
    end
  end

  def publish(_attributes, _options),
    do: {:error, Error.new(:invalid_input, :derivation_request)}

  @doc false
  @spec execute(DerivationRequest.t(), GenServer.server(), function(), integer(), atom()) ::
          {:ok, CommandReceipt.t(), CommandEnvelope.t()} | {:error, Error.t()}
  def execute(%DerivationRequest{} = request, store_server, clock, deadline, pubsub) do
    now = safe_clock(clock)
    graphs = snapshot_graphs(request)

    with %DateTime{} <- now,
         {:ok, snapshot} <- StoreServer.request(store_server, {:semantic_snapshot, graphs}),
         :ok <- exact_sources(request, snapshot),
         :ok <- expected_prior(request, snapshot),
         {:ok, target} <- build_target(request, snapshot, now, deadline),
         {:ok, envelope} <- command_envelope(request, snapshot, target, now),
         {:ok, receipt} <- CommandPipeline.execute(envelope, store_server, deadline) do
      ChangeFeed.publish(envelope, receipt, pubsub)
      {:ok, receipt, envelope}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :derived_graph_publish)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :derived_graph_publish)}
  end

  @spec status(map(), map()) ::
          {:ok, :current | :stale | :incompatible | :invalidated} | {:error, Error.t()}
  def status(metadata, current_graph_revisions) when is_map(current_graph_revisions) do
    current_sources =
      current_graph_revisions
      |> Enum.map(fn {graph, revision} -> %{graph: graph, revision: revision} end)

    DerivedAuthority.status(metadata, current_sources)
  end

  def status(_metadata, _current_revisions),
    do: {:error, Error.new(:invalid_input, :derived_graph_status)}

  defp snapshot_graphs(request) do
    prior =
      case request.expected_prior_derivation do
        %{graph_iri: graph} -> [graph]
        nil -> []
      end

    ([request.target_graph_iri] ++ Map.keys(request.source_graph_revisions) ++ prior)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp exact_sources(request, snapshot) do
    actual = Map.take(snapshot.graph_revisions, Map.keys(request.source_graph_revisions))

    valid? =
      case request.operation do
        :mark_stale -> actual != request.source_graph_revisions
        _publish_or_delete -> actual == request.source_graph_revisions
      end

    if valid?, do: :ok, else: {:error, Error.new(:stale_precondition, :derived_source_revisions)}
  end

  defp expected_prior(%{expected_prior_derivation: nil}, _snapshot), do: :ok

  defp expected_prior(request, snapshot) do
    prior = request.expected_prior_derivation

    if Map.get(snapshot.graph_revisions, prior.graph_iri) == prior.revision,
      do: :ok,
      else: {:error, Error.new(:stale_precondition, :prior_derivation)}
  end

  defp build_target(request, snapshot, now, deadline) do
    current_revision = Map.fetch!(snapshot.graph_revisions, request.target_graph_iri)
    existing = complete_existing(snapshot, request.target_graph_iri)
    operation = if existing == [], do: :create, else: :replace

    source_revisions =
      request.source_graph_revisions
      |> Enum.map(fn {graph, revision} -> %{graph: graph, revision: revision} end)
      |> Enum.sort_by(& &1.graph)

    invalidation_state =
      case request.operation do
        :publish -> :current
        :mark_stale -> :stale
        :delete -> :invalidated
      end

    metadata_attributes = %{
      owner_scope: request.scope_iri,
      ontology_version: "https://jido.run/ontology/release/#{request.ontology_version}",
      creation_activity: request.command_iri,
      created_at: now,
      lifecycle_state: :open,
      completeness_state: :complete,
      graph_revision: current_revision + 1,
      rule_set: request.rule_set_iri,
      invalidation_state: invalidation_state,
      source_graph_revisions: source_revisions,
      parent_graph: prior_graph(request)
    }

    with {:ok, metadata} <- GraphMetadata.new(request.target_graph_iri, metadata_attributes),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata),
         additions <- target_additions(request, existing, metadata_quads),
         :ok <- validate_isolated(request, metadata, additions, operation, deadline) do
      {:ok,
       %{
         family: :derived,
         graph_iri: request.target_graph_iri,
         operation: operation,
         metadata: metadata,
         additions: additions,
         removals: if(operation == :replace, do: existing, else: []),
         supersessions: [],
         invalidations: []
       }}
    end
  end

  defp target_additions(%{operation: :delete} = request, _existing, metadata_quads),
    do: metadata_quads ++ derivation_annotations(request)

  defp target_additions(%{operation: :mark_stale} = request, existing, metadata_quads) do
    metadata_quads ++ content_quads(existing) ++ derivation_annotations(request)
  end

  defp target_additions(request, _existing, metadata_quads) do
    metadata_quads ++
      Enum.map(request.statements, fn statement ->
        {subject, predicate, object} = RDF.Triple.new(statement)
        {subject, predicate, object, RDF.iri(request.target_graph_iri)}
      end) ++
      derivation_annotations(request)
  end

  defp derivation_annotations(request) do
    [
      RDF.quad(
        request.target_graph_iri,
        @jf <> "derivationQueryVersion",
        RDF.literal(request.query_version),
        request.target_graph_iri
      ),
      RDF.quad(
        request.target_graph_iri,
        @jf <> "ruleRevision",
        RDF.XSD.NonNegativeInteger.new(request.rule_revision),
        request.target_graph_iri
      )
    ]
  end

  defp content_quads(existing) do
    metadata_subject =
      existing
      |> List.first()
      |> case do
        nil -> nil
        {_s, _p, _o, g} -> g
      end

    references =
      existing
      |> Enum.flat_map(fn
        {^metadata_subject, %RDF.IRI{value: @jf <> "sourceGraphRevision"}, object, _graph} ->
          [object]

        _other ->
          []
      end)

    Enum.reject(existing, fn {subject, _predicate, _object, _graph} ->
      RDF.Term.equal_value?(subject, metadata_subject) or
        Enum.any?(references, &RDF.Term.equal_value?(subject, &1))
    end)
  end

  defp validate_isolated(request, metadata, additions, operation, deadline) do
    case Validator.validate(
           %{
             operation: operation,
             family: :derived,
             graph_iri: request.target_graph_iri,
             metadata: metadata,
             existing_metadata: if(operation == :replace, do: metadata, else: nil),
             additions: additions,
             existing: [],
             shape_version: request.shape_version
           },
           deadline_monotonic_ms: deadline
         ) do
      {:ok, _report} -> :ok
      {:error, %Error{} = error, _report} -> {:error, error}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp command_envelope(request, snapshot, target, now) do
    attributes = %{
      command_type: "PublishDerivedGraph",
      command_version: "1.1.0",
      command_iri: request.command_iri,
      principal_iri: request.authority.principal_iri,
      actor_iri: request.authority.actor_iri,
      delegated_agent_iri: request.authority.delegated_agent_iri,
      delegation_iri: request.authority.delegation_iri,
      scope_iri: request.scope_iri,
      idempotency_key: request.idempotency_key,
      correlation_iri: request.correlation_iri,
      causation_iri: request.causation_iri,
      ontology_version: request.ontology_version,
      shape_version: request.shape_version,
      expected_dataset_revision: snapshot.dataset_revision,
      expected_graph_revisions: %{
        request.target_graph_iri => Map.fetch!(snapshot.graph_revisions, request.target_graph_iri)
      },
      reason: request.reason,
      payload: %{changes: [target], guards: []}
    }

    CommandEnvelope.new(attributes, clock: fn -> now end)
  end

  defp graph_quads(dataset, graph_iri) do
    case RDF.Dataset.graph(dataset, RDF.iri(graph_iri)) do
      nil -> []
      graph -> RDF.Graph.quads(graph)
    end
  end

  defp complete_existing(snapshot, graph_iri) do
    exported = graph_quads(snapshot.dataset, graph_iri)

    metadata =
      case Map.get(snapshot.graph_metadata, graph_iri) do
        nil ->
          []

        graph_metadata ->
          case GraphMetadata.quads(graph_metadata) do
            {:ok, quads} -> quads
            {:error, _error} -> []
          end
      end

    Enum.uniq(exported ++ metadata)
  end

  defp prior_graph(%{expected_prior_derivation: %{graph_iri: graph}, target_graph_iri: target})
       when graph != target,
       do: graph

  defp prior_graph(_request), do: nil

  defp safe_clock(clock) do
    case clock.() do
      %DateTime{} = now -> DateTime.truncate(now, :microsecond)
      _invalid -> nil
    end
  rescue
    _error -> nil
  end
end
