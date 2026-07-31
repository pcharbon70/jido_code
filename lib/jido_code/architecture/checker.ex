defmodule JidoCode.Architecture.Checker do
  @moduledoc false

  alias JidoCode.Architecture.Violation

  @default_limit 50
  @elixir_globs ["lib/**/*.ex"]
  @presentation_globs ["lib/**/*.heex", "assets/**/*.js", "assets/**/*.ts", "assets/**/*.vue"]
  @excluded_prefixes ["lib/jido_code/architecture/", "lib/mix/tasks/"]

  @forbidden_persistence_prefixes [
    "Ash.Resource",
    "CubDB",
    "Ecto.Repo",
    "Ecto.Schema",
    "Level",
    "Postgrex",
    "Redix",
    "RocksDB"
  ]

  @raw_sparql ~r/\b(?:SELECT\s+.+?\s+WHERE\s*\{|ASK\s*\{|CONSTRUCT\s*\{|INSERT\s+DATA\s*\{|DELETE\s+(?:DATA|WHERE)\s*\{)/is
  @generic_store ~r/(?:^|\.)(?:EntityStore|GenericEntityStore|RecordStore|CrudStore)$/
  @record_codec_functions [:encode_record, :decode_record, :dump_entity, :load_entity]
  @store_handle_fields [:store, :db, :dict_manager, :transaction]
  @direct_update_owners [
    "JidoCode.Knowledge.AtomicCommit",
    "JidoCode.Knowledge.Metadata",
    "JidoCode.Knowledge.RestoreLog"
  ]
  @theme_path "assets/js/theme.js"
  @theme_sha256 "b5c950f5dfe08d10ad0eb9e72144a7440452d628f1ce330101341dc45a74eba2"
  @file_roles %{
    temporary: [:integrations, :runtime],
    build_artifact: [:integrations, :runtime],
    external_worktree: [:integrations, :runtime],
    graph_backup: [:knowledge]
  }

  @spec check(Path.t(), keyword()) :: {:ok, []} | {:error, [Violation.t()]}
  def check(root \\ File.cwd!(), opts \\ []) do
    sources =
      (@elixir_globs ++ @presentation_globs)
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.uniq()
      |> Enum.map(fn path -> {Path.relative_to(path, root), File.read!(path)} end)

    check_sources(sources, opts)
  end

  @spec check_sources([{String.t(), String.t()}], keyword()) ::
          {:ok, []} | {:error, [Violation.t()]}
  def check_sources(sources, opts \\ []) when is_list(sources) do
    limit = Keyword.get(opts, :limit, @default_limit)

    violations =
      sources
      |> Enum.reject(fn {path, _source} -> excluded?(path) end)
      |> Enum.flat_map(&analyze_source/1)
      |> Enum.uniq_by(&{&1.rule, &1.file, &1.line, &1.message})
      |> Enum.sort_by(&{&1.file, &1.line, &1.rule})
      |> Enum.take(limit)

    if violations == [], do: {:ok, []}, else: {:error, violations}
  end

  defp analyze_source({path, source}) do
    case Path.extname(path) do
      extension when extension in [".ex", ".exs"] ->
        analyze_elixir(path, source)

      extension when extension in [".heex", ".js", ".ts", ".vue"] ->
        analyze_presentation(path, source)

      _other ->
        []
    end
  end

  defp analyze_elixir(path, source) do
    case Code.string_to_quoted(source, columns: true, token_metadata: true) do
      {:ok, ast} ->
        modules = collect_modules(ast)
        caller = modules |> List.first() |> elem_or_default(0, "Unknown")
        plane = plane(caller)
        aliases = collect_aliases(ast)
        calls = collect_calls(ast)
        file_role = collect_file_role(ast)
        struct_fields = collect_struct_fields(ast)
        functions = collect_functions(ast)
        json_derived? = json_encoder_derived?(ast)

        []
        |> add_multiple_module_violation(path, modules)
        |> add_forbidden_dependency_violations(path, aliases)
        |> add_direction_violations(path, caller, plane, aliases)
        |> add_call_violations(path, caller, plane, calls, file_role)
        |> add_model_violations(
          path,
          caller,
          plane,
          modules,
          struct_fields,
          functions,
          json_derived?
        )
        |> add_raw_sparql_violation(path, source, plane)

      {:error, {location, description, token}} ->
        [
          violation(
            :source_parse,
            path,
            location_line(location),
            "cannot parse source: #{description} #{inspect(token)}"
          )
        ]
    end
  end

  defp analyze_presentation(path, source) do
    []
    |> maybe_add(
      Regex.match?(@raw_sparql, source),
      violation(
        :presentation_raw_sparql,
        path,
        matching_line(source, @raw_sparql),
        "presentation code must use a reviewed projection, not raw SPARQL"
      )
    )
    |> maybe_add(
      browser_persistence_violation?(path, source),
      violation(
        :presentation_persistence,
        path,
        browser_persistence_line(source),
        "browser persistence is limited to phx:theme in assets/js/theme.js"
      )
    )
  end

  defp add_multiple_module_violation(violations, _path, [_one]), do: violations
  defp add_multiple_module_violation(violations, _path, []), do: violations

  defp add_multiple_module_violation(violations, path, [_first, {_name, line} | _rest]) do
    [
      violation(
        :module_ownership,
        path,
        line,
        "define one module per file so dependency ownership remains unambiguous"
      )
      | violations
    ]
  end

  defp add_forbidden_dependency_violations(violations, path, aliases) do
    Enum.reduce(aliases, violations, fn {target, line}, acc ->
      if Enum.any?(@forbidden_persistence_prefixes, &module_prefix?(target, &1)) do
        [
          violation(
            :parallel_persistence,
            path,
            line,
            "#{target} is a prohibited application persistence dependency"
          )
          | acc
        ]
      else
        acc
      end
    end)
  end

  defp add_direction_violations(violations, path, caller, caller_plane, aliases) do
    Enum.reduce(aliases, violations, fn {target, line}, acc ->
      case direction_error(caller, caller_plane, target) do
        nil -> acc
        message -> [violation(:dependency_direction, path, line, message) | acc]
      end
    end)
  end

  defp add_call_violations(violations, path, caller, caller_plane, calls, file_role) do
    Enum.reduce(calls, violations, fn call, acc ->
      acc
      |> maybe_add(
        call.module in [":dets", ":mnesia"],
        violation(
          :parallel_persistence,
          path,
          call.line,
          "#{call.module}.#{call.function} is prohibited; durable state belongs in the graph"
        )
      )
      |> maybe_add(
        call.module == ":rocksdb" and not module_prefix?(caller, "JidoCode.Knowledge.Backend"),
        violation(
          :raw_rocksdb,
          path,
          call.line,
          "direct :rocksdb access is limited to JidoCode.Knowledge.Backend"
        )
      )
      |> maybe_add(
        call.module == "TripleStore" and call.function == :open and
          caller != "JidoCode.Knowledge.StoreServer",
        violation(
          :store_ownership,
          path,
          call.line,
          "only JidoCode.Knowledge.StoreServer may open TripleStore"
        )
      )
      |> maybe_add(
        call.module == "TripleStore" and call.function in [:update, :update!] and
          caller not in @direct_update_owners,
        violation(
          :write_coordinator,
          path,
          call.line,
          "persistent graph updates must run through an approved knowledge write coordinator"
        )
      )
      |> maybe_add(
        module_prefix?(call.module, "TripleStore") and caller_plane != :knowledge,
        violation(
          :raw_store_access,
          path,
          call.line,
          "#{caller} must use a public knowledge contract instead of #{call.module}"
        )
      )
      |> maybe_add_file_write(path, caller_plane, call, file_role)
    end)
  end

  defp add_model_violations(
         violations,
         path,
         caller,
         caller_plane,
         modules,
         fields,
         functions,
         json_derived?
       ) do
    {module_name, line} = List.first(modules) || {caller, 1}

    violations
    |> maybe_add(
      Regex.match?(@generic_store, module_name),
      violation(
        :record_domain_model,
        path,
        line,
        "generic entity/record stores are prohibited; model durable relationships as RDF"
      )
    )
    |> maybe_add(
      json_derived? and Enum.count(fields, &foreign_key_field?/1) >= 2,
      violation(
        :foreign_key_model,
        path,
        line,
        "persisted JSON structs with foreign-key-shaped fields are prohibited"
      )
    )
    |> maybe_add(
      Enum.any?(functions, &(&1.name in @record_codec_functions)),
      violation(
        :record_codec,
        path,
        function_line(functions, @record_codec_functions),
        "record/entity codecs are prohibited; RDF is the durable model"
      )
    )
    |> maybe_add(
      caller_plane != :knowledge and Enum.any?(fields, &(&1 in @store_handle_fields)),
      violation(
        :store_handle_leak,
        path,
        line,
        "raw store-handle fields cannot leave JidoCode.Knowledge"
      )
    )
  end

  defp add_raw_sparql_violation(violations, _path, _source, :knowledge), do: violations

  defp add_raw_sparql_violation(violations, path, source, _plane) do
    maybe_add(
      violations,
      Regex.match?(@raw_sparql, source),
      violation(
        :raw_sparql,
        path,
        matching_line(source, @raw_sparql),
        "raw SPARQL is private to JidoCode.Knowledge query and command adapters"
      )
    )
  end

  defp maybe_add_file_write(violations, path, plane, call, file_role) do
    if file_write_call?(call) and not valid_file_role?(plane, file_role) do
      [
        violation(
          :file_persistence,
          path,
          call.line,
          "filesystem writes require an approved @architecture_file_role and owner namespace"
        )
        | violations
      ]
    else
      violations
    end
  end

  defp direction_error(caller, caller_plane, target) do
    target_plane = plane(target)

    cond do
      target == caller ->
        nil

      caller_plane == :knowledge and target_plane in [:factory, :integrations, :runtime, :web] ->
        "JidoCode.Knowledge cannot depend on #{target}"

      caller_plane == :factory and target_plane == :knowledge and
          not public_knowledge_target?(:factory, target) ->
        "JidoCode.Factory may use only public knowledge commands, queries, health, and errors"

      caller_plane == :factory and target_plane in [:integrations, :web] ->
        "JidoCode.Factory cannot depend on #{target}"

      caller_plane == :integrations and target_plane in [:knowledge, :web] ->
        "JidoCode.Integrations cannot depend on #{target}"

      caller_plane == :runtime and target_plane in [:knowledge, :integrations, :web] ->
        "JidoCode.Runtime cannot depend on #{target}"

      caller_plane == :web and target_plane == :knowledge and
          not public_knowledge_target?(:web, target) ->
        "JidoCodeWeb may use only approved knowledge projections, health, and errors"

      true ->
        nil
    end
  end

  defp public_knowledge_target?(:factory, target) do
    target == "JidoCode.Knowledge" or
      Enum.any?(
        [
          "JidoCode.Knowledge.Commands",
          "JidoCode.Knowledge.Queries",
          "JidoCode.Knowledge.Projections",
          "JidoCode.Knowledge.Health",
          "JidoCode.Knowledge.Error"
        ],
        &module_prefix?(target, &1)
      )
  end

  defp public_knowledge_target?(:web, target) do
    Enum.any?(
      [
        "JidoCode.Knowledge.Projections",
        "JidoCode.Knowledge.Health",
        "JidoCode.Knowledge.Error"
      ],
      &module_prefix?(target, &1)
    )
  end

  defp collect_modules(ast) do
    {_ast, modules} =
      Macro.prewalk(ast, [], fn
        {:defmodule, meta, [module_ast, _body]} = node, acc ->
          {node, [{module_name(module_ast), Keyword.get(meta, :line, 1)} | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(modules)
  end

  defp collect_aliases(ast) do
    {_ast, aliases} =
      Macro.prewalk(ast, [], fn
        {:__aliases__, meta, parts} = node, acc ->
          {node, [{Enum.map_join(parts, ".", &to_string/1), Keyword.get(meta, :line, 1)} | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(aliases)
  end

  defp collect_calls(ast) do
    {_ast, calls} =
      Macro.prewalk(ast, [], fn
        {{:., _dot_meta, [module_ast, function]}, meta, args} = node, acc
        when is_atom(function) and is_list(args) ->
          call = %{
            module: module_name(module_ast),
            function: function,
            args: args,
            line: Keyword.get(meta, :line, 1)
          }

          {node, [call | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(calls)
  end

  defp collect_file_role(ast) do
    {_ast, roles} =
      Macro.prewalk(ast, [], fn
        {:@, _meta, [{:architecture_file_role, _attribute_meta, [role]}]} = node, acc
        when is_atom(role) ->
          {node, [role | acc]}

        node, acc ->
          {node, acc}
      end)

    List.first(roles)
  end

  defp collect_struct_fields(ast) do
    {_ast, fields} =
      Macro.prewalk(ast, [], fn
        {:defstruct, _meta, [definition]} = node, acc ->
          {node, struct_field_names(definition) ++ acc}

        node, acc ->
          {node, acc}
      end)

    fields
  end

  defp collect_functions(ast) do
    {_ast, functions} =
      Macro.prewalk(ast, [], fn
        {kind, meta, [{name, _function_meta, _arguments} | _body]} = node, acc
        when kind in [:def, :defp] and is_atom(name) ->
          {node, [%{name: name, line: Keyword.get(meta, :line, 1)} | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(functions)
  end

  defp json_encoder_derived?(ast) do
    {_ast, found?} =
      Macro.prewalk(ast, false, fn
        {:@, _meta, [{:derive, _attribute_meta, [derive_ast]}]} = node, acc ->
          {node, acc or contains_module?(derive_ast, "Jason.Encoder")}

        node, acc ->
          {node, acc}
      end)

    found?
  end

  defp contains_module?(ast, expected) do
    {_ast, found?} =
      Macro.prewalk(ast, false, fn
        {:__aliases__, _meta, parts} = node, acc ->
          {node, acc or Enum.map_join(parts, ".", &to_string/1) == expected}

        node, acc ->
          {node, acc}
      end)

    found?
  end

  defp struct_field_names(fields) when is_list(fields) do
    Enum.flat_map(fields, fn
      field when is_atom(field) -> [field]
      {field, _default} when is_atom(field) -> [field]
      _other -> []
    end)
  end

  defp struct_field_names(_other), do: []

  defp file_write_call?(%{module: "File", function: function})
       when function in [:write, :write!, :stream!, :cp, :cp!, :cp_r, :cp_r!, :rename],
       do: true

  defp file_write_call?(%{module: ":file", function: function})
       when function in [:write_file, :pwrite, :write],
       do: true

  defp file_write_call?(%{module: "File", function: function, args: args})
       when function in [:open, :open!] do
    Enum.any?(args, fn arg ->
      Macro.to_string(arg) =~ ~r/\b(?:write|append|exclusive)\b/
    end)
  end

  defp file_write_call?(_call), do: false

  defp valid_file_role?(plane, role) do
    plane in Map.get(@file_roles, role, [])
  end

  defp foreign_key_field?(field) do
    field |> Atom.to_string() |> String.ends_with?("_id")
  end

  defp function_line(functions, names) do
    case Enum.find(functions, &(&1.name in names)) do
      nil -> 1
      function -> function.line
    end
  end

  defp browser_persistence_violation?(path, source) do
    local_storage? = String.contains?(source, ["localStorage", "sessionStorage"])
    indexed_db? = String.contains?(source, ["indexedDB", "IndexedDB"])
    allowed_theme? = path == @theme_path and source_sha256(source) == @theme_sha256

    indexed_db? or (local_storage? and not allowed_theme?)
  end

  defp source_sha256(source) do
    :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)
  end

  defp browser_persistence_line(source) do
    pattern = ~r/(?:localStorage|sessionStorage|indexedDB|IndexedDB)/
    matching_line(source, pattern)
  end

  defp matching_line(source, pattern) do
    case Regex.run(pattern, source, return: :index) do
      [{offset, _length} | _rest] ->
        source |> binary_part(0, offset) |> count_lines()

      _no_match ->
        1
    end
  end

  defp count_lines(prefix), do: length(String.split(prefix, "\n"))

  defp location_line(location) when is_list(location), do: Keyword.get(location, :line, 1)
  defp location_line({line, _column}) when is_integer(line), do: line
  defp location_line(line) when is_integer(line), do: line
  defp location_line(_location), do: 1

  defp module_name({:__aliases__, _meta, parts}), do: Enum.map_join(parts, ".", &to_string/1)
  defp module_name(module) when is_atom(module), do: inspect(module)
  defp module_name(_module), do: "Unknown"

  defp plane("JidoCodeWeb" <> _rest), do: :web
  defp plane(module), do: plane_for_jido_code(module)

  defp plane_for_jido_code(module) do
    cond do
      module_prefix?(module, "JidoCode.Knowledge") -> :knowledge
      module_prefix?(module, "JidoCode.Factory") -> :factory
      module_prefix?(module, "JidoCode.Integrations") -> :integrations
      module_prefix?(module, "JidoCode.Runtime") -> :runtime
      module_prefix?(module, "JidoCode.Architecture") -> :tooling
      module_prefix?(module, "JidoCode") -> :root
      true -> :external
    end
  end

  defp module_prefix?(module, prefix),
    do: module == prefix or String.starts_with?(module, prefix <> ".")

  defp excluded?(path), do: Enum.any?(@excluded_prefixes, &String.starts_with?(path, &1))

  defp elem_or_default(tuple, index, _default) when is_tuple(tuple), do: elem(tuple, index)
  defp elem_or_default(_value, _index, default), do: default

  defp maybe_add(violations, true, violation), do: [violation | violations]
  defp maybe_add(violations, false, _violation), do: violations

  defp violation(rule, file, line, message) do
    %Violation{rule: rule, file: file, line: max(line, 1), message: message}
  end
end
