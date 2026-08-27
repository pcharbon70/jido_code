defmodule JidoCode.Knowledge.RepositoryWiki.MixStatic do
  @moduledoc "Bounded non-evaluating extraction of structurally provable Mix project facts."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.SafeAst

  @profile "mix-static/1.0.0"
  @maximums Map.merge(SafeAst.default_limits(), %{
              functions: 128,
              dependencies: 512,
              diagnostics: 256
            })
  @option_keys ~w[only targets optional override runtime path in_umbrella git github branch tag ref sparse subdir hex repo app compile depth manager]

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      parser: System.version(),
      limits: @maximums,
      evaluation: :forbidden,
      macro_expansion: :forbidden,
      code_loading: :forbidden,
      network: :forbidden
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec extract(String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def extract(source, attributes \\ %{})

  def extract(source, attributes) when is_binary(source) and is_map(attributes) do
    limits = Map.get(attributes, :limits, @maximums)
    source_path = Map.get(attributes, :source_path, "mix.exs")

    with :ok <- valid_path(source_path),
         :ok <- valid_limits(limits),
         {:ok, ast, measurement} <-
           SafeAst.parse(source, limits: limits, operation: :repository_wiki_mix_static),
         {:ok, functions, definition_diagnostics} <- functions(ast, limits),
         {:ok, fields, dependencies, extraction_diagnostics} <-
           extract_functions(functions, limits) do
      diagnostics =
        (definition_diagnostics ++ extraction_diagnostics)
        |> Enum.sort_by(&{&1.location.line || 0, &1.location.column || 0, &1.code, &1.field})
        |> Enum.take(limits.diagnostics)

      coverage = coverage(fields, diagnostics)

      result = %{
        profile: @profile,
        profile_digest: profile().digest,
        parser_version: System.version(),
        source_path: source_path,
        source_digest: sha256(source),
        ast: measurement,
        fields: Enum.sort_by(fields, & &1.name),
        dependencies: Enum.sort_by(dependencies, &{&1.name, &1.location.line || 0}),
        diagnostics: diagnostics,
        coverage: coverage,
        dependency_count: length(dependencies),
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      {:ok, Map.put(result, :digest, Contract.digest(result))}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  rescue
    _error -> invalid()
  end

  def extract(_source, _attributes), do: invalid()

  defp functions(ast, limits) do
    {definitions, diagnostics} = collect_functions(ast, %{}, [])

    if map_size(definitions) <= limits.functions do
      {:ok, definitions, diagnostics}
    else
      invalid()
    end
  end

  defp collect_functions({name, _metadata, [head, body]} = node, definitions, diagnostics) do
    {definitions, diagnostics} =
      case SafeAst.atom_name(name) do
        {:ok, kind} when kind in ["def", "defp"] ->
          add_function(head, body, definitions, diagnostics)

        _other ->
          {definitions, diagnostics}
      end

    node
    |> Tuple.to_list()
    |> Enum.reduce({definitions, diagnostics}, fn child, {defs, diags} ->
      collect_functions(child, defs, diags)
    end)
  end

  defp collect_functions(value, definitions, diagnostics) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.reduce({definitions, diagnostics}, fn child, {defs, diags} ->
      collect_functions(child, defs, diags)
    end)
  end

  defp collect_functions(value, definitions, diagnostics) when is_list(value) do
    Enum.reduce(value, {definitions, diagnostics}, fn child, {defs, diags} ->
      collect_functions(child, defs, diags)
    end)
  end

  defp collect_functions(_value, definitions, diagnostics), do: {definitions, diagnostics}

  defp add_function({name, metadata, arguments}, body_keyword, definitions, diagnostics) do
    with {:ok, function_name} <- SafeAst.atom_name(name),
         true <- arguments in [nil, []],
         {:ok, body} <- keyword_value(body_keyword, "do") do
      definition = %{body: body, location: location(metadata)}

      if Map.has_key?(definitions, function_name) do
        diagnostic =
          diagnostic(:duplicate_function, function_name, :unsupported, location(metadata))

        {definitions, [diagnostic | diagnostics]}
      else
        {Map.put(definitions, function_name, definition), diagnostics}
      end
    else
      _not_zero_arity -> {definitions, diagnostics}
    end
  end

  defp add_function(_head, _body, definitions, diagnostics), do: {definitions, diagnostics}

  defp extract_functions(functions, limits) do
    project = Map.get(functions, "project")
    application = Map.get(functions, "application")
    cli = Map.get(functions, "cli")

    with {:ok, project_fields, project_dependencies, project_diagnostics} <-
           extract_project(project, functions, limits),
         {:ok, application_fields, application_diagnostics} <-
           extract_keyword_function("application", application, functions, limits),
         {:ok, cli_fields, cli_diagnostics} <-
           extract_keyword_function("cli", cli, functions, limits) do
      {:ok, project_fields ++ application_fields ++ cli_fields, project_dependencies,
       project_diagnostics ++ application_diagnostics ++ cli_diagnostics}
    end
  end

  defp extract_project(nil, _functions, _limits) do
    {:ok, [], [], [diagnostic(:missing_project, "project", :invalid, %{line: nil, column: nil})]}
  end

  defp extract_project(definition, functions, limits) do
    case keyword_expression(definition.body) do
      {:ok, pairs} ->
        Enum.reduce_while(pairs, {:ok, [], [], []}, fn {name, expression, field_location},
                                                       {:ok, fields, dependencies, diagnostics} ->
          case name do
            "deps" ->
              case resolve(expression, functions, %{}, [], limits) do
                {:ok, resolved} ->
                  values = dependency_values(resolved)
                  locations = dependency_locations(expression, functions)

                  case dependencies(values, locations, field_location, limits) do
                    {:ok, extracted, dependency_diagnostics} ->
                      field = field("deps", length(extracted), :static_exact, field_location)

                      {:cont,
                       {:ok, [field | fields], extracted, dependency_diagnostics ++ diagnostics}}

                    {:error, %Error{} = error} ->
                      {:halt, {:error, error}}
                  end

                {:unresolved, reason} ->
                  field = field("deps", nil, :dynamic_required, field_location)
                  diag = diagnostic(reason, "deps", :dynamic_required, field_location)
                  {:cont, {:ok, [field | fields], dependencies, [diag | diagnostics]}}
              end

            "aliases" ->
              {field, diagnostic} = extract_aliases(expression, functions, limits, field_location)
              next_diagnostics = if diagnostic, do: [diagnostic | diagnostics], else: diagnostics
              {:cont, {:ok, [field | fields], dependencies, next_diagnostics}}

            _other ->
              {field, diagnostic} =
                extract_field(name, expression, functions, limits, field_location)

              next_diagnostics = if diagnostic, do: [diagnostic | diagnostics], else: diagnostics
              {:cont, {:ok, [field | fields], dependencies, next_diagnostics}}
          end
        end)
        |> case do
          {:ok, fields, dependencies, diagnostics} ->
            {:ok, Enum.reverse(fields), dependencies, Enum.reverse(diagnostics)}

          {:error, %Error{} = error} ->
            {:error, error}
        end

      :error ->
        location = SafeAst.location(definition.body)
        diagnostic = diagnostic(:dynamic_project, "project", :dynamic_required, location)
        {:ok, [], [], [diagnostic]}
    end
  end

  defp extract_keyword_function(_prefix, nil, _functions, _limits), do: {:ok, [], []}

  defp extract_keyword_function(prefix, definition, functions, limits) do
    case keyword_expression(definition.body) do
      {:ok, pairs} ->
        {fields, diagnostics} =
          Enum.reduce(pairs, {[], []}, fn {name, expression, field_location},
                                          {fields, diagnostics} ->
            field_name = prefix <> "." <> name

            {field, diagnostic} =
              extract_field(field_name, expression, functions, limits, field_location)

            next_diagnostics = if diagnostic, do: [diagnostic | diagnostics], else: diagnostics
            {[field | fields], next_diagnostics}
          end)

        {:ok, Enum.reverse(fields), Enum.reverse(diagnostics)}

      :error ->
        location = SafeAst.location(definition.body)
        {:ok, [], [diagnostic(:dynamic_function, prefix, :dynamic_required, location)]}
    end
  end

  defp extract_field(name, expression, functions, limits, field_location) do
    case resolve(expression, functions, %{}, [], limits) do
      {:ok, value} ->
        {field(name, simplify(value), :static_exact, field_location), nil}

      {:unresolved, reason} ->
        {field(name, nil, :dynamic_required, field_location),
         diagnostic(reason, name, :dynamic_required, field_location)}
    end
  end

  defp extract_aliases(expression, functions, limits, field_location) do
    case resolve(expression, functions, %{}, [], limits) do
      {:ok, %{keyword: pairs}} ->
        names = pairs |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()
        {field("aliases", names, :static_exact, field_location), nil}

      {:ok, _other} ->
        {field("aliases", nil, :unsupported, field_location),
         diagnostic(:invalid_aliases, "aliases", :unsupported, field_location)}

      {:unresolved, reason} ->
        {field("aliases", nil, :dynamic_required, field_location),
         diagnostic(reason, "aliases", :dynamic_required, field_location)}
    end
  end

  defp resolve(expression, functions, bindings, stack, limits) do
    case SafeAst.literal(expression, limits) do
      {:ok, value} ->
        {:ok, value}

      {:unresolved, _reason} ->
        resolve_expression(expression, functions, bindings, stack, limits)
    end
  end

  defp resolve_expression(
         {:__block__, _metadata, expressions},
         functions,
         bindings,
         stack,
         limits
       )
       when is_list(expressions) do
    resolve_block(expressions, functions, bindings, stack, limits)
  end

  defp resolve_expression(
         {name, _metadata, arguments} = expression,
         functions,
         bindings,
         stack,
         limits
       ) do
    case SafeAst.atom_name(name) do
      {:ok, "++"} when is_list(arguments) and length(arguments) == 2 ->
        [left, right] = arguments

        with {:ok, left_values} when is_list(left_values) <-
               resolve(left, functions, bindings, stack, limits),
             {:ok, right_values} when is_list(right_values) <-
               resolve(right, functions, bindings, stack, limits),
             true <- length(left_values) + length(right_values) <= limits.collection_items do
          {:ok, left_values ++ right_values}
        else
          _invalid -> {:unresolved, :dynamic_concatenation}
        end

      {:ok, function_name} when arguments in [nil, []] ->
        cond do
          arguments == nil and Map.has_key?(bindings, function_name) ->
            {:ok, Map.fetch!(bindings, function_name)}

          function_name in stack ->
            {:unresolved, :recursive_function}

          map_size(functions) > limits.functions ->
            {:unresolved, :function_limit}

          definition = functions[function_name] ->
            resolve(definition.body, functions, bindings, [function_name | stack], limits)

          true ->
            {:unresolved, :function_call}
        end

      _other ->
        {:unresolved, expression_reason(expression)}
    end
  end

  defp resolve_expression(expression, _functions, _bindings, _stack, _limits),
    do: {:unresolved, expression_reason(expression)}

  defp resolve_block([], _functions, _bindings, _stack, _limits), do: {:unresolved, :empty_block}

  defp resolve_block([last], functions, bindings, stack, limits),
    do: resolve(last, functions, bindings, stack, limits)

  defp resolve_block([expression | rest], functions, bindings, stack, limits) do
    case assignment(expression) do
      {:ok, name, value_expression} ->
        case resolve(value_expression, functions, bindings, stack, limits) do
          {:ok, value} ->
            resolve_block(rest, functions, Map.put(bindings, name, value), stack, limits)

          {:unresolved, reason} ->
            {:unresolved, reason}
        end

      :error ->
        {:unresolved, :block_expression}
    end
  end

  defp assignment({operator, _metadata, [{name, _name_metadata, nil}, value]}) do
    with {:ok, "="} <- SafeAst.atom_name(operator),
         {:ok, variable_name} <- SafeAst.atom_name(name) do
      {:ok, variable_name, value}
    else
      _invalid -> :error
    end
  end

  defp assignment(_expression), do: :error

  defp dependencies(values, locations, fallback_location, limits)
       when length(values) <= limits.dependencies do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, [], []}, fn {value, index}, {:ok, dependencies, diagnostics} ->
      dependency_location = Enum.at(locations, index, fallback_location)

      case dependency(value, dependency_location) do
        {:ok, dependency} ->
          {:cont, {:ok, [dependency | dependencies], diagnostics}}

        {:unsupported, reason} ->
          diag = diagnostic(reason, "deps", :unsupported, dependency_location)
          {:cont, {:ok, dependencies, [diag | diagnostics]}}
      end
    end)
    |> case do
      {:ok, dependencies, diagnostics} ->
        names = Enum.map(dependencies, & &1.name)

        if length(names) == length(Enum.uniq(names)) do
          {:ok, Enum.reverse(dependencies), Enum.reverse(diagnostics)}
        else
          invalid()
        end
    end
  end

  defp dependencies(_values, _locations, _location, _limits), do: invalid()

  defp dependency_values(values) when is_list(values), do: values

  defp dependency_values(%{keyword: pairs}) do
    Enum.map(pairs, fn {name, value} -> %{tuple: [%{atom: name}, value]} end)
  end

  defp dependency_values(_value), do: :invalid

  defp dependency_locations(expression, functions) do
    source_expression =
      case expression do
        {name, _metadata, arguments} when arguments in [nil, []] ->
          case SafeAst.atom_name(name) do
            {:ok, function_name} ->
              case functions[function_name] do
                %{body: body} -> body
                nil -> expression
              end

            _other ->
              expression
          end

        _other ->
          expression
      end

    case source_expression do
      values when is_list(values) -> Enum.map(values, &SafeAst.location/1)
      _other -> []
    end
  end

  defp dependency(%{tuple: [name_value | rest]}, fallback_location) do
    with {:ok, name} <- neutral_name(name_value),
         true <- Regex.match?(~r/^[a-z][a-z0-9_]{0,127}$/, name),
         {:ok, requirement, options} <- dependency_tail(rest),
         {:ok, normalized_options} <- options(options) do
      {:ok,
       %{
         name: name,
         requirement: requirement,
         direct: true,
         scm: dependency_scm(normalized_options),
         environments: scope_values(normalized_options["only"]),
         targets: scope_values(normalized_options["targets"]),
         optional: normalized_options["optional"] == true,
         override: normalized_options["override"] == true,
         runtime: Map.get(normalized_options, "runtime", true),
         options: normalized_options,
         location: fallback_location
       }}
    else
      _invalid -> {:unsupported, :dependency_declaration}
    end
  end

  defp dependency(_value, _location), do: {:unsupported, :dependency_declaration}

  defp dependency_tail([requirement]) when is_binary(requirement),
    do: {:ok, requirement, %{keyword: []}}

  defp dependency_tail([%{keyword: _pairs} = options]), do: {:ok, nil, options}

  defp dependency_tail([requirement, %{keyword: _pairs} = options]) when is_binary(requirement),
    do: {:ok, requirement, options}

  defp dependency_tail(_rest), do: :error

  defp options(%{keyword: pairs}) do
    if Enum.all?(pairs, fn {key, _value} -> key in @option_keys end) do
      keys = Enum.map(pairs, &elem(&1, 0))

      if length(keys) == length(Enum.uniq(keys)) do
        {:ok, Map.new(pairs, fn {key, value} -> {key, simplify(value)} end)}
      else
        :error
      end
    else
      :error
    end
  end

  defp dependency_scm(options) do
    cond do
      Map.has_key?(options, "path") -> "path"
      options["in_umbrella"] == true -> "umbrella"
      Map.has_key?(options, "git") or Map.has_key?(options, "github") -> "git"
      true -> "hex"
    end
  end

  defp scope_values(nil), do: []
  defp scope_values(value) when is_binary(value), do: [value]

  defp scope_values(values) when is_list(values),
    do: values |> Enum.filter(&is_binary/1) |> Enum.uniq() |> Enum.sort()

  defp scope_values(_value), do: []

  defp neutral_name(%{atom: name}) when is_binary(name), do: {:ok, name}
  defp neutral_name(name) when is_binary(name), do: {:ok, name}
  defp neutral_name(_value), do: :error

  defp keyword_expression({:__block__, _metadata, expressions}) when is_list(expressions) do
    expressions |> List.last() |> keyword_expression()
  end

  defp keyword_expression(expression), do: SafeAst.encoded_keyword(expression)

  defp keyword_value(keyword, key) do
    native_key = if key == "do", do: :do, else: nil

    cond do
      native_key && Keyword.keyword?(keyword) ->
        Keyword.fetch(keyword, native_key)

      true ->
        with {:ok, pairs} <- SafeAst.encoded_keyword(keyword),
             {_key, value, _location} <-
               Enum.find(pairs, fn {name, _value, _location} -> name == key end) do
          {:ok, value}
        else
          _invalid -> :error
        end
    end
  end

  defp expression_reason({{:., _metadata, _parts}, _call_metadata, _arguments}), do: :remote_call

  defp expression_reason({name, _metadata, _arguments}) do
    case SafeAst.atom_name(name) do
      {:ok, value} when value in ["if", "case", "cond", "for", "with"] -> :conditional
      {:ok, value} when value in ["import", "require", "use"] -> :macro_or_import
      {:ok, _value} -> :function_call
      _other -> :expression
    end
  end

  defp expression_reason(_expression), do: :expression

  defp simplify(%{atom: name}), do: name
  defp simplify(%{module: name}), do: name

  defp simplify(%{keyword: pairs}),
    do: Map.new(pairs, fn {key, value} -> {key, simplify(value)} end)

  defp simplify(%{tuple: values}), do: %{tuple: Enum.map(values, &simplify/1)}

  defp simplify(%{map: pairs}),
    do: %{map: Enum.map(pairs, fn {key, value} -> {simplify(key), simplify(value)} end)}

  defp simplify(values) when is_list(values), do: Enum.map(values, &simplify/1)
  defp simplify(value), do: value

  defp field(name, value, state, location),
    do: %{name: name, value: value, state: state, location: location, authority: :declared}

  defp diagnostic(code, field, state, location),
    do: %{code: code, field: field, state: state, location: location}

  defp coverage(fields, diagnostics) do
    exact = Enum.count(fields, &(&1.state == :static_exact))
    partial = Enum.count(fields, &(&1.state == :static_partial))
    unresolved = Enum.count(fields, &(&1.state == :dynamic_required))
    unsupported = Enum.count(fields, &(&1.state == :unsupported))
    invalid = Enum.count(diagnostics, &(&1.state == :invalid))
    total = exact + partial + unresolved + unsupported

    %{
      fields: total,
      static_exact: exact,
      static_partial: partial,
      dynamic_required: unresolved,
      unsupported: unsupported,
      invalid: invalid,
      exact_ratio_millionths: if(total == 0, do: 0, else: div(exact * 1_000_000, total))
    }
  end

  defp valid_limits(limits) do
    required = Map.keys(@maximums)

    if is_map(limits) and
         Enum.all?(required, fn key ->
           value = limits[key]
           maximum = @maximums[key]
           is_integer(value) and value > 0 and value <= maximum
         end) do
      :ok
    else
      invalid()
    end
  end

  defp valid_path(path) when is_binary(path) and byte_size(path) <= 512 do
    components = Path.split(path)

    if Path.type(path) == :relative and components != [] and
         Enum.all?(components, &(&1 not in ["", ".", ".."])) do
      :ok
    else
      invalid()
    end
  end

  defp valid_path(_path), do: invalid()

  defp location(metadata) when is_list(metadata),
    do: %{line: metadata[:line], column: metadata[:column]}

  defp sha256(value),
    do: value |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_mix_static)}
end
