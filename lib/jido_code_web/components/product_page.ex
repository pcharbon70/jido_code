defmodule JidoCodeWeb.Components.ProductPage do
  @moduledoc "Presentation-only placeholder for authorized Phase 3 route ownership."

  use Phoenix.Component

  alias JidoCodeWeb.Components.Application, as: App
  alias JidoCodeWeb.Layouts

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :page, :map, required: true

  def placeholder(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} frame={:content}>
      <App.shell id="product-shell" main_id="product-main">
        <:masthead>
          <header id="product-route-masthead" class="border-b border-border bg-card px-4 py-4 sm:px-6">
            <a id="product-route-home" href="/factory" class="font-semibold">JidoCode factory</a>
          </header>
        </:masthead>
        <section id={"product-page-#{@page.key}"} data-product-route={@page.key}>
          <h1 id="product-page-title" tabindex="-1" class="text-3xl font-semibold">
            {@page.title}
          </h1>
          <p id="product-page-summary" class="mt-3 max-w-3xl text-muted-foreground">
            {@page.summary}
          </p>
          <section
            id="product-projection-unavailable"
            aria-labelledby="product-projection-unavailable-title"
            class="mt-8 rounded-lg border border-border bg-card p-6"
          >
            <h2 id="product-projection-unavailable-title" class="font-semibold">
              Projection not configured
            </h2>
            <p class="mt-2 text-sm text-muted-foreground">
              This durable page is available, but its bounded read projection is introduced in Phase 4.
            </p>
          </section>
        </section>
      </App.shell>
    </Layouts.app>
    """
  end
end
