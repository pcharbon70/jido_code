defmodule JidoCodeWeb.Components.ProductPage do
  @moduledoc "Presentation-only full-page shell for authorized Phase 3 routes."

  use Phoenix.Component

  alias JidoCodeWeb.Components.Application, as: App
  alias JidoCodeWeb.Components.UI
  alias JidoCodeWeb.Layouts

  attr :flash, :map, required: true
  attr :conn, :any, required: true
  attr :current_scope, :map, default: nil
  attr :page, :map, required: true
  attr :view_model, :map, required: true

  def placeholder(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} frame={:content}>
      <App.shell id="product-shell" main_id="product-main" class="min-w-0">
        <:masthead>
          <App.masthead id="product-masthead" brand={@view_model.brand}>
            <:primary_navigation>
              <App.primary_navigation
                :if={@view_model.primary_navigation != []}
                id="product-primary-navigation"
                items={@view_model.primary_navigation}
              />
            </:primary_navigation>
            <:project_switcher :if={@view_model.projects != []}>
              <App.project_switcher
                id="product-project-switcher"
                form={@view_model.project_form}
                field={@view_model.project_form[:project_ref]}
                action="/projects/switch"
                projects={@view_model.projects}
              />
            </:project_switcher>
            <:utility_navigation>
              <App.utility_navigation
                id="product-utility-navigation"
                items={@view_model.utility_navigation}
              />
            </:utility_navigation>
            <:account_menu>
              <App.account_session_menu
                id="product-account-menu"
                account={Map.take(@view_model.principal, [:display_name, :session_label])}
                actions={@view_model.account_actions}
              />
            </:account_menu>
            <:responsive_navigation>
              <App.responsive_navigation
                id="product-responsive-navigation"
                items={@view_model.responsive_navigation}
              />
            </:responsive_navigation>
          </App.masthead>
        </:masthead>
        <:context>
          <App.context_explanation id="product-context" context={@view_model.context} />
        </:context>

        <App.breadcrumbs id="product-breadcrumbs" items={@view_model.breadcrumbs} />

        <section id={"product-page-#{@page.key}"} data-product-route={@page.key} class="grid gap-6">
          <App.page_header
            id="product-page-header"
            eyebrow={@view_model.context.scope_label}
            title={@page.title}
            summary={@page.summary}
            actions={@view_model.page_actions}
          />

          <App.error_summary
            :if={@view_model.errors != []}
            id="product-error-summary"
            title="Review the filter values"
            errors={@view_model.errors}
          />

          <App.attempt_context
            :if={@view_model.attempt}
            id="product-attempt-context"
            attempt={@view_model.attempt}
          />

          <App.service_banner
            :for={{notice, index} <- Enum.with_index(@view_model.notices, 1)}
            id={"product-notice-#{index}"}
            kind={notice.kind}
            title={notice.title}
            message={notice.message}
          />

          <App.filter_search
            :if={@view_model.filter}
            id="product-filter-search"
            form={@view_model.filter.form}
            query_field={@view_model.filter.query_field}
            action={@conn.request_path}
            filters={@view_model.filter.filters}
            reset={%{label: "Clear filters", href: @conn.request_path}}
          />

          <App.empty_state
            id="product-projection-unavailable"
            state={:unavailable}
            title="Projection not configured"
            message="This durable page is available, but its bounded read projection is introduced in Phase 4."
          />

          <App.pagination
            :if={@view_model.pagination}
            id="product-pagination"
            summary={@view_model.pagination.summary}
            pages={@view_model.pagination.pages}
            previous={@view_model.pagination.previous}
            next={@view_model.pagination.next}
          />

          <.form
            for={@view_model.sign_out_form}
            id="product-sign-out-form"
            action="/sign-out"
            method="delete"
            class="justify-self-start"
          >
            <UI.button id="product-sign-out-submit" type="submit" variant={:outline}>
              Sign out
            </UI.button>
          </.form>
        </section>

        <:footer>
          <App.footer
            id="product-footer"
            product_label="JidoCode factory"
            metadata={@view_model.support.metadata}
            support_links={@view_model.support.links}
          />
        </:footer>
      </App.shell>
    </Layouts.app>
    """
  end
end
