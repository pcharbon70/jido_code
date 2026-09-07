defmodule JidoCodeWeb.Components.ProductPage do
  @moduledoc "Presentation-only full-page shell for authorized Phase 3 routes."

  use Phoenix.Component

  alias JidoCodeWeb.Components.Application, as: App
  alias JidoCodeWeb.Components.UI
  alias JidoCodeWeb.Layouts
  alias JidoCodeWeb.ReadEnhancement

  attr :flash, :map, required: true
  attr :conn, :any, required: true
  attr :current_scope, :map, default: nil
  attr :page, :map, required: true
  attr :view_model, :map, required: true
  slot :inner_block

  def placeholder(assigns) do
    ~H"""
    <%= if @conn.assigns[:enhanced_read] do %>
      <.read_content conn={@conn} page={@page} view_model={@view_model}>
        {render_slot(@inner_block)}
      </.read_content>
    <% else %>
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

          <section
            id={"product-page-#{@page.key}"}
            data-product-route={@page.key}
            class="grid gap-6"
            {ReadEnhancement.attributes(@page, @conn)}
          >
            <App.page_header
              id="product-page-header"
              eyebrow={@view_model.context.scope_label}
              title={@page.title}
              summary={@page.summary}
              actions={@view_model.page_actions}
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

            <UI.link
              :if={ReadEnhancement.supported?(@page.key)}
              id="product-read-refresh"
              href={@page.canonical_url}
              class="justify-self-start rounded text-sm font-medium underline underline-offset-4 transition-colors hover:text-primary focus-visible:outline-2 focus-visible:outline-offset-4"
            >
              Refresh this view
            </UI.link>

            <div
              :if={ReadEnhancement.supported?(@page.key)}
              id="product-stream-controls"
              class="flex flex-wrap items-center gap-x-4 gap-y-2"
              {ReadEnhancement.stream_attributes(@page)}
            >
              <UI.link
                id="product-stream-connect"
                href={@page.canonical_url}
                aria-describedby="product-stream-status"
                class="rounded text-sm font-medium underline underline-offset-4 transition-colors hover:text-primary focus-visible:outline-2 focus-visible:outline-offset-4"
              >
                Refresh and connect
              </UI.link>
              <UI.button
                id="product-stream-pause"
                type="button"
                hidden
                aria-pressed="false"
                aria-describedby="product-stream-status"
              >
                Pause visual updates
              </UI.button>
              <p
                id="product-stream-status"
                role="status"
                aria-live="polite"
                class="text-xs text-muted-foreground"
              >
                Not connected. Connection state is separate from data freshness.
              </p>
            </div>

            <.read_content conn={@conn} page={@page} view_model={@view_model}>
              <%= if @inner_block == [] do %>
                <App.empty_state
                  id="product-projection-unavailable"
                  state={:unavailable}
                  title="Projection not configured"
                  message="This durable page is available, but its bounded read projection is introduced in Phase 4."
                />
              <% else %>
                {render_slot(@inner_block)}
              <% end %>
            </.read_content>

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
    <% end %>
    """
  end

  attr :conn, :any, required: true
  attr :page, :map, required: true
  attr :view_model, :map, required: true
  slot :inner_block, required: true

  def read_content(assigns) do
    ~H"""
    <div
      id="product-owned-content"
      class="grid gap-6"
      data-read-surface={@page.key}
      data-read-url={ReadEnhancement.native_url(@page)}
      data-read-receipt={@conn.assigns[:read_receipt]}
      data-stream-cursor={@conn.assigns[:stream_cursor]}
    >
      <p id="product-read-status" role="status" aria-live="polite" aria-atomic="true" class="sr-only">
        {if @conn.assigns[:enhanced_read],
          do: "View refreshed. Review the current projection status.",
          else: "Current view."}
      </p>
      <div id="product-read-errors">
        <App.error_summary
          :if={@view_model.errors != []}
          id="product-error-summary"
          title="Review the filter values"
          errors={@view_model.errors}
        />
      </div>
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
      {render_slot(@inner_block)}
      <App.pagination
        :if={@view_model.pagination}
        id="product-pagination"
        summary={@view_model.pagination.summary}
        pages={@view_model.pagination.pages}
        previous={@view_model.pagination.previous}
        next={@view_model.pagination.next}
      />
    </div>
    """
  end
end
