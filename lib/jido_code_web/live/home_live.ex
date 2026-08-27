defmodule JidoCodeWeb.HomeLive do
  use JidoCodeWeb, :live_view

  alias JidoCode.Knowledge.Error
  alias JidoCode.Product
  alias JidoCode.Product.CommandGateway
  alias JidoCode.Product.CommandOutcome
  alias JidoCode.Product.GraphProjectionProvider
  alias JidoCode.Product.Projection
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
     |> stream_configure(:attempts, dom_id: &"attempt-#{&1["id"]}")
     |> stream_configure(:knowledge, dom_id: &"knowledge-#{&1["id"]}")
     |> stream(:repositories, [])
     |> stream(:work_items, [])
     |> stream(:attempts, [])
     |> stream(:knowledge, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    surface = SurfaceContract.fetch(params["surface"])
    selected_repository = decode_repository(params["repository"])

    {:noreply,
     socket
     |> assign(:surface, surface)
     |> assign(:selected_repository, selected_repository)
     |> assign(:selected_repository_ref, params["repository"])
     |> load_projection()}
  end

  @impl true
  def handle_event("refresh", _params, socket), do: {:noreply, load_projection(socket)}

  def handle_event("select-surface", %{"surface" => id}, socket) do
    surface = SurfaceContract.fetch(id)

    {:noreply,
     push_patch(socket, to: workbench_path(surface.id, socket.assigns.selected_repository_ref))}
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
              :for={surface <- SurfaceContract.all()}
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

    socket
    |> assign(:projection, projection_metadata)
    |> assign(:repository_refs, repository_refs)
    |> assign(:repository_index, Map.new(projection.repositories, &{&1.iri, &1}))
    |> assign(:repository_count, length(projection.repositories))
    |> assign(:repository_empty?, projection.repositories == [])
    |> assign(:work_count, length(work_items))
    |> assign(:attempt_count, length(projection.attempts))
    |> assign(:knowledge_count, length(projection.knowledge))
    |> assign(:outcome_count, outcome_count)
    |> stream(:repositories, projection.repositories, reset: true)
    |> stream(:work_items, work_items, reset: true)
    |> stream(:attempts, projection.attempts, reset: true)
    |> stream(:knowledge, projection.knowledge, reset: true)
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
end
