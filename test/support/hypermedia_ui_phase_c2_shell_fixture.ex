defmodule JidoCodeWeb.HypermediaUIPhaseC2ShellFixture do
  @moduledoc false

  use JidoCodeWeb, :html

  alias JidoCodeWeb.Components.Application, as: AppComponents

  attr :hostile_content, :string, required: true

  def render(assigns) do
    project_form = to_form(%{"project" => "project-alpha"}, as: :project_switcher)

    filter_form =
      to_form(%{"query" => "attempt", "state" => "running"}, as: :factory_filter)

    assigns
    |> assign(:project_form, project_form)
    |> assign(:filter_form, filter_form)
    |> render_fixture()
  end

  defp render_fixture(assigns) do
    ~H"""
    <AppComponents.shell id="hui-c2-shell" main_id="hui-c2-main">
      <:masthead>
        <AppComponents.masthead
          id="hui-c2-masthead"
          brand={
            %{
              label: "JidoCode",
              href: "/factory",
              service_label: "Coding factory control plane"
            }
          }
        >
          <:primary_navigation>
            <AppComponents.primary_navigation
              id="hui-c2-primary-navigation"
              items={[
                %{key: "fleet", label: "Fleet", href: "/factory", current: true},
                %{key: "projects", label: "Projects", href: "/factory/projects"},
                %{key: "attempts", label: "Attempts", href: "/factory/attempts"}
              ]}
            />
          </:primary_navigation>

          <:project_switcher>
            <AppComponents.project_switcher
              id="hui-c2-project-switcher"
              form={@project_form}
              field={@project_form[:project]}
              action="/factory/projects/switch"
              projects={[
                %{key: "alpha", value: "project-alpha", label: "Project Alpha"},
                %{key: "beta", value: "project-beta", label: "Project Beta"}
              ]}
            />
          </:project_switcher>

          <:utility_navigation>
            <AppComponents.utility_navigation
              id="hui-c2-utility-navigation"
              items={[
                %{key: "documentation", label: "Documentation", href: "/help"},
                %{key: "support", label: "Support", href: "/support"}
              ]}
            />
          </:utility_navigation>

          <:account_menu>
            <AppComponents.account_session_menu
              id="hui-c2-account-menu"
              account={%{display_name: "Ada Reviewer", session_label: "Named session"}}
              actions={[
                %{key: "profile", label: "Account profile", href: "/account"},
                %{key: "session", label: "Session details", href: "/session"}
              ]}
            />
          </:account_menu>

          <:responsive_navigation>
            <AppComponents.responsive_navigation
              id="hui-c2-responsive-navigation"
              summary="Open factory navigation"
              items={[
                %{key: "fleet", label: "Fleet", href: "/factory", current: true},
                %{key: "projects", label: "Projects", href: "/factory/projects"},
                %{key: "attempts", label: "Attempts", href: "/factory/attempts"},
                %{key: "help", label: "Documentation", href: "/help"}
              ]}
            />
          </:responsive_navigation>
        </AppComponents.masthead>
      </:masthead>

      <:context>
        <div
          id="hui-c2-context-stack"
          class="mx-auto grid max-w-[var(--layout-content)] gap-4 px-4 py-4"
        >
          <AppComponents.breadcrumbs
            id="hui-c2-breadcrumbs"
            items={[
              %{key: "factory", label: "Factory", href: "/factory", current: false},
              %{
                key: "alpha",
                label: "Project Alpha",
                href: "/factory/projects/project-alpha",
                current: false
              },
              %{key: "attempt", label: "Attempt A-1042", current: true}
            ]}
          />

          <AppComponents.context_explanation
            id="hui-c2-current-context"
            context={
              %{
                route_label: "Attempt detail",
                scope_label: "Tenant North / Project Alpha / Graph Factory",
                role_label: "Reviewer",
                assurance_label: "Password plus security key",
                readiness: :limited,
                readiness_label: "Read-only while one dependency is degraded",
                explanation:
                  "These labels describe the server-shaped view; navigation visibility is not a grant."
              }
            }
          />

          <AppComponents.attempt_context
            id="hui-c2-attempt-context"
            attempt={
              %{
                label: "Dependency upgrade",
                reference: "A-1042",
                scope_label: "Project Alpha · main@8d7a2f1",
                state: :running,
                state_label: "Running"
              }
            }
          />
        </div>
      </:context>

      <AppComponents.service_banner
        id="hui-c2-maintenance-banner"
        kind={:maintenance}
        title="Planned maintenance"
        message="Artifact previews may arrive later than usual."
      />

      <AppComponents.service_banner
        id="hui-c2-degraded-banner"
        kind={:degraded}
        title="Evidence service degraded"
        message="Some evidence links are temporarily unavailable."
        support={%{label: "View service status", href: "/status"}}
      />

      <AppComponents.page_header
        id="hui-c2-page-header"
        eyebrow="Attempt A-1042"
        title="Dependency upgrade"
        summary={@hostile_content}
        actions={[
          %{key: "receipt", label: "View receipt", href: "/factory/attempts/a-1042/receipt"},
          %{key: "evidence", label: "View evidence", href: "/factory/attempts/a-1042/evidence"}
        ]}
      />

      <AppComponents.filter_search
        id="hui-c2-filter"
        form={@filter_form}
        query_field={@filter_form[:query]}
        action="/factory/attempts"
        search_label="Search attempts"
        placeholder="Reference or objective"
        filters={[
          %{
            key: "state",
            label: "Attempt state",
            help: "Presentation filter only",
            field: @filter_form[:state],
            options: [
              %{key: "all", value: "all", label: "All states"},
              %{key: "running", value: "running", label: "Running"},
              %{key: "failed", value: "failed", label: "Failed"}
            ]
          }
        ]}
        reset={%{label: "Clear filters", href: "/factory/attempts"}}
      />

      <AppComponents.error_summary
        id="hui-c2-error-summary"
        title="Review two filters"
        errors={[
          %{
            key: "query",
            label: "Search query is too broad",
            target_id: "hui-c2-filter-query"
          },
          %{
            key: "state",
            label: "Choose a supported attempt state",
            target_id: "hui-c2-filter-filter-state"
          }
        ]}
      />

      <section id="hui-c2-results" aria-labelledby="hui-c2-results-title">
        <h2 id="hui-c2-results-title" class="text-lg font-semibold">Attempt results</h2>
        <p>Server-rendered result content.</p>
      </section>

      <AppComponents.pagination
        id="hui-c2-pagination"
        summary="Showing attempts 21–40 of 58"
        previous={%{label: "Previous", href: "/factory/attempts?page=1"}}
        pages={[
          %{key: "1", label: "1", href: "/factory/attempts?page=1", current: false},
          %{key: "2", label: "2", current: true},
          %{key: "3", label: "3", href: "/factory/attempts?page=3", current: false}
        ]}
        next={%{label: "Next", href: "/factory/attempts?page=3"}}
      />

      <AppComponents.empty_state
        id="hui-c2-empty-state"
        state={:no_results}
        title="No attempts match these filters"
        message="Clear one or more filters to broaden the result set."
        action={%{label: "Clear filters", href: "/factory/attempts"}}
      />

      <:footer>
        <AppComponents.footer
          id="hui-c2-footer"
          product_label="JidoCode factory"
          metadata={[
            %{key: "release", label: "Release", value: "2026.09"},
            %{key: "support", label: "Support window", value: "Weekdays 09:00–17:00 UTC"}
          ]}
          support_links={[
            %{key: "help", label: "Help", href: "/help"},
            %{key: "accessibility", label: "Accessibility", href: "/accessibility"}
          ]}
        />
      </:footer>
    </AppComponents.shell>
    """
  end
end
