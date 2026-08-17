defmodule JidoCode.Factory.Tool.InputValidator do
  @moduledoc "Closed structural and capability-aware validation for model tool arguments."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge

  @spec validate(Definition.t(), map(), map()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def validate(%Definition{} = definition, arguments, constraints)
      when is_map(arguments) and is_map(constraints) do
    with {:ok, normalized} <- normalize_keys(arguments, definition.input_schema.properties),
         true <- closed_shape?(normalized, definition.input_schema),
         true <- structurally_valid?(normalized, definition.input_schema.properties),
         true <- bounded?(normalized, 32_768),
         :ok <- semantic(definition.name, normalized, constraints) do
      {:ok, normalized}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def validate(_definition, _arguments, _constraints), do: invalid()

  defp normalize_keys(arguments, properties) do
    names = Map.new(Map.keys(properties), &{Atom.to_string(&1), &1})

    Enum.reduce_while(arguments, {:ok, %{}}, fn
      {key, value}, {:ok, normalized} when is_atom(key) ->
        if Map.has_key?(properties, key) and not Map.has_key?(normalized, key),
          do: {:cont, {:ok, Map.put(normalized, key, value)}},
          else: {:halt, :error}

      {key, value}, {:ok, normalized} when is_binary(key) ->
        case Map.fetch(names, key) do
          {:ok, atom_key} when not is_map_key(normalized, atom_key) ->
            {:cont, {:ok, Map.put(normalized, atom_key, value)}}

          _unknown ->
            {:halt, :error}
        end

      _entry, _accumulator ->
        {:halt, :error}
    end)
  end

  defp closed_shape?(arguments, %{required: required, properties: properties}) do
    keys = Map.keys(arguments)
    Enum.all?(required, &(&1 in keys)) and Enum.all?(keys, &Map.has_key?(properties, &1))
  end

  defp closed_shape?(_arguments, _schema), do: false

  defp structurally_valid?(arguments, properties) do
    Enum.all?(arguments, fn {key, value} -> valid_type?(value, Map.fetch!(properties, key)) end)
  end

  defp valid_type?(value, {:string, maximum}) when is_binary(value) do
    byte_size(value) in 1..maximum and
      not Regex.match?(~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u, value)
  end

  defp valid_type?(value, {:text, maximum}) when is_binary(value),
    do: byte_size(value) <= maximum and not String.contains?(value, <<0>>)

  defp valid_type?(value, :relative_path), do: relative_path?(value)

  defp valid_type?(value, :digest),
    do: is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp valid_type?(value, :resource_iri), do: Knowledge.validate_resource_identity(value) == :ok

  defp valid_type?(value, {:integer, minimum, maximum}),
    do: is_integer(value) and value in minimum..maximum

  defp valid_type?(value, {:enum, values}), do: value in values
  defp valid_type?(value, :boolean), do: is_boolean(value)

  defp valid_type?(value, {:list, type, maximum}) when is_list(value) do
    length(value) <= maximum and Enum.all?(value, &valid_type?(&1, type))
  end

  defp valid_type?(_value, _type), do: false

  defp semantic("search_source", arguments, constraints) do
    with :ok <- allowed_ref(arguments.scope_ref, constraints),
         true <- String.trim(arguments.query) != "" do
      :ok
    else
      _invalid -> :error
    end
  end

  defp semantic("inspect_symbol", arguments, constraints),
    do: allowed_ref(arguments.source_ref, constraints)

  defp semantic(name, arguments, constraints)
       when name in ["read_file", "create_file", "delete_file"] do
    allowed_path(arguments.path, constraints)
  end

  defp semantic("apply_edit", arguments, constraints) do
    with :ok <- allowed_path(arguments.path, constraints),
         true <- arguments.old_text != "" and arguments.old_text != arguments.new_text,
         1 <- arguments.expected_matches do
      :ok
    else
      _invalid -> :error
    end
  end

  defp semantic("run_registered_check", arguments, constraints),
    do: registered_command(arguments.check, constraints)

  defp semantic("run_governed_command", arguments, constraints),
    do: registered_command(arguments.command, constraints)

  defp semantic("show_candidate_diff", arguments, constraints),
    do: allowed_ref(arguments.snapshot_ref, constraints)

  defp semantic("submit_candidate", arguments, constraints) do
    with :ok <- allowed_ref(arguments.candidate_ref, constraints),
         :ok <- allowed_ref(arguments.approval_ref, constraints),
         :ok <- allowed_destination(arguments.destination, constraints) do
      :ok
    end
  end

  defp semantic("request_clarification", arguments, _constraints) do
    if String.trim(arguments.question) == "", do: :error, else: :ok
  end

  defp semantic(_name, _arguments, _constraints), do: :error

  defp allowed_path(path, constraints) do
    prefixes = Map.get(constraints, :allowed_path_prefixes, [])

    if prefixes != [] and Enum.all?(prefixes, &relative_path?/1) and
         Enum.any?(prefixes, &inside_path?(path, &1)),
       do: :ok,
       else: :error
  end

  defp allowed_ref(reference, constraints) do
    allowed = Map.get(constraints, :allowed_refs, [])
    if is_list(allowed) and reference in allowed, do: :ok, else: :error
  end

  defp allowed_destination(destination, constraints) do
    allowed = Map.get(constraints, :allowed_destinations, [])
    if is_list(allowed) and destination in allowed, do: :ok, else: :error
  end

  defp registered_command(name, constraints) do
    registered = Map.get(constraints, :registered_commands, [])
    if is_list(registered) and name in registered, do: :ok, else: :error
  end

  defp relative_path?(path) when is_binary(path) and byte_size(path) in 1..512 do
    Path.type(path) == :relative and
      not String.contains?(path, ["\\", <<0>>, "//"]) and
      not String.starts_with?(path, ["./", "/"]) and
      path == Path.join(Path.split(path)) and
      Enum.all?(Path.split(path), &(&1 not in [".", "..", ""]))
  end

  defp relative_path?(_path), do: false

  defp inside_path?(path, prefix) do
    relative = Path.relative_to(path, prefix)

    relative == "." or
      (Path.type(relative) == :relative and relative != ".." and
         not String.starts_with?(relative, "../"))
  end

  defp bounded?(value, maximum),
    do: byte_size(:erlang.term_to_binary(value, [:deterministic])) <= maximum

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :tool_input)}
end
