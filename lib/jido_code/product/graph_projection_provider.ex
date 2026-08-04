defmodule JidoCode.Product.GraphProjectionProvider do
  @moduledoc """
  Rebuilds the product workbench from closed catalog queries.

  Raw RDF terms and query definitions never cross this module. Every returned
  row is reduced to a finite product projection with revision and completeness
  metadata.
  """

  @behaviour JidoCode.Product.ProjectionProvider

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Health
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Product.Projection
  alias JidoCode.Product.QuerySecurity

  @query_version "1.7.0"
  @work_states [:eligible, :blocked, :executing, :awaiting_decision]
  @maximum_repositories 200

  @impl true
  def load(authority, identity, options \\ [])

  def load(%AuthorityContext{} = authority, identity, options) when is_map(identity) do
    query = Keyword.get(options, :query, &Knowledge.query/6)
    health = Keyword.get(options, :health, Readiness.snapshot())
    selected_repository = Keyword.get(options, :repository)

    with :ok <- ready(health),
         {:ok, catalog_graph} <- GraphRegistry.graph_iri(:factory_catalog, %{}),
         {:ok, revision_result} <-
           secure_query(
             query,
             :dataset_revision,
             @query_version,
             %{},
             authority,
             identity.factory_scope_iri,
             []
           ),
         {:ok, cohort_result} <-
           secure_query(
             query,
             :factory_repository_cohort,
             @query_version,
             %{graph: catalog_graph, resource: identity.factory_iri},
             authority,
             identity.factory_scope_iri,
             []
           ),
         :ok <- coherent(revision_result, cohort_result),
         repositories <- repositories(cohort_result),
         :ok <- bounded(repositories),
         {:ok, repository_projection} <-
           load_repository(selected_repository, repositories, authority, identity, query) do
      {:ok,
       build_projection(
         revision_result,
         cohort_result,
         repositories,
         repository_projection
       )}
    else
      {:error, %Error{} = error} -> {:ok, Projection.unavailable(error_state(error))}
      {:error, state} when is_atom(state) -> {:ok, Projection.unavailable(state)}
      _invalid -> {:ok, Projection.unavailable()}
    end
  rescue
    _error -> {:ok, Projection.unavailable()}
  end

  def load(_authority, _identity, _options), do: {:ok, Projection.unavailable(:unauthorized)}

  defp ready(%Health{} = health) do
    cond do
      Health.ready?(health) -> :ok
      health.state == :maintenance -> {:error, :maintenance}
      health.state == :recovering -> {:error, :recovery}
      true -> {:error, :unavailable}
    end
  end

  defp ready(_health), do: {:error, :unavailable}

  defp coherent(%QueryResult{} = left, %QueryResult{} = right) do
    if left.dataset_revision == right.dataset_revision,
      do: :ok,
      else: {:error, Error.new(:stale_precondition, :product_projection)}
  end

  defp coherent(_left, _right), do: {:error, Error.new(:corrupt, :product_projection)}

  defp repositories(%QueryResult{data: rows}) when is_list(rows) do
    rows
    |> Enum.map(fn row ->
      repository_iri = term_value(row, "repository")
      enrollment_iri = term_value(row, "enrollment")

      %{
        id: resource_id(repository_iri),
        iri: repository_iri,
        enrollment_iri: enrollment_iri,
        label: display_label(repository_iri),
        state: "enrolled"
      }
    end)
    |> Enum.filter(&(is_binary(&1.iri) and is_binary(&1.enrollment_iri)))
    |> Enum.uniq_by(& &1.iri)
    |> Enum.sort_by(& &1.label)
  end

  defp repositories(_result), do: []

  defp bounded(repositories) when length(repositories) <= @maximum_repositories, do: :ok
  defp bounded(_repositories), do: {:error, Error.new(:invalid_input, :product_projection_limit)}

  defp load_repository(nil, _repositories, _authority, _identity, _query) do
    {:ok,
     %{
       work: Projection.empty_work(),
       attempts: [],
       outcomes: Projection.empty_outcomes(),
       knowledge: [],
       results: []
     }}
  end

  defp load_repository(repository, repositories, authority, identity, query) do
    if Enum.any?(repositories, &(&1.iri == repository)) do
      with {:ok, control_graph} <-
             GraphRegistry.graph_iri(:repository_control, %{repository: repository}),
           {:ok, memory_graph} <- GraphRegistry.graph_iri(:memory, %{repository: repository}),
           {:ok, work, work_results} <-
             load_work(control_graph, authority, identity.factory_scope_iri, query),
           {:ok, attempts} <-
             secure_query(
               query,
               :active_attempts,
               @query_version,
               %{graph: control_graph},
               authority,
               identity.factory_scope_iri,
               []
             ),
           {:ok, knowledge} <-
             secure_query(
               query,
               :knowledge_by_scope,
               @query_version,
               %{graph: memory_graph, resource: repository},
               authority,
               identity.factory_scope_iri,
               []
             ) do
        {:ok,
         %{
           work: work,
           attempts: rows(attempts),
           outcomes: Projection.empty_outcomes(),
           knowledge: rows(knowledge),
           results: work_results ++ [attempts, knowledge]
         }}
      end
    else
      {:error, Error.new(:unauthorized, :product_repository_selection)}
    end
  end

  defp load_work(graph, authority, scope, query) do
    Enum.reduce_while(@work_states, {:ok, Projection.empty_work(), []}, fn state,
                                                                           {:ok, work, results} ->
      case secure_query(
             query,
             :work_lens,
             @query_version,
             %{graph: graph, state: state},
             authority,
             scope,
             []
           ) do
        {:ok, result} -> {:cont, {:ok, Map.put(work, state, rows(result)), [result | results]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp build_projection(revision, cohort, repositories, repository_projection) do
    results = [revision, cohort | repository_projection.results]
    truncated? = Enum.any?(results, & &1.truncated?)
    complete? = Enum.all?(results, &complete?/1)
    freshness = freshness(results)

    state =
      cond do
        truncated? -> :truncated
        not complete? -> :incomplete
        freshness == "stale" -> :stale
        repositories == [] -> :empty
        true -> :ready
      end

    %Projection{
      state: state,
      dataset_revision: revision.dataset_revision,
      generated_at: DateTime.utc_now() |> DateTime.truncate(:second),
      freshness: freshness,
      complete?: complete?,
      truncated?: truncated?,
      repositories: repositories,
      work: repository_projection.work,
      attempts: repository_projection.attempts,
      outcomes: repository_projection.outcomes,
      knowledge: repository_projection.knowledge,
      warnings: results |> Enum.flat_map(& &1.warnings) |> Enum.map(&safe_text/1) |> Enum.uniq()
    }
  end

  defp rows(%QueryResult{data: data}) when is_list(data) do
    Enum.map(data, fn row ->
      row
      |> Enum.map(fn {key, value} -> {safe_key(key), json_value(value)} end)
      |> Map.new()
      |> Map.put_new("id", resource_id(inspect(row)))
    end)
  end

  defp rows(_result), do: []

  defp complete?(%QueryResult{completeness: %{complete?: value}}), do: value == true
  defp complete?(_result), do: false

  defp freshness(results) do
    if Enum.any?(results, &(Map.get(&1.freshness, :state) == :stale)),
      do: "stale",
      else: "current"
  end

  defp term_value(row, key) when is_map(row) do
    case Map.get(row, key) do
      %{value: value} -> value
      value when is_binary(value) -> value
      _missing -> nil
    end
  end

  defp json_value(%{value: value}), do: json_value(value)
  defp json_value(value) when is_binary(value) or is_number(value) or is_boolean(value), do: value
  defp json_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp json_value(value) when is_atom(value), do: Atom.to_string(value)
  defp json_value(_value), do: nil

  defp safe_key(key) when is_atom(key), do: Atom.to_string(key)
  defp safe_key(key) when is_binary(key), do: String.slice(key, 0, 80)
  defp safe_key(_key), do: "value"

  defp safe_text(value), do: value |> to_string() |> String.slice(0, 160)

  defp display_label(nil), do: "Unknown repository"

  defp display_label(iri) do
    uri = URI.parse(iri)
    uri.fragment || (uri.path && Path.basename(uri.path)) || "Repository"
  end

  defp resource_id(value) do
    value
    |> to_string()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp error_state(%Error{kind: :unauthorized}), do: :unauthorized
  defp error_state(%Error{kind: :stale_precondition}), do: :stale
  defp error_state(_error), do: :unavailable

  defp secure_query(query, name, version, parameters, authority, scope, options) do
    QuerySecurity.execute(query, name, version, parameters, authority, scope, options)
  end
end
