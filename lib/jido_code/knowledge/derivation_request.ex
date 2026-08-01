defmodule JidoCode.Knowledge.DerivationRequest do
  @moduledoc """
  Validated transient request to publish, stale, or delete a derived graph.
  """

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Validation.ShapeCatalog

  @operations [:publish, :mark_stale, :delete]
  @max_statements 900
  @max_sources 8

  @derive {Inspect,
           only: [
             :operation,
             :command_iri,
             :scope_iri,
             :target_graph_iri,
             :rule_set_iri,
             :rule_set_slug,
             :rule_revision,
             :query_version,
             :source_graph_revisions
           ]}
  @enforce_keys [
    :operation,
    :command_iri,
    :authority,
    :scope_iri,
    :idempotency_key,
    :correlation_iri,
    :causation_iri,
    :ontology_version,
    :shape_version,
    :target_graph_iri,
    :rule_set_iri,
    :rule_set_slug,
    :rule_revision,
    :query_version,
    :source_graph_revisions,
    :expected_prior_derivation,
    :reason,
    :statements
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    request = struct!(__MODULE__, attributes)

    with true <- request.operation in @operations,
         :ok <- ResourceIdentity.validate(request.command_iri),
         true <- match?(%AuthorityContext{}, request.authority),
         :ok <- ResourceIdentity.validate(request.scope_iri),
         :ok <- bounded_text(request.idempotency_key, 256),
         :ok <- ResourceIdentity.validate(request.correlation_iri),
         :ok <- ResourceIdentity.validate(request.causation_iri),
         true <-
           ShapeCatalog.known_versions?(request.ontology_version, request.shape_version),
         {:ok, :derived} <- GraphRegistry.identify(request.target_graph_iri),
         :ok <- ResourceIdentity.validate(request.rule_set_iri),
         true <- Regex.match?(~r/^[a-z][a-z0-9-]{0,63}$/, request.rule_set_slug),
         true <- is_integer(request.rule_revision) and request.rule_revision >= 0,
         {:ok, expected_graph} <-
           GraphRegistry.graph_iri(:derived, %{
             rule_set: request.rule_set_slug,
             revision: request.rule_revision
           }),
         true <- expected_graph == request.target_graph_iri,
         :ok <- bounded_text(request.query_version, 64),
         :ok <- source_revisions(request.source_graph_revisions),
         :ok <- prior_derivation(request.expected_prior_derivation),
         :ok <- bounded_text(request.reason, 512),
         :ok <- statements(request.operation, request.statements) do
      {:ok, request}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  defp source_revisions(revisions)
       when is_map(revisions) and map_size(revisions) in 1..@max_sources do
    if Enum.all?(revisions, fn {graph, revision} ->
         is_integer(revision) and revision >= 0 and
           match?({:ok, family} when family != :derived, GraphRegistry.identify(graph))
       end),
       do: :ok,
       else: invalid()
  end

  defp source_revisions(_revisions), do: invalid()
  defp prior_derivation(nil), do: :ok

  defp prior_derivation(%{graph_iri: graph, revision: revision})
       when is_integer(revision) and revision >= 0 do
    case GraphRegistry.identify(graph) do
      {:ok, :derived} -> :ok
      _invalid -> invalid()
    end
  end

  defp prior_derivation(_prior), do: invalid()

  defp statements(:publish, statements)
       when is_list(statements) and length(statements) <= @max_statements do
    if Enum.all?(statements, &valid_statement?/1), do: :ok, else: invalid()
  end

  defp statements(operation, []) when operation in [:mark_stale, :delete], do: :ok
  defp statements(_operation, _statements), do: invalid()

  defp valid_statement?(statement) do
    case RDF.Triple.new(statement) do
      {subject, predicate, _object} = triple ->
        RDF.Triple.valid?(triple) and not RDF.Triple.has_bnode?(triple) and
          match?(%RDF.IRI{}, subject) and match?(%RDF.IRI{}, predicate)

      _invalid ->
        false
    end
  rescue
    _error -> false
  end

  defp bounded_text(value, maximum) when is_binary(value) do
    if byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/, value),
      do: :ok,
      else: invalid()
  end

  defp bounded_text(_value, _maximum), do: invalid()
  defp invalid, do: {:error, Error.new(:invalid_input, :derivation_request)}
end
