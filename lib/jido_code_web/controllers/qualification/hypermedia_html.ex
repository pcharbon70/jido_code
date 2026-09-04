defmodule JidoCodeWeb.Qualification.HypermediaHTML do
  @moduledoc "HEEx boundary for the isolated HUI-B3 qualification consumer."

  use JidoCodeWeb, :html

  embed_templates "hypermedia_html/*"

  attr :view, :map, required: true
  attr :previous_url, :string, required: true
  attr :next_url, :string, required: true

  def results(assigns) do
    ~H"""
    <section
      id="hui-b3-results-region"
      aria-labelledby="hui-b3-results-title"
      data-fixture-state={@view.state}
      data-fixture-page={@view.page}
      data-fixture-total={@view.total}
      class="space-y-4"
      tabindex="-1"
    >
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p class="text-xs font-medium uppercase tracking-wider text-muted-foreground">
            Bounded fixture
          </p>
          <h2 id="hui-b3-results-title" class="mt-1 text-lg font-semibold">Results</h2>
        </div>
        <UI.badge id="hui-b3-result-count" variant="secondary">{@view.total} total</UI.badge>
      </div>

      <div
        :if={@view.state == "loading"}
        id="hui-b3-loading-state"
        role="status"
        aria-live="polite"
        class="rounded-xl border border-border p-6"
      >
        <p class="font-medium">Loading the bounded fixture…</p>
        <p class="mt-1 text-sm text-muted-foreground">The native page remains navigable.</p>
      </div>

      <UI.status
        :if={@view.state == "error"}
        id="hui-b3-results-error"
        kind={:failure}
        live={:assertive}
      >
        Fixture results are unavailable. Adjust the filter or use the ready view.
      </UI.status>

      <div
        :if={@view.state == "empty" or (@view.items == [] and @view.state == "ready")}
        id="hui-b3-empty-state"
        class="rounded-xl border border-dashed border-border p-8 text-center"
      >
        <p class="font-medium">No fixture rows match.</p>
        <p class="mt-1 text-sm text-muted-foreground">
          Clear the filter to restore the bounded list.
        </p>
      </div>

      <UI.table
        :if={@view.state == "ready" and @view.items != []}
        id="hui-b3-results-table"
        caption="Qualification fixture results"
        class="rounded-xl border border-border"
      >
        <:head>
          <tr>
            <th class="px-4 py-3">Label</th><th class="px-4 py-3">State</th><th class="px-4 py-3">
              Detail
            </th>
          </tr>
        </:head>
        <tr :for={item <- @view.items} id={item.id}>
          <td class="px-4 py-3 font-medium">{item.label}</td>
          <td class="px-4 py-3">{item.state}</td>
          <td class="px-4 py-3 text-muted-foreground">{item.detail}</td>
        </tr>
      </UI.table>

      <nav
        id="hui-b3-pagination"
        aria-label="Fixture pagination"
        class="flex items-center justify-between text-sm"
      >
        <UI.link id="hui-b3-previous-page" href={@previous_url} aria-disabled={@view.page == 1}>Previous</UI.link>
        <span id="hui-b3-page-position">Page {@view.page} of {@view.page_count}</span>
        <UI.link
          id="hui-b3-next-page"
          href={@next_url}
          aria-disabled={@view.page == @view.page_count}
        >Next</UI.link>
      </nav>
    </section>
    """
  end

  attr :kind, :atom, values: [:neutral, :success, :failure], default: :neutral
  attr :message, :string, required: true

  def enhanced_outcome(assigns) do
    ~H"""
    <UI.status
      id="hui-b3-enhanced-outcome"
      kind={@kind}
      live={if(@kind == :failure, do: :assertive, else: :polite)}
    >
      {@message}
    </UI.status>
    """
  end

  attr :connection, :string, required: true
  attr :freshness, :string, required: true
  attr :message, :string, required: true

  def stream_status(assigns) do
    ~H"""
    <UI.status
      id="hui-b3-stream-state"
      kind={if(@connection == "connected", do: :success, else: :neutral)}
      live={:polite}
      data-connection-state={@connection}
      data-fixture-freshness={@freshness}
    >
      <span id="hui-b3-connection-value">Connection: {@connection}.</span>
      <span id="hui-b3-freshness-value">Fixture freshness: {@freshness}.</span>
      <span id="hui-b3-stream-message">{@message}</span>
    </UI.status>
    """
  end
end
