defmodule JidoCode.Product.GraphReadProjectionProvider do
  @moduledoc """
  Builds HUI-C4 native-shell projections from reviewed catalog queries.

  Query names, versions, graphs, scopes, page bounds, and resource kinds are
  server owned. Cohort rows are joined to independently authorized identity
  registry resources before any label, count, total, or opaque link is shaped.
  """

  @behaviour JidoCode.Product.ReadProjectionProvider

  require Logger

  alias JidoCode.Identity.AuthorityBuilder
  alias JidoCode.Identity.AuthorizationResult
  alias JidoCode.Identity.Store
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Health
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Product.ReadProjection
  alias JidoCode.Product.ReadProjectionQuery

  @query_version "2.11.0"
  @supported_surfaces [
    :factory,
    :fleet,
    :projects,
    :project,
    :project_attempts,
    :project_wiki,
    :project_dependencies,
    :attempt
  ]
  @candidate_limit 100
  @scan_limit 24
  @page_size 20
  @surface_timeout_ms 5_500
  @work_states [:eligible, :blocked, :executing, :awaiting_decision]
  @sort_columns ~w[project work agent stage health freshness]

  @impl true
  def load(context, options \\ [])

  def load(context, options) when is_map(context) and is_list(options) do
    surface = get_in(context, [:page, :key])

    if surface in @supported_surfaces do
      timeout = Keyword.get(options, :surface_timeout_ms, @surface_timeout_ms)
      task = Task.async(fn -> guarded_load(context, options) end)

      case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
        {:ok, result} -> result
        _timeout -> {:ok, ReadProjection.unavailable(surface, :error)}
      end
    else
      {:error, :unsupported_read_projection_surface}
    end
  end

  def load(_context, _options), do: {:error, :invalid_read_projection_context}

  defp guarded_load(context, options) do
    do_load(context, options)
  rescue
    _error -> {:ok, ReadProjection.unavailable(context.page.key, :error)}
  catch
    :exit, _reason -> {:ok, ReadProjection.unavailable(context.page.key, :error)}
  end

  defp do_load(context, options) do
    case context.page.key do
      surface when surface in [:factory, :fleet, :projects] ->
        load_factory(context, options)

      surface
      when surface in [:project, :project_attempts, :project_wiki, :project_dependencies] ->
        load_project(context, options)

      :attempt ->
        load_attempt(context, options)
    end
  end

  defp load_factory(context, options) do
    surface = context.page.key
    health = Keyword.get(options, :health, Readiness.snapshot())

    with :ok <- composed(options),
         {:ok, query_authorization} <-
           authorize(context, surface, :query, :before_query_execution, :factory, options),
         :ok <- ready(health),
         {:ok, catalog_graph} <- GraphRegistry.graph_iri(:factory_catalog, %{}),
         {:ok, cohort} <-
           query(
             options,
             :factory_cohort,
             %{graph: catalog_graph, resource: query_authorization.product_identity.factory_iri},
             query_authorization.authority_context,
             query_authorization.product_identity.factory_scope_iri
           ),
         {:ok, project_resources} <- resources(options, :project, @candidate_limit),
         {:ok, candidates} <-
           authorized_candidates(context, cohort, project_resources, options),
         {:ok, field_authorization} <-
           authorize(context, surface, :query, :before_field_shaping, :factory, options) do
      build_factory_projection(
        context,
        cohort,
        candidates,
        field_authorization,
        options
      )
    else
      {:error, %Error{} = error} ->
        Logger.debug("HUI-C4 factory projection rejected: #{error.kind}/#{error.operation}")
        {:ok, ReadProjection.unavailable(surface, error_outcome(error))}

      {:error, outcome} when is_atom(outcome) ->
        {:ok, ReadProjection.unavailable(surface, outcome)}

      _invalid ->
        {:ok, ReadProjection.unavailable(surface, :error)}
    end
  end

  defp load_project(context, options) do
    surface = context.page.key
    health = Keyword.get(options, :health, Readiness.snapshot())
    resource_ref = context.page.route_params.resource_ref

    with :ok <- composed(options),
         {:ok, project} <- resolve_resource(options, resource_ref),
         true <- project.kind == :project,
         {:ok, query_authorization} <-
           authorize(
             context,
             surface,
             :query,
             :before_query_execution,
             project.resource_ref,
             options
           ),
         :ok <- ready(health),
         {:ok, repository_scope} <- ResourceIdentity.scope(:repository, project.iri),
         {:ok, catalog_graph} <- GraphRegistry.graph_iri(:factory_catalog, %{}),
         {:ok, control_graph} <-
           GraphRegistry.graph_iri(:repository_control, %{repository: project.iri}),
         {:ok, description} <-
           query(
             options,
             :repository_description,
             %{graph: catalog_graph, resource: project.iri},
             query_authorization.authority_context,
             query_authorization.product_identity.factory_scope_iri
           ),
         project_data <-
           load_project_data(
             context,
             project,
             repository_scope,
             catalog_graph,
             control_graph,
             description,
             query_authorization,
             options
           ),
         {:ok, field_authorization} <-
           authorize(
             context,
             surface,
             :query,
             :before_field_shaping,
             project.resource_ref,
             options
           ),
         true <- field_authorization.decision == :allowed do
      build_project_projection(context, project, description, project_data, options)
    else
      false ->
        {:ok, ReadProjection.unavailable(surface, :denied)}

      {:error, %Error{} = error} ->
        {:ok, ReadProjection.unavailable(surface, error_outcome(error))}

      {:error, outcome} when is_atom(outcome) ->
        {:ok, ReadProjection.unavailable(surface, outcome)}

      _invalid ->
        {:ok, ReadProjection.unavailable(surface, :error)}
    end
  end

  defp load_attempt(context, options) do
    surface = :attempt
    health = Keyword.get(options, :health, Readiness.snapshot())
    parent_ref = context.page.route_params.parent_ref
    attempt_ref = context.page.route_params.resource_ref

    with :ok <- composed(options),
         {:ok, project} <- resolve_resource(options, parent_ref),
         {:ok, attempt} <- resolve_resource(options, attempt_ref),
         true <- project.kind == :project,
         true <- attempt.kind == :attempt,
         true <- attempt.parent_ref == project.resource_ref,
         true <- attempt.tenant_ref == project.tenant_ref,
         true <- attempt.project_ref == project.project_ref,
         {:ok, query_authorization} <-
           authorize(
             context,
             :attempt,
             :query,
             :before_query_execution,
             attempt.resource_ref,
             options
           ),
         :ok <- ready(health),
         {:ok, repository_scope} <- ResourceIdentity.scope(:repository, project.iri),
         {:ok, run_graph} <- GraphRegistry.graph_iri(:run_attempt, %{attempt: attempt.iri}),
         attempt_data <-
           load_attempt_data(
             context,
             project,
             attempt,
             repository_scope,
             run_graph,
             query_authorization,
             options
           ),
         true <- attempt_data.results != [],
         {:ok, field_authorization} <-
           authorize(
             context,
             :attempt,
             :query,
             :before_field_shaping,
             attempt.resource_ref,
             options
           ),
         true <- field_authorization.decision == :allowed do
      build_attempt_projection(context, project, attempt, attempt_data, options)
    else
      false ->
        {:ok, ReadProjection.unavailable(surface, :denied)}

      {:error, %Error{} = error} ->
        {:ok, ReadProjection.unavailable(surface, error_outcome(error))}

      {:error, outcome} when is_atom(outcome) ->
        {:ok, ReadProjection.unavailable(surface, outcome)}

      _invalid ->
        {:ok, ReadProjection.unavailable(surface, :error)}
    end
  end

  defp ready(%Health{} = health) do
    cond do
      Health.ready?(health) -> :ok
      health.state == :maintenance -> {:error, :maintenance}
      health.state == :recovering -> {:error, :recovery}
      true -> {:error, :unavailable}
    end
  end

  defp ready(_health), do: {:error, :unavailable}

  defp composed(options) do
    configured? =
      Keyword.has_key?(options, :health) or
        Application.get_env(:jido_code, :knowledge_store, [])[:enabled] == true

    if configured?, do: :ok, else: {:error, :unconfigured}
  end

  defp authorized_candidates(context, %QueryResult{} = cohort, project_resources, options) do
    cohort_repositories =
      cohort.data
      |> list()
      |> Enum.map(&term_value(&1, "repository"))
      |> Enum.filter(&valid_iri?/1)
      |> MapSet.new()

    candidates =
      project_resources
      |> Enum.filter(&match?(%JidoCode.Identity.Resource{kind: :project}, &1))
      |> Enum.filter(&MapSet.member?(cohort_repositories, &1.iri))
      |> Enum.sort_by(&safe_project_label/1)
      |> Enum.take(@candidate_limit)
      |> Enum.reduce([], fn resource, accepted ->
        case authorize(
               context,
               :project,
               :query,
               :before_query_execution,
               resource.resource_ref,
               options
             ) do
          {:ok, authorization} -> [%{resource: resource, authorization: authorization} | accepted]
          _not_authorized -> accepted
        end
      end)
      |> Enum.reverse()

    {:ok, candidates}
  end

  defp authorized_candidates(_context, _cohort, _resources, _options),
    do: {:error, Error.new(:corrupt, :hui_c4_factory_cohort)}

  defp build_factory_projection(context, cohort, candidates, field_authorization, options) do
    scan_candidates = Enum.take(candidates, @scan_limit)

    details =
      Enum.map(scan_candidates, fn candidate ->
        load_fleet_row(candidate, options)
      end)

    query = context.page.query
    visible = details |> filter_rows(query) |> sort_rows(query)
    page = Map.get(query, "page", 1)
    page_rows = visible |> Enum.drop((page - 1) * @page_size) |> Enum.take(@page_size)
    public_rows = Enum.map(page_rows, &public_fleet_row/1)

    known_total? =
      complete?(cohort) and not cohort.truncated? and length(candidates) <= @scan_limit

    path = URI.parse(context.page.canonical_url).path
    pagination = pagination(path, query, page, visible, known_total?)
    attention = attention_items(details)
    attention_families = attention_families(attention, details)
    health = health_items(candidates, attention, cohort, details)
    results = [cohort | Enum.flat_map(details, & &1.results)]
    data_rows = surface_rows(context.page.key, page_rows, candidates)
    state = projection_state(results, data_rows, length(candidates) > @scan_limit)
    generated_at = now(options)

    attributes =
      base_attributes(context.page.key, state, results, generated_at)
      |> Map.merge(%{
        attention: if(context.page.key == :factory, do: attention, else: []),
        attention_families: if(context.page.key == :factory, do: attention_families, else: []),
        health: if(context.page.key == :factory, do: health, else: []),
        fleet: if(context.page.key in [:factory, :fleet], do: public_rows, else: []),
        projects: if(context.page.key == :projects, do: public_rows, else: []),
        pagination: pagination,
        summaries: %{
          authorized_rows: if(known_total?, do: length(visible), else: nil),
          page_rows: length(page_rows),
          attention_rows: length(attention),
          totals_known?: known_total?,
          sort_column: Map.get(query, "sort", "project"),
          sort_direction: Map.get(query, "direction", "ascending"),
          sort_hrefs: sort_hrefs(path, query)
        },
        capabilities: factory_capabilities(attention_families),
        truncated?: state == :truncated or length(candidates) > @scan_limit,
        cache: %{status: :bypass},
        warnings: safe_warnings(results, length(candidates) > @scan_limit)
      })

    with true <- field_authorization.decision == :allowed,
         {:ok, projection} <- ReadProjection.new(attributes) do
      {:ok, projection}
    else
      _redacted -> {:ok, ReadProjection.unavailable(context.page.key, :denied)}
    end
  end

  defp surface_rows(surface, page_rows, _candidates) when surface in [:factory, :fleet],
    do: page_rows

  defp surface_rows(:projects, page_rows, _candidates), do: page_rows

  defp public_fleet_row(row) do
    Map.take(row, [
      :project,
      :project_href,
      :work,
      :agent,
      :stage,
      :health,
      :health_state,
      :freshness
    ])
  end

  defp load_project_data(
         context,
         project,
         repository_scope,
         catalog_graph,
         control_graph,
         description,
         authorization,
         options
       ) do
    enrollment =
      optional_query(
        options,
        :active_enrollment,
        %{graph: catalog_graph, resource: project.iri},
        authorization.authority_context,
        authorization.product_identity.factory_scope_iri
      )

    work =
      Map.new(@work_states, fn state ->
        {state,
         optional_query(
           options,
           :work_lens,
           %{graph: control_graph, state: state},
           authorization.authority_context,
           repository_scope
         )}
      end)

    attempts_result =
      optional_query(
        options,
        :active_attempts,
        %{graph: control_graph},
        authorization.authority_context,
        repository_scope
      )

    wiki_result =
      optional_query(
        options,
        :wiki_enrollment,
        %{graph: control_graph, resource: project.iri},
        authorization.authority_context,
        repository_scope
      )

    attempts =
      authorized_attempt_rows(
        context,
        project,
        optional_result(attempts_result),
        options
      )

    wiki = wiki_summary(optional_result(wiki_result))

    {dependencies, dependency_result, dependency_capability} =
      load_dependencies(wiki, project, repository_scope, authorization, options)

    outcomes =
      [enrollment, attempts_result, wiki_result, dependency_result | Map.values(work)]
      |> Enum.reject(&is_nil/1)

    %{
      description: description,
      enrollment: enrollment,
      work: work,
      attempts_result: attempts_result,
      attempts: attempts,
      wiki_result: wiki_result,
      wiki: wiki,
      dependencies: dependencies,
      dependency_capability: dependency_capability,
      results: [description | successful_results(outcomes)],
      failures: Enum.count(outcomes, &(&1.outcome != :ok))
    }
  end

  defp build_project_projection(context, project, description, data, options) do
    query = context.page.query
    attempts = filter_attempts(data.attempts, query)
    page = Map.get(query, "page", 1)
    page_attempts = attempts |> Enum.drop((page - 1) * @page_size) |> Enum.take(@page_size)

    pagination =
      attempt_pagination(URI.parse(context.page.canonical_url).path, query, page, attempts)

    work_counts = work_counts(data.work)
    state = project_state(data.results, data.failures)
    generated_at = now(options)
    project_summary = project_summary(project, description, data, work_counts)
    capabilities = project_capabilities(data)

    attributes =
      base_attributes(context.page.key, state, data.results, generated_at)
      |> Map.merge(%{
        project: project_summary,
        attempts:
          if(context.page.key == :project_attempts,
            do: page_attempts,
            else: Enum.take(data.attempts, 10)
          ),
        wiki: if(context.page.key in [:project, :project_wiki], do: data.wiki),
        dependencies:
          if(context.page.key in [:project, :project_dependencies],
            do: data.dependencies,
            else: []
          ),
        summaries: %{
          work: work_counts,
          attempt_count: length(data.attempts),
          attempt_total_known?: optional_complete?(data.attempts_result),
          dependency_count:
            if(data.dependency_capability == :ready, do: length(data.dependencies), else: nil),
          cost: :unavailable,
          budget: :unavailable,
          alias_semantics: :one_conceptual_repository
        },
        capabilities: capabilities,
        pagination:
          if(context.page.key == :project_attempts,
            do: pagination,
            else: ReadProjection.empty_pagination()
          ),
        complete?: data.failures == 0 and Enum.all?(data.results, &complete?/1),
        truncated?: state == :truncated,
        warnings: safe_warnings(data.results, false) ++ failure_warnings(data.failures),
        cache: %{status: :bypass}
      })

    ReadProjection.new(attributes)
  end

  defp project_summary(project, description, data, work_counts) do
    enrollment_state =
      case optional_result(data.enrollment) do
        %QueryResult{data: rows} when is_list(rows) and rows != [] -> "Enrolled"
        %QueryResult{} -> "Enrollment not observed"
        nil -> "Enrollment unavailable"
      end

    %{
      label: safe_project_label(project),
      resource_ref: project.resource_ref,
      repository_identity: "One conceptual repository",
      project_alias: "Project is a presentation alias for this repository",
      enrollment: enrollment_state,
      desired_state: desired_state(work_counts),
      current_state: current_state(work_counts),
      branch_policy: "Branch/worktree policy unavailable in the current projection",
      owner: "Project owner",
      evidence: evidence_posture(work_counts),
      wiki: if(data.wiki, do: data.wiki.state, else: "Unavailable"),
      dependencies:
        if(data.dependency_capability == :ready,
          do: "#{length(data.dependencies)} projected",
          else: "Unavailable"
        ),
      budget: "Unavailable; missing observations are not zero",
      cost: "Unavailable; missing observations are not zero",
      provenance:
        "Reviewed query #{description.query_version} at dataset revision #{description.dataset_revision}"
    }
  end

  defp project_capabilities(data) do
    [
      capability(:repository_identity, "Repository identity", :ready),
      capability(:work_summary, "Desired and current work", outcome_state(data.work)),
      capability(:attempt_summary, "Attempt summaries", data.attempts_result.outcome),
      capability(:wiki, "Repository wiki", wiki_capability(data.wiki_result, data.wiki)),
      capability(:dependencies, "Dependency summary", data.dependency_capability),
      capability(:cost, "Cost and budget", :unconfigured),
      capability(:knowledge, "Additional knowledge lenses", :unconfigured),
      capability(:semantic_controls, "Semantic controls", :unconfigured)
    ]
  end

  defp capability(key, label, state), do: %{key: key, label: label, state: state}

  defp outcome_state(work) when is_map(work) do
    outcomes = work |> Map.values() |> Enum.map(& &1.outcome)
    if Enum.all?(outcomes, &(&1 == :ok)), do: :ready, else: :incomplete
  end

  defp wiki_capability(%{outcome: :ok}, %{state: "Disabled"}), do: :disabled
  defp wiki_capability(%{outcome: :ok}, _wiki), do: :ready
  defp wiki_capability(_outcome, _wiki), do: :unavailable

  defp wiki_summary(nil), do: nil

  defp wiki_summary(%QueryResult{data: rows}) when is_list(rows) do
    case List.first(rows) do
      nil ->
        %{
          state: "Disabled",
          enrollment_revision: "Not enrolled",
          generation: "Not configured",
          current_edition: "None",
          freshness: "Unknown",
          source_snapshot: nil,
          source_fence: nil,
          cost: "Unavailable; no cost is inferred"
        }

      row ->
        state = row |> term_value("state") |> concept_label("Configured")

        %{
          state: state,
          enrollment_revision: safe_scalar(term_value(row, "revision"), "Unknown"),
          generation: row |> term_value("generation") |> concept_label("Not configured"),
          current_edition:
            if(valid_iri?(term_value(row, "currentEdition")), do: "Available", else: "None"),
          freshness: "Current enrollment projection",
          source_snapshot: nil,
          source_fence: nil,
          cost: "Unavailable; no cost is inferred"
        }
    end
  end

  defp wiki_summary(_result), do: nil

  defp load_dependencies(nil, _project, _scope, _authorization, _options),
    do: {[], nil, :unconfigured}

  defp load_dependencies(wiki, project, repository_scope, authorization, options) do
    with snapshot when is_binary(snapshot) <- wiki.source_snapshot,
         revision when is_binary(revision) <- wiki.source_fence,
         {:ok, graph} <-
           GraphRegistry.graph_iri(:source_revision, %{
             repository: project.iri,
             revision: revision
           }) do
      outcome =
        optional_query(
          options,
          :source_dependencies,
          %{graph: graph, snapshot: snapshot},
          authorization.authority_context,
          repository_scope
        )

      {dependency_rows(optional_result(outcome)), outcome,
       if(outcome.outcome == :ok, do: :ready, else: :unavailable)}
    else
      _unavailable -> {[], nil, :unconfigured}
    end
  end

  defp dependency_rows(%QueryResult{data: rows}) when is_list(rows) do
    rows
    |> Enum.map(fn row ->
      %{
        label: safe_scalar(term_value(row, "name"), "Source component"),
        dependency: safe_scalar(term_value(row, "dependencyName"), "Dependency"),
        status: "Observed in the exact source snapshot"
      }
    end)
    |> Enum.uniq()
    |> Enum.take(50)
  end

  defp dependency_rows(_result), do: []

  defp authorized_attempt_rows(_context, _project, nil, _options), do: []

  defp authorized_attempt_rows(context, project, %QueryResult{data: rows}, options)
       when is_list(rows) do
    allowed_iris =
      rows
      |> Enum.map(&term_value(&1, "attempt"))
      |> Enum.filter(&valid_iri?/1)
      |> MapSet.new()

    row_by_iri =
      rows
      |> Enum.reduce(%{}, fn row, acc ->
        case term_value(row, "attempt") do
          iri when is_binary(iri) -> Map.put_new(acc, iri, row)
          _missing -> acc
        end
      end)

    with {:ok, resources} <- resources(options, :attempt, @candidate_limit) do
      resources
      |> Enum.filter(fn resource ->
        resource.kind == :attempt and resource.parent_ref == project.resource_ref and
          resource.tenant_ref == project.tenant_ref and
          resource.project_ref == project.project_ref and
          MapSet.member?(allowed_iris, resource.iri)
      end)
      |> Enum.sort_by(& &1.resource_ref)
      |> Enum.reduce([], fn resource, accepted ->
        case authorize(
               context,
               :attempt,
               :query,
               :before_field_shaping,
               resource.resource_ref,
               options
             ) do
          {:ok, %{decision: :allowed}} ->
            row = Map.fetch!(row_by_iri, resource.iri)
            [public_attempt_row(resource, row) | accepted]

          _not_authorized ->
            accepted
        end
      end)
      |> Enum.reverse()
      |> Enum.take(50)
    else
      _unavailable -> []
    end
  end

  defp authorized_attempt_rows(_context, _project, _result, _options), do: []

  defp public_attempt_row(resource, row) do
    %{
      label: safe_ref_label(resource.resource_ref, "Attempt"),
      href: "/projects/#{resource.parent_ref}/attempts/#{resource.resource_ref}",
      task: row |> term_value("task") |> concept_label("Task unavailable"),
      lifecycle: row |> term_value("state") |> concept_label("State unavailable"),
      fence: safe_scalar(term_value(row, "fence"), "Unavailable"),
      freshness: "Current query revision",
      owner: "Project owner"
    }
  end

  defp filter_attempts(attempts, query) do
    q = query |> Map.get("q") |> normalize_search()
    state = Map.get(query, "state")

    attempts
    |> Enum.filter(fn attempt ->
      searchable = String.downcase(attempt.label <> " " <> attempt.task)
      search_match? = is_nil(q) or String.contains?(searchable, q)
      state_match? = is_nil(state) or attempt_state_match?(attempt.lifecycle, state)
      search_match? and state_match?
    end)
    |> Enum.sort_by(&String.downcase(&1.label))
  end

  defp attempt_state_match?(lifecycle, filter) do
    state = String.downcase(lifecycle)

    case filter do
      "active" -> String.contains?(state, ["running", "executing", "starting", "prepared"])
      "waiting" -> String.contains?(state, ["waiting", "blocked"])
      "blocked" -> String.contains?(state, "blocked")
      "verifying" -> String.contains?(state, ["verif", "decision"])
      "complete" -> String.contains?(state, ["complete", "cancel", "fail", "timed out"])
      _other -> false
    end
  end

  defp attempt_pagination(path, query, page, attempts) do
    total = length(attempts)
    page_count = max(1, ceil(total / @page_size))

    %{
      page: page,
      page_size: @page_size,
      known_total: total,
      page_count: page_count,
      previous_href: if(page > 1, do: page_href(path, query, page - 1)),
      next_href: if(page < page_count, do: page_href(path, query, page + 1)),
      summary: "Page #{page} of #{page_count}; #{total} authorized attempt(s)"
    }
  end

  defp work_counts(work) do
    Map.new(@work_states, fn state ->
      count =
        case optional_result(Map.fetch!(work, state)) do
          %QueryResult{} = result -> length(current_rows(result))
          nil -> nil
        end

      {state, count}
    end)
  end

  defp desired_state(counts) do
    cond do
      counts.eligible in [nil, 0] and counts.blocked in [nil, 0] and
        counts.executing in [nil, 0] and counts.awaiting_decision in [nil, 0] ->
        "No current desired work observed"

      true ->
        "#{counts.eligible || 0} eligible · #{counts.blocked || 0} blocked"
    end
  end

  defp current_state(counts) do
    "#{counts.executing || 0} executing · #{counts.awaiting_decision || 0} awaiting decision"
  end

  defp evidence_posture(counts) do
    if (counts.awaiting_decision || 0) > 0,
      do: "Independent verification or decision needed",
      else: "No verification need observed in the bounded work projection"
  end

  defp project_state(results, failures) do
    cond do
      results == [] -> :unavailable
      contradictory?(results) -> :contradicted
      Enum.any?(results, & &1.truncated?) -> :truncated
      failures > 0 or not Enum.all?(results, &complete?/1) -> :incomplete
      freshness(results) == :stale -> :stale
      true -> :ready
    end
  end

  defp load_attempt_data(
         context,
         project,
         attempt,
         repository_scope,
         run_graph,
         authorization,
         options
       ) do
    bindings = [
      :attempt_status,
      :attempt_timeline,
      :managed_attempt,
      :attempt_artifacts,
      :tool_invocations,
      :run_completeness
    ]

    outcomes =
      Map.new(bindings, fn binding ->
        {binding,
         optional_query(
           options,
           binding,
           %{graph: run_graph, resource: attempt.iri},
           authorization.authority_context,
           repository_scope
         )}
      end)

    evidence =
      case authorize_as(
             context,
             :evidence_page,
             :reviewer,
             :query,
             :before_query_execution,
             attempt.resource_ref,
             options
           ) do
        {:ok, evidence_authorization} ->
          with {:ok, evidence_graph} <-
                 GraphRegistry.graph_iri(:evidence, %{repository: project.iri}) do
            optional_query(
              options,
              :evidence_by_attempt,
              %{graph: evidence_graph, resource: attempt.iri},
              evidence_authorization.authority_context,
              repository_scope
            )
          else
            _invalid -> %{outcome: :unavailable, result: nil}
          end

        _not_authorized ->
          %{outcome: :unauthorized, result: nil}
      end

    all_outcomes = [evidence | Map.values(outcomes)]

    %{
      outcomes: outcomes,
      evidence: evidence,
      results: successful_results(all_outcomes),
      failures: Enum.count(all_outcomes, &(&1.outcome not in [:ok, :unauthorized])),
      evidence_authorized?: evidence.outcome != :unauthorized
    }
  end

  defp build_attempt_projection(_context, project, attempt, data, options) do
    status = optional_result(data.outcomes.attempt_status)
    timeline = optional_result(data.outcomes.attempt_timeline)
    managed = optional_result(data.outcomes.managed_attempt)
    artifacts = optional_result(data.outcomes.attempt_artifacts)
    tools = optional_result(data.outcomes.tool_invocations)
    evidence = optional_result(data.evidence)
    state = project_state(data.results, data.failures)
    lifecycle = lifecycle_steps(timeline)
    outcome_rail = outcome_steps(artifacts, evidence, data.evidence_authorized?)
    generated_at = now(options)

    attempt_summary =
      attempt_summary(
        project,
        attempt,
        status,
        managed,
        timeline,
        lifecycle,
        outcome_rail,
        data.results
      )

    counts = attempt_counts(timeline, artifacts, tools, evidence, data.evidence_authorized?)

    attributes =
      base_attributes(:attempt, state, data.results, generated_at)
      |> Map.merge(%{
        attempt: attempt_summary,
        summaries: %{
          counts: counts,
          recent_items: recent_attempt_items(timeline, artifacts),
          plan_state: "Plan state is separately labeled from observed runtime state",
          evidence_state:
            if(data.evidence_authorized?,
              do: "Claims and independent verification remain distinct",
              else: "Independent evidence is not authorized"
            ),
          source_state: "Candidate source is not externally applied source",
          progress_state: "Running does not imply semantic progress"
        },
        capabilities: [
          capability(:read_workspace, "Read-only attempt workspace", :ready),
          capability(:interaction_detail, "Interaction detail", :unconfigured),
          capability(:receipt_detail, "Receipt detail", :unconfigured),
          capability(:cost, "Cost attribution", :unconfigured),
          capability(:pause, "Pause", :unconfigured),
          capability(:stop, "Stop", :unconfigured),
          capability(:retry, "Retry", :unconfigured),
          capability(:approve, "Approve", :unconfigured)
        ],
        complete?: data.failures == 0 and Enum.all?(data.results, &complete?/1),
        truncated?: state == :truncated,
        warnings: safe_warnings(data.results, false) ++ failure_warnings(data.failures),
        cache: %{status: :bypass}
      })

    ReadProjection.new(attributes)
  end

  defp attempt_summary(
         project,
         attempt,
         status,
         managed,
         timeline,
         lifecycle,
         outcomes,
         results
       ) do
    managed_row = first_row(managed)

    %{
      label: safe_ref_label(attempt.resource_ref, "Attempt"),
      project: safe_project_label(project),
      task: known_concept_property(status, "task", "Unavailable"),
      agent: known_concept_property(status, "agent", "Unavailable"),
      profile: managed_row |> term_value("profile") |> concept_label("Unavailable"),
      runtime: known_property(status, "runtimeVersion", "Unavailable"),
      owner: "Project owner",
      branch: known_property(status, "branch", "Unavailable"),
      worktree: known_property(status, "worktree", "Unavailable"),
      revision: latest_revision(timeline),
      fence: managed_row |> term_value("fence") |> safe_scalar("Unavailable"),
      freshness: freshness(results) |> freshness_label(),
      lifecycle_steps: lifecycle,
      outcomes: outcomes,
      budget: nil
    }
  end

  defp lifecycle_steps(nil), do: []

  defp lifecycle_steps(%QueryResult{data: rows}) when is_list(rows) do
    ordered =
      rows
      |> Enum.sort_by(&(numeric(term_value(&1, "revision")) || 0))
      |> Enum.take(-12)

    last_index = length(ordered) - 1

    ordered
    |> Enum.with_index()
    |> Enum.map(fn {row, index} ->
      %{
        label: row |> term_value("state") |> concept_label("Unknown lifecycle state"),
        state: if(index == last_index, do: :current, else: :complete)
      }
    end)
  end

  defp lifecycle_steps(_result), do: []

  defp outcome_steps(artifacts, evidence, evidence_authorized?) do
    artifact_count = row_count(artifacts)
    evidence_count = row_count(evidence)

    [
      %{
        label:
          if(artifact_count > 0,
            do: "Candidate artifact claimed",
            else: "Candidate artifact not observed"
          ),
        state: if(artifact_count > 0, do: :observed, else: :unavailable),
        as_of: "Claimed output is not external application"
      },
      %{
        label:
          cond do
            not evidence_authorized? -> "Independent verification not authorized"
            evidence_count > 0 -> "Independent verification evidence observed"
            true -> "Independent verification not observed"
          end,
        state:
          cond do
            not evidence_authorized? -> :unavailable
            evidence_count > 0 -> :observed
            true -> :pending
          end,
        as_of: "Evidence remains distinct from the attempt claim"
      },
      %{
        label: "External source application unavailable",
        state: :unavailable,
        as_of: "A candidate is not an externally applied source revision"
      }
    ]
  end

  defp attempt_counts(timeline, artifacts, tools, evidence, evidence_authorized?) do
    [
      count(:interactions, "Interactions", nil, :unconfigured),
      count(:artifacts, "Artifacts", row_count(artifacts), :ready),
      count(:effects, "Admitted effects", row_count(tools), :ready),
      count(
        :verification,
        "Independent verification",
        if(evidence_authorized?, do: row_count(evidence)),
        if(evidence_authorized?, do: :ready, else: :unauthorized)
      ),
      count(:decisions, "Decisions", nil, :unconfigured),
      count(:receipts, "Receipts", nil, :unconfigured),
      count(:cost, "Cost records", nil, :unconfigured),
      count(:timeline, "Lifecycle observations", row_count(timeline), :ready)
    ]
  end

  defp count(key, label, value, state), do: %{key: key, label: label, value: value, state: state}

  defp recent_attempt_items(timeline, artifacts) do
    timeline_items =
      case timeline do
        %QueryResult{data: rows} when is_list(rows) ->
          rows
          |> Enum.take(8)
          |> Enum.map(fn row ->
            %{
              label: row |> term_value("state") |> concept_label("Lifecycle observation"),
              detail:
                "Observed lifecycle revision #{safe_scalar(term_value(row, "revision"), "unknown")}",
              kind: :lifecycle
            }
          end)

        _other ->
          []
      end

    artifact_items =
      case artifacts do
        %QueryResult{data: rows} when is_list(rows) ->
          rows
          |> Enum.take(4)
          |> Enum.map(fn row ->
            %{
              label: row |> term_value("kind") |> concept_label("Artifact"),
              detail: "Claimed artifact metadata; content is not embedded",
              kind: :artifact
            }
          end)

        _other ->
          []
      end

    Enum.take(timeline_items ++ artifact_items, 12)
  end

  defp known_property(nil, _suffix, fallback), do: fallback

  defp known_property(%QueryResult{data: rows}, suffix, fallback) when is_list(rows) do
    Enum.find_value(rows, fallback, fn row ->
      predicate = term_value(row, "predicate")

      if is_binary(predicate) and String.ends_with?(predicate, suffix) do
        term_value(row, "object") |> safe_scalar(fallback)
      end
    end)
  end

  defp known_property(_result, _suffix, fallback), do: fallback

  defp known_concept_property(nil, _suffix, fallback), do: fallback

  defp known_concept_property(%QueryResult{data: rows}, suffix, fallback) when is_list(rows) do
    Enum.find_value(rows, fallback, fn row ->
      predicate = term_value(row, "predicate")

      if is_binary(predicate) and String.ends_with?(predicate, suffix) do
        row |> term_value("object") |> concept_label(fallback)
      end
    end)
  end

  defp known_concept_property(_result, _suffix, fallback), do: fallback

  defp first_row(%QueryResult{data: rows}) when is_list(rows), do: List.first(rows) || %{}
  defp first_row(_result), do: %{}

  defp latest_revision(%QueryResult{data: rows}) when is_list(rows) do
    rows
    |> Enum.map(&(numeric(term_value(&1, "revision")) || 0))
    |> Enum.max(fn -> 0 end)
    |> case do
      0 -> "Unavailable"
      revision -> Integer.to_string(revision)
    end
  end

  defp latest_revision(_result), do: "Unavailable"

  defp row_count(%QueryResult{data: rows}) when is_list(rows), do: length(rows)
  defp row_count(_result), do: 0

  defp numeric(value) when is_integer(value), do: value

  defp numeric(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      _invalid -> nil
    end
  end

  defp numeric(_value), do: nil

  defp optional_query(options, binding, parameters, authority, scope) do
    case query(options, binding, parameters, authority, scope) do
      {:ok, %QueryResult{} = result} -> %{outcome: :ok, result: result}
      {:error, %Error{} = error} -> %{outcome: error_outcome(error), result: nil}
      {:error, outcome} when is_atom(outcome) -> %{outcome: outcome, result: nil}
      _invalid -> %{outcome: :error, result: nil}
    end
  end

  defp optional_result(%{result: result}), do: result
  defp optional_result(_outcome), do: nil

  defp optional_complete?(%{outcome: :ok, result: result}), do: complete?(result)
  defp optional_complete?(_outcome), do: false

  defp successful_results(outcomes) do
    outcomes
    |> Enum.flat_map(fn
      %{outcome: :ok, result: %QueryResult{} = result} -> [result]
      _other -> []
    end)
  end

  defp failure_warnings(0), do: []
  defp failure_warnings(_count), do: [:optional_projection_unavailable]

  defp safe_ref_label(value, fallback) when is_binary(value) do
    value
    |> String.replace(~r/[[:cntrl:]]/u, "")
    |> String.slice(0, 160)
    |> case do
      "" -> fallback
      label -> label
    end
  end

  defp safe_ref_label(_value, fallback), do: fallback

  defp safe_scalar(value, fallback)
       when is_binary(value) or is_integer(value) or is_float(value) or is_atom(value) do
    value
    |> to_string()
    |> String.replace(~r/[[:cntrl:]]/u, "")
    |> String.slice(0, 160)
    |> case do
      "" -> fallback
      label -> label
    end
  end

  defp safe_scalar(_value, fallback), do: fallback

  defp load_fleet_row(%{resource: resource, authorization: authorization}, options) do
    with {:ok, scope} <- ResourceIdentity.scope(:repository, resource.iri),
         {:ok, graph} <- GraphRegistry.graph_iri(:repository_control, %{repository: resource.iri}),
         {:ok, work_results} <- load_work(graph, authorization, scope, options),
         {:ok, attempts} <-
           query(
             options,
             :active_attempts,
             %{graph: graph},
             authorization.authority_context,
             scope
           ) do
      results = Map.values(work_results) ++ [attempts]
      current_attempts = current_rows(attempts)

      counts =
        Map.new(work_results, fn {state, result} -> {state, length(current_rows(result))} end)

      stage = stage_label(counts, current_attempts)
      freshness = freshness(results)
      unavailable? = false

      %{
        project: safe_project_label(resource),
        project_href: "/projects/#{resource.resource_ref}",
        work: work_label(counts),
        agent: "Not configured",
        stage: stage,
        health: health_label(counts, results),
        health_state: row_state(counts, results),
        freshness: freshness_label(freshness),
        state_key: filter_state(counts),
        resource_ref: resource.resource_ref,
        blocked_count: counts.blocked,
        awaiting_count: counts.awaiting_decision,
        failed_count: failed_count(current_attempts),
        unavailable?: unavailable?,
        results: results
      }
    else
      _unavailable -> unavailable_row(resource)
    end
  end

  defp load_work(graph, authorization, scope, options) do
    Enum.reduce_while(@work_states, {:ok, %{}}, fn state, {:ok, results} ->
      case query(
             options,
             :work_lens,
             %{graph: graph, state: state},
             authorization.authority_context,
             scope
           ) do
        {:ok, result} -> {:cont, {:ok, Map.put(results, state, result)}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp unavailable_row(resource) do
    %{
      project: safe_project_label(resource),
      project_href: "/projects/#{resource.resource_ref}",
      work: "Unavailable",
      agent: "Not configured",
      stage: "Projection unavailable",
      health: "Unavailable",
      health_state: :unavailable,
      freshness: "Unknown",
      state_key: "unavailable",
      resource_ref: resource.resource_ref,
      blocked_count: 0,
      awaiting_count: 0,
      failed_count: 0,
      unavailable?: true,
      results: []
    }
  end

  defp attention_items(details) do
    details
    |> Enum.flat_map(fn row ->
      destination = row.project_href

      []
      |> maybe_attention(row.failed_count > 0, %{
        severity: :critical,
        title: "Failed attempt",
        reason: "Durable attempt state reports a failure outcome.",
        scope_label: row.project,
        owner: "Project owner",
        age: row.freshness,
        destination_href: destination,
        destination_label: "Open project"
      })
      |> maybe_attention(row.blocked_count > 0, %{
        severity: :high,
        title: "Blocked work",
        reason: "#{row.blocked_count} authorized work item(s) have a current blocked endpoint.",
        scope_label: row.project,
        owner: "Project owner",
        age: row.freshness,
        destination_href: destination,
        destination_label: "Review project"
      })
      |> maybe_attention(row.awaiting_count > 0, %{
        severity: :medium,
        title: "Verification or decision needed",
        reason:
          "#{row.awaiting_count} authorized work item(s) await an independently governed decision.",
        scope_label: row.project,
        owner: "Project owner",
        age: row.freshness,
        destination_href: destination,
        destination_label: "Review project"
      })
      |> maybe_attention(row.freshness == "Stale", %{
        severity: :medium,
        title: "Stale projection",
        reason: "The latest reviewed query result is outside its accepted freshness target.",
        scope_label: row.project,
        owner: "Factory operator",
        age: "Stale",
        destination_href: destination,
        destination_label: "Open project"
      })
      |> maybe_attention(row.unavailable?, %{
        severity: :information,
        title: "Projection unavailable",
        reason: "Current authorized project facts could not be rebuilt.",
        scope_label: row.project,
        owner: "Factory operator",
        age: "Unknown",
        destination_href: destination,
        destination_label: "Open project"
      })
    end)
    |> Enum.sort_by(&severity_rank(&1.severity), :desc)
    |> Enum.take(24)
  end

  defp maybe_attention(items, true, item), do: [item | items]
  defp maybe_attention(items, false, _item), do: items

  defp attention_families(attention, details) do
    counts = %{
      blocked: Enum.count(attention, &(&1.title == "Blocked work")),
      failed: Enum.count(attention, &(&1.title == "Failed attempt")),
      stale: Enum.count(attention, &(&1.title == "Stale projection")),
      verification_needed:
        Enum.count(attention, &(&1.title == "Verification or decision needed")),
      unavailable: Enum.count(attention, &(&1.title == "Projection unavailable"))
    }

    [
      family(:blocked, "Blocked", counts.blocked, :ready),
      family(:failed, "Failed", counts.failed, :ready),
      family(:stale, "Stale", counts.stale, :ready),
      family(:budget_near, "Budget near", nil, :unconfigured),
      family(:verification_needed, "Verification needed", counts.verification_needed, :ready),
      family(:approval_needed, "Approval needed", nil, :unconfigured),
      family(:incident, "Incident", nil, :unconfigured),
      family(:unavailable, "Unavailable", counts.unavailable, availability_state(details))
    ]
  end

  defp family(key, label, count, state), do: %{key: key, label: label, count: count, state: state}

  defp availability_state(details) do
    if Enum.any?(details, & &1.unavailable?), do: :incomplete, else: :ready
  end

  defp health_items(candidates, attention, cohort, details) do
    [
      %{
        label: "Authorized projects",
        value:
          if(complete?(cohort) and not cohort.truncated?, do: length(candidates), else: "Unknown"),
        status: :healthy,
        detail: "Computed only after row authorization."
      },
      %{
        label: "Needs attention",
        value: length(attention),
        status: if(attention == [], do: :healthy, else: :attention),
        detail: "Derived from current durable facts; not an acknowledgement resource."
      },
      %{
        label: "Projection freshness",
        value: freshness_label(freshness([cohort | Enum.flat_map(details, & &1.results)])),
        status: if(freshness([cohort]) == :current, do: :healthy, else: :attention),
        detail: "Process liveness is not semantic progress."
      },
      %{
        label: "Factory capability",
        value: "Evaluation only",
        status: :unknown,
        detail:
          "Read projections are active; semantic controls remain unavailable until Milestone E."
      }
    ]
  end

  defp factory_capabilities(families) do
    [
      %{key: :read_projection, label: "Reviewed read projections", state: :ready},
      %{key: :semantic_controls, label: "Semantic controls", state: :unconfigured},
      %{
        key: :attention_acknowledgement,
        label: "Durable attention acknowledgement",
        state: :unconfigured
      },
      %{
        key: :attention_family_coverage,
        label: "Attention families with current bindings",
        state:
          if(Enum.any?(families, &(&1.state == :unconfigured)), do: :incomplete, else: :ready)
      }
    ]
  end

  defp filter_rows(rows, query) do
    q = query |> Map.get("q") |> normalize_search()
    state = Map.get(query, "state")

    Enum.filter(rows, fn row ->
      matches_search? = is_nil(q) or String.contains?(String.downcase(row.project), q)
      matches_state? = is_nil(state) or state_match?(row.state_key, state)
      matches_search? and matches_state?
    end)
  end

  defp sort_rows(rows, query) do
    column = Map.get(query, "sort", "project")
    direction = Map.get(query, "direction", "ascending")

    sorted = Enum.sort_by(rows, &sort_value(&1, column), :asc)
    if direction == "descending", do: Enum.reverse(sorted), else: sorted
  end

  defp sort_value(row, "work"), do: String.downcase(row.work)
  defp sort_value(row, "agent"), do: String.downcase(row.agent)
  defp sort_value(row, "stage"), do: String.downcase(row.stage)
  defp sort_value(row, "health"), do: String.downcase(row.health)
  defp sort_value(row, "freshness"), do: String.downcase(row.freshness)
  defp sort_value(row, _project), do: String.downcase(row.project)

  defp state_match?("executing", "active"), do: true
  defp state_match?("eligible", "active"), do: true
  defp state_match?("awaiting_decision", "waiting"), do: true
  defp state_match?("blocked", "waiting"), do: true
  defp state_match?("blocked", "blocked"), do: true
  defp state_match?("awaiting_decision", "verifying"), do: true
  defp state_match?("complete", "complete"), do: true
  defp state_match?(_row, _filter), do: false

  defp pagination(path, query, page, rows, known_total?) do
    total = if(known_total?, do: length(rows), else: nil)
    page_count = if(is_integer(total), do: max(1, ceil(total / @page_size)), else: nil)
    previous = if(page > 1, do: page_href(path, query, page - 1), else: nil)

    next =
      cond do
        page_count && page < page_count -> page_href(path, query, page + 1)
        is_nil(page_count) && length(rows) > page * @page_size -> page_href(path, query, page + 1)
        true -> nil
      end

    summary =
      if page_count,
        do: "Page #{page} of #{page_count}; #{total} authorized row(s)",
        else: "Page #{page}; authorized total is unavailable"

    %{
      page: page,
      page_size: @page_size,
      known_total: total,
      page_count: page_count,
      previous_href: previous,
      next_href: next,
      summary: summary
    }
  end

  defp page_href(path, query, page) do
    encoded =
      query
      |> Map.put("page", page)
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()
      |> URI.encode_query()

    path <> "?" <> encoded
  end

  defp sort_hrefs(path, query) do
    Map.new(@sort_columns, fn column ->
      current_column = Map.get(query, "sort", "project")
      current_direction = Map.get(query, "direction", "ascending")

      direction =
        if current_column == column and current_direction == "ascending",
          do: "descending",
          else: "ascending"

      next_query =
        query
        |> Map.put("sort", column)
        |> Map.put("direction", direction)
        |> Map.delete("page")
        |> Enum.reject(fn
          {"sort", "project"} -> true
          {"direction", "ascending"} -> true
          {_key, nil} -> true
          _pair -> false
        end)
        |> Map.new()

      href =
        if(map_size(next_query) == 0, do: path, else: path <> "?" <> URI.encode_query(next_query))

      {String.to_existing_atom(column), href}
    end)
  end

  defp base_attributes(surface, state, results, generated_at) do
    %{
      surface: surface,
      state: state,
      source_outcome: state,
      query_version: @query_version,
      dataset_revision: dataset_revision(results),
      source_revision_count: source_revision_count(results),
      generated_at: generated_at,
      freshness: freshness(results),
      complete?: Enum.all?(results, &complete?/1),
      truncated?: Enum.any?(results, & &1.truncated?),
      attention: [],
      attention_families: [],
      health: [],
      fleet: [],
      projects: [],
      project: nil,
      attempts: [],
      wiki: nil,
      dependencies: [],
      attempt: nil,
      summaries: %{},
      capabilities: [],
      warnings: [],
      pagination: ReadProjection.empty_pagination(),
      cache: %{status: :bypass}
    }
  end

  defp projection_state(results, rows, scan_truncated?) do
    cond do
      contradictory?(results) -> :contradicted
      scan_truncated? or Enum.any?(results, & &1.truncated?) -> :truncated
      not Enum.all?(results, &complete?/1) -> :incomplete
      freshness(results) == :stale -> :stale
      rows == [] -> :empty
      true -> :ready
    end
  end

  defp contradictory?(results) do
    revisions = results |> Enum.map(& &1.dataset_revision) |> Enum.uniq()

    length(revisions) > 1 or
      Enum.any?(results, fn result ->
        Enum.any?(result.warnings, &warning_contradiction?/1)
      end)
  end

  defp warning_contradiction?(:contradiction), do: true
  defp warning_contradiction?({:consistency, :contradicted}), do: true
  defp warning_contradiction?(_warning), do: false

  defp safe_warnings(results, scan_truncated?) do
    warnings =
      results
      |> Enum.flat_map(& &1.warnings)
      |> Enum.map(&safe_warning/1)
      |> Enum.uniq()
      |> Enum.take(20)

    if scan_truncated?, do: Enum.uniq([:scan_limit_reached | warnings]), else: warnings
  end

  defp safe_warning(value) when is_atom(value), do: value
  defp safe_warning({:consistency, value}) when is_atom(value), do: {:consistency, value}
  defp safe_warning(_value), do: :query_warning

  defp dataset_revision([]), do: nil

  defp dataset_revision(results) do
    case results |> Enum.map(& &1.dataset_revision) |> Enum.uniq() do
      [revision] -> revision
      _mixed -> results |> Enum.map(& &1.dataset_revision) |> Enum.max(fn -> nil end)
    end
  end

  defp source_revision_count(results) do
    results
    |> Enum.flat_map(&Map.keys(&1.graph_revisions))
    |> Enum.uniq()
    |> length()
  end

  defp complete?(%QueryResult{query_name: :dataset_revision, truncated?: false}), do: true
  defp complete?(%QueryResult{completeness: %{complete?: value}}), do: value == true
  defp complete?(%QueryResult{completeness: value}) when value in [:complete, :declared], do: true
  defp complete?(%QueryResult{truncated?: false, completeness: nil}), do: false
  defp complete?(_result), do: false

  defp freshness(results) do
    cond do
      results == [] -> :unknown
      Enum.any?(results, &(freshness_state(&1) == :stale)) -> :stale
      Enum.all?(results, &(freshness_state(&1) == :current)) -> :current
      true -> :unknown
    end
  end

  defp freshness_state(%QueryResult{freshness: value}) when is_atom(value), do: value
  defp freshness_state(%QueryResult{freshness: %{state: value}}) when is_atom(value), do: value
  defp freshness_state(_result), do: :unknown

  defp current_rows(%QueryResult{data: rows}) when is_list(rows) do
    Enum.filter(rows, fn row -> is_nil(term_value(row, "successor")) end)
  end

  defp current_rows(_result), do: []

  defp stage_label(counts, attempts) do
    cond do
      counts.blocked > 0 -> "Blocked"
      counts.awaiting_decision > 0 -> "Verification needed"
      attempts != [] -> attempts |> hd() |> term_value("state") |> concept_label("Running")
      counts.executing > 0 -> "Running"
      counts.eligible > 0 -> "Ready"
      true -> "No active work"
    end
  end

  defp work_label(counts) do
    "#{counts.executing} running · #{counts.blocked} blocked · #{counts.awaiting_decision} awaiting"
  end

  defp health_label(counts, results) do
    cond do
      contradictory?(results) -> "Contradicted"
      counts.blocked > 0 -> "Needs attention"
      freshness(results) == :stale -> "Stale"
      true -> "Current"
    end
  end

  defp row_state(counts, results) do
    cond do
      contradictory?(results) -> :contradicted
      Enum.any?(results, & &1.truncated?) -> :truncated
      not Enum.all?(results, &complete?/1) -> :incomplete
      freshness(results) == :stale -> :stale
      counts.blocked > 0 -> :ready
      true -> :ready
    end
  end

  defp filter_state(counts) do
    cond do
      counts.blocked > 0 -> "blocked"
      counts.awaiting_decision > 0 -> "awaiting_decision"
      counts.executing > 0 -> "executing"
      counts.eligible > 0 -> "eligible"
      true -> "complete"
    end
  end

  defp failed_count(rows) do
    Enum.count(rows, fn row ->
      row |> term_value("successorState") |> concept_label("") |> String.downcase() =~ "fail"
    end)
  end

  defp freshness_label(:current), do: "Current"
  defp freshness_label(:stale), do: "Stale"
  defp freshness_label(:unknown), do: "Unknown"

  defp severity_rank(:critical), do: 4
  defp severity_rank(:high), do: 3
  defp severity_rank(:medium), do: 2
  defp severity_rank(:low), do: 1
  defp severity_rank(_other), do: 0

  defp normalize_search(nil), do: nil
  defp normalize_search(value), do: value |> String.downcase() |> String.trim()

  defp safe_project_label(resource) do
    resource.project_ref
    |> to_string()
    |> String.replace(~r/[[:cntrl:]]/u, "")
    |> String.slice(0, 160)
    |> case do
      "" -> "Project"
      label -> label
    end
  end

  defp concept_label(nil, fallback), do: fallback

  defp concept_label(value, fallback) do
    value
    |> to_string()
    |> URI.parse()
    |> then(fn uri -> uri.fragment || (uri.path && Path.basename(uri.path)) || fallback end)
    |> Macro.underscore()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp term_value(row, key) when is_map(row) do
    value =
      case Map.fetch(row, key) do
        {:ok, found} ->
          found

        :error ->
          Enum.find_value(row, fn {candidate, found} ->
            if to_string(candidate) == key, do: found
          end)
      end

    case value do
      %{value: value} -> value
      value when is_binary(value) or is_number(value) or is_boolean(value) -> value
      _missing -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp term_value(_row, _key), do: nil

  defp valid_iri?(value) when is_binary(value) do
    uri = URI.parse(value)
    uri.scheme in ["http", "https", "urn"] and is_nil(uri.userinfo)
  end

  defp valid_iri?(_value), do: false

  defp list(value) when is_list(value), do: value
  defp list(_value), do: []

  defp query(options, binding, parameters, authority, scope) do
    query = Keyword.get(options, :query, &Knowledge.query/6)
    ReadProjectionQuery.execute(query, binding, parameters, authority, scope)
  end

  defp resources(options, kind, limit) do
    loader = Keyword.get(options, :resources, &Store.registered_resources/2)
    loader.(kind, limit)
  rescue
    _error -> {:error, :unavailable}
  end

  defp resolve_resource(options, resource_ref) do
    resolver = Keyword.get(options, :resolve_resource, &Store.resolve_resource/1)
    resolver.(resource_ref)
  rescue
    _error -> {:error, :unavailable}
  end

  defp authorize(context, surface, action, point, resource_ref, options) do
    {operation, area} = operation_area(surface)
    authorize_as(context, operation, area, action, point, resource_ref, options)
  end

  defp authorize_as(context, operation, area, action, point, resource_ref, options) do
    callback = Keyword.get(options, :authorize, &default_authorize/6)
    callback.(context, operation, area, action, point, resource_ref)
  rescue
    _error -> {:error, :unavailable}
  end

  defp default_authorize(context, operation, area, action, point, resource_ref) do
    with {:ok, request} <-
           AuthorityBuilder.request(operation, area, action, resource_ref,
             reauthorization_point: point,
             correlation_ref: correlation(context.page.key, point, resource_ref)
           ),
         {:ok, %AuthorizationResult{} = authorization} <-
           AuthorityBuilder.build(context.session_ref, request, touch: false),
         :allowed <- authorization.decision do
      {:ok, authorization}
    else
      {:ok, %AuthorizationResult{decision: decision}} -> {:error, decision}
      decision when is_atom(decision) -> {:error, decision}
      {:error, reason} -> {:error, reason}
    end
  end

  defp operation_area(surface) when surface in [:factory, :fleet],
    do: {:factory_shell, :developer}

  defp operation_area(surface)
       when surface in [
              :projects,
              :project,
              :project_attempts,
              :project_wiki,
              :project_dependencies
            ],
       do: {:project_page, :developer}

  defp operation_area(:attempt), do: {:attempt_page, :developer}

  defp correlation(surface, point, resource_ref) do
    value = :erlang.phash2({surface, point, resource_ref})
    "hui-c4-#{surface}-#{point}-#{value}"
  end

  defp now(options) do
    clock = Keyword.get(options, :clock, fn -> DateTime.utc_now() end)
    clock.() |> DateTime.truncate(:second)
  end

  defp error_outcome(%Error{kind: :unauthorized}), do: :denied
  defp error_outcome(%Error{kind: :stale_precondition}), do: :stale
  defp error_outcome(%Error{kind: :timeout}), do: :error
  defp error_outcome(_error), do: :unavailable
end
