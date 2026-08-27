defmodule JidoCode.Knowledge.RepositoryWiki.SafeAst do
  @moduledoc false

  alias JidoCode.Knowledge.Error

  @atom_marker :__jido_wiki_static_atom__
  @default_limits %{
    source_bytes: 262_144,
    ast_nodes: 50_000,
    ast_depth: 64,
    string_bytes: 16_384,
    collection_items: 2_048
  }

  @spec default_limits() :: map()
  def default_limits, do: @default_limits

  @spec parse(String.t(), keyword()) :: {:ok, term(), map()} | {:error, Error.t()}
  def parse(source, options \\ [])

  def parse(source, options) when is_binary(source) and is_list(options) do
    limits = options |> Keyword.get(:limits, @default_limits) |> Map.merge(%{})
    operation = Keyword.get(options, :operation, :repository_wiki_safe_ast)

    try do
      with :ok <- validate_limits(limits, operation),
           true <- byte_size(source) <= limits.source_bytes,
           {:ok, ast} <- quoted(source, operation),
           {:ok, measurement} <- measure(ast, limits, operation) do
        {:ok, ast, measurement}
      else
        {:error, %Error{} = error} -> {:error, error}
        _invalid -> {:error, Error.new(:invalid_input, operation)}
      end
    rescue
      _error -> {:error, Error.new(:invalid_input, operation)}
    end
  end

  def parse(_source, options) do
    operation =
      if is_list(options),
        do: Keyword.get(options, :operation, :repository_wiki_safe_ast),
        else: :repository_wiki_safe_ast

    {:error, Error.new(:invalid_input, operation)}
  end

  @spec atom_name(term()) :: {:ok, String.t()} | :error
  def atom_name({@atom_marker, _metadata, [name]}) when is_binary(name), do: {:ok, name}
  def atom_name(_value), do: :error

  @spec location(term()) :: %{line: pos_integer() | nil, column: pos_integer() | nil}
  def location({_name, metadata, _arguments}) when is_list(metadata) do
    %{line: metadata[:line], column: metadata[:column]}
  end

  def location({left, _right}), do: location(left)
  def location(_value), do: %{line: nil, column: nil}

  @spec literal(term(), map()) :: {:ok, term()} | {:unresolved, atom()}
  def literal(value, limits \\ @default_limits)

  def literal(value, limits) when is_binary(value) do
    if byte_size(value) <= limits.string_bytes,
      do: {:ok, value},
      else: {:unresolved, :string_limit}
  end

  def literal(value, _limits)
      when is_integer(value) or is_float(value) or is_boolean(value) or is_nil(value),
      do: {:ok, value}

  def literal({@atom_marker, _metadata, ["true"]}, _limits), do: {:ok, true}
  def literal({@atom_marker, _metadata, ["false"]}, _limits), do: {:ok, false}
  def literal({@atom_marker, _metadata, ["nil"]}, _limits), do: {:ok, nil}

  def literal({@atom_marker, _metadata, [name]}, limits) when is_binary(name) do
    if byte_size(name) <= limits.string_bytes,
      do: {:ok, %{atom: name}},
      else: {:unresolved, :string_limit}
  end

  def literal({:__aliases__, _metadata, parts}, limits) when is_list(parts) do
    with true <- length(parts) <= limits.collection_items,
         {:ok, names} <- literal_alias_parts(parts, limits) do
      {:ok, %{module: Enum.join(names, ".")}}
    else
      _invalid -> {:unresolved, :invalid_alias}
    end
  end

  def literal({:{}, _metadata, values}, limits) when is_list(values) do
    with true <- length(values) <= limits.collection_items,
         {:ok, normalized} <- literal_collection(values, limits) do
      {:ok, %{tuple: normalized}}
    else
      _invalid -> {:unresolved, :invalid_tuple}
    end
  end

  def literal({:%{}, _metadata, pairs}, limits) when is_list(pairs) do
    with true <- length(pairs) <= limits.collection_items,
         {:ok, normalized} <- literal_pairs(pairs, limits) do
      {:ok, %{map: normalized}}
    else
      _invalid -> {:unresolved, :invalid_map}
    end
  end

  def literal({left, right}, limits) do
    with {:ok, normalized_left} <- literal(left, limits),
         {:ok, normalized_right} <- literal(right, limits) do
      {:ok, %{tuple: [normalized_left, normalized_right]}}
    else
      {:unresolved, _reason} = unresolved -> unresolved
    end
  end

  def literal({:__block__, _metadata, [value]}, limits), do: literal(value, limits)

  def literal({operator, _metadata, [left, right]}, limits) do
    case atom_name(operator) do
      {:ok, "++"} -> concatenate(left, right, limits)
      _other -> {:unresolved, :expression}
    end
  end

  def literal(values, limits) when is_list(values) do
    cond do
      length(values) > limits.collection_items ->
        {:unresolved, :collection_limit}

      encoded_keyword?(values) ->
        with {:ok, pairs} <- literal_keyword(values, limits) do
          {:ok, %{keyword: pairs}}
        end

      true ->
        literal_collection(values, limits)
    end
  end

  def literal(_value, _limits), do: {:unresolved, :expression}

  @spec encoded_keyword(term()) :: {:ok, [{String.t(), term(), map()}]} | :error
  def encoded_keyword(values) when is_list(values) do
    if encoded_keyword?(values) do
      {:ok,
       Enum.map(values, fn {key, value} ->
         {:ok, name} = atom_name(key)
         {name, value, location(key)}
       end)}
    else
      :error
    end
  end

  def encoded_keyword(_values), do: :error

  defp quoted(source, operation) do
    options = [
      columns: true,
      token_metadata: true,
      emit_warnings: false,
      static_atoms_encoder: fn name, metadata ->
        {:ok, {@atom_marker, metadata, [name]}}
      end
    ]

    case Code.string_to_quoted(source, options) do
      {:ok, ast} -> {:ok, ast}
      {:error, _diagnostic} -> {:error, Error.new(:invalid_input, operation)}
    end
  end

  defp validate_limits(limits, operation) do
    required = [:source_bytes, :ast_nodes, :ast_depth, :string_bytes, :collection_items]

    if is_map(limits) and
         Enum.all?(required, fn key ->
           value = limits[key]
           is_integer(value) and value > 0
         end) do
      :ok
    else
      {:error, Error.new(:invalid_input, operation)}
    end
  end

  defp measure(ast, limits, operation) do
    case measure_term(ast, 1, 0, limits) do
      {:ok, nodes, depth} -> {:ok, %{nodes: nodes, depth: depth}}
      :limit -> {:error, Error.new(:invalid_input, operation)}
    end
  end

  defp measure_term(_value, depth, count, limits)
       when depth > limits.ast_depth or count >= limits.ast_nodes,
       do: :limit

  defp measure_term(value, depth, count, limits) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> measure_children(depth, count + 1, limits)
  end

  defp measure_term(value, depth, count, limits) when is_list(value),
    do: measure_children(value, depth, count + 1, limits)

  defp measure_term(value, depth, count, _limits) when is_binary(value),
    do: {:ok, count + 1, depth}

  defp measure_term(_value, depth, count, _limits), do: {:ok, count + 1, depth}

  defp measure_children(children, depth, count, limits) do
    Enum.reduce_while(children, {:ok, count, depth}, fn child, {:ok, nodes, maximum_depth} ->
      case measure_term(child, depth + 1, nodes, limits) do
        {:ok, child_nodes, child_depth} ->
          {:cont, {:ok, child_nodes, max(maximum_depth, child_depth)}}

        :limit ->
          {:halt, :limit}
      end
    end)
  end

  defp literal_alias_parts(parts, limits) do
    Enum.reduce_while(parts, {:ok, []}, fn part, {:ok, names} ->
      case atom_name(part) do
        {:ok, name} when byte_size(name) <= limits.string_bytes -> {:cont, {:ok, [name | names]}}
        _other -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, names} -> {:ok, Enum.reverse(names)}
      :error -> :error
    end
  end

  defp literal_collection(values, limits) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, result} ->
      case literal(value, limits) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | result]}}
        {:unresolved, _reason} = unresolved -> {:halt, unresolved}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:unresolved, _reason} = unresolved -> unresolved
    end
  end

  defp literal_pairs(pairs, limits) do
    Enum.reduce_while(pairs, {:ok, []}, fn
      {key, value}, {:ok, result} ->
        with {:ok, normalized_key} <- literal(key, limits),
             {:ok, normalized_value} <- literal(value, limits) do
          {:cont, {:ok, [{normalized_key, normalized_value} | result]}}
        else
          {:unresolved, _reason} = unresolved -> {:halt, unresolved}
        end

      _invalid, _result ->
        {:halt, {:unresolved, :invalid_map_pair}}
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:unresolved, _reason} = unresolved -> unresolved
    end
  end

  defp literal_keyword(values, limits) do
    Enum.reduce_while(values, {:ok, []}, fn {key, value}, {:ok, result} ->
      {:ok, name} = atom_name(key)

      case literal(value, limits) do
        {:ok, normalized} -> {:cont, {:ok, [{name, normalized} | result]}}
        {:unresolved, _reason} = unresolved -> {:halt, unresolved}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:unresolved, _reason} = unresolved -> unresolved
    end
  end

  defp encoded_keyword?(values) do
    values != [] and
      Enum.all?(values, fn
        {key, _value} -> match?({:ok, _name}, atom_name(key))
        _other -> false
      end)
  end

  defp concatenate(left, right, limits) do
    with {:ok, left_values} when is_list(left_values) <- literal(left, limits),
         {:ok, right_values} when is_list(right_values) <- literal(right, limits),
         true <- length(left_values) + length(right_values) <= limits.collection_items do
      {:ok, left_values ++ right_values}
    else
      _invalid -> {:unresolved, :dynamic_concatenation}
    end
  end
end
