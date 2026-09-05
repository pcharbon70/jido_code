defmodule JidoCodeWeb.ProductPageViewModel do
  @moduledoc """
  Builds the closed, presentation-only model for an already-authorized page.

  Navigation candidates and registry candidates are reauthorized one by one.
  A role label explains an accepted decision but never selects a destination.
  """

  alias JidoCode.Identity.AuthorityBuilder
  alias JidoCode.Identity.AuthorizationResult
  alias JidoCode.Identity.Store

  @maximum_projects 50
  @state_options [
    %{key: "all", value: "all", label: "All states"},
    %{key: "active", value: "active", label: "Active"},
    %{key: "waiting", value: "waiting", label: "Waiting"},
    %{key: "blocked", value: "blocked", label: "Blocked"},
    %{key: "verifying", value: "verifying", label: "Verifying"},
    %{key: "complete", value: "complete", label: "Complete"}
  ]

  @route_labels %{
    factory: "Needs attention",
    fleet: "Fleet",
    projects: "Projects",
    project: "Overview",
    project_attempts: "Attempts",
    project_wiki: "Wiki",
    project_dependencies: "Dependencies",
    attempt: "Attempt workspace",
    knowledge: "Knowledge lens",
    review: "Candidate review",
    operations: "Operations",
    costs: "Costs",
    security: "Security",
    incidents: "Incidents",
    governance: "Governance",
    account: "Account",
    sessions: "Sessions"
  }

  @spec build(Plug.Conn.t(), map()) :: map()
  def build(conn, page) do
    human = Map.fetch!(conn.assigns, :authenticated_human)
    session_ref = human.session_ref
    project = project_context(page)
    primary = primary_navigation(session_ref, page, project)
    utility = utility_navigation(session_ref, page)
    account_actions = account_actions(page)
    projects = authorized_projects(session_ref)
    current_project = if(project, do: project.resource_ref, else: first_project_ref(projects))
    filter = filter_model(page)

    %{
      brand: %{label: "JidoCode", href: "/factory", service_label: "Secure factory control plane"},
      principal: principal(human),
      context: context(page, human, project),
      primary_navigation: primary,
      utility_navigation: utility,
      responsive_navigation: primary ++ utility ++ account_actions,
      account_actions: account_actions,
      projects: projects,
      project_form:
        Phoenix.Component.to_form(%{"project_ref" => current_project || ""}, as: :project_switch),
      breadcrumbs: breadcrumbs(page, project),
      attempt: attempt_context(page, project),
      notices: notices(page),
      support: support(page),
      filter: filter,
      page_actions: page_actions(page, project),
      pagination: pagination(page),
      errors: page.query_errors,
      sign_out_form: Phoenix.Component.to_form(%{}, as: :sign_out)
    }
  end

  defp principal(human) do
    %{
      display_name: human.account.display_name,
      session_label: assurance_label(human.session.assurance),
      assurance: human.session.assurance
    }
  end

  defp context(page, human, project) do
    authorization = page.authorization

    roles =
      case authorization do
        %AuthorizationResult{} -> authorization.membership_explanations
        _session -> []
      end

    %{
      route_label: Map.fetch!(@route_labels, page.key),
      scope_label: if(project, do: "Project #{project.project_ref}", else: "Factory"),
      role_label: role_label(roles),
      assurance_label: assurance_label(human.session.assurance),
      readiness: :limited,
      readiness_label: "Read projection pending",
      explanation:
        "Identity and route authority are current. Read projection data remains unavailable until its accepted provider is connected."
    }
  end

  defp primary_navigation(session_ref, page, project) do
    candidates = [
      nav(
        "factory",
        "Attention",
        "/factory",
        :factory_shell,
        :developer,
        :factory,
        page.key == :factory
      ),
      nav(
        "fleet",
        "Fleet",
        "/factory/fleet",
        :factory_shell,
        :developer,
        :factory,
        page.key == :fleet
      ),
      nav(
        "projects",
        "Projects",
        "/projects",
        :project_page,
        :developer,
        :factory,
        page.key == :projects
      )
    ]

    project_candidates =
      if project do
        ref = project.resource_ref

        [
          nav(
            "project",
            "Overview",
            "/projects/#{ref}",
            :project_page,
            :developer,
            ref,
            page.key == :project,
            :project
          ),
          nav(
            "project-attempts",
            "Attempts",
            "/projects/#{ref}/attempts",
            :project_page,
            :developer,
            ref,
            page.key in [:project_attempts, :attempt],
            :project
          ),
          nav(
            "project-wiki",
            "Wiki",
            "/projects/#{ref}/wiki",
            :project_page,
            :developer,
            ref,
            page.key == :project_wiki,
            :project
          ),
          nav(
            "project-dependencies",
            "Dependencies",
            "/projects/#{ref}/dependencies",
            :project_page,
            :developer,
            ref,
            page.key == :project_dependencies,
            :project
          ),
          nav(
            "project-knowledge",
            "Knowledge",
            "/projects/#{ref}/knowledge/source",
            :knowledge_page,
            :knowledge,
            ref,
            page.key == :knowledge,
            :project
          )
        ]
      else
        []
      end

    authorize_navigation(session_ref, candidates ++ project_candidates)
  end

  defp utility_navigation(session_ref, page) do
    [
      nav(
        "operations",
        "Operations",
        "/operations",
        :operations_page,
        :operations,
        :factory,
        page.key == :operations
      ),
      nav("costs", "Costs", "/operations/costs", :cost_page, :cost, :factory, page.key == :costs),
      nav(
        "security",
        "Security",
        "/security",
        :security_page,
        :security,
        :factory,
        page.key in [:security, :incidents]
      ),
      nav(
        "governance",
        "Governance",
        "/governance",
        :administration_page,
        :administration,
        :factory,
        page.key == :governance
      )
    ]
    |> authorize_navigation(session_ref)
  end

  defp account_actions(page) do
    [
      %{key: "account", label: "Account", href: "/account", current: page.key == :account},
      %{
        key: "sessions",
        label: "Sessions",
        href: "/account/sessions",
        current: page.key == :sessions
      }
    ]
  end

  defp nav(key, label, href, operation, area, resource_ref, current, kind \\ :factory) do
    %{
      key: key,
      label: label,
      href: href,
      operation: operation,
      area: area,
      resource_ref: resource_ref,
      resource_kind: kind,
      current: current
    }
  end

  defp authorize_navigation(candidates, session_ref) when is_list(candidates),
    do: authorize_navigation(session_ref, candidates)

  defp authorize_navigation(session_ref, candidates) do
    candidates
    |> Enum.filter(&authorized?(session_ref, &1))
    |> Enum.map(&Map.take(&1, [:key, :label, :href, :current]))
  end

  defp authorized?(session_ref, candidate) do
    with {:ok, request} <-
           AuthorityBuilder.request(
             candidate.operation,
             candidate.area,
             :page,
             candidate.resource_ref,
             correlation_ref: "navigation-#{candidate.key}"
           ),
         {:ok, authorization} <- AuthorityBuilder.build(session_ref, request, touch: false),
         :allowed <- authorization.decision do
      authorization.current_scope.resource_kind == candidate.resource_kind
    else
      _not_authorized -> false
    end
  end

  defp authorized_projects(session_ref) do
    with {:ok, candidates} <- Store.registered_resources(:project, @maximum_projects) do
      candidates
      |> Enum.filter(fn project ->
        authorized?(
          session_ref,
          nav(
            "project-candidate",
            "Project",
            "/",
            :project_page,
            :developer,
            project.resource_ref,
            false,
            :project
          )
        )
      end)
      |> Enum.map(fn project ->
        %{
          key: project.resource_ref,
          value: project.resource_ref,
          label: "Project #{project.project_ref}"
        }
      end)
    else
      _unavailable -> []
    end
  end

  defp first_project_ref([project | _rest]), do: project.value
  defp first_project_ref([]), do: nil

  defp project_context(%{route_params: %{resource_ref: ref, resource_kind: :project}}) do
    case Store.resolve_resource(ref) do
      {:ok, project} -> project
      _missing -> nil
    end
  end

  defp project_context(%{route_params: %{parent_ref: ref, parent_kind: :project}}) do
    case Store.resolve_resource(ref) do
      {:ok, project} -> project
      _missing -> nil
    end
  end

  defp project_context(_page), do: nil

  defp attempt_context(%{key: :attempt, route_params: params}, project) do
    %{
      label: "Attempt",
      reference: params.resource_ref,
      scope_label: "Project #{project.project_ref}",
      state: :queued,
      state_label: "Read projection pending"
    }
  end

  defp attempt_context(_page, _project), do: nil

  defp breadcrumbs(page, project) do
    base = [%{key: "factory", label: "Factory", href: "/factory", current: false}]

    project_items =
      cond do
        page.key == :projects ->
          [%{key: "current", label: "Projects", current: true}]

        project ->
          [
            %{key: "projects", label: "Projects", href: "/projects", current: false},
            %{
              key: "project",
              label: "Project #{project.project_ref}",
              href: "/projects/#{project.resource_ref}",
              current: page.key == :project
            }
          ] ++ current_leaf(page)

        page.key == :factory ->
          [%{key: "current", label: "Needs attention", current: true}]

        true ->
          [%{key: "current", label: Map.fetch!(@route_labels, page.key), current: true}]
      end

    normalize_breadcrumb_current(base ++ project_items)
  end

  defp current_leaf(%{key: :project}), do: []

  defp current_leaf(page),
    do: [%{key: "current", label: Map.fetch!(@route_labels, page.key), current: true}]

  defp normalize_breadcrumb_current(items) do
    last_index = length(items) - 1

    items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> Map.put(item, :current, index == last_index) end)
    |> Enum.map(fn item -> if(item.current, do: Map.delete(item, :href), else: item) end)
  end

  defp notices(_page) do
    [
      %{
        kind: :maintenance,
        title: "Read projection pending",
        message:
          "Navigation and current authority are active; projection content is not configured in this phase."
      }
    ]
  end

  defp support(page) do
    %{
      metadata: [
        %{key: "route", label: "Route", value: Map.fetch!(@route_labels, page.key)},
        %{key: "freshness", label: "Freshness", value: "No projection loaded"}
      ],
      links: [
        %{key: "account", label: "Account", href: "/account", current: false},
        %{key: "sessions", label: "Sessions", href: "/account/sessions", current: false}
      ]
    }
  end

  defp filter_model(page) do
    fields = MapSet.new(page.query_fields)

    if MapSet.member?(fields, "q") do
      values = %{
        "q" => Map.get(page.query, "q", ""),
        "state" => Map.get(page.query, "state", "all")
      }

      form = Phoenix.Component.to_form(values, as: nil)

      %{
        form: form,
        query_field: form[:q],
        filters:
          if(MapSet.member?(fields, "state"),
            do: [
              %{
                key: "state",
                label: "State",
                help: "Server-owned closed state filter.",
                field: form[:state],
                options: @state_options
              }
            ],
            else: []
          )
      }
    end
  end

  defp page_actions(%{key: :incidents}, _project),
    do: [%{key: "security", label: "Security overview", href: "/security", current: false}]

  defp page_actions(%{key: :project_attempts}, project),
    do: [
      %{
        key: "overview",
        label: "Project overview",
        href: "/projects/#{project.resource_ref}",
        current: false
      }
    ]

  defp page_actions(_page, _project), do: []

  defp pagination(page) do
    if "page" in page.query_fields do
      current = Map.get(page.query, "page", 1)
      path = URI.parse(page.canonical_url).path

      pages =
        Enum.map(1..3, fn number ->
          %{
            key: Integer.to_string(number),
            label: Integer.to_string(number),
            href: page_href(path, page.query, number),
            current: number == current
          }
        end)

      %{
        summary: "Page #{current} of 3; projection results are not loaded.",
        pages: pages,
        previous:
          if(current > 1,
            do: %{label: "Previous", href: page_href(path, page.query, current - 1)}
          ),
        next:
          if(current < 3,
            do: %{label: "Next", href: page_href(path, page.query, current + 1)}
          )
      }
    end
  end

  defp page_href(path, query, number) do
    query = if(number == 1, do: Map.delete(query, "page"), else: Map.put(query, "page", number))
    if map_size(query) == 0, do: path, else: path <> "?" <> URI.encode_query(query)
  end

  defp role_label([]), do: "Named account"

  defp role_label(roles) do
    roles
    |> Enum.map(&(&1 |> Atom.to_string() |> String.replace("_", " ")))
    |> Enum.join(", ")
  end

  defp assurance_label(:baseline), do: "Baseline assurance"
  defp assurance_label(:phishing_resistant), do: "Phishing-resistant assurance"
  defp assurance_label(:action_bound_step_up), do: "Current action-bound step-up"
end
