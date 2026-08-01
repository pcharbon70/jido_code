defmodule JidoCode.Knowledge.Projection do
  @moduledoc """
  Builds consumer projections without creating a second domain authority.
  """

  alias JidoCode.Knowledge.AuthorizationScope
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ProjectionCatalog
  alias JidoCode.Knowledge.ProjectionEnvelope
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @spec build(QueryResult.t(), AuthorityContext.t(), String.t(), keyword()) ::
          {:ok, ProjectionEnvelope.t()} | {:error, Error.t()}
  def build(result, authority, scope_iri, options \\ [])

  def build(
        %QueryResult{} = result,
        %AuthorityContext{} = authority,
        scope_iri,
        options
      ) do
    version = Keyword.get(options, :version, ProjectionCatalog.version())
    generated_at = Keyword.get(options, :generated_at, DateTime.utc_now())
    parameters = Keyword.get(options, :parameters, %{})

    with {:ok, definition} <- ProjectionCatalog.fetch(result.query_name, version),
         true <- definition.query_version == result.query_version,
         :ok <- ResourceIdentity.validate(scope_iri),
         {:ok, scope_digest} <- AuthorizationScope.digest(authority, scope_iri),
         true <- match?(%DateTime{}, generated_at),
         true <- attributable?(result),
         {:ok, parameters_digest} <- digest_parameters(parameters),
         {:ok, data} <- decode(definition.shape, result.data),
         true <- json_safe?(data) do
      {:ok,
       %ProjectionEnvelope{
         projection_name: definition.name,
         projection_version: definition.version,
         shape: definition.shape,
         actor_scope: scope_iri,
         authorization_scope_digest: scope_digest,
         dataset_revision: result.dataset_revision,
         source_graph_revisions: result.graph_revisions,
         ontology_version: result.ontology_version,
         query_name: result.query_name,
         query_version: result.query_version,
         generated_at: generated_at,
         completeness: result.completeness,
         freshness: result.freshness,
         truncated?: result.truncated?,
         warnings: result.warnings,
         cursor: result.cursor,
         consistency: result.consistency,
         parameters_digest: parameters_digest,
         data: add_display_labels(data)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :projection_decode)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :projection_decode)}
  end

  def build(_result, _authority, _scope_iri, _options),
    do: {:error, Error.new(:invalid_input, :projection_decode)}

  defp attributable?(result) do
    is_integer(result.dataset_revision) and result.dataset_revision >= 0 and
      is_map(result.graph_revisions) and not is_nil(result.consistency) and
      is_binary(result.query_version) and is_map(result.completeness)
  end

  defp decode(:scalar, value) when is_boolean(value), do: {:ok, value}

  defp decode(:scalar, [row]) when is_map(row) and map_size(row) == 1 do
    {:ok, row |> Map.values() |> List.first()}
  end

  defp decode(shape, rows) when shape in [:table, :timeline] and is_list(rows),
    do: {:ok, rows}

  defp decode(:bounded_subgraph, triples) when is_list(triples), do: {:ok, triples}
  defp decode(:tree, tree) when is_map(tree) or is_list(tree), do: {:ok, tree}
  defp decode(_shape, _value), do: {:error, Error.new(:corrupt, :projection_decode)}

  defp digest_parameters(parameters) when is_map(parameters) do
    if json_safe?(parameters) do
      digest =
        parameters
        |> :erlang.term_to_binary([:deterministic])
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      {:ok, digest}
    else
      {:error, Error.new(:invalid_input, :projection_parameters)}
    end
  end

  defp digest_parameters(_parameters),
    do: {:error, Error.new(:invalid_input, :projection_parameters)}

  defp add_display_labels(%{type: :iri, value: value} = term) when is_binary(value) do
    Map.put(term, :display_label, value |> iri_label() |> escape_label())
  end

  defp add_display_labels(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {key, add_display_labels(item)} end)

  defp add_display_labels(value) when is_list(value), do: Enum.map(value, &add_display_labels/1)
  defp add_display_labels(value), do: value

  defp iri_label(iri) do
    uri = URI.parse(iri)
    fragment = uri.fragment
    path_label = uri.path && uri.path |> String.split("/", trim: true) |> List.last()
    fragment || path_label || iri
  end

  defp escape_label(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp json_safe?(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: true

  defp json_safe?(value) when is_atom(value), do: true
  defp json_safe?(value) when is_list(value), do: Enum.all?(value, &json_safe?/1)

  defp json_safe?(value) when is_map(value) and not is_struct(value),
    do: Enum.all?(value, fn {key, item} -> json_key?(key) and json_safe?(item) end)

  defp json_safe?(_value), do: false
  defp json_key?(key), do: is_binary(key) or is_atom(key)
end
