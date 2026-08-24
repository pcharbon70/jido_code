defmodule JidoCode.Knowledge.Ontology.Release do
  @moduledoc """
  Verifies, canonicalizes, and loads an immutable ontology release.

  Release sources are local, digest-pinned inputs. Imports are descriptive;
  this module never resolves ontology content over the network.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.WriteBatch
  alias JidoCode.Knowledge.Writer

  @current_version "1.3.0"
  @versions [@current_version, "1.2.0", "1.1.0", "1.0.0"]
  @base_versions %{"1.3.0" => "1.2.0", "1.2.0" => "1.1.0", "1.1.0" => "1.0.0"}
  @schema_sources %{
    "1.0.0" => ~w[factory.ttl policy-terms.ttl shapes.ttl work-states.ttl],
    "1.1.0" => ~w[memory.ttl shapes.ttl],
    "1.2.0" => ~w[semantic-accounting.ttl shapes.ttl],
    "1.3.0" => ~w[managed-coding.ttl shapes.ttl]
  }
  @max_artifact_bytes 1_000_000
  @required_manifest_keys ~w[
    canonical_nquads_sha256
    compatibility
    graph_iri
    imports
    ontology_iri
    package_sha256
    released_on
    resource_namespace
    shape_version
    shapes_iri
    sources
    term_namespace
    version
  ]

  @spec current_version() :: String.t()
  def current_version, do: @current_version

  @spec versions() :: [String.t()]
  def versions, do: @versions

  @spec verify(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def verify(version \\ @current_version, options \\ []) do
    with {:ok, manifest} <- manifest(version, options),
         :ok <- verify_sources(manifest, version, options),
         {:ok, canonical} <- canonical_nquads(version, options),
         :ok <- verify_canonical_digest(canonical, manifest) do
      {:ok, public_manifest(manifest)}
    end
  end

  @spec manifest(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def manifest(version \\ @current_version, options \\ []) do
    with :ok <- validate_version(version),
         {:ok, contents} <- read_bounded(release_path(version, "manifest.json", options)),
         {:ok, decoded} <- decode_manifest(contents),
         :ok <- validate_manifest(decoded, version) do
      {:ok, decoded}
    end
  end

  @spec dataset(String.t(), keyword()) :: {:ok, RDF.Dataset.t()} | {:error, Error.t()}
  def dataset(version \\ @current_version, options \\ []) do
    with {:ok, manifest} <- manifest(version, options),
         :ok <- verify_sources(manifest, version, options),
         {:ok, inherited} <- inherited_dataset(version),
         {:ok, current} <- parse_sources(manifest, version, options) do
      {:ok, RDF.Dataset.add(inherited, current)}
    end
  end

  @spec canonical_nquads(String.t(), keyword()) :: {:ok, String.t()} | {:error, Error.t()}
  def canonical_nquads(version \\ @current_version, options \\ []) do
    with {:ok, dataset} <- dataset(version, options) do
      canonical =
        dataset
        |> RDF.Dataset.canonicalize()
        |> RDF.NQuads.write_string!(sort: true)

      {:ok, canonical}
    end
  rescue
    _error -> {:error, Error.new(:corrupt, :canonicalize_ontology)}
  end

  @spec checksum(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def checksum(version \\ @current_version, options \\ []) do
    with {:ok, manifest} <- manifest(version, options),
         {:ok, canonical} <- canonical_nquads(version, options) do
      {:ok,
       %{
         version: version,
         package_sha256: package_digest(manifest["sources"]),
         canonical_nquads_sha256: sha256(canonical),
         quad_count: canonical |> String.split("\n", trim: true) |> length()
       }}
    end
  end

  @spec load(keyword()) :: {:ok, map()} | {:error, Error.t()} | tuple()
  def load(options \\ []) do
    version = Keyword.get(options, :version, @current_version)
    writer = Keyword.get(options, :writer, Writer)
    store_server = Keyword.get(options, :store_server, StoreServer)

    with {:ok, manifest} <- verify(version, options),
         {:ok, dataset} <- dataset(version, options),
         {:ok, _summary} <- store_summary(store_server),
         {:ok, batch} <-
           WriteBatch.new(RDF.Dataset.quads(dataset),
             commit_id: ontology_commit_id(version),
             expected_dataset_revision: 0,
             expected_graph_revisions: %{manifest.graph_iri => 0},
             operation_metadata: %{class: :ontology_release, version: version}
           ),
         {:ok, receipt} <- Writer.commit(writer, batch, []) do
      {:ok,
       %{
         version: version,
         graph_iri: manifest.graph_iri,
         canonical_nquads_sha256: manifest.canonical_nquads_sha256,
         receipt: receipt
       }}
    end
  end

  defp release_root(version, options) do
    case Keyword.get(options, :root) do
      nil -> Application.app_dir(:jido_code, Path.join("priv/ontology", version))
      root when is_binary(root) -> Path.expand(root)
    end
  end

  defp release_path(version, filename, options) do
    Path.join(release_root(version, options), filename)
  end

  defp validate_version(version) when version in @versions, do: :ok
  defp validate_version(_version), do: {:error, Error.new(:incompatible, :ontology_version)}

  defp read_bounded(path) do
    with {:ok, %{type: :regular, size: size}} when size <= @max_artifact_bytes <- File.stat(path),
         {:ok, contents} <- File.read(path) do
      {:ok, contents}
    else
      _error -> {:error, Error.new(:corrupt, :read_ontology_release)}
    end
  end

  defp decode_manifest(contents) do
    case Jason.decode(contents) do
      {:ok, manifest} when is_map(manifest) -> {:ok, manifest}
      _invalid -> {:error, Error.new(:corrupt, :decode_ontology_manifest)}
    end
  end

  defp validate_manifest(manifest, version) do
    with true <- Map.keys(manifest) |> Enum.sort() == Enum.sort(@required_manifest_keys),
         true <- manifest["version"] == version,
         true <- valid_sha?(manifest["package_sha256"]),
         true <- valid_sha?(manifest["canonical_nquads_sha256"]),
         true <- valid_iri?(manifest["ontology_iri"]),
         true <- valid_iri?(manifest["shapes_iri"]),
         true <- valid_graph_iri?(manifest["graph_iri"], version),
         true <- manifest["term_namespace"] == "https://jido.run/ontology/factory#",
         true <- manifest["resource_namespace"] == "https://jido.run/id/",
         true <- manifest["shape_version"] == version,
         true <- is_list(manifest["imports"]),
         true <- Enum.all?(manifest["imports"], &valid_iri?/1),
         true <- valid_source_map?(manifest["sources"]) do
      :ok
    else
      _invalid -> {:error, Error.new(:corrupt, :validate_ontology_manifest)}
    end
  end

  defp valid_source_map?(sources) when is_map(sources) and map_size(sources) > 0 do
    Enum.all?(sources, fn {name, digest} -> valid_source_name?(name) and valid_sha?(digest) end)
  end

  defp valid_source_map?(_sources), do: false

  defp valid_source_name?(name) when is_binary(name) do
    Path.basename(name) == name and Path.extname(name) in [".ttl", ".md"]
  end

  defp valid_source_name?(_name), do: false

  defp valid_sha?(value) when is_binary(value), do: Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp valid_sha?(_value), do: false

  defp valid_iri?(value) when is_binary(value), do: RDF.IRI.valid?(value)
  defp valid_iri?(_value), do: false

  defp valid_graph_iri?(value, version) do
    value == "https://jido.run/graph/ontology/#{version}" and valid_iri?(value)
  end

  defp verify_sources(manifest, version, options) do
    actual =
      Enum.reduce_while(manifest["sources"], %{}, fn {name, expected}, digests ->
        case read_bounded(release_path(version, name, options)) do
          {:ok, contents} ->
            if sha256(contents) == expected do
              {:cont, Map.put(digests, name, expected)}
            else
              {:halt, :error}
            end

          _missing_or_changed ->
            {:halt, :error}
        end
      end)

    if is_map(actual) and package_digest(actual) == manifest["package_sha256"] do
      :ok
    else
      {:error, Error.new(:corrupt, :verify_ontology_sources)}
    end
  end

  defp parse_sources(manifest, version, options) do
    graph_iri = RDF.iri(manifest["graph_iri"])

    manifest["sources"]
    |> Map.keys()
    |> Enum.filter(&(Path.extname(&1) == ".ttl"))
    |> Enum.sort()
    |> Enum.reduce_while({:ok, RDF.Dataset.new()}, fn name, {:ok, dataset} ->
      path = release_path(version, name, options)

      case RDF.Turtle.read_file(path) do
        {:ok, %RDF.Graph{} = graph} ->
          named_graph = RDF.Graph.change_name(graph, graph_iri)

          if Enum.any?(RDF.Graph.quads(named_graph), &RDF.Quad.has_bnode?/1) do
            {:halt, {:error, Error.new(:corrupt, :parse_ontology_sources)}}
          else
            {:cont, {:ok, RDF.Dataset.add(dataset, named_graph)}}
          end

        _invalid ->
          {:halt, {:error, Error.new(:corrupt, :parse_ontology_sources)}}
      end
    end)
  rescue
    _error -> {:error, Error.new(:corrupt, :parse_ontology_sources)}
  end

  defp inherited_dataset(version) do
    case Map.fetch(@base_versions, version) do
      :error ->
        {:ok, RDF.Dataset.new()}

      {:ok, base_version} ->
        with {:ok, _verified} <- verify(base_version),
             {:ok, base} <- schema_dataset(base_version) do
          graph_iri = RDF.iri("https://jido.run/graph/ontology/#{version}")

          inherited =
            base
            |> RDF.Dataset.quads()
            |> Enum.map(fn {subject, predicate, object, _graph} ->
              RDF.quad(subject, predicate, object, graph_iri)
            end)
            |> RDF.Dataset.new()

          {:ok, inherited}
        end
    end
  end

  defp schema_dataset(version) do
    with {:ok, manifest} <- manifest(version),
         {:ok, current} <-
           parse_selected_sources(manifest, version, Map.fetch!(@schema_sources, version)),
         {:ok, inherited} <- inherited_dataset(version) do
      {:ok, RDF.Dataset.add(inherited, current)}
    end
  end

  defp parse_selected_sources(manifest, version, source_names) do
    selected =
      manifest
      |> Map.update!("sources", &Map.take(&1, source_names))

    parse_sources(selected, version, [])
  end

  defp verify_canonical_digest(canonical, manifest) do
    if sha256(canonical) == manifest["canonical_nquads_sha256"] do
      :ok
    else
      {:error, Error.new(:corrupt, :verify_ontology_canonical_digest)}
    end
  end

  defp package_digest(sources) do
    sources
    |> Enum.sort()
    |> Enum.map_join("", fn {name, digest} -> "#{name}:#{digest}\n" end)
    |> sha256()
  end

  defp sha256(contents) do
    contents
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp public_manifest(manifest) do
    %{
      version: manifest["version"],
      shape_version: manifest["shape_version"],
      ontology_iri: manifest["ontology_iri"],
      shapes_iri: manifest["shapes_iri"],
      graph_iri: manifest["graph_iri"],
      term_namespace: manifest["term_namespace"],
      resource_namespace: manifest["resource_namespace"],
      imports: manifest["imports"],
      compatibility: manifest["compatibility"],
      released_on: manifest["released_on"],
      package_sha256: manifest["package_sha256"],
      canonical_nquads_sha256: manifest["canonical_nquads_sha256"]
    }
  end

  defp ontology_commit_id(version) do
    token = String.replace(version, ".", "_")
    "urn:jido-code:commit:ontology_release_#{token}"
  end

  defp store_summary(server) do
    summary = StoreServer.summary(server)

    if summary.ready? and is_integer(summary.dataset_revision) do
      {:ok, summary}
    else
      {:error, Error.new(:unavailable, :load_ontology)}
    end
  catch
    :exit, _reason -> {:error, Error.new(:unavailable, :load_ontology)}
  end
end
