defmodule JidoCode.Integrations.ElixirSourceAnalyzer do
  @moduledoc """
  Deterministic Elixir AST analyzer for exact disposable worktrees.

  Files are parsed, never compiled or executed. The emitted RDF contains
  identities, names, arities, relations, digests, and coverage only; raw source
  text is excluded.
  """

  @behaviour JidoCode.Factory.Ports.SourceAnalyzer

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.SourceAnalysis.Identity
  alias JidoCode.Factory.SourceAnalysis.Request
  alias JidoCode.Factory.SourceAnalysis.Result

  @enforce_keys [:version]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @version "elixir-ast/1.0.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @special_forms MapSet.new([
                   :__aliases__,
                   :__block__,
                   :{},
                   :<<>>,
                   :%,
                   :%{},
                   :&,
                   :.,
                   :=,
                   :^,
                   :|,
                   :when,
                   :fn,
                   :case,
                   :cond,
                   :if,
                   :unless,
                   :for,
                   :with,
                   :receive,
                   :try,
                   :quote,
                   :unquote,
                   :def,
                   :defp,
                   :defmodule
                 ])

  @spec new(keyword()) :: {:ok, t()}
  def new(_options \\ []), do: {:ok, %__MODULE__{version: @version}}

  @impl true
  def analyze(%__MODULE__{} = analyzer, %Request{} = request) do
    deadline = System.monotonic_time(:millisecond) + request.limits.timeout_ms
    configuration_digest = configuration_digest(analyzer, request)

    with :ok <- before_deadline(deadline),
         {:ok, activity_iri} <-
           Identity.activity(request.snapshot_iri, analyzer.version, configuration_digest),
         {:ok, files, discovery_warnings} <- discover_files(request),
         {:ok, analyzed} <-
           analyze_files(
             files,
             request,
             activity_iri,
             deadline
           ),
         quads <-
           activity_quads(request, analyzer, activity_iri, configuration_digest) ++ analyzed.quads,
         :ok <- statement_limit(quads, request.limits),
         dataset <- RDF.Dataset.new(quads),
         dataset_statement_count <- dataset |> RDF.Dataset.quads() |> length(),
         {:ok, result} <-
           Result.new(%{
             dataset: dataset,
             analyzer_version: analyzer.version,
             configuration_digest: configuration_digest,
             input_tree_digest: request.input_tree_digest,
             coverage: %{
               status: coverage_status(discovery_warnings ++ analyzed.warnings),
               discovered_files: length(files),
               analyzed_files: analyzed.file_count,
               analyzed_bytes: analyzed.byte_count,
               expressions: analyzed.expression_count
             },
             warnings: Enum.uniq(discovery_warnings ++ analyzed.warnings),
             resource_counts: %{
               files: analyzed.file_count,
               modules: analyzed.module_count,
               functions: analyzed.function_count,
               references: analyzed.reference_count,
               expressions: analyzed.expression_count,
               triples: dataset_statement_count
             }
           }) do
      {:ok, result}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      {:error, _contract_error} -> {:error, AdapterError.new(:corrupt, :source_analysis_result)}
      _invalid -> {:error, AdapterError.new(:invalid_input, :source_analysis)}
    end
  rescue
    _error -> {:error, AdapterError.new(:corrupt, :source_analysis)}
  end

  def analyze(_analyzer, _request),
    do: {:error, AdapterError.new(:invalid_input, :source_analysis)}

  defp discover_files(request) do
    root = Path.expand(request.worktree.path)

    request.include_paths
    |> Enum.map(&Path.join(root, &1))
    |> Enum.filter(&File.dir?/1)
    |> Enum.reduce_while({:ok, [], []}, fn path, {:ok, files, warnings} ->
      relative = Path.relative_to(path, root)

      case walk(path, relative, root, request, files, warnings) do
        {:ok, next_files, next_warnings} ->
          {:cont, {:ok, next_files, next_warnings}}

        {:limit, next_files, next_warnings} ->
          {:halt, {:ok, next_files, ["file_limit_reached" | next_warnings]}}

        {:error, %AdapterError{} = error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, files, warnings} -> {:ok, Enum.sort(Enum.uniq(files)), Enum.uniq(warnings)}
      error -> error
    end
  end

  defp walk(_path, _relative, _root, request, files, warnings)
       when length(files) >= request.limits.max_files,
       do: {:limit, files, warnings}

  defp walk(path, relative, root, request, files, warnings) do
    if excluded?(relative, request.exclude_paths) do
      {:ok, files, warnings}
    else
      case File.lstat(path) do
        {:ok, %File.Stat{type: :symlink}} ->
          {:ok, files, ["symlink_skipped" | warnings]}

        {:ok, %File.Stat{type: :directory}} ->
          walk_directory(path, relative, root, request, files, warnings)

        {:ok, %File.Stat{type: :regular}} ->
          if Path.extname(path) in [".ex", ".exs"],
            do: {:ok, [{path, Path.relative_to(path, root)} | files], warnings},
            else: {:ok, files, warnings}

        {:ok, _unsupported} ->
          {:ok, files, ["unsupported_file_type_skipped" | warnings]}

        {:error, _reason} ->
          {:error, AdapterError.new(:unavailable, :source_file_stat)}
      end
    end
  end

  defp walk_directory(path, relative, root, request, files, warnings) do
    case File.ls(path) do
      {:ok, names} ->
        names
        |> Enum.sort()
        |> Enum.reduce_while({:ok, files, warnings}, fn name, {:ok, acc, acc_warnings} ->
          child = Path.join(path, name)
          child_relative = Path.join(relative, name)

          case walk(child, child_relative, root, request, acc, acc_warnings) do
            {:ok, next, next_warnings} -> {:cont, {:ok, next, next_warnings}}
            {:limit, next, next_warnings} -> {:halt, {:limit, next, next_warnings}}
            {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
          end
        end)

      {:error, _reason} ->
        {:error, AdapterError.new(:unavailable, :source_directory_read)}
    end
  end

  defp analyze_files(files, request, activity, deadline) do
    initial = %{
      quads: [],
      warnings: [],
      byte_count: 0,
      expression_count: 0,
      file_count: 0,
      module_count: 0,
      function_count: 0,
      reference_count: 0,
      symbol_iris: MapSet.new()
    }

    Enum.reduce_while(files, {:ok, initial}, fn {path, relative}, {:ok, state} ->
      with :ok <- before_deadline(deadline),
           {:ok, stat} <- safe_stat(path),
           :ok <- file_size_allowed(stat.size, state.byte_count, request.limits),
           {:ok, source} <- safe_read(path),
           {:ok, ast} <- parse(source),
           :ok <- before_deadline(deadline),
           expressions <- expression_count(ast),
           :ok <- expression_limit(state.expression_count + expressions, request.limits),
           content_digest <- digest(source),
           {:ok, artifact} <- Identity.artifact(request.snapshot_iri, relative, content_digest),
           {:ok, semantics} <-
             source_semantics(
               ast,
               request,
               artifact,
               activity,
               stat.size,
               relative,
               content_digest
             ),
           :ok <- before_deadline(deadline),
           {:ok, merged} <- merge_semantics(state, semantics, expressions, stat.size, request) do
        {:cont, {:ok, merged}}
      else
        {:skip, warning} ->
          {:cont, {:ok, %{state | warnings: [warning | state.warnings]}}}

        {:error, %AdapterError{} = error} ->
          if error.operation in [:source_file_size, :source_total_bytes, :source_expression_limit] do
            {:halt,
             {:ok, %{state | warnings: [Atom.to_string(error.operation) | state.warnings]}}}
          else
            {:halt, {:error, error}}
          end
      end
    end)
    |> case do
      {:ok, state} ->
        {:ok, %{state | quads: Enum.reverse(state.quads), warnings: Enum.reverse(state.warnings)}}

      error ->
        error
    end
  end

  defp source_semantics(ast, request, artifact, activity, size, relative, content_digest) do
    modules = module_entries(ast)

    with {:ok, module_semantics} <-
           Enum.reduce_while(modules, {:ok, empty_semantics()}, fn module, {:ok, acc} ->
             case module_semantics(module, request, artifact) do
               {:ok, semantics} -> {:cont, {:ok, combine_semantics(acc, semantics)}}
               {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
             end
           end) do
      artifact_quads = [
        quad(artifact, @rdf_type, iri(@jf <> "SourceArtifact"), request.output_graph_iri),
        quad(
          artifact,
          @jf <> "sourceSnapshot",
          iri(request.snapshot_iri),
          request.output_graph_iri
        ),
        quad(
          artifact,
          @prov <> "wasDerivedFrom",
          iri(request.snapshot_iri),
          request.output_graph_iri
        ),
        quad(artifact, @prov <> "wasGeneratedBy", iri(activity), request.output_graph_iri),
        quad(
          artifact,
          @jf <> "relativePath",
          RDF.XSD.String.new(relative),
          request.output_graph_iri
        ),
        quad(
          artifact,
          @jf <> "contentDigest",
          RDF.XSD.String.new(content_digest),
          request.output_graph_iri
        ),
        quad(
          artifact,
          @jf <> "byteCount",
          RDF.XSD.NonNegativeInteger.new(size),
          request.output_graph_iri
        ),
        quad(artifact, @jf <> "language", RDF.XSD.String.new("Elixir"), request.output_graph_iri)
      ]

      {:ok, %{module_semantics | quads: artifact_quads ++ module_semantics.quads}}
    end
  end

  defp module_semantics(%{name: module_name, body: body}, request, artifact) do
    with {:ok, module_iri} <- Identity.symbol(request.snapshot_iri, :module, module_name),
         {:ok, functions} <- function_semantics(body, module_name, module_iri, request, artifact),
         {:ok, dependencies} <- dependency_semantics(body, module_iri, request, artifact) do
      quads = [
        symbol_quads(module_iri, "Module", :module, module_name, request, artifact),
        quad(artifact, @jf <> "containsSymbol", iri(module_iri), request.output_graph_iri)
      ]

      {:ok,
       %{
         quads: [quads | functions.quads ++ dependencies.quads] |> List.flatten(),
         modules: 1,
         functions: functions.functions,
         references: functions.references + dependencies.references,
         symbol_iris:
           MapSet.union(
             MapSet.put(functions.symbol_iris, module_iri),
             dependencies.symbol_iris
           )
       }}
    else
      {:error, _error} -> {:error, AdapterError.new(:invalid_input, :source_symbol_identity)}
    end
  end

  defp function_semantics(body, module_name, module_iri, request, artifact) do
    body
    |> function_entries()
    |> Enum.reduce_while({:ok, empty_semantics()}, fn function, {:ok, acc} ->
      qualified = "#{module_name}.#{function.name}/#{function.arity}"

      with {:ok, function_iri} <-
             Identity.symbol(request.snapshot_iri, function.visibility, qualified),
           {:ok, calls} <-
             call_semantics(function.body, function_iri, module_name, request, artifact) do
        quads = [
          symbol_quads(
            function_iri,
            "Function",
            function.visibility,
            qualified,
            request,
            artifact
          ),
          quad(
            function_iri,
            @jf <> "arity",
            RDF.XSD.NonNegativeInteger.new(function.arity),
            request.output_graph_iri
          ),
          quad(
            function_iri,
            @jf <> "visibility",
            RDF.XSD.String.new(Atom.to_string(function.visibility)),
            request.output_graph_iri
          ),
          quad(module_iri, @jf <> "defines", iri(function_iri), request.output_graph_iri),
          quad(artifact, @jf <> "containsSymbol", iri(function_iri), request.output_graph_iri)
        ]

        next = %{
          quads: quads ++ calls.quads ++ acc.quads,
          modules: 0,
          functions: acc.functions + 1,
          references: acc.references + calls.references,
          symbol_iris:
            acc.symbol_iris
            |> MapSet.put(function_iri)
            |> MapSet.union(calls.symbol_iris)
        }

        {:cont, {:ok, next}}
      else
        {:error, _error} ->
          {:halt, {:error, AdapterError.new(:invalid_input, :source_symbol_identity)}}
      end
    end)
  end

  defp call_semantics(body, function_iri, module_name, request, artifact) do
    body
    |> call_entries(module_name)
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, empty_semantics()}, fn call, {:ok, acc} ->
      with {:ok, target} <- Identity.symbol(request.snapshot_iri, :reference, call) do
        quads = [
          symbol_quads(target, "Reference", :reference, call, request, artifact),
          quad(function_iri, @jf <> "calls", iri(target), request.output_graph_iri)
        ]

        {:cont,
         {:ok,
          %{
            acc
            | quads: quads ++ acc.quads,
              references: acc.references + 1,
              symbol_iris: MapSet.put(acc.symbol_iris, target)
          }}}
      else
        {:error, _error} ->
          {:halt, {:error, AdapterError.new(:invalid_input, :source_symbol_identity)}}
      end
    end)
  end

  defp dependency_semantics(body, module_iri, request, artifact) do
    dependencies = dependency_entries(body)
    otp_patterns = Enum.filter(dependencies, &(&1 in ["GenServer", "Supervisor", "Application"]))

    dependencies
    |> Enum.reduce_while({:ok, empty_semantics()}, fn dependency, {:ok, acc} ->
      with {:ok, target} <- Identity.symbol(request.snapshot_iri, :module_reference, dependency) do
        pattern_quads =
          if dependency in otp_patterns do
            [
              quad(
                module_iri,
                @jf <> "otpPattern",
                RDF.XSD.String.new(dependency),
                request.output_graph_iri
              )
            ]
          else
            []
          end

        quads = [
          symbol_quads(
            target,
            "Reference",
            :module_reference,
            dependency,
            request,
            artifact
          ),
          quad(module_iri, @jf <> "dependsOn", iri(target), request.output_graph_iri)
          | pattern_quads
        ]

        {:cont,
         {:ok,
          %{
            acc
            | quads: quads ++ acc.quads,
              references: acc.references + 1,
              symbol_iris: MapSet.put(acc.symbol_iris, target)
          }}}
      else
        {:error, _error} ->
          {:halt, {:error, AdapterError.new(:invalid_input, :source_symbol_identity)}}
      end
    end)
  end

  defp activity_quads(request, analyzer, activity, config_digest) do
    graph = request.output_graph_iri

    [
      quad(activity, @rdf_type, iri(@prov <> "Activity"), graph),
      quad(activity, @jf <> "sourceSnapshot", iri(request.snapshot_iri), graph),
      quad(activity, @prov <> "used", iri(request.snapshot_iri), graph),
      quad(activity, @jf <> "analyzerVersion", RDF.XSD.String.new(analyzer.version), graph),
      quad(activity, @jf <> "configurationDigest", RDF.XSD.String.new(config_digest), graph),
      quad(
        activity,
        @jf <> "inputTreeDigest",
        RDF.XSD.String.new(request.input_tree_digest),
        graph
      )
    ]
  end

  defp symbol_quads(symbol, kind, identity_kind, name, request, artifact) do
    [
      quad(symbol, @rdf_type, iri(@jf <> "CodeSymbol"), request.output_graph_iri),
      quad(symbol, @jf <> "sourceSnapshot", iri(request.snapshot_iri), request.output_graph_iri),
      quad(symbol, @jf <> "inArtifact", iri(artifact), request.output_graph_iri),
      quad(symbol, @jf <> "symbolKind", iri(@concept <> kind), request.output_graph_iri),
      quad(
        symbol,
        @jf <> "identityKind",
        RDF.XSD.String.new(Atom.to_string(identity_kind)),
        request.output_graph_iri
      ),
      quad(symbol, @jf <> "displayName", RDF.XSD.String.new(name), request.output_graph_iri)
    ]
  end

  defp module_entries(ast) do
    {_ast, modules} =
      Macro.prewalk(ast, [], fn
        {:defmodule, _meta, [name_ast, [do: body]]} = node, acc ->
          name = Macro.to_string(name_ast)
          {node, [%{name: name, body: body} | acc]}

        node, acc ->
          {node, acc}
      end)

    modules |> Enum.reverse() |> Enum.uniq_by(& &1.name)
  end

  defp function_entries(body) do
    {_ast, functions} =
      Macro.prewalk(body, [], fn
        {visibility, _meta, [head, [do: function_body]]} = node, acc
        when visibility in [:def, :defp] ->
          case function_head(head) do
            {:ok, name, arity} ->
              {node,
               [%{name: name, arity: arity, visibility: visibility, body: function_body} | acc]}

            :error ->
              {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(functions)
  end

  defp function_head({:when, _meta, [head | _guards]}), do: function_head(head)

  defp function_head({name, _meta, args}) when is_atom(name) and is_list(args),
    do: {:ok, name, length(args)}

  defp function_head({name, _meta, nil}) when is_atom(name), do: {:ok, name, 0}
  defp function_head(_head), do: :error

  defp call_entries(body, module_name) do
    {_ast, calls} =
      Macro.prewalk(body, [], fn
        {{:., _dot_meta, [module_ast, name]}, _meta, args} = node, acc
        when is_atom(name) and is_list(args) ->
          module = Macro.to_string(module_ast)
          {node, ["#{module}.#{name}/#{length(args)}" | acc]}

        {name, _meta, args} = node, acc when is_atom(name) and is_list(args) ->
          if MapSet.member?(@special_forms, name),
            do: {node, acc},
            else: {node, ["#{module_name}.#{name}/#{length(args)}" | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(calls)
  end

  defp dependency_entries(body) do
    {_ast, dependencies} =
      Macro.prewalk(body, [], fn
        {kind, _meta, [module_ast | _rest]} = node, acc
        when kind in [:alias, :import, :require, :use] ->
          {node, [Macro.to_string(module_ast) | acc]}

        {:@, _meta, [{:behaviour, _attribute_meta, [module_ast]}]} = node, acc ->
          {node, [Macro.to_string(module_ast) | acc]}

        node, acc ->
          {node, acc}
      end)

    dependencies |> Enum.reverse() |> Enum.uniq()
  end

  defp expression_count(ast) do
    {_ast, count} = Macro.prewalk(ast, 0, fn node, count -> {node, count + 1} end)
    count
  end

  defp merge_semantics(state, semantics, expressions, bytes, request) do
    symbols = MapSet.union(state.symbol_iris, semantics.symbol_iris)

    if MapSet.size(symbols) <= request.limits.max_symbols do
      {:ok,
       %{
         state
         | quads: semantics.quads ++ state.quads,
           byte_count: state.byte_count + bytes,
           expression_count: state.expression_count + expressions,
           file_count: state.file_count + 1,
           module_count: state.module_count + semantics.modules,
           function_count: state.function_count + semantics.functions,
           reference_count: state.reference_count + semantics.references,
           symbol_iris: symbols
       }}
    else
      {:error, AdapterError.new(:invalid_input, :source_symbol_limit)}
    end
  end

  defp empty_semantics do
    %{quads: [], modules: 0, functions: 0, references: 0, symbol_iris: MapSet.new()}
  end

  defp combine_semantics(left, right) do
    %{
      quads: left.quads ++ right.quads,
      modules: left.modules + right.modules,
      functions: left.functions + right.functions,
      references: left.references + right.references,
      symbol_iris: MapSet.union(left.symbol_iris, right.symbol_iris)
    }
  end

  defp configuration_digest(analyzer, request) do
    %{
      analyzer: analyzer.version,
      profile: request.profile,
      include_paths: request.include_paths,
      exclude_paths: request.exclude_paths,
      limits: request.limits,
      ontology_version: request.ontology_version
    }
    |> :erlang.term_to_binary([:deterministic])
    |> digest()
  end

  defp parse(source) do
    case Code.string_to_quoted(source, columns: true, token_metadata: true) do
      {:ok, ast} -> {:ok, ast}
      {:error, _reason} -> {:skip, "parse_error"}
    end
  end

  defp safe_stat(path) do
    case File.stat(path) do
      {:ok, %File.Stat{} = stat} -> {:ok, stat}
      {:error, _reason} -> {:error, AdapterError.new(:unavailable, :source_file_stat)}
    end
  end

  defp safe_read(path) do
    case File.read(path) do
      {:ok, source} -> {:ok, source}
      {:error, _reason} -> {:error, AdapterError.new(:unavailable, :source_file_read)}
    end
  end

  defp file_size_allowed(size, _total, limits) when size > limits.max_file_bytes,
    do: {:error, AdapterError.new(:invalid_input, :source_file_size)}

  defp file_size_allowed(size, total, limits) when size + total > limits.max_total_bytes,
    do: {:error, AdapterError.new(:invalid_input, :source_total_bytes)}

  defp file_size_allowed(_size, _total, _limits), do: :ok

  defp expression_limit(total, limits) when total > limits.max_expressions,
    do: {:error, AdapterError.new(:invalid_input, :source_expression_limit)}

  defp expression_limit(_total, _limits), do: :ok

  defp statement_limit(quads, limits) do
    if length(quads) <= limits.max_statements,
      do: :ok,
      else: {:error, AdapterError.new(:invalid_input, :source_statement_limit)}
  end

  defp excluded?(relative, exclusions) do
    Enum.any?(exclusions, &(relative == &1 or String.starts_with?(relative, &1 <> "/")))
  end

  defp coverage_status([]), do: :complete
  defp coverage_status(_warnings), do: :partial

  defp before_deadline(deadline) do
    if System.monotonic_time(:millisecond) < deadline,
      do: :ok,
      else: {:error, AdapterError.new(:timeout, :source_analysis)}
  end

  defp digest(value) when is_binary(value) do
    value |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end

  defp quad(subject, predicate, object, graph), do: RDF.quad(subject, predicate, object, graph)
  defp iri(value), do: RDF.iri(value)
end
