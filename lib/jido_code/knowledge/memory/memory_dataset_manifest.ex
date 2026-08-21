defmodule JidoCode.Knowledge.Memory.MemoryDatasetManifest do
  @moduledoc "Chronological, authorization-bound manifest for one governed memory dataset."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.CrossRepositoryAuthorization
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @revision "1.0.0"
  @splits ~w[development validation evaluation]a
  @content_states ~w[omitted unavailable authorized_reference cryptographically_erased]a
  @forbidden_classes ~w[secret_value personal prompt]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"

  @enforce_keys [
    :iri,
    :revision,
    :cohort_iri,
    :purpose,
    :authorization_iri,
    :repository_iris,
    :source_graph_iris,
    :source_resource_iris,
    :cutoff,
    :classifications,
    :extractor_revision,
    :query_revision,
    :split_policy,
    :erasure_generations,
    :exact_content_states,
    :created_at,
    :status
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  def revision, do: @revision
  def splits, do: @splits

  def new(%CrossRepositoryAuthorization{} = authorization, attributes) when is_map(attributes) do
    with true <- attributes[:cohort_iri] == authorization.cohort_iri,
         true <- attributes[:purpose] == authorization.purpose,
         true <- attributes[:authorization_iri] == authorization.iri,
         {:ok, repositories} <- exact_resources(attributes[:repository_iris], 2, 50),
         true <- subset?(repositories, authorization.repository_iris),
         {:ok, graphs} <- exact_graphs(attributes[:source_graph_iris], 1, 200),
         {:ok, resources} <- exact_resources(attributes[:source_resource_iris], 1, 2_000),
         %DateTime{} = cutoff <- attributes[:cutoff],
         true <- DateTime.compare(cutoff, authorization.effective_cutoff) in [:lt, :eq],
         {:ok, classifications} <- classifications(attributes[:classifications]),
         true <- subset?(classifications, authorization.data_classes),
         true <- Enum.all?(classifications, &(&1 not in @forbidden_classes)),
         true <- revision?(attributes[:extractor_revision]),
         true <- revision?(attributes[:query_revision]),
         {:ok, split_policy} <- split_policy(attributes[:split_policy], repositories),
         {:ok, generations} <-
           exact_generations(attributes[:erasure_generations], repositories, authorization),
         {:ok, content_states} <- content_states(attributes[:exact_content_states]),
         %DateTime{} = created_at <- attributes[:created_at],
         true <- DateTime.compare(cutoff, created_at) in [:lt, :eq],
         {:ok, iri} <-
           identity(
             authorization,
             attributes,
             repositories,
             graphs,
             resources,
             classifications,
             split_policy,
             generations,
             content_states
           ) do
      {:ok,
       struct!(__MODULE__,
         iri: iri,
         revision: @revision,
         cohort_iri: authorization.cohort_iri,
         purpose: authorization.purpose,
         authorization_iri: authorization.iri,
         repository_iris: repositories,
         source_graph_iris: graphs,
         source_resource_iris: resources,
         cutoff: DateTime.truncate(cutoff, :microsecond),
         classifications: classifications,
         extractor_revision: attributes.extractor_revision,
         query_revision: attributes.query_revision,
         split_policy: split_policy,
         erasure_generations: generations,
         exact_content_states: content_states,
         created_at: DateTime.truncate(created_at, :microsecond),
         status: :building
       )}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_authorization, _attributes), do: invalid()

  def statements(%__MODULE__{} = manifest) do
    [
      {manifest.iri, @rdf_type, RDF.iri(@jf <> "MemoryDatasetManifest")},
      {manifest.iri, @jf <> "version", RDF.XSD.String.new(manifest.revision)},
      {manifest.iri, @jf <> "cohort", RDF.iri(manifest.cohort_iri)},
      {manifest.iri, @jf <> "authorization", RDF.iri(manifest.authorization_iri)},
      {manifest.iri, @jf <> "purpose", concept(manifest.purpose)},
      {manifest.iri, @jf <> "effectiveCutoff", RDF.XSD.DateTime.new(manifest.cutoff)},
      {manifest.iri, @jf <> "extractorRevision", RDF.XSD.String.new(manifest.extractor_revision)},
      {manifest.iri, @jf <> "queryRevision", RDF.XSD.String.new(manifest.query_revision)},
      {manifest.iri, @jf <> "createdAt", RDF.XSD.DateTime.new(manifest.created_at)},
      {manifest.iri, @jf <> "datasetState", concept(manifest.status)}
    ] ++
      iris(manifest.iri, @jf <> "repository", manifest.repository_iris) ++
      iris(manifest.iri, @jf <> "sourceGraph", manifest.source_graph_iris) ++
      iris(manifest.iri, @jf <> "sourceResource", manifest.source_resource_iris) ++
      Enum.map(manifest.classifications, &{manifest.iri, @jf <> "allowedDataClass", concept(&1)}) ++
      Enum.flat_map(manifest.split_policy, fn {repository, split} ->
        node = child(manifest.iri, "split", repository)

        [
          {manifest.iri, @jf <> "splitAssignment", RDF.iri(node)},
          {node, @jf <> "repository", RDF.iri(repository)},
          {node, @jf <> "split", concept(split)}
        ]
      end) ++
      Enum.flat_map(manifest.erasure_generations, fn {repository, generation} ->
        node = child(manifest.iri, "erasure-generation", repository)

        [
          {manifest.iri, @jf <> "erasureGeneration", RDF.iri(node)},
          {node, @jf <> "repository", RDF.iri(repository)},
          {node, @jf <> "generation", RDF.XSD.NonNegativeInteger.new(generation)}
        ]
      end) ++
      Enum.flat_map(manifest.exact_content_states, fn {content, state} ->
        node = child(manifest.iri, "content-state", content)

        [
          {manifest.iri, @jf <> "exactContentState", RDF.iri(node)},
          {node, @jf <> "content", RDF.iri(content)},
          {node, @jf <> "state", concept(state)}
        ]
      end)
  end

  defp identity(
         authorization,
         attributes,
         repositories,
         graphs,
         resources,
         classes,
         splits,
         generations,
         states
       ) do
    material =
      [
        authorization.iri,
        Enum.join(repositories, "\n"),
        Enum.join(graphs, "\n"),
        Enum.join(resources, "\n"),
        DateTime.to_iso8601(attributes.cutoff),
        Enum.map_join(classes, "\n", &Atom.to_string/1),
        attributes.extractor_revision,
        attributes.query_revision,
        pairs(splits),
        pairs(generations),
        pairs(states)
      ]
      |> Enum.join("\n--\n")

    ResourceIdentity.deterministic(:memory_dataset_manifest, material)
  end

  defp exact_resources(values, minimum, maximum) when is_list(values) do
    normalized = Enum.uniq(values) |> Enum.sort()

    if length(normalized) == length(values) and length(normalized) >= minimum and
         length(normalized) <= maximum and
         Enum.all?(normalized, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, normalized},
       else: :error
  end

  defp exact_resources(_values, _minimum, _maximum), do: :error

  defp exact_graphs(values, minimum, maximum) when is_list(values) do
    normalized = Enum.uniq(values) |> Enum.sort()

    if length(normalized) == length(values) and length(normalized) >= minimum and
         length(normalized) <= maximum and
         Enum.all?(normalized, fn graph ->
           match?({:ok, _family}, GraphRegistry.identify(graph))
         end),
       do: {:ok, normalized},
       else: :error
  end

  defp exact_graphs(_values, _minimum, _maximum), do: :error

  defp classifications(values) when is_list(values) do
    normalized = Enum.uniq(values) |> Enum.sort()

    if normalized != [] and Enum.all?(normalized, &(&1 in DataPolicy.classifications())),
      do: {:ok, normalized},
      else: :error
  end

  defp classifications(_values), do: :error

  defp split_policy(policy, repositories) when is_map(policy) do
    if Enum.sort(Map.keys(policy)) == repositories and
         Enum.all?(policy, fn {_repository, split} -> split in @splits end) and
         policy |> Map.values() |> Enum.uniq() |> length() >= 2,
       do: {:ok, Map.new(policy)},
       else: :error
  end

  defp split_policy(_policy, _repositories), do: :error

  defp exact_generations(generations, repositories, authorization) when is_map(generations) do
    expected = Map.take(authorization.erasure_generations, repositories)
    if generations == expected, do: {:ok, Map.new(generations)}, else: :error
  end

  defp exact_generations(_generations, _repositories, _authorization), do: :error

  defp content_states(states) when is_map(states) do
    if map_size(states) <= 2_000 and
         Enum.all?(states, fn {iri, state} ->
           ResourceIdentity.validate(iri) == :ok and state in @content_states
         end),
       do: {:ok, Map.new(states)},
       else: :error
  end

  defp content_states(_states), do: :error
  defp subset?(values, allowed), do: Enum.all?(values, &(&1 in allowed))
  defp revision?(value), do: is_binary(value) and Regex.match?(~r/^\d+\.\d+\.\d+$/, value)

  defp pairs(map),
    do: Enum.map_join(Enum.sort(map), "\n", fn {key, value} -> "#{key}:#{value}" end)

  defp iris(subject, predicate, values), do: Enum.map(values, &{subject, predicate, RDF.iri(&1)})

  defp concept(value),
    do: RDF.iri("https://jido.run/ontology/concept/" <> Macro.camelize(to_string(value)))

  defp child(parent, kind, resource) do
    digest = :crypto.hash(:sha256, resource) |> Base.encode16(case: :lower)
    parent <> "/" <> kind <> "/" <> digest
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :memory_dataset_manifest)}
end
