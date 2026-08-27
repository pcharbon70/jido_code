defmodule JidoCode.Product.RepositoryWikiProjectionProvider do
  @moduledoc """
  Rebuilds one repository wiki product projection from reviewed graph queries.

  Authorization runs before navigation becomes a search candidate. The search
  index and decoded navigation are disposable and can be recreated after any
  restart from the current edition graph.
  """

  require Logger

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Product.RepositoryWikiProjection
  alias JidoCode.Product.RepositoryWikiQuerySecurity
  alias JidoCode.Product.RepositoryWikiSearchIndex

  @version "2.10.0"
  @maximum_history 200
  @maximum_gaps 200

  @spec load(AuthorityContext.t(), map(), keyword()) ::
          {:ok, RepositoryWikiProjection.t()} | {:error, Error.t()}
  def load(authority, identity, options \\ [])

  def load(%AuthorityContext{} = authority, identity, options)
      when is_map(identity) and is_list(options) do
    repository = Keyword.get(options, :repository)
    authorized? = Keyword.get(options, :repository_authorized?, false)
    query = Keyword.get(options, :query, &Knowledge.query/6)
    metadata = Keyword.get(options, :metadata, &QueryRunner.graph_metadata/1)

    case {repository, authorized?, Map.get(identity, :actor_iri)} do
      {nil, _authorized?, _actor_iri} ->
        {:ok, RepositoryWikiProjection.unavailable(:unselected)}

      {repository, true, actor_iri} when actor_iri == authority.actor_iri ->
        load_authorized(repository, authority, query, metadata, options)

      {repository, _authorized?, _actor_iri} ->
        {:ok, RepositoryWikiProjection.unavailable(:unauthorized, repository)}
    end
  rescue
    _error -> {:ok, RepositoryWikiProjection.unavailable(:unavailable, options[:repository])}
  end

  def load(_authority, _identity, _options),
    do: {:ok, RepositoryWikiProjection.unavailable(:unauthorized)}

  defp load_authorized(repository, authority, query, metadata, options) do
    with :ok <- ResourceIdentity.validate(repository),
         {:ok, control_graph} <-
           GraphRegistry.graph_iri(:repository_control, %{repository: repository}),
         {:ok, control_scope} <- graph_scope(metadata, control_graph, repository),
         {:ok, enrollment_result} <-
           secure_query(
             query,
             :repository_wiki_enrollment_detail,
             %{graph: control_graph, resource: repository},
             authority,
             control_scope
           ),
         enrollment <- enrollment(enrollment_result) do
      load_enrollment(
        repository,
        enrollment,
        enrollment_result,
        control_graph,
        control_scope,
        authority,
        query,
        metadata,
        options
      )
    else
      {:error, :missing} ->
        {:ok, RepositoryWikiProjection.unavailable(:disabled, repository)}

      {:error, %Error{} = error} ->
        Logger.debug("repository wiki projection rejected: #{error.kind}/#{error.operation}")
        {:ok, RepositoryWikiProjection.unavailable(error_state(error), repository)}

      _invalid ->
        {:ok, RepositoryWikiProjection.unavailable(:unavailable, repository)}
    end
  end

  defp load_enrollment(
         repository,
         nil,
         _result,
         _graph,
         _scope,
         _authority,
         _query,
         _metadata,
         _options
       ),
       do: {:ok, RepositoryWikiProjection.unavailable(:disabled, repository)}

  defp load_enrollment(
         repository,
         enrollment,
         enrollment_result,
         control_graph,
         control_scope,
         authority,
         query,
         metadata,
         options
       ) do
    cond do
      enrollment.read_visibility != :retained ->
        {:ok, RepositoryWikiProjection.unavailable(:hidden, repository)}

      is_nil(enrollment.current_edition_iri) ->
        {:ok, empty_projection(repository, enrollment_result, enrollment)}

      true ->
        load_edition(
          repository,
          enrollment,
          enrollment_result,
          control_graph,
          control_scope,
          authority,
          query,
          metadata,
          options
        )
    end
  end

  defp load_edition(
         repository,
         enrollment,
         enrollment_result,
         control_graph,
         control_scope,
         authority,
         query,
         metadata,
         options
       ) do
    edition_iri = enrollment.current_edition_iri

    with {:ok, wiki_graph} <-
           GraphRegistry.graph_iri(:repository_wiki, %{
             repository: repository,
             edition: edition_iri
           }),
         {:ok, wiki_scope} <- graph_scope(metadata, wiki_graph, repository),
         {:ok, edition_result} <-
           secure_query(
             query,
             :repository_wiki_current_edition,
             %{control_graph: control_graph, wiki_graph: wiki_graph, resource: repository},
             authority,
             control_scope
           ),
         :ok <- coherent(enrollment_result, edition_result),
         {:ok, navigation_result} <-
           secure_query(
             query,
             :repository_wiki_navigation_tree,
             %{graph: wiki_graph, resource: edition_iri},
             authority,
             wiki_scope
           ),
         :ok <- coherent(edition_result, navigation_result),
         navigation <- navigation(navigation_result),
         {:ok, gap_result} <-
           secure_query(
             query,
             :repository_wiki_known_gaps,
             %{graph: wiki_graph, resource: edition_iri},
             authority,
             wiki_scope
           ),
         {:ok, history_result} <-
           secure_query(
             query,
             :repository_wiki_edition_history,
             %{graph: control_graph, resource: repository},
             authority,
             control_scope
           ),
         :ok <- coherent_many([navigation_result, gap_result, history_result]),
         {:ok, search_index} <-
           RepositoryWikiSearchIndex.build(
             edition_iri,
             navigation_result.dataset_revision,
             navigation
           ),
         {:ok, search_results} <-
           search(search_index, Keyword.get(options, :search_query, "")),
         {:ok, selected_page, backlinks, sources} <-
           selected_page(
             Keyword.get(options, :page_slug),
             repository,
             edition_iri,
             wiki_graph,
             wiki_scope,
             authority,
             query
           ) do
      edition = edition(edition_result)
      gaps = result_rows(gap_result, @maximum_gaps)
      history = result_rows(history_result, @maximum_history)
      state = projection_state(edition, navigation_result, gap_result)

      {:ok,
       %RepositoryWikiProjection{
         state: state,
         visible?: true,
         repository_iri: repository,
         dataset_revision: edition_result.dataset_revision,
         enrollment: enrollment,
         edition: edition,
         navigation: navigation,
         selected_page: selected_page,
         backlinks: backlinks,
         sources: sources,
         gaps: gaps,
         history: history,
         search_results: search_results,
         settings: settings(enrollment, Keyword.get(options, :regeneration_available?, false)),
         warnings:
           [enrollment_result, edition_result, navigation_result, gap_result, history_result]
           |> Enum.flat_map(& &1.warnings)
           |> Enum.map(&safe_warning/1)
           |> Enum.uniq()
       }}
    else
      {:error, %Error{} = error} ->
        {:ok, RepositoryWikiProjection.unavailable(error_state(error), repository)}

      _invalid ->
        {:ok, RepositoryWikiProjection.unavailable(:unavailable, repository)}
    end
  end

  defp selected_page(nil, _repository, _edition, _graph, _scope, _authority, _query),
    do: {:ok, nil, [], []}

  defp selected_page(slug, repository, edition, graph, scope, authority, query)
       when is_binary(slug) do
    with :ok <- validate_slug(slug),
         {:ok, page_result} <-
           secure_query(
             query,
             :repository_wiki_page_by_slug,
             %{graph: graph, resource: repository, edition: edition, slug: slug},
             authority,
             scope
           ),
         [page] <- navigation(page_result),
         {:ok, backlink_result} <-
           secure_query(
             query,
             :repository_wiki_backlinks,
             %{graph: graph, resource: page.page_iri},
             authority,
             scope
           ),
         {:ok, source_result} <-
           secure_query(
             query,
             :repository_wiki_source_references,
             %{graph: graph, resource: page.page_iri},
             authority,
             scope
           ),
         :ok <- coherent_many([page_result, backlink_result, source_result]) do
      {:ok, page, result_rows(backlink_result, 200), result_rows(source_result, 200)}
    else
      [] -> {:ok, nil, [], []}
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :repository_wiki_page_projection)}
    end
  end

  defp empty_projection(repository, result, enrollment) do
    %RepositoryWikiProjection{
      state: :empty,
      visible?: true,
      repository_iri: repository,
      dataset_revision: result.dataset_revision,
      enrollment: enrollment,
      edition: nil,
      navigation: [],
      selected_page: nil,
      backlinks: [],
      sources: [],
      gaps: [],
      history: [],
      search_results: [],
      settings: settings(enrollment, true),
      warnings: Enum.map(result.warnings, &safe_warning/1)
    }
  end

  defp enrollment(%QueryResult{} = result) do
    result
    |> raw_rows()
    |> List.first()
    |> case do
      nil ->
        nil

      row ->
        %{
          enrollment_iri: term(row, "enrollment"),
          revision: integer_term(row, "revision"),
          state: concept(row, "state", [:off, :manual, :automatic], :off),
          generation_mode: :deterministic_only,
          preview_mode: concept(row, "preview", [:disabled, :allowed], :disabled),
          read_visibility: concept(row, "readVisibility", [:hidden, :retained], :hidden),
          accounting_retention: term(row, "accountingRetention"),
          audit_retention: term(row, "auditRetention"),
          cancellation_generation: integer_term(row, "cancellationGeneration"),
          generation_profile_iri: term(row, "profile"),
          current_edition_iri: term(row, "currentEdition"),
          recorded_at: term(row, "recorded")
        }
    end
  end

  defp edition(result) do
    result
    |> raw_rows()
    |> List.first()
    |> case do
      nil ->
        nil

      row ->
        %{
          edition_iri: term(row, "edition"),
          state: concept_text(row, "editionState"),
          source_snapshot_iri: term(row, "sourceSnapshot"),
          source_fence: term(row, "sourceFence"),
          compiler_profile: term(row, "compilerProfile"),
          compiler_digest: term(row, "compilerDigest"),
          freshness: concept_text(row, "freshness"),
          closed_at: term(row, "closedAt"),
          generation_mode: :deterministic_only,
          model_tokens: 0,
          usage_cost_microunits: 0
        }
    end
  end

  defp navigation(result) do
    result
    |> raw_rows()
    |> Enum.map(fn row ->
      %{
        page_iri: term(row, "page"),
        kind: concept_text(row, "kind"),
        stable_key: safe_text(term(row, "stableKey"), 160),
        slug: safe_text(term(row, "slug"), 160),
        title: safe_text(term(row, "title"), 256),
        order: integer_term(row, "pageOrder"),
        audience: safe_text(term(row, "audience") || "reference", 32),
        parent_slug: optional_text(term(row, "parentSlug"), 160),
        freshness: concept_text(row, "freshness"),
        completeness: concept_text(row, "completeness"),
        content_digest: optional_text(term(row, "contentDigest"), 64)
      }
    end)
    |> Enum.filter(fn page ->
      ResourceIdentity.validate(page.page_iri) == :ok and page.slug != "" and page.title != "" and
        is_integer(page.order) and page.order >= 0
    end)
    |> Enum.uniq_by(& &1.page_iri)
    |> Enum.sort_by(&{&1.order, &1.slug})
  end

  defp result_rows(result, maximum) do
    result
    |> raw_rows()
    |> Enum.take(maximum)
    |> Enum.map(fn row ->
      row
      |> Enum.map(fn {key, value} -> {safe_text(key, 80), safe_value(value)} end)
      |> Map.new()
      |> Map.put_new("id", row_id(row))
    end)
  end

  defp search(_index, query) when query in [nil, ""], do: {:ok, []}
  defp search(index, query), do: RepositoryWikiSearchIndex.search(index, query, 20)

  defp graph_scope(metadata, graph, repository) do
    case metadata.(graph) do
      {:ok, %{owner_scope: owner, lifecycle_state: state}}
      when state in [:open, :closed] and owner == repository ->
        {:ok, owner}

      {:ok, nil} ->
        {:error, :missing}

      {:error, %Error{} = error} ->
        {:error, error}

      _invalid ->
        {:error, Error.new(:unauthorized, :repository_wiki_graph_scope)}
    end
  end

  defp coherent_many([first | rest]) do
    Enum.reduce_while(rest, :ok, fn result, :ok ->
      case coherent(first, result) do
        :ok -> {:cont, :ok}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp coherent(%QueryResult{} = left, %QueryResult{} = right) do
    if left.dataset_revision == right.dataset_revision,
      do: :ok,
      else: {:error, Error.new(:stale_precondition, :repository_wiki_projection)}
  end

  defp projection_state(nil, _navigation, _gaps), do: :incomplete

  defp projection_state(edition, navigation, gaps) do
    cond do
      navigation.truncated? or gaps.truncated? -> :incomplete
      String.contains?(String.downcase(edition.freshness), "stale") -> :stale
      raw_rows(navigation) == [] -> :empty
      true -> :current
    end
  end

  defp settings(enrollment, regeneration?) do
    %{
      mode: enrollment.state,
      read_visibility: enrollment.read_visibility,
      retention: :standard,
      generation_mode: :deterministic_only,
      token_posture: :zero_model_tokens,
      regeneration_available?: regeneration? and enrollment.state in [:manual, :automatic]
    }
  end

  defp validate_slug(value) do
    if Regex.match?(~r/^[a-z0-9][a-z0-9-]{0,159}$/u, value),
      do: :ok,
      else: {:error, Error.new(:invalid_input, :repository_wiki_page_slug)}
  end

  defp secure_query(query, name, parameters, authority, scope) do
    RepositoryWikiQuerySecurity.execute(query, name, @version, parameters, authority, scope, [])
  end

  defp raw_rows(%QueryResult{data: rows}) when is_list(rows), do: rows
  defp raw_rows(_result), do: []

  defp term(row, key) do
    case Map.get(row, key) do
      %{value: value} -> value
      value when is_binary(value) or is_integer(value) -> value
      %DateTime{} = value -> DateTime.to_iso8601(value)
      _missing -> nil
    end
  end

  defp integer_term(row, key) do
    case term(row, key) do
      value when is_integer(value) ->
        value

      value when is_binary(value) ->
        case Integer.parse(value) do
          {number, ""} -> number
          _invalid -> 0
        end

      _missing ->
        0
    end
  end

  defp concept(row, key, allowed, fallback) do
    value = concept_text(row, key)
    Enum.find(allowed, fallback, &String.ends_with?(value, Atom.to_string(&1)))
  end

  defp concept_text(row, key) do
    row
    |> term(key)
    |> case do
      value when is_binary(value) ->
        value
        |> String.split(["/", "#"])
        |> List.last()
        |> Macro.underscore()
        |> String.trim_leading("wiki_")
        |> safe_text(96)

      _missing ->
        "unknown"
    end
  end

  defp safe_value(%{value: value}), do: safe_value(value)
  defp safe_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp safe_value(value) when is_binary(value), do: safe_text(value, 512)
  defp safe_value(value) when is_integer(value) or is_float(value) or is_boolean(value), do: value
  defp safe_value(_value), do: nil

  defp optional_text(nil, _maximum), do: nil
  defp optional_text(value, maximum), do: safe_text(value, maximum)

  defp safe_text(value, maximum) when is_binary(value),
    do: value |> String.replace(~r/[\x00-\x1F\x7F]/u, "") |> String.slice(0, maximum)

  defp safe_text(value, maximum) when is_atom(value),
    do: value |> Atom.to_string() |> safe_text(maximum)

  defp safe_text(_value, _maximum), do: ""

  defp row_id(row) do
    row
    |> inspect(limit: 50, printable_limit: 500)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp safe_warning(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_warning(_value), do: "query_warning"

  defp error_state(%Error{kind: :unauthorized}), do: :unauthorized
  defp error_state(%Error{kind: :stale_precondition}), do: :unavailable
  defp error_state(_error), do: :unavailable
end
