defmodule JidoCode.Knowledge.GraphMetadata do
  @moduledoc """
  Builds and reads graph-local lifecycle and ownership metadata.

  Metadata statements live in the graph they describe and are committed in the
  same atomic batch as graph creation. Reads select only the named graph
  resource itself and never expose graph contents.
  """

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Metadata, as: SubstrateMetadata
  alias JidoCode.Knowledge.ResourceIdentity
  alias TripleStore.SPARQL.Query

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @named_graph "https://jido.run/ontology/factory#NamedGraph"
  @base "https://jido.run/ontology/factory#"
  @ontology_release_prefix "https://jido.run/ontology/release/"
  @xsd_integer "http://www.w3.org/2001/XMLSchema#integer"
  @xsd_non_negative_integer "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
  @xsd_date_time "http://www.w3.org/2001/XMLSchema#dateTime"
  @xsd_string "http://www.w3.org/2001/XMLSchema#string"
  @max_metadata_statements 50
  @max_source_revision_refs 8

  @predicate_keys %{
    @rdf_type => :type,
    (@base <> "graphKind") => :graph_kind,
    (@base <> "ownerScope") => :owner_scope,
    (@base <> "ontologyVersion") => :ontology_version,
    (@base <> "creationActivity") => :creation_activity,
    (@base <> "createdAt") => :created_at,
    (@base <> "lifecycleState") => :lifecycle_state,
    (@base <> "completenessState") => :completeness_state,
    (@base <> "graphRevision") => :graph_revision,
    (@base <> "sourceRevision") => :source_revision,
    (@base <> "parentGraph") => :parent_graph,
    (@base <> "closedAt") => :closed_at,
    (@base <> "ruleSet") => :rule_set,
    (@base <> "invalidationState") => :invalidation_state,
    (@base <> "retentionClass") => :retention_class,
    (@base <> "sourceGraphRevision") => :source_revision_refs
  }

  @revision_predicate_keys %{
    @rdf_type => :type,
    (@base <> "sourceGraph") => :graph,
    (@base <> "sourceRevisionNumber") => :revision
  }

  @required_keys [
    :graph_iri,
    :family,
    :graph_kind,
    :owner_scope,
    :ontology_version,
    :creation_activity,
    :created_at,
    :lifecycle_state,
    :completeness_state,
    :graph_revision,
    :retention_class
  ]

  @spec new(String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def new(graph_iri, attributes) when is_binary(graph_iri) and is_map(attributes) do
    with {:ok, family} <- GraphRegistry.identify(graph_iri),
         {:ok, contract} <- GraphRegistry.fetch(family),
         {:ok, graph_kind} <- GraphRegistry.graph_kind_iri(family) do
      metadata = %{
        graph_iri: graph_iri,
        family: family,
        graph_kind: graph_kind,
        owner_scope: Map.get(attributes, :owner_scope),
        ontology_version: Map.get(attributes, :ontology_version),
        creation_activity: Map.get(attributes, :creation_activity),
        created_at: Map.get(attributes, :created_at),
        lifecycle_state: Map.get(attributes, :lifecycle_state),
        completeness_state: Map.get(attributes, :completeness_state),
        graph_revision: Map.get(attributes, :graph_revision, 1),
        retention_class: Atom.to_string(contract.retention),
        source_revision: Map.get(attributes, :source_revision),
        parent_graph: Map.get(attributes, :parent_graph),
        closed_at: Map.get(attributes, :closed_at),
        rule_set: Map.get(attributes, :rule_set),
        invalidation_state: Map.get(attributes, :invalidation_state),
        source_graph_revisions: Map.get(attributes, :source_graph_revisions, [])
      }

      with :ok <- validate_required(metadata),
           :ok <- validate_family_fields(metadata, contract) do
        {:ok, metadata}
      end
    end
  end

  def new(_graph_iri, _attributes), do: invalid(:graph_metadata)

  @spec quads(map()) :: {:ok, [RDF.Quad.t()]} | {:error, Error.t()}
  def quads(metadata) when is_map(metadata) do
    with :ok <- validate_required(metadata),
         {:ok, lifecycle} <- lifecycle_iri(metadata.lifecycle_state),
         {:ok, completeness} <- completeness_iri(metadata.completeness_state) do
      base = [
        quad(metadata, @rdf_type, RDF.iri(@named_graph)),
        quad(metadata, @base <> "graphKind", RDF.iri(metadata.graph_kind)),
        quad(metadata, @base <> "ownerScope", RDF.iri(metadata.owner_scope)),
        quad(metadata, @base <> "ontologyVersion", RDF.iri(metadata.ontology_version)),
        quad(metadata, @base <> "creationActivity", RDF.iri(metadata.creation_activity)),
        quad(metadata, @base <> "createdAt", RDF.literal(metadata.created_at)),
        quad(metadata, @base <> "lifecycleState", RDF.iri(lifecycle)),
        quad(metadata, @base <> "completenessState", RDF.iri(completeness)),
        quad(
          metadata,
          @base <> "graphRevision",
          RDF.XSD.NonNegativeInteger.new(metadata.graph_revision)
        ),
        quad(metadata, @base <> "retentionClass", RDF.literal(metadata.retention_class))
      ]

      {:ok, base ++ optional_quads(metadata)}
    end
  rescue
    _error -> invalid(:graph_metadata_quads)
  end

  def quads(_metadata), do: invalid(:graph_metadata_quads)

  @doc false
  @spec read(TripleStore.store(), String.t()) :: {:ok, map() | nil} | {:error, Error.t()}
  def read(store, graph_iri) when is_binary(graph_iri) do
    with {:ok, _family} <- GraphRegistry.identify(graph_iri) do
      context = %{db: store.db, dict_manager: store.dict_manager, permit_all: true}

      case Query.query(context, metadata_query(graph_iri), timeout: 5_000, use_cache: false) do
        {:ok, []} ->
          {:ok, nil}

        {:ok, rows} when length(rows) < @max_metadata_statements ->
          with {:ok, metadata} <- decode_rows(graph_iri, rows),
               {:ok, metadata} <- load_family_metadata(context, metadata),
               {:ok, revision} when is_integer(revision) <-
                 SubstrateMetadata.graph_revision(store, graph_iri) do
            {:ok, %{metadata | graph_revision: revision}}
          else
            _invalid -> {:error, Error.new(:corrupt, :read_graph_metadata)}
          end

        {:ok, _too_many} ->
          {:error, Error.new(:corrupt, :read_graph_metadata)}

        {:error, reason} ->
          {:error, BackendFailure.translate(reason, :read_graph_metadata)}
      end
    end
  end

  def read(_store, _graph_iri), do: invalid(:read_graph_metadata)

  defp validate_required(metadata) do
    cond do
      Enum.any?(@required_keys, &(not Map.has_key?(metadata, &1))) ->
        invalid(:graph_metadata)

      ResourceIdentity.validate(metadata.owner_scope) != :ok ->
        invalid(:graph_owner_scope)

      ResourceIdentity.validate(metadata.creation_activity) != :ok ->
        invalid(:graph_creation_activity)

      not ontology_version?(metadata.ontology_version) ->
        invalid(:graph_ontology_version)

      not match?(%DateTime{}, metadata.created_at) ->
        invalid(:graph_creation_time)

      metadata.lifecycle_state not in [:open, :closed, :invalidated] ->
        invalid(:graph_lifecycle)

      metadata.completeness_state not in [:building, :complete, :incomplete] ->
        invalid(:graph_completeness)

      not (is_integer(metadata.graph_revision) and metadata.graph_revision > 0) ->
        invalid(:graph_revision)

      not (is_binary(metadata.retention_class) and byte_size(metadata.retention_class) <= 64) ->
        invalid(:graph_retention)

      true ->
        :ok
    end
  end

  defp validate_family_fields(metadata, contract) do
    cond do
      contract.mutability == :immutable and
          (metadata.lifecycle_state != :closed or metadata.completeness_state != :complete or
             not match?(%DateTime{}, metadata.closed_at)) ->
        invalid(:immutable_graph_metadata)

      metadata.family == :source_revision and not valid_optional_iri?(metadata.source_revision) ->
        invalid(:source_graph_metadata)

      metadata.family == :derived and
          (not valid_rule_set?(metadata.rule_set) or
             metadata.invalidation_state not in [:current, :stale, :incompatible, :invalidated] or
             not valid_source_revisions?(metadata.source_graph_revisions)) ->
        invalid(:derived_graph_metadata)

      metadata.lifecycle_state == :closed and not match?(%DateTime{}, metadata.closed_at) ->
        invalid(:graph_closure_time)

      metadata.lifecycle_state != :closed and not is_nil(metadata.closed_at) ->
        invalid(:graph_closure_time)

      not valid_optional_graph?(metadata.parent_graph) ->
        invalid(:parent_graph_metadata)

      true ->
        :ok
    end
  end

  defp ontology_version?(value) when is_binary(value) do
    String.starts_with?(value, @ontology_release_prefix) and RDF.IRI.valid?(value)
  end

  defp ontology_version?(_value), do: false

  defp valid_optional_iri?(value) when is_binary(value), do: RDF.IRI.valid?(value)
  defp valid_optional_iri?(_value), do: false

  defp valid_optional_graph?(nil), do: true
  defp valid_optional_graph?(value), do: match?({:ok, _family}, GraphRegistry.identify(value))

  defp valid_rule_set?(value) when is_binary(value), do: ResourceIdentity.validate(value) == :ok

  defp valid_rule_set?(_value), do: false

  defp valid_source_revisions?(values) when is_list(values) and values != [] do
    valid? =
      Enum.all?(values, fn
        %{graph: graph, revision: revision} when is_integer(revision) and revision >= 0 ->
          match?({:ok, _family}, GraphRegistry.identify(graph))

        _invalid ->
          false
      end)

    valid? and length(values) <= @max_source_revision_refs and
      length(Enum.uniq_by(values, & &1.graph)) == length(values)
  end

  defp valid_source_revisions?(_values), do: false

  defp optional_quads(metadata) do
    []
    |> maybe_add_iri(metadata, :source_revision, "sourceRevision")
    |> maybe_add_iri(metadata, :parent_graph, "parentGraph")
    |> maybe_add_iri(metadata, :rule_set, "ruleSet")
    |> maybe_add_concept(metadata, :invalidation_state, "invalidationState")
    |> maybe_add_literal(metadata, :closed_at, "closedAt")
    |> add_source_revisions(metadata)
  end

  defp maybe_add_iri(quads, metadata, key, predicate) do
    case Map.get(metadata, key) do
      nil -> quads
      value -> [quad(metadata, @base <> predicate, RDF.iri(value)) | quads]
    end
  end

  defp maybe_add_literal(quads, metadata, key, predicate) do
    case Map.get(metadata, key) do
      nil -> quads
      value -> [quad(metadata, @base <> predicate, RDF.literal(value)) | quads]
    end
  end

  defp maybe_add_concept(quads, metadata, key, predicate) do
    case Map.get(metadata, key) do
      nil ->
        quads

      state ->
        [quad(metadata, @base <> predicate, RDF.iri(invalidation_state_iri(state))) | quads]
    end
  end

  defp add_source_revisions(quads, metadata) do
    Enum.reduce(metadata.source_graph_revisions, quads, fn source, acc ->
      {:ok, reference} =
        ResourceIdentity.deterministic(
          :graph_revision_reference,
          "#{source.graph}|#{source.revision}"
        )

      [
        quad(metadata, @base <> "sourceGraphRevision", RDF.iri(reference)),
        resource_quad(metadata, reference, @rdf_type, RDF.iri(@base <> "GraphRevisionReference")),
        resource_quad(metadata, reference, @base <> "sourceGraph", RDF.iri(source.graph)),
        resource_quad(
          metadata,
          reference,
          @base <> "sourceRevisionNumber",
          RDF.XSD.NonNegativeInteger.new(source.revision)
        )
        | acc
      ]
    end)
  end

  defp quad(metadata, predicate, object) do
    RDF.quad(metadata.graph_iri, predicate, object, metadata.graph_iri)
  end

  defp resource_quad(metadata, subject, predicate, object) do
    RDF.quad(subject, predicate, object, metadata.graph_iri)
  end

  defp lifecycle_iri(:open), do: {:ok, "https://jido.run/ontology/concept/Open"}
  defp lifecycle_iri(:closed), do: {:ok, "https://jido.run/ontology/concept/Closed"}

  defp lifecycle_iri(:invalidated),
    do: {:ok, "https://jido.run/ontology/concept/GraphInvalidated"}

  defp lifecycle_iri(_state), do: invalid(:graph_lifecycle)

  defp completeness_iri(:building), do: {:ok, "https://jido.run/ontology/concept/Building"}
  defp completeness_iri(:complete), do: {:ok, "https://jido.run/ontology/concept/Complete"}
  defp completeness_iri(:incomplete), do: {:ok, "https://jido.run/ontology/concept/Incomplete"}
  defp completeness_iri(_state), do: invalid(:graph_completeness)

  defp metadata_query(graph_iri) do
    term = graph_iri |> RDF.iri() |> RDF.NTriples.Encoder.term()

    """
    SELECT ?predicate ?object
    WHERE {
      GRAPH #{term} {
        #{term} ?predicate ?object .
      }
    }
    LIMIT #{@max_metadata_statements}
    """
  end

  defp decode_rows(graph_iri, rows) do
    result =
      Enum.reduce_while(rows, {:ok, %{graph_iri: graph_iri}}, fn row, {:ok, metadata} ->
        with {:named_node, predicate} <- Map.get(row, "predicate"),
             {:ok, key} <- Map.fetch(@predicate_keys, predicate),
             {:ok, value} <- decode_object(Map.get(row, "object")) do
          {:cont, {:ok, put_decoded(metadata, key, value)}}
        else
          :error -> {:cont, {:ok, metadata}}
          _invalid -> {:halt, {:error, Error.new(:corrupt, :read_graph_metadata)}}
        end
      end)

    with {:ok, metadata} <- result,
         false <- Map.get(metadata, :duplicate?, false),
         true <- complete_read_metadata?(metadata),
         {:ok, family} <- GraphRegistry.identify(graph_iri) do
      {:ok, Map.put(metadata, :family, family)}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:corrupt, :read_graph_metadata)}
    end
  end

  defp put_decoded(metadata, :source_revision_refs, value) do
    Map.update(metadata, :source_revision_refs, [value], &[value | &1])
  end

  defp put_decoded(metadata, key, value) do
    value = normalize_decoded(key, value)

    if Map.has_key?(metadata, key),
      do: Map.put(metadata, :duplicate?, true),
      else: Map.put(metadata, key, value)
  end

  defp normalize_decoded(:lifecycle_state, "https://jido.run/ontology/concept/Open"), do: :open

  defp normalize_decoded(:lifecycle_state, "https://jido.run/ontology/concept/Closed"),
    do: :closed

  defp normalize_decoded(
         :lifecycle_state,
         "https://jido.run/ontology/concept/GraphInvalidated"
       ),
       do: :invalidated

  defp normalize_decoded(:completeness_state, "https://jido.run/ontology/concept/Building"),
    do: :building

  defp normalize_decoded(:completeness_state, "https://jido.run/ontology/concept/Complete"),
    do: :complete

  defp normalize_decoded(:completeness_state, "https://jido.run/ontology/concept/Incomplete"),
    do: :incomplete

  defp normalize_decoded(:invalidation_state, "https://jido.run/ontology/concept/Current"),
    do: :current

  defp normalize_decoded(:invalidation_state, "https://jido.run/ontology/concept/Stale"),
    do: :stale

  defp normalize_decoded(
         :invalidation_state,
         "https://jido.run/ontology/concept/Incompatible"
       ),
       do: :incompatible

  defp normalize_decoded(
         :invalidation_state,
         "https://jido.run/ontology/concept/DerivedInvalidated"
       ),
       do: :invalidated

  defp normalize_decoded(_key, value), do: value

  defp complete_read_metadata?(metadata) do
    required = [
      :type,
      :graph_kind,
      :owner_scope,
      :ontology_version,
      :creation_activity,
      :created_at,
      :lifecycle_state,
      :completeness_state,
      :graph_revision,
      :retention_class
    ]

    Enum.all?(required, &Map.has_key?(metadata, &1)) and
      Map.get(metadata, :type) == @named_graph
  end

  defp decode_object({:named_node, value}) when is_binary(value), do: {:ok, value}
  defp decode_object({:literal, :simple, value}) when is_binary(value), do: {:ok, value}
  defp decode_object({:literal, :typed, value, @xsd_string}), do: {:ok, value}

  defp decode_object({:literal, :typed, lexical, datatype})
       when datatype in [@xsd_integer, @xsd_non_negative_integer] do
    case Integer.parse(lexical) do
      {integer, ""} when integer >= 0 -> {:ok, integer}
      _invalid -> :error
    end
  end

  defp decode_object({:literal, :typed, lexical, @xsd_date_time}) do
    case DateTime.from_iso8601(lexical) do
      {:ok, value, 0} -> {:ok, value}
      _invalid -> :error
    end
  end

  defp decode_object(_object), do: :error

  defp load_family_metadata(context, %{family: :derived} = metadata) do
    references = Map.get(metadata, :source_revision_refs, []) |> Enum.sort()

    if references == [] or length(references) > @max_source_revision_refs do
      {:error, Error.new(:corrupt, :read_graph_metadata)}
    else
      with {:ok, resources} <- load_revision_resources(context, metadata.graph_iri, references),
           {:ok, revisions} <- normalize_revision_resources(resources) do
        {:ok,
         metadata
         |> Map.delete(:source_revision_refs)
         |> Map.put(:source_graph_revisions, revisions)}
      end
    end
  end

  defp load_family_metadata(_context, metadata), do: {:ok, metadata}

  defp revision_query(graph_iri, reference_iri) do
    graph = graph_iri |> RDF.iri() |> RDF.NTriples.Encoder.term()
    reference = reference_iri |> RDF.iri() |> RDF.NTriples.Encoder.term()

    """
    SELECT ?predicate ?object
    WHERE {
      GRAPH #{graph} {
        #{reference} ?predicate ?object .
      }
    }
    LIMIT #{@max_metadata_statements}
    """
  end

  defp load_revision_resources(context, graph_iri, references) do
    Enum.reduce_while(references, {:ok, %{}}, fn reference, {:ok, resources} ->
      case Query.query(context, revision_query(graph_iri, reference),
             timeout: 5_000,
             use_cache: false
           ) do
        {:ok, rows} when length(rows) < @max_metadata_statements ->
          case decode_revision_resource(rows) do
            {:ok, resource} ->
              {:cont, {:ok, Map.put(resources, reference, resource)}}

            :error ->
              {:halt, {:error, Error.new(:corrupt, :read_graph_metadata)}}
          end

        _too_many_or_failed ->
          {:halt, {:error, Error.new(:corrupt, :read_graph_metadata)}}
      end
    end)
  end

  defp decode_revision_resource(rows) do
    Enum.reduce_while(rows, {:ok, %{}}, fn row, {:ok, resource} ->
      with {:named_node, predicate} <- Map.get(row, "predicate"),
           {:ok, key} <- Map.fetch(@revision_predicate_keys, predicate),
           false <- Map.has_key?(resource, key),
           {:ok, value} <- decode_object(Map.get(row, "object")) do
        {:cont, {:ok, Map.put(resource, key, value)}}
      else
        _invalid -> {:halt, :error}
      end
    end)
  end

  defp normalize_revision_resources(resources) do
    Enum.reduce_while(resources, {:ok, []}, fn {_reference, resource}, {:ok, revisions} ->
      with true <- resource.type == @base <> "GraphRevisionReference",
           {:ok, _family} <- GraphRegistry.identify(resource.graph),
           true <- is_integer(resource.revision) and resource.revision >= 0 do
        {:cont, {:ok, [%{graph: resource.graph, revision: resource.revision} | revisions]}}
      else
        _invalid -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, revisions} -> {:ok, Enum.sort_by(revisions, &{&1.graph, &1.revision})}
      :error -> :error
    end
  rescue
    _error -> :error
  end

  defp invalidation_state_iri(:current), do: "https://jido.run/ontology/concept/Current"
  defp invalidation_state_iri(:stale), do: "https://jido.run/ontology/concept/Stale"

  defp invalidation_state_iri(:incompatible),
    do: "https://jido.run/ontology/concept/Incompatible"

  defp invalidation_state_iri(:invalidated),
    do: "https://jido.run/ontology/concept/DerivedInvalidated"

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
