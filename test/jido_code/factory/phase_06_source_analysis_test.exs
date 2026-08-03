defmodule JidoCode.Factory.Phase06SourceAnalysisTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Observations.GitSnapshot
  alias JidoCode.Factory.Observations.Worktree
  alias JidoCode.Factory.SourceAnalysis.Request
  alias JidoCode.Integrations.ElixirSourceAnalyzer
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @observed_at ~U[2026-08-01 15:00:00Z]
  @tree String.duplicate("b", 40)
  @raw_marker "RAW_SOURCE_MUST_NOT_BE_PERSISTED"

  test "analysis is deterministic across disposable worktree recreation and excludes raw source",
       context do
    root = temporary_root(context)
    first_path = Path.join(root, "first")
    second_path = Path.join(root, "second")
    on_exit(fn -> File.rm_rf(root) end)

    write_fixture!(first_path)
    write_fixture!(second_path)

    request = request!(first_path)
    assert {:ok, analyzer} = ElixirSourceAnalyzer.new()
    assert {:ok, first} = ElixirSourceAnalyzer.analyze(analyzer, request)

    File.rm_rf!(first_path)

    assert {:ok, second} =
             ElixirSourceAnalyzer.analyze(analyzer, request!(second_path))

    first_nquads = RDF.NQuads.write_string!(first.dataset, sort: true)
    second_nquads = RDF.NQuads.write_string!(second.dataset, sort: true)

    assert first_nquads == second_nquads
    refute first_nquads =~ @raw_marker
    refute first_nquads =~ first_path
    refute first_nquads =~ second_path
    assert first.analyzer_version == "elixir-ast/1.0.0"
    assert first.configuration_digest == second.configuration_digest
    assert first.input_tree_digest == @tree
    assert first.coverage.status == :partial
    assert "parse_error" in first.warnings
    assert "symlink_skipped" in first.warnings
    assert first.resource_counts.modules == 2
    assert first.resource_counts.functions >= 3
    assert first.resource_counts.triples == length(RDF.Dataset.quads(first.dataset))
    refute function_exported?(ElixirSourceAnalyzer, :execute, 2)
  end

  test "request and analyzer bounds fail closed", context do
    root = temporary_root(context)
    on_exit(fn -> File.rm_rf(root) end)
    File.mkdir_p!(Path.join(root, "lib"))
    File.write!(Path.join(root, "lib/large.ex"), String.duplicate("# bounded\n", 200))

    attributes = request_attributes(root)

    assert {:error, %{kind: :invalid_input, operation: :source_analysis_request}} =
             Request.new(%{attributes | profile: :unsupported})

    unclean = %{attributes.git_snapshot | clean?: false}

    assert {:error, %{kind: :invalid_input, operation: :source_analysis_request}} =
             Request.new(%{attributes | git_snapshot: unclean})

    {:ok, observation_graph} =
      GraphRegistry.graph_iri(:observation_batch, %{
        repository: attributes.repository_iri,
        batch: resource!("wrong-source-output")
      })

    assert {:error, %{kind: :invalid_input}} =
             Request.new(%{attributes | output_graph_iri: observation_graph})

    limits = %{attributes.limits | max_file_bytes: 1_024}
    assert {:ok, bounded_request} = Request.new(%{attributes | limits: limits})
    assert {:ok, analyzer} = ElixirSourceAnalyzer.new()
    assert {:ok, result} = ElixirSourceAnalyzer.analyze(analyzer, bounded_request)
    assert result.coverage.status == :partial
    assert "source_file_size" in result.warnings
    assert result.resource_counts.files == 0
    assert result.resource_counts.triples <= limits.max_statements
  end

  defp write_fixture!(root) do
    lib = Path.join(root, "lib")
    File.mkdir_p!(lib)

    File.write!(
      Path.join(lib, "worker.ex"),
      """
      defmodule Fixture.Worker do
        use GenServer
        alias Fixture.Helper

        def start_link(argument), do: GenServer.start_link(__MODULE__, argument)
        def handle_call(message, _from, state), do: {:reply, Helper.reply(message), state}
        def marker, do: \"#{@raw_marker}\"
      end

      defmodule Fixture.Helper do
        def reply(message), do: message
      end
      """
    )

    File.write!(Path.join(lib, "malformed.ex"), "defmodule Fixture.Malformed do")
    File.ln_s!(Path.join(lib, "worker.ex"), Path.join(lib, "linked.ex"))
  end

  defp request!(path) do
    {:ok, request} = Request.new(request_attributes(path))
    request
  end

  defp request_attributes(path) do
    {:ok, repository} = ResourceIdentity.conceptual_repository("phase-06-source-analysis")
    {:ok, snapshot} = ResourceIdentity.repository_snapshot(repository, :sha1, @tree)
    {:ok, graph} = Knowledge.source_graph_identity(repository, snapshot)

    %{
      repository_iri: repository,
      snapshot_iri: snapshot,
      worktree: %Worktree{
        operation_id: "source-analysis-fixture",
        remote_digest: String.duplicate("a", 64),
        ref: "refs/heads/main",
        created_at: @observed_at,
        path: path
      },
      git_snapshot: git_snapshot!(),
      profile: :elixir,
      include_paths: ["lib"],
      exclude_paths: ["deps", "_build"],
      limits: %{
        max_files: 20,
        max_total_bytes: 100_000,
        max_file_bytes: 20_000,
        max_symbols: 50,
        max_expressions: 10_000,
        max_statements: 400,
        timeout_ms: 5_000
      },
      ontology_version: "1.0.0",
      output_graph_iri: graph,
      input_tree_digest: @tree
    }
  end

  defp temporary_root(context) do
    Path.join(
      System.tmp_dir!(),
      "jido-code-source-analysis-#{context.test}-#{System.unique_integer([:positive])}"
    )
  end

  defp resource!(seed) do
    {:ok, iri} = ResourceIdentity.repository(seed)
    iri
  end

  defp git_snapshot! do
    {:ok, snapshot} =
      GitSnapshot.new(%{
        commit_sha: String.duplicate("a", 40),
        tree_sha: @tree,
        parents: [],
        ref: "refs/heads/main",
        object_format: :sha1,
        submodules?: false,
        lfs?: false,
        clean?: true,
        observed_at: @observed_at,
        limitations: []
      })

    snapshot
  end
end
