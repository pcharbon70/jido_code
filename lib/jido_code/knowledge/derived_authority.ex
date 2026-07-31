defmodule JidoCode.Knowledge.DerivedAuthority do
  @moduledoc """
  Authority, staleness, and rebuild rules for disposable derived graphs.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Validation.ShapeCatalog

  @restricted_operations [:satisfy_goal, :authorize_command, :accept_claim]

  @spec status(map(), [map()], keyword()) ::
          {:ok, :current | :stale | :incompatible | :invalidated} | {:error, Error.t()}
  def status(metadata, current_sources, options \\ [])

  def status(%{family: :derived} = metadata, current_sources, options)
      when is_list(current_sources) and is_list(options) do
    expected_ontology =
      Keyword.get(
        options,
        :ontology_version,
        "https://jido.run/ontology/release/#{ShapeCatalog.ontology_version()}"
      )

    expected_rule_set = Keyword.get(options, :rule_set, Map.get(metadata, :rule_set))

    required = [:invalidation_state, :ontology_version, :rule_set, :source_graph_revisions]

    with true <- Enum.all?(required, &Map.has_key?(metadata, &1)),
         {:ok, stored_sources} <- normalize_sources(Map.get(metadata, :source_graph_revisions)),
         {:ok, current_sources} <- normalize_sources(current_sources) do
      result =
        cond do
          Map.get(metadata, :invalidation_state) == :invalidated -> :invalidated
          Map.get(metadata, :invalidation_state) == :incompatible -> :incompatible
          Map.get(metadata, :ontology_version) != expected_ontology -> :incompatible
          Map.get(metadata, :rule_set) != expected_rule_set -> :incompatible
          Map.get(metadata, :invalidation_state) == :stale -> :stale
          stored_sources != current_sources -> :stale
          Map.get(metadata, :invalidation_state) == :current -> :current
          true -> :incompatible
        end

      {:ok, result}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :derived_graph_status)}
    end
  end

  def status(_metadata, _sources, _options),
    do: {:error, Error.new(:invalid_input, :derived_graph_status)}

  @spec authorize(atom(), map(), map() | nil) :: :ok | {:error, Error.t()}
  def authorize(operation, %{family: :derived, graph_iri: graph_iri}, decision)
      when operation in @restricted_operations do
    with true <- is_map(decision),
         :ok <- ResourceIdentity.validate(Map.get(decision, :decision_iri)),
         :ok <- ResourceIdentity.validate(Map.get(decision, :authority)),
         :ok <- ResourceIdentity.validate(Map.get(decision, :policy)),
         true <- Map.get(decision, :consumes_graph) == graph_iri do
      :ok
    else
      _invalid -> {:error, Error.new(:unauthorized, :derived_graph_authority)}
    end
  end

  def authorize(operation, %{family: :derived}, _decision)
      when operation not in @restricted_operations,
      do: :ok

  def authorize(_operation, %{family: family}, _decision) when family != :derived, do: :ok

  def authorize(_operation, _source, _decision),
    do: {:error, Error.new(:invalid_input, :derived_graph_authority)}

  @spec rebuild_plan(map(), [map()], keyword()) :: {:ok, map()} | {:error, Error.t()}
  def rebuild_plan(metadata, current_sources, options)
      when is_map(metadata) and is_list(current_sources) and is_list(options) do
    with {:ok, :stale} <- status(metadata, current_sources, options),
         :ok <- ResourceIdentity.validate(Map.get(metadata, :owner_scope)),
         {:ok, revision} <- required_non_negative_integer(options, :revision),
         {:ok, rule_set_slug} <- required_binary(options, :rule_set_slug),
         {:ok, activity} <- required_binary(options, :activity),
         :ok <- ResourceIdentity.validate(activity),
         {:ok, created_at} <- required_datetime(options, :created_at),
         {:ok, graph_iri} <-
           GraphRegistry.graph_iri(:derived, %{rule_set: rule_set_slug, revision: revision}),
         {:ok, sources} <- normalize_sources(current_sources) do
      {:ok,
       %{
         family: :derived,
         graph_iri: graph_iri,
         scopes: %{rule_set: rule_set_slug, revision: revision},
         capability: :reasoner,
         attributes: %{
           owner_scope: Map.get(metadata, :owner_scope),
           ontology_version:
             Keyword.get(options, :ontology_version, Map.get(metadata, :ontology_version)),
           creation_activity: activity,
           created_at: created_at,
           closed_at: created_at,
           rule_set: Keyword.get(options, :rule_set, Map.get(metadata, :rule_set)),
           source_graph_revisions: sources,
           invalidation_state: :current
         }
       }}
    else
      {:ok, status} when status in [:current, :invalidated] ->
        {:error, Error.new(:conflict, :derived_graph_rebuild)}

      {:ok, :incompatible} ->
        {:error, Error.new(:incompatible, :derived_graph_rebuild)}

      {:error, %Error{} = error} ->
        {:error, error}

      _invalid ->
        {:error, Error.new(:invalid_input, :derived_graph_rebuild)}
    end
  end

  def rebuild_plan(_metadata, _sources, _options),
    do: {:error, Error.new(:invalid_input, :derived_graph_rebuild)}

  defp normalize_sources(sources) when is_list(sources) and sources != [] do
    Enum.reduce_while(sources, {:ok, []}, fn
      %{graph: graph, revision: revision} = source, {:ok, normalized}
      when is_integer(revision) and revision >= 0 ->
        case GraphRegistry.identify(graph) do
          {:ok, _family} ->
            {:cont, {:ok, [Map.take(source, [:graph, :revision]) | normalized]}}

          {:error, %Error{} = error} ->
            {:halt, {:error, error}}
        end

      _invalid, _acc ->
        {:halt, {:error, Error.new(:invalid_input, :derived_source_revisions)}}
    end)
    |> case do
      {:ok, normalized} ->
        sorted = Enum.sort_by(normalized, &{&1.graph, &1.revision})

        if Enum.uniq_by(sorted, & &1.graph) == sorted,
          do: {:ok, sorted},
          else: {:error, Error.new(:invalid_input, :derived_source_revisions)}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp normalize_sources(_sources),
    do: {:error, Error.new(:invalid_input, :derived_source_revisions)}

  defp required_non_negative_integer(options, key) do
    case Keyword.fetch(options, key) do
      {:ok, value} when is_integer(value) and value >= 0 -> {:ok, value}
      _missing_or_invalid -> {:error, Error.new(:invalid_input, :derived_graph_rebuild)}
    end
  end

  defp required_binary(options, key) do
    case Keyword.fetch(options, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      _missing_or_invalid -> {:error, Error.new(:invalid_input, :derived_graph_rebuild)}
    end
  end

  defp required_datetime(options, key) do
    case Keyword.fetch(options, key) do
      {:ok, %DateTime{} = value} -> {:ok, value}
      _missing_or_invalid -> {:error, Error.new(:invalid_input, :derived_graph_rebuild)}
    end
  end
end
