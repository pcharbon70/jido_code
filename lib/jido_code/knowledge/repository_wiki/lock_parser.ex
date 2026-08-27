defmodule JidoCode.Knowledge.RepositoryWiki.LockParser do
  @moduledoc "Bounded literal parser for supported Mix lock entries without term evaluation."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.SafeAst

  @profile "mix-lock/1.0.0"
  @maximums Map.merge(SafeAst.default_limits(), %{entries: 2_048, edges: 16_384, diagnostics: 512})
  @checksum ~r/^[a-fA-F0-9]{64}$/
  @revision ~r/^[a-fA-F0-9]{7,64}$/

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      parser: System.version(),
      limits: @maximums,
      evaluation: :forbidden,
      term_decoding: :forbidden,
      atom_creation: :forbidden,
      network: :forbidden
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec parse(String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def parse(source, attributes \\ %{})

  def parse(source, attributes) when is_binary(source) and is_map(attributes) do
    limits = Map.get(attributes, :limits, @maximums)
    source_path = Map.get(attributes, :source_path, "mix.lock")

    with :ok <- valid_path(source_path),
         :ok <- valid_limits(limits),
         {:ok, ast, measurement} <-
           SafeAst.parse(source, limits: limits, operation: :repository_wiki_lock_parse),
         {:ok, pairs} <- lock_pairs(ast),
         true <- length(pairs) <= limits.entries,
         :ok <- unique_keys(pairs),
         {:ok, entries, diagnostics} <- parse_entries(pairs, limits),
         true <- Enum.sum(Enum.map(entries, &length(&1.edges))) <= limits.edges do
      ordered_entries = Enum.sort_by(entries, & &1.name)
      ordered_diagnostics = Enum.sort_by(diagnostics, &{&1.entry, &1.code})

      result = %{
        profile: @profile,
        profile_digest: profile().digest,
        parser_version: System.version(),
        source_path: source_path,
        source_digest: sha256(source),
        ast: measurement,
        entries: ordered_entries,
        diagnostics: Enum.take(ordered_diagnostics, limits.diagnostics),
        entry_count: length(ordered_entries),
        edge_count: Enum.sum(Enum.map(ordered_entries, &length(&1.edges))),
        supported_count: Enum.count(ordered_entries, &(&1.status == :supported)),
        unsupported_count: Enum.count(ordered_entries, &(&1.status == :unsupported)),
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      {:ok, Map.put(result, :digest, Contract.digest(result))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def parse(_source, _attributes), do: invalid()

  defp lock_pairs({:%{}, _metadata, pairs}) when is_list(pairs), do: {:ok, pairs}
  defp lock_pairs(_ast), do: invalid()

  defp unique_keys(pairs) do
    names = Enum.map(pairs, fn {key, _value} -> key_name(key) end)

    if Enum.all?(names, &match?({:ok, _name}, &1)) do
      values = Enum.map(names, fn {:ok, name} -> name end)
      if length(values) == length(Enum.uniq(values)), do: :ok, else: invalid()
    else
      invalid()
    end
  end

  defp parse_entries(pairs, limits) do
    Enum.reduce_while(pairs, {:ok, [], []}, fn {key, value}, {:ok, entries, diagnostics} ->
      {:ok, name} = key_name(key)

      case SafeAst.literal(value, limits) do
        {:ok, neutral} ->
          case parse_entry(name, neutral) do
            {:ok, entry} ->
              {:cont, {:ok, [entry | entries], diagnostics}}

            {:unsupported, entry, diagnostic} ->
              {:cont, {:ok, [entry | entries], [diagnostic | diagnostics]}}

            {:error, %Error{} = error} ->
              {:halt, {:error, error}}
          end

        {:unresolved, _reason} ->
          {:halt, invalid()}
      end
    end)
    |> case do
      {:ok, entries, diagnostics} -> {:ok, Enum.reverse(entries), Enum.reverse(diagnostics)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp parse_entry(name, %{
         tuple: [
           %{atom: "hex"},
           package,
           version,
           checksum,
           managers,
           edges,
           repository,
           outer_checksum
         ]
       }) do
    with {:ok, package_name} <- scalar_name(package),
         true <- is_binary(version) and byte_size(version) <= 256,
         :ok <- valid_checksum(checksum),
         :ok <- valid_checksum(outer_checksum),
         {:ok, manager_names} <- names(managers),
         {:ok, dependencies} <- dependency_edges(edges),
         true <- is_binary(repository) and byte_size(repository) <= 128 do
      {:ok,
       base_entry(name, "hex", %{
         package: package_name,
         version: version,
         checksum: String.downcase(checksum),
         outer_checksum: String.downcase(outer_checksum),
         managers: Enum.sort(manager_names),
         repository: repository,
         edges: Enum.sort_by(dependencies, & &1.name)
       })}
    else
      _invalid -> invalid()
    end
  end

  defp parse_entry(name, %{tuple: [%{atom: "git"}, url, revision, options]}) do
    with true <- is_binary(url) and byte_size(url) <= 2_048,
         true <- is_binary(revision) and Regex.match?(@revision, revision),
         {:ok, option_map} <- keyword_map(options) do
      {:ok,
       base_entry(name, "git", %{
         url: url,
         revision: String.downcase(revision),
         options: option_map,
         managers: [],
         edges: []
       })}
    else
      _invalid -> invalid()
    end
  end

  defp parse_entry(name, %{tuple: [%{atom: "path"}, path, options]}) do
    with true <- is_binary(path) and byte_size(path) <= 512,
         {:ok, option_map} <- keyword_map(options) do
      {:ok,
       base_entry(name, "path", %{
         path: path,
         options: option_map,
         managers: [],
         edges: []
       })}
    else
      _invalid -> invalid()
    end
  end

  defp parse_entry(name, neutral) do
    entry = %{
      name: name,
      kind: "unsupported",
      status: :unsupported,
      identity: nil,
      managers: [],
      edges: [],
      shape_digest: Contract.digest(neutral)
    }

    diagnostic = %{entry: name, code: :unsupported_lock_shape, state: :unsupported}
    {:unsupported, entry, diagnostic}
  end

  defp base_entry(name, kind, attributes) do
    identity =
      case kind do
        "hex" ->
          Enum.join([kind, attributes.repository, attributes.package, attributes.version], ":")

        "git" ->
          Enum.join([kind, attributes.url, attributes.revision], ":")

        "path" ->
          Enum.join([kind, attributes.path], ":")
      end

    attributes
    |> Map.merge(%{name: name, kind: kind, status: :supported, identity: identity})
  end

  defp dependency_edges(values) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn
      %{tuple: [name, requirement, options]}, {:ok, result} when is_binary(requirement) ->
        with {:ok, dependency_name} <- scalar_name(name),
             {:ok, option_map} <- keyword_map(options) do
          edge = %{
            name: dependency_name,
            requirement: requirement,
            package: Map.get(option_map, "hex", dependency_name),
            repository: Map.get(option_map, "repo", "hexpm"),
            optional: Map.get(option_map, "optional", false)
          }

          {:cont, {:ok, [edge | result]}}
        else
          _invalid -> {:halt, :error}
        end

      _invalid, _result ->
        {:halt, :error}
    end)
    |> case do
      {:ok, edges} ->
        names = Enum.map(edges, & &1.name)
        if length(names) == length(Enum.uniq(names)), do: {:ok, Enum.reverse(edges)}, else: :error

      :error ->
        :error
    end
  end

  defp dependency_edges(_values), do: :error

  defp names(values) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, result} ->
      case scalar_name(value) do
        {:ok, name} -> {:cont, {:ok, [name | result]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      :error -> :error
    end
  end

  defp names(_values), do: :error

  defp keyword_map(%{keyword: pairs}) do
    keys = Enum.map(pairs, &elem(&1, 0))

    if length(keys) == length(Enum.uniq(keys)) do
      {:ok, Map.new(pairs, fn {key, value} -> {key, simplify(value)} end)}
    else
      :error
    end
  end

  defp keyword_map([]), do: {:ok, %{}}

  defp keyword_map(_value), do: :error

  defp key_name(value) when is_binary(value) and byte_size(value) <= 128, do: {:ok, value}
  defp key_name(value), do: scalar_name_from_ast(value)

  defp scalar_name_from_ast(value) do
    case SafeAst.atom_name(value) do
      {:ok, name} when byte_size(name) <= 128 -> {:ok, name}
      _other -> :error
    end
  end

  defp scalar_name(%{atom: value}) when is_binary(value) and byte_size(value) <= 128,
    do: {:ok, value}

  defp scalar_name(value) when is_binary(value) and byte_size(value) <= 128, do: {:ok, value}
  defp scalar_name(_value), do: :error

  defp simplify(%{atom: value}), do: value
  defp simplify(%{module: value}), do: value

  defp simplify(%{keyword: pairs}),
    do: Map.new(pairs, fn {key, value} -> {key, simplify(value)} end)

  defp simplify(%{tuple: values}), do: %{tuple: Enum.map(values, &simplify/1)}
  defp simplify(values) when is_list(values), do: Enum.map(values, &simplify/1)
  defp simplify(value), do: value

  defp valid_checksum(value) when is_binary(value) do
    if Regex.match?(@checksum, value), do: :ok, else: :error
  end

  defp valid_checksum(_value), do: :error

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

  defp sha256(value),
    do: value |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_lock_parse)}
end
