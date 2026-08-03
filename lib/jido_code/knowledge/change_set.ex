defmodule JidoCode.Knowledge.ChangeSet do
  @moduledoc """
  Canonical, transient representation of one logical semantic graph delta.

  Ordinary change sets are append-first. Supersession and invalidation are RDF
  additions; removals are admitted only through an explicit maintenance port.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Vocabulary

  @derive {Inspect,
           only: [
             :change_set_iri,
             :command_iri,
             :actor_iri,
             :scope_iri,
             :request_fingerprint,
             :target_graphs,
             :assertion_count,
             :supersession_count,
             :invalidation_count
           ]}
  @enforce_keys [
    :change_set_iri,
    :command_iri,
    :actor_iri,
    :scope_iri,
    :causation_iri,
    :ontology_version,
    :shape_version,
    :validation_context,
    :request_fingerprint,
    :commit_metadata,
    :targets,
    :target_graphs,
    :additions,
    :removals,
    :expected_dataset_revision,
    :expected_graph_revisions,
    :assertion_count,
    :supersession_count,
    :invalidation_count
  ]
  defstruct @enforce_keys

  @jf "https://jido.run/ontology/factory#"
  @prov_invalidated "http://www.w3.org/ns/prov#invalidatedAtTime"
  @max_additions 1_000
  @max_targets 16

  @type t :: %__MODULE__{}

  @spec new(CommandEnvelope.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(envelope, options \\ [])

  def new(%CommandEnvelope{} = envelope, options) when is_list(options) do
    maintenance? = Keyword.get(options, :maintenance?, false)

    with {:ok, definition} <-
           CommandRegistry.resolve(envelope.command_type, envelope.command_version),
         {:ok, targets} <-
           normalize_targets(envelope.payload[:changes], definition, maintenance?),
         true <- length(targets) in 1..@max_targets,
         additions = targets |> Enum.flat_map(& &1.additions) |> canonical_quads(),
         removals = targets |> Enum.flat_map(& &1.removals) |> canonical_quads(),
         true <- length(additions) <= @max_additions,
         target_graphs = targets |> Enum.map(& &1.graph_iri) |> Enum.uniq() |> Enum.sort(),
         true <-
           MapSet.subset?(
             MapSet.new(target_graphs),
             MapSet.new(Map.keys(envelope.expected_graph_revisions))
           ),
         fingerprint <- fingerprint(envelope, targets, additions, removals),
         {:ok, change_set_iri} <- ResourceIdentity.deterministic(:change_set, fingerprint) do
      {:ok,
       %__MODULE__{
         change_set_iri: change_set_iri,
         command_iri: envelope.command_iri,
         actor_iri: envelope.actor_iri,
         scope_iri: envelope.scope_iri,
         causation_iri: envelope.causation_iri,
         ontology_version: envelope.ontology_version,
         shape_version: envelope.shape_version,
         validation_context: %{registry: GraphRegistry.revision(), command: definition.version},
         request_fingerprint: fingerprint,
         commit_metadata: %{issued_at: envelope.issued_at},
         targets: targets,
         target_graphs: target_graphs,
         additions: additions,
         removals: removals,
         expected_dataset_revision: envelope.expected_dataset_revision,
         expected_graph_revisions: envelope.expected_graph_revisions,
         assertion_count: Enum.sum(Enum.map(targets, & &1.assertion_count)),
         supersession_count: Enum.sum(Enum.map(targets, & &1.supersession_count)),
         invalidation_count: Enum.sum(Enum.map(targets, & &1.invalidation_count))
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:change_set)
    end
  rescue
    _error -> invalid(:change_set)
  catch
    _kind, _reason -> invalid(:change_set)
  end

  def new(_envelope, _options), do: invalid(:change_set)

  defp normalize_targets(changes, definition, maintenance?) when is_list(changes) do
    Enum.reduce_while(changes, {:ok, []}, fn change, {:ok, targets} ->
      case normalize_target(change, definition, maintenance?) do
        {:ok, target} -> {:cont, {:ok, [target | targets]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, targets} -> {:ok, Enum.reverse(targets)}
      error -> error
    end
  end

  defp normalize_targets(_changes, _definition, _maintenance?), do: invalid(:change_targets)

  defp normalize_target(change, definition, maintenance?) when is_map(change) do
    family = change[:family]
    graph_iri = change[:graph_iri]
    operation = change[:operation]
    replacement? = operation == :replace and Map.get(definition, :allow_replacement?, false)
    closure? = operation == :close and Map.get(definition, :allow_closure?, false)

    lifecycle_metadata =
      case operation do
        :create -> nil
        :close -> %{lifecycle_state: :open}
        _other -> change[:metadata]
      end

    with true <- family in definition.graph_families,
         {:ok, ^family} <- GraphRegistry.identify(graph_iri),
         true <- operation in [:create, :append, :close, :replace, :maintenance],
         true <- operation != :replace or replacement?,
         true <- operation != :close or closure?,
         true <- operation != :maintenance or maintenance?,
         true <-
           GraphRegistry.write_allowed?(
             family,
             lifecycle_operation(operation),
             lifecycle_metadata
           ),
         {:ok, assertions} <- normalize_statements(change[:additions] || [], graph_iri),
         {:ok, supersessions} <- supersession_quads(change[:supersessions] || [], graph_iri),
         {:ok, invalidations} <- invalidation_quads(change[:invalidations] || [], graph_iri),
         {:ok, removals} <-
           normalize_removals(
             change[:removals] || [],
             graph_iri,
             maintenance? or replacement? or closure?
           ) do
      {:ok,
       %{
         family: family,
         graph_iri: graph_iri,
         operation: operation,
         metadata: change[:metadata],
         additions: canonical_quads(assertions ++ supersessions ++ invalidations),
         removals: canonical_quads(removals),
         assertion_count: length(assertions),
         supersession_count: length(supersessions),
         invalidation_count: length(invalidations)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:change_target)
    end
  end

  defp normalize_target(_change, _definition, _maintenance?), do: invalid(:change_target)

  defp lifecycle_operation(:maintenance), do: :append
  defp lifecycle_operation(operation), do: operation

  defp normalize_statements(statements, graph_iri) when is_list(statements) do
    Enum.reduce_while(statements, {:ok, []}, fn statement, {:ok, quads} ->
      case normalize_statement(statement, graph_iri) do
        {:ok, quad} -> {:cont, {:ok, [quad | quads]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, quads} -> {:ok, Enum.reverse(quads)}
      error -> error
    end
  end

  defp normalize_statements(_statements, _graph_iri), do: invalid(:change_statements)

  defp normalize_statement({subject, predicate, object}, graph_iri),
    do: normalize_statement({subject, predicate, object, graph_iri}, graph_iri)

  defp normalize_statement(statement, graph_iri) do
    case RDF.Quad.new(statement) do
      {_, _, _, %RDF.IRI{value: ^graph_iri}} = quad ->
        if RDF.Quad.valid?(quad) and not RDF.Quad.has_bnode?(quad) and
             graph_iri != Vocabulary.system_graph(),
           do: {:ok, quad},
           else: invalid(:change_statement)

      _wrong_graph ->
        invalid(:change_placement)
    end
  rescue
    _error -> invalid(:change_statement)
  end

  defp supersession_quads(values, graph_iri) when is_list(values) do
    values
    |> Enum.map(fn
      {subject, prior} -> {subject, @jf <> "supersedes", RDF.iri(prior)}
      _invalid -> :invalid
    end)
    |> normalize_statements(graph_iri)
  rescue
    _error -> invalid(:change_supersession)
  end

  defp supersession_quads(_values, _graph_iri), do: invalid(:change_supersession)

  defp invalidation_quads(values, graph_iri) when is_list(values) do
    values
    |> Enum.map(fn
      {subject, %DateTime{} = time} ->
        {subject, @prov_invalidated, RDF.XSD.DateTime.new(DateTime.truncate(time, :microsecond))}

      _invalid ->
        :invalid
    end)
    |> normalize_statements(graph_iri)
  rescue
    _error -> invalid(:change_invalidation)
  end

  defp invalidation_quads(_values, _graph_iri), do: invalid(:change_invalidation)

  defp normalize_removals([], _graph_iri, _maintenance?), do: {:ok, []}
  defp normalize_removals(values, graph_iri, true), do: normalize_statements(values, graph_iri)
  defp normalize_removals(_values, _graph_iri, false), do: invalid(:change_removal)

  defp fingerprint(envelope, targets, additions, removals) do
    logical_targets =
      Enum.map(targets, fn target ->
        {target.family, target.graph_iri, target.operation, canonical_nquads(target.additions),
         canonical_nquads(target.removals)}
      end)

    {
      envelope.command_type,
      envelope.command_version,
      envelope.actor_iri,
      envelope.delegated_agent_iri,
      envelope.scope_iri,
      envelope.idempotency_key,
      envelope.correlation_iri,
      envelope.causation_iri,
      envelope.ontology_version,
      envelope.shape_version,
      envelope.expected_dataset_revision,
      Enum.sort(envelope.expected_graph_revisions),
      envelope.reason,
      envelope.issued_at,
      Enum.sort(logical_targets),
      canonical_nquads(additions),
      canonical_nquads(removals)
    }
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_quads(quads) do
    quads
    |> Enum.uniq()
    |> Enum.sort_by(&canonical_nquads([&1]))
  end

  defp canonical_nquads([]), do: ""

  defp canonical_nquads(quads) do
    quads |> RDF.Dataset.new() |> RDF.NQuads.write_string!(sort: true)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
