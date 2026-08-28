defmodule JidoCodeWeb.HomeLive do
  use JidoCodeWeb, :live_view

  alias JidoCode.Knowledge.Error
  alias JidoCode.Product
  alias JidoCode.Product.CommandGateway
  alias JidoCode.Product.CommandOutcome
  alias JidoCode.Product.GraphProjectionProvider
  alias JidoCode.Product.Projection
  alias JidoCode.Product.RepositoryWikiProjection
  alias JidoCode.Product.RepositoryWikiProjectionProvider
  alias JidoCode.Product.RepositoryWikiSurfaceContract
  alias JidoCode.Product.SurfaceContract

  @impl true
  def mount(_params, _session, socket) do
    identity = socket.assigns.product_identity

    if connected?(socket), do: Product.subscribe_changes(identity.factory_scope_iri)

    {:ok,
     socket
     |> assign(:page_title, "Repository factory")
     |> assign(:identity, identity)
     |> assign(:surface, SurfaceContract.default())
     |> assign(:selected_repository, nil)
     |> assign(:selected_repository_ref, nil)
     |> assign(:repository_refs, %{})
     |> assign(:repository_index, %{})
     |> assign(:projection, Projection.unavailable())
     |> assign(:repository_count, 0)
     |> assign(:repository_empty?, true)
     |> assign(:work_count, 0)
     |> assign(:attempt_count, 0)
     |> assign(:knowledge_count, 0)
     |> assign(:outcome_count, 0)
     |> assign(:filter_form, to_form(%{"query" => ""}, as: :filter))
     |> assign(:enrollment_form, enrollment_form())
     |> assign(:enrollment_preview, nil)
     |> assign(:command_receipt, nil)
     |> assign(:wiki_projection, RepositoryWikiProjection.unavailable(:unselected))
     |> assign(:wiki_view, RepositoryWikiSurfaceContract.fetch(nil))
     |> assign(:wiki_page_slug, nil)
     |> assign(:wiki_search_query, "")
     |> assign(:wiki_search_form, to_form(%{"query" => ""}, as: :wiki_search))
     |> assign(:wiki_settings_form, wiki_settings_form())
     |> assign(:wiki_command_receipt, nil)
     |> stream_configure(:attempts, dom_id: &"attempt-#{&1["id"]}")
     |> stream_configure(:knowledge, dom_id: &"knowledge-#{&1["id"]}")
     |> stream_configure(:wiki_navigation, dom_id: &"wiki-page-#{&1.slug}")
     |> stream_configure(:wiki_search_results, dom_id: &"wiki-search-result-#{&1.slug}")
     |> stream_configure(:wiki_history, dom_id: &"wiki-history-#{&1["id"]}")
     |> stream_configure(:wiki_gaps, dom_id: &"wiki-gap-#{&1["id"]}")
     |> stream_configure(:wiki_sources, dom_id: &"wiki-source-#{&1["id"]}")
     |> stream_configure(:wiki_backlinks, dom_id: &"wiki-backlink-#{&1["id"]}")
     |> stream_configure(:wiki_currency_totals, dom_id: &"wiki-currency-#{&1.id}")
     |> stream_configure(:wiki_usage_breakdowns, dom_id: &"wiki-usage-breakdown-#{&1.id}")
     |> stream_configure(:wiki_reservations, dom_id: &"wiki-reservation-#{&1.id}")
     |> stream_configure(:wiki_fleet_repositories, dom_id: &"wiki-fleet-repository-#{&1.id}")
     |> stream_configure(:wiki_alerts, dom_id: &"wiki-alert-#{&1.id}")
     |> stream(:repositories, [])
     |> stream(:work_items, [])
     |> stream(:attempts, [])
     |> stream(:knowledge, [])
     |> stream(:wiki_navigation, [])
     |> stream(:wiki_search_results, [])
     |> stream(:wiki_history, [])
     |> stream(:wiki_gaps, [])
     |> stream(:wiki_sources, [])
     |> stream(:wiki_backlinks, [])
     |> stream(:wiki_currency_totals, [])
     |> stream(:wiki_usage_breakdowns, [])
     |> stream(:wiki_reservations, [])
     |> stream(:wiki_fleet_repositories, [])
     |> stream(:wiki_alerts, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    surface = SurfaceContract.fetch(params["surface"])
    selected_repository = decode_repository(params["repository"])
    wiki_view = RepositoryWikiSurfaceContract.fetch(params["wiki_view"])
    wiki_page_slug = RepositoryWikiSurfaceContract.page_slug(params["wiki_page"], wiki_view)
    wiki_search_query = RepositoryWikiSurfaceContract.search_query(params["wiki_query"])

    {:noreply,
     socket
     |> assign(:surface, surface)
     |> assign(:selected_repository, selected_repository)
     |> assign(:selected_repository_ref, params["repository"])
     |> assign(:wiki_view, wiki_view)
     |> assign(:wiki_page_slug, wiki_page_slug)
     |> assign(:wiki_search_query, wiki_search_query)
     |> assign(:wiki_search_form, to_form(%{"query" => wiki_search_query}, as: :wiki_search))
     |> load_projection()}
  end

  @impl true
  def handle_event("refresh", _params, socket), do: {:noreply, load_projection(socket)}

  def handle_event("select-surface", %{"surface" => id}, socket) do
    surface = SurfaceContract.fetch(id)

    {:noreply,
     push_patch(socket, to: workbench_path(surface.id, socket.assigns.selected_repository_ref))}
  end

  def handle_event("select-wiki-view", %{"view" => id}, socket) do
    view = RepositoryWikiSurfaceContract.fetch(id)

    {:noreply,
     push_patch(socket,
       to:
         wiki_path(socket, %{
           wiki_view: view.id,
           wiki_page: view.page_slug,
           wiki_query: nil
         })
     )}
  end

  def handle_event("open-wiki-settings", _params, socket) do
    {:noreply,
     push_patch(socket,
       to: wiki_path(socket, %{wiki_view: "settings", wiki_page: nil, wiki_query: nil})
     )}
  end

  def handle_event("open-wiki-page", %{"slug" => slug}, socket) do
    view = socket.assigns.wiki_view
    admitted = RepositoryWikiSurfaceContract.page_slug(slug, view)

    {:noreply,
     push_patch(socket,
       to: wiki_path(socket, %{wiki_view: view.id, wiki_page: admitted})
     )}
  end

  def handle_event("search-wiki", %{"wiki_search" => %{"query" => query}}, socket) do
    admitted = RepositoryWikiSurfaceContract.search_query(query)

    {:noreply,
     push_patch(socket,
       to: wiki_path(socket, %{wiki_view: "search", wiki_page: nil, wiki_query: admitted})
     )}
  end

  def handle_event("validate-wiki-settings", %{"wiki_settings" => params}, socket) do
    {:noreply, assign(socket, :wiki_settings_form, to_form(params, as: :wiki_settings))}
  end

  def handle_event("save-wiki-settings", %{"wiki_settings" => params}, socket) do
    gateway = Application.get_env(:jido_code, :product_command_gateway, CommandGateway)

    case socket.assigns.selected_repository do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a repository before changing wiki policy.")}

      repository ->
        case gateway.configure_repository_wiki(
               socket.assigns.authority,
               socket.assigns.identity,
               repository,
               params
             ) do
          {:ok, %CommandOutcome{outcome: outcome} = receipt}
          when outcome in [:committed, :already_committed] ->
            {:noreply,
             socket
             |> assign(:wiki_command_receipt, receipt_view(receipt))
             |> put_flash(:info, "Repository wiki policy committed.")
             |> load_projection()}

          {:ok, %CommandOutcome{} = receipt} ->
            {:noreply,
             socket
             |> assign(:wiki_settings_form, to_form(params, as: :wiki_settings))
             |> assign(:wiki_command_receipt, receipt_view(receipt))
             |> put_flash(:error, wiki_command_outcome_message(receipt))}

          {:error, %Error{} = error} ->
            {:noreply,
             socket
             |> assign(:wiki_settings_form, to_form(params, as: :wiki_settings))
             |> put_flash(:error, wiki_command_error_message(error))}
        end
    end
  end

  def handle_event("regenerate-wiki", _params, socket) do
    gateway = Application.get_env(:jido_code, :product_command_gateway, CommandGateway)

    case socket.assigns.selected_repository do
      nil ->
        {:noreply, put_flash(socket, :error, "Select a repository before regenerating its wiki.")}

      repository ->
        case gateway.regenerate_repository_wiki(
               socket.assigns.authority,
               socket.assigns.identity,
               repository
             ) do
          {:ok, %CommandOutcome{outcome: outcome} = receipt}
          when outcome in [:committed, :already_committed] ->
            {:noreply,
             socket
             |> assign(:wiki_command_receipt, receipt_view(receipt))
             |> put_flash(:info, "Deterministic wiki regeneration requested.")
             |> load_projection()}

          {:ok, %CommandOutcome{} = receipt} ->
            {:noreply, put_flash(socket, :error, wiki_command_outcome_message(receipt))}

          {:error, %Error{} = error} ->
            {:noreply, put_flash(socket, :error, wiki_command_error_message(error))}
        end
    end
  end

  def handle_event("select-repository", %{"repository" => ref}, socket) do
    case Map.fetch(socket.assigns.repository_refs, ref) do
      {:ok, _repository} ->
        {:noreply, push_patch(socket, to: workbench_path("repositories", ref))}

      :error ->
        {:noreply, put_flash(socket, :error, "That repository is not available in this scope.")}
    end
  end

  def handle_event("filter", %{"filter" => %{"query" => query}}, socket) do
    normalized = query |> to_string() |> String.trim() |> String.slice(0, 80)

    repositories =
      socket.assigns.repository_index
      |> Map.values()
      |> Enum.filter(fn repository ->
        normalized == "" or
          String.contains?(String.downcase(repository.label), String.downcase(normalized))
      end)

    {:noreply,
     socket
     |> assign(:filter_form, to_form(%{"query" => normalized}, as: :filter))
     |> assign(:repository_empty?, repositories == [])
     |> stream(:repositories, repositories, reset: true)}
  end

  def handle_event("validate-enrollment", %{"enrollment" => params}, socket) do
    {:noreply,
     socket
     |> assign(:enrollment_form, to_form(params, as: :enrollment))
     |> assign(:enrollment_preview, enrollment_preview(params))}
  end

  def handle_event("save-enrollment", %{"enrollment" => params}, socket) do
    gateway = Application.get_env(:jido_code, :product_command_gateway, CommandGateway)

    case gateway.enroll_repository(socket.assigns.authority, socket.assigns.identity, params) do
      {:ok, %CommandOutcome{outcome: outcome} = receipt}
      when outcome in [:committed, :already_committed] ->
        {:noreply,
         socket
         |> assign(:command_receipt, receipt_view(receipt))
         |> assign(:enrollment_form, enrollment_form())
         |> assign(:enrollment_preview, nil)
         |> put_flash(
           :info,
           "Repository enrollment committed at graph revision #{receipt.dataset_revision}."
         )
         |> load_projection()}

      {:ok, %CommandOutcome{} = receipt} ->
        {:noreply,
         socket
         |> assign(:enrollment_form, to_form(params, as: :enrollment))
         |> assign(:command_receipt, receipt_view(receipt))
         |> put_flash(:error, command_outcome_message(receipt))}

      {:error, %Error{} = error} ->
        {:noreply,
         socket
         |> assign(:enrollment_form, to_form(params, as: :enrollment))
         |> assign(:command_receipt, %{outcome: error.kind, retry: error.retry})
         |> put_flash(:error, command_error_message(error))}
    end
  end

  def handle_event("product/semantic-event", %{"action" => "refresh"}, socket),
    do: handle_event("refresh", %{}, socket)

  def handle_event(
        "product/semantic-event",
        %{"action" => "select-surface", "surface" => surface},
        socket
      ),
      do: handle_event("select-surface", %{"surface" => surface}, socket)

  def handle_event("product/semantic-event", _payload, socket) do
    {:noreply, put_flash(socket, :error, "That interaction is not available.")}
  end

  @impl true
  def handle_info({:jido_code_change, _event}, socket), do: {:noreply, load_projection(socket)}
  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div
        id="factory-workbench"
        class="grid min-h-full bg-frame-canvas text-foreground lg:grid-cols-[15rem_minmax(0,1fr)]"
      >
        <aside
          id="factory-navigation"
          aria-label="Factory navigation"
          class="border-b border-frame-border bg-frame-chrome lg:border-b-0 lg:border-r"
        >
          <div class="flex gap-1 overflow-x-auto p-2 lg:block lg:space-y-1 lg:p-3">
            <button
              :for={
                surface <- SurfaceContract.visible(@selected_repository, @wiki_projection.visible?)
              }
              id={"factory-nav-#{surface.id}"}
              type="button"
              phx-click="select-surface"
              phx-value-surface={surface.id}
              aria-current={if(@surface.id == surface.id, do: "page", else: "false")}
              class={[
                "flex min-h-11 shrink-0 items-center gap-3 rounded-md px-3 text-left text-sm outline-none transition-colors focus-visible:ring-2 focus-visible:ring-frame-focus lg:w-full",
                @surface.id == surface.id && "bg-navigation-current font-semibold text-frame-text",
                @surface.id != surface.id && "text-navigation-default hover:bg-navigation-hover"
              ]}
            >
              <.icon name={surface.icon} class="size-4 shrink-0" />
              <span>{surface.label}</span>
            </button>
          </div>

          <div class="hidden border-t border-frame-border p-4 lg:block">
            <p class="text-xs font-medium text-frame-text-muted">Graph revision</p>
            <p id="factory-sidebar-revision" class="mt-1 font-mono text-sm text-frame-text">
              {@projection.dataset_revision || "unavailable"}
            </p>
          </div>
        </aside>

        <div class="min-w-0">
          <header
            id="factory-surface-header"
            class="flex min-h-16 flex-col gap-3 border-b border-frame-border bg-background px-4 py-3 sm:flex-row sm:items-center sm:justify-between sm:px-6"
          >
            <div class="min-w-0">
              <div class="flex items-center gap-2">
                <h1 id="factory-surface-title" class="truncate text-lg font-semibold">
                  {@surface.label}
                </h1>
                <.projection_badge state={@projection.state} />
              </div>
              <p class="mt-1 truncate text-xs text-muted-foreground">{@surface.description}</p>
            </div>

            <button
              id="factory-refresh"
              type="button"
              phx-click="refresh"
              aria-label="Refresh graph projections"
              title="Refresh graph projections"
              class="inline-flex size-9 shrink-0 items-center justify-center rounded-md border border-border bg-background text-muted-foreground outline-none transition-colors hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring"
            >
              <.icon name="hero-arrow-path" class="size-4 phx-click-loading:animate-spin" />
            </button>
          </header>

          <main
            id="factory-surface-content"
            class="mx-auto grid w-full max-w-[96rem] gap-5 p-4 sm:p-6"
          >
            <.projection_notice projection={@projection} />

            <%= case @surface.id do %>
              <% "factory" -> %>
                <.factory_overview
                  projection={@projection}
                  repository_count={@repository_count}
                  work_count={@work_count}
                  attempt_count={@attempt_count}
                  knowledge_count={@knowledge_count}
                  outcome_count={@outcome_count}
                  selected_repository={@selected_repository}
                  socket={@socket}
                />
              <% "repositories" -> %>
                <.repositories_surface
                  streams={@streams}
                  empty?={@repository_empty?}
                  count={@repository_count}
                  selected={@selected_repository}
                  refs={@repository_refs}
                  form={@filter_form}
                  enrollment_form={@enrollment_form}
                  enrollment_preview={@enrollment_preview}
                  command_receipt={@command_receipt}
                />
              <% "work" -> %>
                <.work_surface streams={@streams} count={@work_count} selected={@selected_repository} />
              <% "execution" -> %>
                <.execution_surface
                  streams={@streams}
                  count={@attempt_count}
                  selected={@selected_repository}
                />
              <% "outcomes" -> %>
                <.outcomes_surface projection={@projection} selected={@selected_repository} />
              <% "knowledge" -> %>
                <.knowledge_surface
                  streams={@streams}
                  count={@knowledge_count}
                  selected={@selected_repository}
                />
              <% "wiki" -> %>
                <.repository_wiki_surface
                  projection={@wiki_projection}
                  view={@wiki_view}
                  selected_repository={@selected_repository}
                  streams={@streams}
                  search_form={@wiki_search_form}
                  settings_form={@wiki_settings_form}
                  command_receipt={@wiki_command_receipt}
                />
            <% end %>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :projection, :any, required: true
  attr :repository_count, :integer, required: true
  attr :work_count, :integer, required: true
  attr :attempt_count, :integer, required: true
  attr :knowledge_count, :integer, required: true
  attr :outcome_count, :integer, required: true
  attr :selected_repository, :string, default: nil
  attr :socket, :any, required: true

  defp factory_overview(assigns) do
    ~H"""
    <section id="factory-posture" aria-labelledby="factory-posture-title" class="grid gap-4">
      <div class="flex items-end justify-between gap-4">
        <div>
          <p class="text-xs font-medium uppercase text-muted-foreground">Control plane</p>
          <h2 id="factory-posture-title" class="mt-1 text-xl font-semibold">Factory posture</h2>
        </div>
        <p class="font-mono text-xs text-muted-foreground">freshness: {@projection.freshness}</p>
      </div>

      <div
        id="factory-metrics"
        class="grid gap-px overflow-hidden rounded-lg border border-border bg-border sm:grid-cols-2 xl:grid-cols-4"
      >
        <.metric
          id="repositories"
          label="Repositories"
          value={@repository_count}
          detail="Authorized cohort"
        />
        <.metric id="work" label="Active work" value={@work_count} detail="Current endpoints" />
        <.metric
          id="attempts"
          label="Attempts"
          value={@attempt_count}
          detail="Graph-visible activity"
        />
        <.metric
          id="revision"
          label="Dataset revision"
          value={@projection.dataset_revision || "-"}
          detail="Authoritative commit"
        />
      </div>

      <section
        id="factory-flow-island-region"
        aria-label="Factory workflow overview"
        class="min-h-80 border-y border-border bg-background py-5"
      >
        <.vue_surface
          id="factory-flow-island"
          component="product/FactoryFlowIsland"
          events={semantic_event("product/semantic-event")}
          props={%{workflow: workflow_props(assigns)}}
          socket={@socket}
          ssr={true}
        />
      </section>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :detail, :string, required: true

  defp metric(assigns) do
    ~H"""
    <div id={"factory-metric-#{@id}"} class="min-w-0 bg-card p-4">
      <p class="text-xs font-medium text-muted-foreground">{@label}</p>
      <p class="mt-2 truncate text-2xl font-semibold">{@value}</p>
      <p class="mt-1 text-xs text-muted-foreground">{@detail}</p>
    </div>
    """
  end

  attr :streams, :map, required: true
  attr :empty?, :boolean, required: true
  attr :count, :integer, required: true
  attr :selected, :string, default: nil
  attr :refs, :map, required: true
  attr :form, :map, required: true
  attr :enrollment_form, :map, required: true
  attr :enrollment_preview, :map, default: nil
  attr :command_receipt, :map, default: nil

  defp repositories_surface(assigns) do
    ~H"""
    <section id="repository-catalog" aria-labelledby="repository-catalog-title" class="grid gap-4">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p class="text-xs text-muted-foreground">{@count} authorized repositories</p>
          <h2 id="repository-catalog-title" class="mt-1 text-xl font-semibold">Repository catalog</h2>
        </div>
        <.form for={@form} id="repository-filter-form" phx-change="filter" class="w-full sm:max-w-xs">
          <.input
            field={@form[:query]}
            type="search"
            placeholder="Filter repositories"
            autocomplete="off"
          />
        </.form>
      </div>

      <div id="repositories" phx-update="stream" class="grid gap-2">
        <div
          id="repositories-empty"
          class="hidden only:grid min-h-44 place-items-center border-y border-border text-center"
        >
          <div>
            <.icon name="hero-code-bracket-square" class="mx-auto size-6 text-muted-foreground" />
            <p class="mt-2 text-sm font-medium">No repositories in this projection</p>
            <p class="mt-1 text-xs text-muted-foreground">
              Enrollment will appear after an accepted graph command.
            </p>
          </div>
        </div>
        <button
          :for={{id, repository} <- @streams.repositories}
          id={id}
          type="button"
          phx-click="select-repository"
          phx-value-repository={ref_for(@refs, repository.iri)}
          aria-current={if(@selected == repository.iri, do: "true", else: "false")}
          class={[
            "grid min-h-16 grid-cols-[minmax(0,1fr)_auto] items-center gap-4 rounded-md border px-4 text-left outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring",
            @selected == repository.iri && "border-primary bg-accent",
            @selected != repository.iri && "border-border bg-card hover:bg-muted"
          ]}
        >
          <span class="min-w-0">
            <span class="block truncate text-sm font-semibold">{repository.label}</span>
            <span class="mt-1 block truncate font-mono text-xs text-muted-foreground">
              {repository.iri}
            </span>
          </span>
          <span class="flex items-center gap-2 text-xs text-muted-foreground">
            {repository.state}
            <.icon name="hero-chevron-right" class="size-4" />
          </span>
        </button>
      </div>

      <div
        :if={@selected}
        id="selected-repository-wiki-policy"
        class="flex flex-col gap-3 rounded-lg border border-border bg-muted/30 p-4 sm:flex-row sm:items-center sm:justify-between"
      >
        <div>
          <p class="text-sm font-semibold">Repository wiki policy</p>
          <p class="mt-1 text-xs text-muted-foreground">
            Opt out, choose deterministic maintenance, or review retained-read posture.
          </p>
        </div>
        <button
          id="open-wiki-settings"
          type="button"
          phx-click="open-wiki-settings"
          class="inline-flex min-h-10 items-center justify-center rounded-lg border border-border bg-background px-3 text-sm font-semibold transition-colors hover:bg-muted"
        >
          <.icon name="hero-cog-6-tooth" class="mr-2 size-4" /> Configure wiki
        </button>
      </div>

      <section
        id="repository-enrollment"
        aria-labelledby="repository-enrollment-title"
        class="grid gap-4 border-t border-border pt-5"
      >
        <div>
          <p class="text-xs font-medium uppercase text-muted-foreground">Semantic command</p>
          <h3 id="repository-enrollment-title" class="mt-1 text-base font-semibold">
            Enroll repository
          </h3>
        </div>

        <.form
          for={@enrollment_form}
          id="repository-enrollment-form"
          phx-change="validate-enrollment"
          phx-submit="save-enrollment"
          class="grid gap-3 md:grid-cols-2 xl:grid-cols-3"
        >
          <.input
            field={@enrollment_form[:conceptual_key]}
            type="text"
            label="Conceptual key"
            autocomplete="off"
          />
          <.input
            field={@enrollment_form[:provider]}
            type="url"
            label="Provider"
            autocomplete="url"
          />
          <.input
            field={@enrollment_form[:external_id]}
            type="text"
            label="Provider repository ID"
            autocomplete="off"
          />
          <.input
            field={@enrollment_form[:owner]}
            type="text"
            label="Owner"
            autocomplete="off"
          />
          <.input
            field={@enrollment_form[:name]}
            type="text"
            label="Repository name"
            autocomplete="off"
          />
          <.input
            field={@enrollment_form[:reason]}
            type="text"
            label="Reason"
            autocomplete="off"
          />
          <input
            type="hidden"
            name={@enrollment_form[:idempotency_key].name}
            value={@enrollment_form[:idempotency_key].value}
          />
          <div class="flex flex-col justify-end gap-3 md:col-span-2 xl:col-span-3 sm:flex-row sm:items-center sm:justify-between">
            <.input
              field={@enrollment_form[:confirmed]}
              type="checkbox"
              label="Confirm policy-governed enrollment"
            />
            <UI.button
              id="repository-enrollment-submit"
              type="submit"
              disabled={is_nil(@enrollment_preview)}
            >
              <.icon name="hero-plus" class="size-4" /> Enroll
            </UI.button>
          </div>
        </.form>

        <div
          :if={@enrollment_preview}
          id="repository-enrollment-preview"
          class="border-l-2 border-primary bg-muted px-4 py-3 text-xs"
        >
          <p class="font-semibold">Command preview</p>
          <p class="mt-1 text-muted-foreground">{@enrollment_preview.summary}</p>
        </div>

        <div
          :if={@command_receipt}
          id="product-command-receipt"
          role="status"
          class="flex items-center justify-between gap-4 border-y border-border py-3 text-xs"
        >
          <span>Last command: <strong>{@command_receipt.outcome}</strong></span>
          <span class="font-mono text-muted-foreground">retry: {@command_receipt.retry}</span>
        </div>
      </section>
    </section>
    """
  end

  attr :streams, :map, required: true
  attr :count, :integer, required: true
  attr :selected, :string, default: nil

  defp work_surface(assigns) do
    ~H"""
    <section id="work-queue" aria-labelledby="work-queue-title" class="grid gap-4">
      <.selection_header id="work-queue-title" title="Work queue" count={@count} selected={@selected} />
      <div id="work-items" phx-update="stream" class="grid gap-3 lg:grid-cols-2">
        <.stream_empty
          id="work-items-empty"
          icon="hero-queue-list"
          message="Select a repository to inspect graph-derived work."
        />
        <article
          :for={{id, item} <- @streams.work_items}
          id={id}
          class="rounded-md border border-border bg-card p-4"
        >
          <div class="flex items-center justify-between gap-3">
            <p class="text-xs font-semibold uppercase text-muted-foreground">{item.kind}</p>
            <UI.badge variant="outline">revision {item.revision || "-"}</UI.badge>
          </div>
          <p class="mt-3 break-all font-mono text-xs">{item.resource || item.id}</p>
        </article>
      </div>
    </section>
    """
  end

  attr :streams, :map, required: true
  attr :count, :integer, required: true
  attr :selected, :string, default: nil

  defp execution_surface(assigns) do
    ~H"""
    <section id="execution-activity" aria-labelledby="execution-title" class="grid gap-4">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <.selection_header
          id="execution-title"
          title="Execution activity"
          count={@count}
          selected={@selected}
        />
        <.link
          id="open-coding-agent-workbench"
          navigate={~p"/coding-agents"}
          class="inline-flex h-10 items-center justify-center gap-2 rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground transition-all hover:-translate-y-0.5 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <.icon name="hero-sparkles" class="size-4" /> New coding task
        </.link>
      </div>
      <div id="attempts" phx-update="stream" class="grid gap-2">
        <.stream_empty
          id="attempts-empty"
          icon="hero-command-line"
          message="No graph-visible attempts for the current selection."
        />
        <article
          :for={{id, attempt} <- @streams.attempts}
          id={id}
          class="grid gap-3 rounded-md border border-border bg-card p-4 sm:grid-cols-[1fr_auto]"
        >
          <div class="min-w-0">
            <p class="truncate text-sm font-semibold">{attempt["attempt"] || "Execution attempt"}</p>
            <p class="mt-1 truncate font-mono text-xs text-muted-foreground">{attempt["task"]}</p>
          </div>
          <UI.badge variant="outline">{attempt["state"] || "unknown"}</UI.badge>
        </article>
      </div>
    </section>
    """
  end

  attr :projection, :any, required: true
  attr :selected, :string, default: nil

  defp outcomes_surface(assigns) do
    ~H"""
    <section id="accepted-outcomes" aria-labelledby="outcomes-title" class="grid gap-4">
      <.selection_header
        id="outcomes-title"
        title="Evidence and decisions"
        count={0}
        selected={@selected}
      />
      <div class="grid min-h-52 place-items-center border-y border-border text-center">
        <div class="max-w-md">
          <.icon name="hero-check-badge" class="mx-auto size-7 text-muted-foreground" />
          <p class="mt-3 text-sm font-medium">Choose a goal from the work projection</p>
          <p class="mt-1 text-xs leading-5 text-muted-foreground">
            Evidence, decisions, waivers, follow-up, and satisfaction are loaded only for an exact authorized goal.
          </p>
        </div>
      </div>
    </section>
    """
  end

  attr :streams, :map, required: true
  attr :count, :integer, required: true
  attr :selected, :string, default: nil

  defp knowledge_surface(assigns) do
    ~H"""
    <section id="accepted-knowledge" aria-labelledby="knowledge-title" class="grid gap-4">
      <.selection_header
        id="knowledge-title"
        title="Accepted knowledge"
        count={@count}
        selected={@selected}
      />
      <div id="knowledge-items" phx-update="stream" class="grid gap-3 lg:grid-cols-2">
        <.stream_empty
          id="knowledge-items-empty"
          icon="hero-light-bulb"
          message="No accepted knowledge for the current scope."
        />
        <article
          :for={{id, assertion} <- @streams.knowledge}
          id={id}
          class="rounded-md border border-border bg-card p-4"
        >
          <p class="break-all font-mono text-xs">{assertion["assertion"] || assertion["id"]}</p>
          <p class="mt-2 text-xs text-muted-foreground">
            {assertion["state"] || "accepted assertion"}
          </p>
        </article>
      </div>
    </section>
    """
  end

  attr :projection, :any, required: true
  attr :view, :map, required: true
  attr :selected_repository, :string, default: nil
  attr :streams, :map, required: true
  attr :search_form, :map, required: true
  attr :settings_form, :map, required: true
  attr :command_receipt, :map, default: nil

  defp repository_wiki_surface(assigns) do
    ~H"""
    <section id="repository-wiki" aria-labelledby="repository-wiki-title" class="grid gap-5">
      <div class="flex flex-col gap-3 border-b border-border pb-5 sm:flex-row sm:items-end sm:justify-between">
        <div class="min-w-0">
          <p class="truncate font-mono text-xs text-muted-foreground">
            {@selected_repository || "No repository selected"}
          </p>
          <div class="mt-1 flex items-center gap-2">
            <h2 id="repository-wiki-title" class="text-xl font-semibold">Repository wiki</h2>
            <span
              id="wiki-state"
              class={[
                "inline-flex rounded-full px-2 py-0.5 text-[0.6875rem] font-semibold uppercase tracking-wide",
                @projection.state == :current && "bg-emerald-500/15 text-emerald-700",
                @projection.state in [:stale, :incomplete, :empty, :rebuilding] &&
                  "bg-amber-500/15 text-amber-700",
                @projection.state not in [:current, :stale, :incomplete, :empty, :rebuilding] &&
                  "bg-muted text-muted-foreground"
              ]}
            >
              {@projection.state}
            </span>
          </div>
        </div>
        <p class="max-w-xl text-xs leading-5 text-muted-foreground">
          Deterministic-only generation. This edition records zero model tokens and no model cost.
        </p>
      </div>

      <%= if is_nil(@selected_repository) do %>
        <div
          id="wiki-unselected"
          class="grid min-h-64 place-items-center rounded-xl border border-dashed border-border bg-card/40 text-center"
        >
          <div class="max-w-md px-6">
            <.icon name="hero-book-open" class="mx-auto size-8 text-muted-foreground" />
            <p class="mt-3 font-semibold">Select a repository</p>
            <p class="mt-1 text-sm leading-6 text-muted-foreground">
              Wiki visibility, editions, and settings are always evaluated inside one repository scope.
            </p>
          </div>
        </div>
      <% else %>
        <%= if not @projection.visible? and @view.id != "settings" do %>
          <div
            id={"wiki-state-#{@projection.state}"}
            role="status"
            class="grid min-h-64 place-items-center rounded-xl border border-dashed border-border bg-card/40 text-center"
          >
            <div class="max-w-lg px-6">
              <.icon name="hero-shield-exclamation" class="mx-auto size-8 text-muted-foreground" />
              <p class="mt-3 font-semibold">{wiki_state_title(@projection.state)}</p>
              <p class="mt-1 text-sm leading-6 text-muted-foreground">
                {wiki_state_detail(@projection.state)} No cached page or search result is displayed.
              </p>
            </div>
          </div>
        <% else %>
          <div
            id="wiki-edition-status"
            class="grid gap-px overflow-hidden rounded-xl border border-border bg-border sm:grid-cols-2 xl:grid-cols-4"
          >
            <.wiki_stat
              id="source"
              label="Source revision"
              value={wiki_edition_value(@projection, :source_fence, "not compiled")}
            />
            <.wiki_stat
              id="edition"
              label="Edition"
              value={wiki_edition_value(@projection, :edition_iri, "pending") |> compact_iri()}
            />
            <.wiki_stat
              id="freshness"
              label="Freshness"
              value={wiki_edition_value(@projection, :freshness, Atom.to_string(@projection.state))}
            />
            <.wiki_stat
              id="tokens"
              label="Model usage"
              value={wiki_model_usage_value(@projection)}
            />
          </div>

          <nav
            id="wiki-view-navigation"
            aria-label="Repository wiki views"
            class="flex gap-1 overflow-x-auto border-b border-border pb-px"
          >
            <button
              :for={item <- RepositoryWikiSurfaceContract.all()}
              id={"wiki-view-#{item.id}"}
              type="button"
              phx-click="select-wiki-view"
              phx-value-view={item.id}
              aria-current={if(@view.id == item.id, do: "page", else: "false")}
              class={[
                "inline-flex min-h-10 shrink-0 items-center gap-2 border-b-2 px-3 text-sm outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring",
                @view.id == item.id && "border-foreground font-semibold text-foreground",
                @view.id != item.id &&
                  "border-transparent text-muted-foreground hover:text-foreground"
              ]}
            >
              <.icon name={item.icon} class="size-4" />
              {item.label}
            </button>
          </nav>

          <%= case @view.id do %>
            <% "search" -> %>
              <div id="wiki-search" class="grid gap-4">
                <.form
                  for={@search_form}
                  id="wiki-search-form"
                  phx-submit="search-wiki"
                  class="flex gap-2"
                >
                  <.input
                    field={@search_form[:query]}
                    type="search"
                    label="Search the current edition"
                    placeholder="Guide, dependency, architecture…"
                    autocomplete="off"
                    class="min-h-11 w-full rounded-lg border border-input bg-background px-3 text-sm outline-none transition-shadow focus:ring-2 focus:ring-ring"
                  />
                  <button
                    id="wiki-search-submit"
                    type="submit"
                    class="mt-7 inline-flex min-h-11 items-center justify-center rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground transition-opacity hover:opacity-90"
                  >
                    Search
                  </button>
                </.form>
                <div id="wiki-search-results" phx-update="stream" class="grid gap-2">
                  <.stream_empty
                    id="wiki-search-empty"
                    icon="hero-magnifying-glass"
                    message="Enter plain words to search the authorized current edition."
                  />
                  <button
                    :for={{id, result} <- @streams.wiki_search_results}
                    id={id}
                    type="button"
                    phx-click="open-wiki-page"
                    phx-value-slug={result.slug}
                    class="group rounded-lg border border-border bg-card p-4 text-left transition-colors hover:border-foreground/30 hover:bg-muted/50"
                  >
                    <span class="flex items-center justify-between gap-4">
                      <span class="font-semibold group-hover:underline">{result.title}</span>
                      <span class="font-mono text-xs text-muted-foreground">
                        score {result.score}
                      </span>
                    </span>
                    <span class="mt-1 block text-xs text-muted-foreground">{result.snippet}</span>
                  </button>
                </div>
              </div>
            <% "history" -> %>
              <div id="wiki-history" phx-update="stream" class="grid gap-2">
                <.stream_empty
                  id="wiki-history-empty"
                  icon="hero-clock"
                  message="No retained edition history is available."
                />
                <article
                  :for={{id, item} <- @streams.wiki_history}
                  id={id}
                  class="grid gap-2 rounded-lg border border-border bg-card p-4 sm:grid-cols-[1fr_auto]"
                >
                  <div>
                    <p class="text-sm font-semibold">Enrollment revision {item["revision"] || "-"}</p>
                    <p class="mt-1 break-all font-mono text-xs text-muted-foreground">
                      {item["currentEdition"] || "No current edition"}
                    </p>
                  </div>
                  <span class="text-xs text-muted-foreground">{item["state"] || "unknown"}</span>
                </article>
              </div>
            <% "gaps" -> %>
              <div id="wiki-known-gaps" phx-update="stream" class="grid gap-2">
                <.stream_empty
                  id="wiki-gaps-empty"
                  icon="hero-check-circle"
                  message="No visible gaps were reported for this edition."
                />
                <article
                  :for={{id, gap} <- @streams.wiki_gaps}
                  id={id}
                  class="rounded-lg border border-amber-500/30 bg-amber-500/5 p-4"
                >
                  <p class="text-sm font-semibold">{gap["omissionCode"] || "incomplete"}</p>
                  <p class="mt-1 font-mono text-xs text-muted-foreground">
                    {gap["sourceLocator"] || "edition"}
                  </p>
                </article>
              </div>
            <% "usage" -> %>
              <section id="wiki-usage" aria-labelledby="wiki-usage-title" class="grid gap-5">
                <div class="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
                  <div>
                    <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                      Accounting state
                    </p>
                    <h3 id="wiki-usage-title" class="mt-1 text-xl font-semibold">
                      Repository usage and cost
                    </h3>
                  </div>
                  <span
                    id="wiki-usage-state"
                    class="rounded-full bg-muted px-3 py-1 text-xs font-semibold text-muted-foreground"
                  >
                    {@projection.usage.state}
                  </span>
                </div>

                <div
                  id="wiki-usage-totals"
                  class="grid gap-px overflow-hidden rounded-xl border border-border bg-border sm:grid-cols-2 xl:grid-cols-4"
                >
                  <.wiki_stat
                    id="usage-attempts"
                    label="Attempts"
                    value={Integer.to_string(@projection.usage.totals.attempts)}
                  />
                  <.wiki_stat
                    id="usage-tokens"
                    label="Model tokens"
                    value={Integer.to_string(wiki_total_tokens(@projection.usage.totals))}
                  />
                  <.wiki_stat
                    id="usage-reserved"
                    label="Reserved liability"
                    value={format_microunits(@projection.usage.totals.reserved_liability_microunits)}
                  />
                  <.wiki_stat
                    id="usage-unknown"
                    label="Unknown liability"
                    value={format_microunits(@projection.usage.totals.unknown_liability_microunits)}
                  />
                </div>

                <div class="grid gap-5 xl:grid-cols-2">
                  <div class="rounded-xl border border-border bg-card p-5">
                    <h4 class="font-semibold">Cost by currency</h4>
                    <div id="wiki-currency-totals" phx-update="stream" class="mt-3 grid gap-2">
                      <.stream_empty
                        id="wiki-currency-empty"
                        icon="hero-banknotes"
                        message="No model-token usage or reservation is recorded for this period."
                      />
                      <article
                        :for={{id, currency} <- @streams.wiki_currency_totals}
                        id={id}
                        class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 rounded-lg border border-border p-3"
                      >
                        <p class="font-mono text-sm font-semibold">{currency.currency}</p>
                        <p class="text-right text-sm">
                          measured {format_microunits(currency.measured)}
                        </p>
                        <p class="col-start-2 text-right text-xs text-muted-foreground">
                          reserved {format_microunits(currency.reserved)} · unknown {format_microunits(
                            currency.unknown
                          )}
                        </p>
                      </article>
                    </div>
                  </div>

                  <div id="wiki-budget" class="rounded-xl border border-border bg-card p-5">
                    <h4 class="font-semibold">Budget and profile</h4>
                    <dl class="mt-3 grid grid-cols-2 gap-3 text-sm">
                      <dt class="text-muted-foreground">State</dt>
                      <dd id="wiki-budget-state" class="text-right font-semibold">
                        {@projection.usage.budget.state}
                      </dd>
                      <dt class="text-muted-foreground">Remaining</dt>
                      <dd id="wiki-budget-remaining" class="text-right font-mono">
                        {format_optional_microunits(
                          @projection.usage.budget.remaining,
                          @projection.usage.budget.currency
                        )}
                      </dd>
                      <dt class="text-muted-foreground">Live reservations</dt>
                      <dd id="wiki-budget-live" class="text-right font-mono">
                        {@projection.usage.budget.live}
                      </dd>
                    </dl>
                    <p
                      id="wiki-synthesis-availability"
                      class="mt-4 text-xs leading-5 text-muted-foreground"
                    >
                      Hosted synthesis is unavailable in deterministic V1. No provider credential, prompt, or endpoint is exposed here.
                    </p>
                  </div>
                </div>

                <div class="grid gap-5 xl:grid-cols-2">
                  <div class="rounded-xl border border-border bg-card p-5">
                    <h4 class="font-semibold">Bounded breakdowns</h4>
                    <div id="wiki-usage-breakdowns" phx-update="stream" class="mt-3 grid gap-2">
                      <.stream_empty
                        id="wiki-usage-breakdowns-empty"
                        icon="hero-chart-bar"
                        message="No usage breakdown is available."
                      />
                      <article
                        :for={{id, item} <- @streams.wiki_usage_breakdowns}
                        id={id}
                        class="flex items-center justify-between gap-4 rounded-lg border border-border p-3 text-sm"
                      >
                        <span class="min-w-0 truncate">
                          <span class="text-xs text-muted-foreground">{item.dimension}</span>
                          <span class="ml-2 font-mono">{compact_iri(item.value)}</span>
                        </span>
                        <span class="shrink-0 text-xs text-muted-foreground">
                          {item.attempts} attempts · {item.tokens} tokens
                        </span>
                      </article>
                    </div>
                  </div>

                  <div class="rounded-xl border border-border bg-card p-5">
                    <h4 class="font-semibold">Live reservations</h4>
                    <div id="wiki-live-reservations" phx-update="stream" class="mt-3 grid gap-2">
                      <.stream_empty
                        id="wiki-reservations-empty"
                        icon="hero-check-circle"
                        message="No live model-cost reservation is held."
                      />
                      <article
                        :for={{id, reservation} <- @streams.wiki_reservations}
                        id={id}
                        class="rounded-lg border border-border p-3 text-sm"
                      >
                        <div class="flex items-center justify-between gap-4">
                          <span class="font-semibold">{reservation.state}</span>
                          <span class="font-mono">
                            {reservation.cost_microunits} {reservation.currency} µ
                          </span>
                        </div>
                        <p class="mt-1 text-xs text-muted-foreground">
                          expires {format_datetime(reservation.expires_at)}
                        </p>
                      </article>
                    </div>
                  </div>
                </div>
              </section>
            <% "operations" -> %>
              <section id="wiki-operations" aria-labelledby="wiki-operations-title" class="grid gap-5">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                    Graph-derived fleet posture
                  </p>
                  <h3 id="wiki-operations-title" class="mt-1 text-xl font-semibold">
                    Repository wiki operations
                  </h3>
                </div>

                <div
                  id="wiki-fleet-summary"
                  class="grid gap-px overflow-hidden rounded-xl border border-border bg-border sm:grid-cols-2 xl:grid-cols-4"
                >
                  <.wiki_stat
                    id="fleet-repositories"
                    label="Repositories"
                    value={@projection.operations.repository_count}
                  />
                  <.wiki_stat
                    id="fleet-stale"
                    label="Stale"
                    value={@projection.operations.stale_count}
                  />
                  <.wiki_stat
                    id="fleet-queue"
                    label="Queued"
                    value={@projection.operations.queue_pending}
                  />
                  <.wiki_stat
                    id="fleet-alerts"
                    label="Alerts"
                    value={@projection.operations.alert_count}
                  />
                </div>

                <div class="grid gap-5 xl:grid-cols-2">
                  <div class="rounded-xl border border-border bg-card p-5">
                    <h4 class="font-semibold">Repository health</h4>
                    <div id="wiki-fleet-repositories" phx-update="stream" class="mt-3 grid gap-2">
                      <.stream_empty
                        id="wiki-fleet-repositories-empty"
                        icon="hero-server-stack"
                        message="No authorized fleet health rows are available."
                      />
                      <article
                        :for={{id, repository} <- @streams.wiki_fleet_repositories}
                        id={id}
                        class="rounded-lg border border-border p-3"
                      >
                        <div class="flex items-center justify-between gap-4 text-sm">
                          <span class="truncate font-mono">
                            {compact_iri(repository.repository_iri)}
                          </span>
                          <span class="font-semibold">{repository.current_state}</span>
                        </div>
                        <p class="mt-1 text-xs text-muted-foreground">
                          {repository.enrollment} · {repository.maintainer} · {repository.queue.pending} queued · {repository.accounting.live_reservations} reservations
                        </p>
                      </article>
                    </div>
                  </div>

                  <div class="rounded-xl border border-border bg-card p-5">
                    <h4 class="font-semibold">Active alerts</h4>
                    <div id="wiki-operations-alerts" phx-update="stream" class="mt-3 grid gap-2">
                      <.stream_empty
                        id="wiki-alerts-empty"
                        icon="hero-check-circle"
                        message="No repository wiki operations alert is active."
                      />
                      <article
                        :for={{id, alert} <- @streams.wiki_alerts}
                        id={id}
                        class={[
                          "rounded-lg border p-3",
                          alert.severity == :critical && "border-red-500/30 bg-red-500/5",
                          alert.severity != :critical && "border-amber-500/30 bg-amber-500/5"
                        ]}
                      >
                        <div class="flex items-center justify-between gap-4 text-sm">
                          <span class="font-semibold">{alert.type}</span>
                          <span class="text-xs uppercase tracking-wide">{alert.severity}</span>
                        </div>
                        <p class="mt-1 truncate font-mono text-xs text-muted-foreground">
                          {compact_iri(alert.repository_iri)}
                        </p>
                      </article>
                    </div>
                  </div>
                </div>

                <aside
                  id="wiki-runbook-note"
                  class="rounded-xl border border-border bg-muted/40 p-5 text-sm leading-6 text-muted-foreground"
                >
                  Recovery uses the existing store backup, then rebuilds disposable navigation/search projections and restarts only eligible maintainers after current-edition, source, enrollment, cancellation, and accounting fences verify.
                </aside>
              </section>
            <% "settings" -> %>
              <div id="wiki-settings" class="grid gap-5 lg:grid-cols-[minmax(0,1fr)_20rem]">
                <.form
                  for={@settings_form}
                  id="wiki-settings-form"
                  phx-change="validate-wiki-settings"
                  phx-submit="save-wiki-settings"
                  class="grid gap-4 rounded-xl border border-border bg-card p-5"
                >
                  <.input
                    field={@settings_form[:mode]}
                    type="select"
                    label="Maintenance mode"
                    options={[
                      {"Off", "off"},
                      {"Manual deterministic", "manual"},
                      {"Automatic deterministic", "automatic"}
                    ]}
                  />
                  <.input
                    field={@settings_form[:read_visibility]}
                    type="select"
                    label="Retained reads"
                    options={[
                      {"Retain current safe edition", "retained"},
                      {"Hide wiki reads", "hidden"}
                    ]}
                  />
                  <.input
                    field={@settings_form[:retention]}
                    type="select"
                    label="Edition retention"
                    options={[{"Standard current and history", "standard"}]}
                  />
                  <.input
                    field={@settings_form[:confirmed]}
                    type="checkbox"
                    label="I understand this changes repository wiki policy"
                  />
                  <button
                    id="wiki-settings-save"
                    type="submit"
                    class="inline-flex min-h-11 items-center justify-center rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground transition-opacity hover:opacity-90"
                  >
                    Save wiki policy
                  </button>
                </.form>
                <aside id="wiki-cost-posture" class="rounded-xl border border-border bg-muted/40 p-5">
                  <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                    Cost posture
                  </p>
                  <p class="mt-2 text-lg font-semibold">Zero model tokens</p>
                  <p class="mt-2 text-sm leading-6 text-muted-foreground">
                    Manual and automatic modes use the pinned deterministic compiler. Off opts out of new wiki generation.
                  </p>
                  <button
                    id="wiki-regenerate"
                    type="button"
                    phx-click="regenerate-wiki"
                    disabled={not @projection.settings.regeneration_available?}
                    class="mt-5 inline-flex min-h-10 w-full items-center justify-center rounded-lg border border-border bg-background px-3 text-sm font-semibold transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    Regenerate deterministically
                  </button>
                  <p
                    :if={@command_receipt}
                    id="wiki-command-receipt"
                    class="mt-3 text-xs text-muted-foreground"
                  >
                    outcome: {@command_receipt.outcome}
                  </p>
                </aside>
              </div>
            <% _page_view -> %>
              <div id="wiki-page-browser" class="grid gap-5 lg:grid-cols-[17rem_minmax(0,1fr)]">
                <aside class="rounded-xl border border-border bg-card p-2">
                  <p class="px-3 py-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                    Current edition
                  </p>
                  <div id="wiki-navigation-pages" phx-update="stream" class="grid gap-1">
                    <.stream_empty
                      id="wiki-navigation-empty"
                      icon="hero-book-open"
                      message="This edition has no projected pages."
                    />
                    <button
                      :for={{id, page} <- @streams.wiki_navigation}
                      id={id}
                      type="button"
                      phx-click="open-wiki-page"
                      phx-value-slug={page.slug}
                      class={[
                        "rounded-md px-3 py-2 text-left text-sm transition-colors hover:bg-muted",
                        @projection.selected_page && @projection.selected_page.slug == page.slug &&
                          "bg-muted font-semibold"
                      ]}
                    >
                      <span class="block truncate">{page.title}</span>
                      <span class="mt-0.5 block truncate text-[0.6875rem] text-muted-foreground">
                        {page.audience} · {page.kind}
                      </span>
                    </button>
                  </div>
                </aside>
                <article
                  id="wiki-page-detail"
                  class="min-w-0 rounded-xl border border-border bg-card p-5 sm:p-7"
                >
                  <%= if @projection.selected_page do %>
                    <div class="flex flex-col gap-3 border-b border-border pb-5 sm:flex-row sm:items-start sm:justify-between">
                      <div>
                        <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                          {@projection.selected_page.audience} · {@projection.selected_page.kind}
                        </p>
                        <h3 id="wiki-page-title" class="mt-2 text-2xl font-semibold tracking-tight">
                          {@projection.selected_page.title}
                        </h3>
                      </div>
                      <span class="rounded-full bg-muted px-2 py-1 text-xs text-muted-foreground">
                        {@projection.selected_page.freshness}
                      </span>
                    </div>
                    <div class="mt-6 grid gap-6 xl:grid-cols-2">
                      <div>
                        <h4 class="text-sm font-semibold">Exact sources</h4>
                        <div id="wiki-page-sources" phx-update="stream" class="mt-3 grid gap-2">
                          <.stream_empty
                            id="wiki-page-sources-empty"
                            icon="hero-document-magnifying-glass"
                            message="No readable source reference is available."
                          />
                          <div
                            :for={{id, source} <- @streams.wiki_sources}
                            id={id}
                            class="rounded-md border border-border p-3"
                          >
                            <p class="break-all font-mono text-xs">
                              {source["sourceLocator"] || source["source"]}
                            </p>
                            <p class="mt-1 text-[0.6875rem] text-muted-foreground">
                              {source["sourceAuthority"]} · {source["freshness"]}
                            </p>
                          </div>
                        </div>
                      </div>
                      <div>
                        <h4 class="text-sm font-semibold">Backlinks</h4>
                        <div id="wiki-page-backlinks" phx-update="stream" class="mt-3 grid gap-2">
                          <.stream_empty
                            id="wiki-page-backlinks-empty"
                            icon="hero-arrow-uturn-left"
                            message="No page links back here."
                          />
                          <button
                            :for={{id, backlink} <- @streams.wiki_backlinks}
                            id={id}
                            type="button"
                            phx-click="open-wiki-page"
                            phx-value-slug={backlink["sourceSlug"]}
                            class="rounded-md border border-border p-3 text-left text-sm transition-colors hover:bg-muted"
                          >
                            {backlink["sourceTitle"] || backlink["sourceSlug"]}
                          </button>
                        </div>
                      </div>
                    </div>
                    <div class="mt-6 rounded-lg bg-muted/50 p-4 text-xs leading-5 text-muted-foreground">
                      Content digest:
                      <span class="break-all font-mono">
                        {@projection.selected_page.content_digest || "not exposed"}
                      </span>
                    </div>
                  <% else %>
                    <div id="wiki-page-empty" class="grid min-h-64 place-items-center text-center">
                      <div>
                        <.icon name="hero-document-text" class="mx-auto size-7 text-muted-foreground" />
                        <p class="mt-3 text-sm text-muted-foreground">
                          This page is not present in the authorized current edition.
                        </p>
                      </div>
                    </div>
                  <% end %>
                </article>
              </div>
          <% end %>
        <% end %>
      <% end %>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  defp wiki_stat(assigns) do
    ~H"""
    <div id={"wiki-stat-#{@id}"} class="min-w-0 bg-card p-4">
      <p class="text-xs font-medium text-muted-foreground">{@label}</p>
      <p class="mt-1 truncate font-mono text-sm font-semibold" title={@value}>{@value}</p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :selected, :string, default: nil

  defp selection_header(assigns) do
    ~H"""
    <div class="flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <p class="max-w-2xl truncate font-mono text-xs text-muted-foreground">
          {@selected || "No repository selected"}
        </p>
        <h2 id={@id} class="mt-1 text-xl font-semibold">{@title}</h2>
      </div>
      <p class="text-xs text-muted-foreground">{@count} projected items</p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :message, :string, required: true

  defp stream_empty(assigns) do
    ~H"""
    <div
      id={@id}
      class="hidden only:grid min-h-44 place-items-center border-y border-border text-center lg:col-span-2"
    >
      <div>
        <.icon name={@icon} class="mx-auto size-6 text-muted-foreground" />
        <p class="mt-2 text-sm text-muted-foreground">{@message}</p>
      </div>
    </div>
    """
  end

  attr :projection, :any, required: true

  defp projection_notice(assigns) do
    ~H"""
    <div
      :if={@projection.state not in [:ready, :empty]}
      id="projection-notice"
      role="status"
      class="flex items-start gap-3 border-l-2 border-status-attention bg-card px-4 py-3 text-sm"
    >
      <.icon name="hero-exclamation-triangle" class="mt-0.5 size-4 shrink-0 text-status-attention" />
      <div>
        <p class="font-semibold">{projection_state_title(@projection.state)}</p>
        <p class="mt-1 text-xs leading-5 text-muted-foreground">
          {projection_state_detail(@projection.state)}
        </p>
      </div>
    </div>
    """
  end

  attr :state, :atom, required: true

  defp projection_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex h-5 items-center rounded px-1.5 text-[0.6875rem] font-medium",
      @state in [:ready, :empty] && "bg-accent text-accent-foreground",
      @state in [:stale, :incomplete, :truncated, :maintenance, :recovery] &&
        "bg-status-attention/15 text-status-attention",
      @state in [:unauthorized, :unavailable, :contradicted] &&
        "bg-status-failure/15 text-status-failure"
    ]}>
      {@state}
    </span>
    """
  end

  defp load_projection(socket) do
    provider =
      Application.get_env(:jido_code, :product_projection_provider, GraphProjectionProvider)

    projection =
      case provider.load(socket.assigns.authority, socket.assigns.identity,
             repository: socket.assigns.selected_repository
           ) do
        {:ok, %Projection{} = projection} -> projection
        _failure -> Projection.unavailable()
      end

    repository_refs =
      Map.new(projection.repositories, fn repository ->
        {:ok, ref} = SurfaceContract.encode_resource(repository.iri)
        {ref, repository.iri}
      end)

    work_items = flatten_work(projection.work)
    outcome_count = outcome_count(projection)
    projection_metadata = projection_metadata(projection)
    repository_index = Map.new(projection.repositories, &{&1.iri, &1})
    wiki_projection = load_wiki_projection(socket, repository_index)
    wiki_projection_metadata = wiki_projection_metadata(wiki_projection)

    socket
    |> assign(:projection, projection_metadata)
    |> assign(:repository_refs, repository_refs)
    |> assign(:repository_index, repository_index)
    |> assign(:repository_count, length(projection.repositories))
    |> assign(:repository_empty?, projection.repositories == [])
    |> assign(:work_count, length(work_items))
    |> assign(:attempt_count, length(projection.attempts))
    |> assign(:knowledge_count, length(projection.knowledge))
    |> assign(:outcome_count, outcome_count)
    |> assign(:wiki_projection, wiki_projection_metadata)
    |> assign(:wiki_settings_form, wiki_settings_form(wiki_projection.settings))
    |> stream(:repositories, projection.repositories, reset: true)
    |> stream(:work_items, work_items, reset: true)
    |> stream(:attempts, projection.attempts, reset: true)
    |> stream(:knowledge, projection.knowledge, reset: true)
    |> stream(:wiki_navigation, wiki_projection.navigation, reset: true)
    |> stream(:wiki_search_results, wiki_projection.search_results, reset: true)
    |> stream(:wiki_history, wiki_projection.history, reset: true)
    |> stream(:wiki_gaps, wiki_projection.gaps, reset: true)
    |> stream(:wiki_sources, wiki_projection.sources, reset: true)
    |> stream(:wiki_backlinks, wiki_projection.backlinks, reset: true)
    |> stream(:wiki_currency_totals, wiki_projection.usage.currency_totals, reset: true)
    |> stream(:wiki_usage_breakdowns, wiki_projection.usage.breakdowns, reset: true)
    |> stream(:wiki_reservations, wiki_projection.usage.reservations, reset: true)
    |> stream(:wiki_fleet_repositories, wiki_projection.operations.repositories, reset: true)
    |> stream(:wiki_alerts, wiki_projection.operations.alerts, reset: true)
  end

  defp load_wiki_projection(socket, repository_index) do
    provider =
      Application.get_env(
        :jido_code,
        :repository_wiki_projection_provider,
        RepositoryWikiProjectionProvider
      )

    repository = socket.assigns.selected_repository

    case provider.load(socket.assigns.authority, socket.assigns.identity,
           repository: repository,
           repository_authorized?:
             is_binary(repository) and Map.has_key?(repository_index, repository),
           page_slug: socket.assigns.wiki_page_slug,
           search_query: socket.assigns.wiki_search_query
         ) do
      {:ok, %RepositoryWikiProjection{} = projection} -> projection
      _failure -> RepositoryWikiProjection.unavailable(:unavailable, repository)
    end
  end

  defp flatten_work(work) do
    Enum.flat_map([:eligible, :blocked, :executing, :awaiting_decision], fn kind ->
      work
      |> Map.get(kind, [])
      |> Enum.map(fn item ->
        %{
          id: item["id"],
          kind: Atom.to_string(kind),
          resource: item["subject"] || item["task"] || item["goal"],
          revision: item["revision"]
        }
      end)
    end)
  end

  defp decode_repository(nil), do: nil

  defp decode_repository(ref) do
    case SurfaceContract.decode_resource(ref) do
      {:ok, repository} -> repository
      :error -> nil
    end
  end

  defp workbench_path(surface, nil), do: ~p"/?#{%{surface: surface}}"

  defp workbench_path(surface, repository),
    do: ~p"/?#{%{surface: surface, repository: repository}}"

  defp wiki_path(socket, overrides) do
    params =
      %{
        surface: "wiki",
        repository: socket.assigns.selected_repository_ref,
        wiki_view: socket.assigns.wiki_view.id,
        wiki_page: socket.assigns.wiki_page_slug,
        wiki_query: socket.assigns.wiki_search_query
      }
      |> Map.merge(overrides)
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Map.new()

    ~p"/?#{params}"
  end

  defp ref_for(refs, repository) do
    Enum.find_value(refs, fn {ref, iri} -> if iri == repository, do: ref end)
  end

  defp workflow_props(assigns) do
    %{
      revision: assigns.projection.dataset_revision,
      state: Atom.to_string(assigns.projection.state),
      selectedRepository: assigns.selected_repository,
      steps: [
        %{id: "repositories", label: "Repositories", count: assigns.repository_count},
        %{id: "work", label: "Work", count: assigns.work_count},
        %{id: "execution", label: "Execution", count: assigns.attempt_count},
        %{id: "outcomes", label: "Outcomes", count: assigns.outcome_count},
        %{id: "knowledge", label: "Knowledge", count: assigns.knowledge_count}
      ]
    }
  end

  defp outcome_count(projection) do
    projection.outcomes |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
  end

  defp projection_metadata(projection) do
    %{
      projection
      | repositories: [],
        work: Projection.empty_work(),
        attempts: [],
        outcomes: Projection.empty_outcomes(),
        knowledge: []
    }
  end

  defp wiki_projection_metadata(projection) do
    usage = %{projection.usage | currency_totals: [], breakdowns: [], reservations: []}
    operations = %{projection.operations | repositories: [], alerts: []}

    %{
      projection
      | navigation: [],
        backlinks: [],
        sources: [],
        gaps: [],
        history: [],
        search_results: [],
        usage: usage,
        operations: operations
    }
  end

  defp projection_state_title(:stale), do: "Projection is stale"
  defp projection_state_title(:incomplete), do: "Projection is incomplete"
  defp projection_state_title(:truncated), do: "Projection reached its bounded limit"
  defp projection_state_title(:unauthorized), do: "Resource is not available"
  defp projection_state_title(:maintenance), do: "Knowledge store is in maintenance"
  defp projection_state_title(:recovery), do: "Knowledge store is recovering"
  defp projection_state_title(:contradicted), do: "Projection contains a contradiction"
  defp projection_state_title(_state), do: "Knowledge store is unavailable"

  defp projection_state_detail(:stale),
    do: "Refresh before making a decision or issuing a command."

  defp projection_state_detail(:incomplete),
    do: "Some source graphs are not complete; omitted facts are not treated as absent."

  defp projection_state_detail(:truncated),
    do: "Narrow the current scope to inspect the remaining results."

  defp projection_state_detail(:unauthorized),
    do: "The resource may not exist or may be outside the current actor scope."

  defp projection_state_detail(:maintenance),
    do: "Writes and authoritative reads remain closed until maintenance completes."

  defp projection_state_detail(:recovery),
    do: "Product projections will rebuild from the graph after integrity checks pass."

  defp projection_state_detail(:contradicted),
    do: "Review the relevant evidence and accepted transition chain."

  defp projection_state_detail(_state),
    do: "No cached product state is shown while the authoritative graph cannot be read."

  defp wiki_state_title(:hidden), do: "Wiki reads are hidden"
  defp wiki_state_title(:disabled), do: "Wiki generation is off"
  defp wiki_state_title(:unauthorized), do: "Wiki is not available"
  defp wiki_state_title(:unavailable), do: "Wiki state is unavailable"
  defp wiki_state_title(_state), do: "No current wiki edition"

  defp wiki_state_detail(:hidden),
    do: "Repository policy does not permit retained wiki reads for this actor."

  defp wiki_state_detail(:disabled),
    do: "No repository wiki policy is enabled, so no generation work is scheduled."

  defp wiki_state_detail(:unauthorized),
    do: "The repository or edition may be outside the current actor scope."

  defp wiki_state_detail(_state),
    do: "The authoritative edition graph could not be projected safely."

  defp wiki_edition_value(%{edition: edition}, key, fallback) when is_map(edition),
    do: Map.get(edition, key) || fallback

  defp wiki_edition_value(_projection, _key, fallback), do: fallback

  defp wiki_model_usage_value(%{usage: %{totals: totals}}) do
    tokens = wiki_total_tokens(totals)
    cost = totals.measured_cost_microunits

    if tokens == 0 and cost == 0,
      do: "0 tokens · 0 cost",
      else: "#{tokens} tokens · #{format_microunits(cost)}"
  end

  defp wiki_model_usage_value(_projection), do: "usage unavailable"

  defp wiki_total_tokens(totals) do
    totals.input_tokens + totals.output_tokens + totals.cached_tokens + totals.reasoning_tokens
  end

  defp format_microunits(value) when is_integer(value) and value >= 0,
    do: "#{value} µunits"

  defp format_microunits(_value), do: "unavailable"

  defp format_optional_microunits(nil, _currency), do: "unavailable"

  defp format_optional_microunits(value, currency)
       when is_integer(value) and value >= 0 and is_binary(currency),
       do: "#{value} #{currency} µ"

  defp format_optional_microunits(_value, _currency), do: "unavailable"

  defp format_datetime(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp format_datetime(_value), do: "unavailable"

  defp compact_iri(value) when is_binary(value) do
    if byte_size(value) > 24, do: "…" <> String.slice(value, -23, 23), else: value
  end

  defp compact_iri(_value), do: "-"

  defp wiki_settings_form(settings \\ RepositoryWikiProjection.default_settings()) do
    to_form(
      %{
        "mode" => Atom.to_string(settings.mode),
        "read_visibility" => Atom.to_string(settings.read_visibility),
        "retention" => Atom.to_string(settings.retention),
        "confirmed" => "false"
      },
      as: :wiki_settings
    )
  end

  defp enrollment_form do
    to_form(
      %{
        "conceptual_key" => "",
        "provider" => "https://github.com",
        "external_id" => "",
        "owner" => "",
        "name" => "",
        "reason" => "",
        "confirmed" => "false",
        "idempotency_key" => idempotency_key()
      },
      as: :enrollment
    )
  end

  defp enrollment_preview(params) do
    required = ~w[conceptual_key provider external_id owner name reason]

    if Enum.all?(required, fn key ->
         value = params[key]
         is_binary(value) and String.trim(value) != "" and byte_size(value) <= 160
       end) and params["confirmed"] == "true" do
      provider = URI.parse(params["provider"]).host || "the configured provider"

      %{
        summary:
          "Enroll #{String.slice(params["owner"], 0, 40)}/#{String.slice(params["name"], 0, 40)} through #{provider}."
      }
    end
  end

  defp idempotency_key do
    :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)
  end

  defp receipt_view(receipt) do
    %{outcome: receipt.outcome, retry: receipt.retry, dataset_revision: receipt.dataset_revision}
  end

  defp command_error_message(%Error{kind: :unauthorized}), do: "Repository is not available."

  defp command_error_message(%Error{kind: kind})
       when kind in [:conflict, :stale_precondition],
       do: "Graph state changed. Refresh and review the command again."

  defp command_error_message(%Error{kind: :invalid_input}),
    do: "Review the enrollment values and confirmation."

  defp command_error_message(_error),
    do: "The enrollment command could not be completed."

  defp command_outcome_message(%CommandOutcome{outcome: :conflicted}),
    do: "Graph state changed. Refresh and review the command again."

  defp command_outcome_message(%CommandOutcome{outcome: :unauthorized}),
    do: "Repository is not available."

  defp command_outcome_message(%CommandOutcome{outcome: :unknown_after_timeout}),
    do: "The command outcome is unknown. Verify its receipt before retrying."

  defp command_outcome_message(_receipt),
    do: "The enrollment command could not be completed."

  defp wiki_command_error_message(%Error{kind: :unauthorized}),
    do: "The repository wiki policy is not available to this actor."

  defp wiki_command_error_message(%Error{kind: kind})
       when kind in [:conflict, :stale_precondition],
       do: "Wiki policy changed. Refresh before trying again."

  defp wiki_command_error_message(%Error{kind: :invalid_input}),
    do: "Review the wiki mode, retained-read, retention, and confirmation values."

  defp wiki_command_error_message(_error), do: "The wiki command could not be completed."

  defp wiki_command_outcome_message(%CommandOutcome{outcome: outcome})
       when outcome in [:conflicted, :stale, :competing],
       do: "Wiki state changed. Refresh before trying again."

  defp wiki_command_outcome_message(%CommandOutcome{outcome: :unauthorized}),
    do: "The repository wiki policy is not available to this actor."

  defp wiki_command_outcome_message(_receipt), do: "The wiki command was not committed."
end
