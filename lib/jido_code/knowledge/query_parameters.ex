defmodule JidoCode.Knowledge.QueryParameters do
  @moduledoc """
  Typed SPARQL term binding for reviewed catalog sources.

  The binder never accepts query fragments. Every value is validated against
  its declared type and serialized with RDF term encoders before replacing a
  fixed placeholder in catalog-owned source text.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryDefinition
  alias JidoCode.Knowledge.ResourceIdentity

  @unsafe_encoded ~r/%(?:0a|0d|22|23|3c|3e|7b|7d)/i
  @control_characters ~r/[\x00-\x1F\x7F]/

  @spec bind(QueryDefinition.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def bind(%QueryDefinition{} = definition, parameters) when is_map(parameters) do
    with :ok <- exact_keys(definition.parameters, parameters),
         {:ok, bound} <- bind_declared(definition.parameters, parameters, definition),
         {:ok, query} <- render(definition, bound) do
      {:ok,
       %{
         query: query,
         normalized: Map.new(bound, fn {name, value} -> {name, value.normalized} end),
         graph_iris: graph_iris(bound)
       }}
    end
  rescue
    _error -> invalid()
  end

  def bind(_definition, _parameters), do: invalid()

  @spec encode_cursor(map()) :: String.t()
  def encode_cursor(values) when is_map(values) do
    values
    |> :erlang.term_to_binary([:deterministic])
    |> Base.url_encode64(padding: false)
  end

  @spec decode_cursor(String.t()) :: {:ok, map()} | {:error, Error.t()}
  def decode_cursor(cursor) when is_binary(cursor) and byte_size(cursor) <= 1_024 do
    with {:ok, binary} <- Base.url_decode64(cursor, padding: false),
         value when is_map(value) <- :erlang.binary_to_term(binary, [:safe]) do
      {:ok, value}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def decode_cursor(_cursor), do: invalid()

  defp exact_keys(schema, parameters) do
    allowed = Map.keys(schema)

    normalized_keys =
      Enum.map(Map.keys(parameters), fn key ->
        Enum.find(allowed, fn allowed_key -> key in [allowed_key, Atom.to_string(allowed_key)] end)
      end)

    required = for {name, %{required: true}} <- schema, do: name

    if nil not in normalized_keys and Enum.uniq(normalized_keys) == normalized_keys and
         Enum.all?(required, &parameter_present?(parameters, &1)) do
      :ok
    else
      invalid()
    end
  end

  defp bind_declared(schema, parameters, definition) do
    Enum.reduce_while(schema, {:ok, %{}}, fn {name, contract}, {:ok, values} ->
      case fetch_parameter(parameters, name) do
        :error when not contract.required ->
          {:cont, {:ok, values}}

        {:ok, value} ->
          case bind_value(value, contract, definition) do
            {:ok, bound} -> {:cont, {:ok, Map.put(values, name, bound)}}
            {:error, %Error{} = error} -> {:halt, {:error, error}}
          end

        :error ->
          {:halt, invalid()}
      end
    end)
  end

  defp bind_value(value, %{type: :graph_iri}, definition) do
    with :ok <- safe_iri(value),
         {:ok, family} <- GraphRegistry.identify(value),
         true <- family in definition.graph_families do
      {:ok, %{term: encode_iri(value), normalized: value, graph_iri: value}}
    else
      _invalid -> invalid()
    end
  end

  defp bind_value(value, %{type: :resource_iri}, _definition) do
    with :ok <- safe_iri(value),
         :ok <- ResourceIdentity.validate(value) do
      {:ok, %{term: encode_iri(value), normalized: value}}
    else
      _invalid -> invalid()
    end
  end

  defp bind_value(%DateTime{} = value, %{type: :datetime}, _definition) do
    literal = RDF.XSD.DateTime.new(value)
    {:ok, %{term: RDF.NTriples.Encoder.term(literal), normalized: DateTime.to_iso8601(value)}}
  rescue
    _error -> invalid()
  end

  defp bind_value(value, %{type: :non_negative_integer} = contract, _definition)
       when is_integer(value) and value >= 0 do
    maximum = Map.get(contract, :max, 1_000_000)

    if value <= maximum,
      do: {:ok, %{term: Integer.to_string(value), normalized: value}},
      else: invalid()
  end

  defp bind_value(value, %{type: :literal} = contract, _definition) when is_binary(value) do
    maximum = Map.get(contract, :max_bytes, 1_024)

    if byte_size(value) <= maximum and not Regex.match?(@control_characters, value) do
      {:ok, %{term: RDF.NTriples.Encoder.term(RDF.literal(value)), normalized: value}}
    else
      invalid()
    end
  end

  defp bind_value(value, %{type: :concept, values: values}, _definition) when is_atom(value) do
    case Map.fetch(values, value) do
      {:ok, iri} -> bind_value(iri, %{type: :resource_iri}, nil)
      :error -> invalid()
    end
  end

  defp bind_value(values, %{type: :iri_collection} = contract, definition)
       when is_list(values) do
    maximum = Map.get(contract, :max_items, definition.limits.parameter_collection_limit)

    with true <- values != [] and length(values) <= maximum,
         {:ok, bound} <- bind_collection(values, definition) do
      {:ok,
       %{
         term: Enum.map_join(bound, " ", & &1.term),
         normalized: Enum.map(bound, & &1.normalized)
       }}
    else
      _invalid -> invalid()
    end
  end

  defp bind_value(value, %{type: :cursor}, _definition) do
    with {:ok, decoded} <- decode_cursor(value) do
      {:ok, %{term: RDF.NTriples.Encoder.term(RDF.literal(value)), normalized: decoded}}
    end
  end

  defp bind_value(_value, _contract, _definition), do: invalid()

  defp bind_collection(values, definition) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, bound} ->
      case bind_value(value, %{type: :resource_iri}, definition) do
        {:ok, item} -> {:cont, {:ok, [item | bound]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp render(definition, bound) do
    query =
      Enum.reduce(bound, definition.source, fn {name, value}, source ->
        String.replace(source, "{{#{name}}}", value.term)
      end)
      |> String.replace("{{row_limit}}", Integer.to_string(definition.limits.row_limit + 1))
      |> String.replace("{{triple_limit}}", Integer.to_string(definition.limits.triple_limit + 1))

    if Regex.match?(~r/\{\{[a-z_]+\}\}/, query), do: invalid(), else: {:ok, query}
  end

  defp graph_iris(bound) do
    bound
    |> Map.values()
    |> Enum.flat_map(fn value -> if value[:graph_iri], do: [value.graph_iri], else: [] end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp safe_iri(value) when is_binary(value) do
    if byte_size(value) <= 512 and RDF.IRI.valid?(value) and
         not Regex.match?(@control_characters, value) and
         not Regex.match?(@unsafe_encoded, value),
       do: :ok,
       else: invalid()
  end

  defp safe_iri(_value), do: invalid()
  defp encode_iri(value), do: RDF.NTriples.Encoder.term(RDF.iri(value))

  defp parameter_present?(parameters, name),
    do: Map.has_key?(parameters, name) or Map.has_key?(parameters, Atom.to_string(name))

  defp fetch_parameter(parameters, name) do
    case Map.fetch(parameters, name) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(parameters, Atom.to_string(name))
    end
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :query_parameters)}
end
