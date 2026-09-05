defmodule JidoCodeWeb.Components.Application do
  @moduledoc """
  Stateless application-shell components for already-shaped presentation data.

  Callers provide display-ready maps and lists in the order they should be
  rendered. Navigation collections must already omit unavailable destinations;
  this module neither discovers routes nor makes access decisions.
  """

  use Phoenix.Component

  import JidoCodeWeb.CoreComponents, only: [icon: 1]

  alias JidoCodeWeb.Components.UI

  @max_primary_items 12
  @max_utility_items 8
  @max_account_actions 8
  @max_breadcrumbs 8
  @max_projects 50
  @max_filters 6
  @max_filter_options 25
  @max_page_actions 6
  @max_pagination_pages 20
  @max_errors 20
  @max_footer_metadata 8
  @max_footer_links 8
  @max_dom_id_bytes 128
  @max_dom_key_bytes 64
  @max_text_bytes 1_000

  @attempt_states %{
    queued: %{badge: :secondary, icon: "hero-clock"},
    running: %{badge: :default, icon: "hero-play-circle"},
    blocked: %{badge: :outline, icon: "hero-pause-circle"},
    succeeded: %{badge: :default, icon: "hero-check-circle"},
    failed: %{badge: :destructive, icon: "hero-x-circle"},
    cancelled: %{badge: :outline, icon: "hero-no-symbol"}
  }

  @readiness_states %{
    ready: %{status: :success, icon: "hero-check-circle"},
    limited: %{status: :attention, icon: "hero-exclamation-triangle"},
    unavailable: %{status: :failure, icon: "hero-x-circle"}
  }

  @empty_states %{
    empty: "hero-inbox",
    no_results: "hero-magnifying-glass",
    unavailable: "hero-cloud"
  }

  @banner_kinds %{
    maintenance: %{role: "status", icon: "hero-wrench-screwdriver"},
    degraded: %{role: "alert", icon: "hero-exclamation-triangle"}
  }

  attr :id, :string, required: true
  attr :main_id, :string, required: true
  attr :skip_label, :string, default: "Skip to main content"
  attr :class, :any, default: nil
  slot :masthead, required: true
  slot :context
  slot :inner_block, required: true
  slot :footer

  @doc "Renders the outer shell, skip target, and stable page regions."
  def shell(assigns) do
    id = dom_id!(assigns.id, :id)
    main_id = dom_id!(assigns.main_id, :main_id)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:main_id, main_id)
      |> assign(:skip_label, text!(assigns.skip_label, :skip_label))
      |> assign(:skip_href, "##{main_id}")

    ~H"""
    <div
      id={@id}
      data-application-shell
      class={["min-h-screen bg-background text-foreground", @class]}
    >
      <UI.link
        id={"#{@id}-skip-link"}
        href={@skip_href}
        class="sr-only fixed left-4 top-4 z-50 rounded-md bg-background px-4 py-3 font-semibold shadow-[var(--elevation-overlay)] focus:not-sr-only"
      >
        {@skip_label}
      </UI.link>

      <div id={"#{@id}-masthead-region"}>{render_slot(@masthead)}</div>

      <div
        :if={@context != []}
        id={"#{@id}-context-region"}
        class="border-b border-border bg-muted/35"
      >
        {render_slot(@context)}
      </div>

      <main
        id={@main_id}
        tabindex="-1"
        class="mx-auto grid w-full max-w-[var(--layout-content)] gap-[var(--space-section)] px-4 py-8 sm:px-6 lg:px-8"
      >
        {render_slot(@inner_block)}
      </main>

      <div :if={@footer != []} id={"#{@id}-footer-region"}>{render_slot(@footer)}</div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :brand, :map, required: true
  attr :class, :any, default: nil
  slot :primary_navigation, required: true
  slot :project_switcher
  slot :utility_navigation
  slot :account_menu
  slot :responsive_navigation

  @doc "Renders brand and caller-shaped navigation regions without resolving routes."
  def masthead(assigns) do
    id = dom_id!(assigns.id, :id)
    brand = normalize_brand!(assigns.brand)

    assigns = assigns |> assign(:id, id) |> assign(:brand, brand)

    ~H"""
    <header
      id={@id}
      data-application-masthead
      class={["border-b border-border bg-card text-card-foreground", @class]}
    >
      <div class="mx-auto grid w-full max-w-[var(--layout-content)] grid-cols-[minmax(0,1fr)_auto] items-center gap-x-3 gap-y-3 px-4 py-3 sm:px-6 lg:flex lg:gap-4 lg:px-8">
        <UI.link
          id={"#{@id}-brand"}
          href={@brand.href}
          class="flex min-h-[var(--touch-target)] min-w-0 items-center gap-3 no-underline"
        >
          <.icon name="hero-command-line" class="size-6 shrink-0" />
          <span class="min-w-0">
            <span class="block truncate font-semibold">{@brand.label}</span>
            <span id={"#{@id}-service-label"} class="block truncate text-xs text-muted-foreground">
              {@brand.service_label}
            </span>
          </span>
        </UI.link>

        <div
          id={"#{@id}-primary-region"}
          class="ml-auto hidden min-w-0 items-center gap-4 lg:flex"
        >
          {render_slot(@primary_navigation)}
        </div>

        <div
          :if={@project_switcher != []}
          id={"#{@id}-project-region"}
          class="col-span-2 row-start-2 min-w-0 lg:col-auto lg:row-auto"
        >
          {render_slot(@project_switcher)}
        </div>

        <div
          :if={@utility_navigation != []}
          id={"#{@id}-utility-region"}
          class="col-span-2 row-start-3 flex min-w-0 justify-end lg:col-auto lg:row-auto lg:block"
        >
          {render_slot(@utility_navigation)}
        </div>

        <div :if={@account_menu != []} id={"#{@id}-account-region"} class="hidden lg:block">
          {render_slot(@account_menu)}
        </div>

        <div
          :if={@responsive_navigation != []}
          id={"#{@id}-responsive-region"}
          class="col-start-2 row-start-1 lg:hidden"
        >
          {render_slot(@responsive_navigation)}
        </div>
      </div>
    </header>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, default: "Primary navigation"
  attr :items, :list, required: true
  attr :class, :any, default: nil

  @doc "Renders a bounded primary-navigation list supplied in display order."
  def primary_navigation(assigns) do
    id = dom_id!(assigns.id, :id)
    items = normalize_links!(assigns.items, :primary_navigation, @max_primary_items, false)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:label, text!(assigns.label, :label))
      |> assign(:items, items)

    ~H"""
    <nav id={@id} aria-label={@label} data-application-primary-navigation class={@class}>
      <ul class="flex flex-wrap items-center gap-1">
        <li :for={item <- @items}>
          <UI.link
            id={"#{@id}-item-#{item.key}"}
            href={item.href}
            aria-current={item.current && "page"}
            class={[
              "inline-flex min-h-[var(--touch-target)] items-center rounded-md px-3 py-2 text-sm font-medium no-underline transition-colors",
              item.current && "bg-accent text-accent-foreground",
              !item.current && "text-muted-foreground hover:bg-accent/70 hover:text-foreground"
            ]}
          >
            {item.label}
          </UI.link>
        </li>
      </ul>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, default: "Utility navigation"
  attr :items, :list, required: true
  attr :class, :any, default: nil

  @doc "Renders a bounded utility-navigation list supplied in display order."
  def utility_navigation(assigns) do
    id = dom_id!(assigns.id, :id)
    items = normalize_links!(assigns.items, :utility_navigation, @max_utility_items, true)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:label, text!(assigns.label, :label))
      |> assign(:items, items)

    ~H"""
    <nav id={@id} aria-label={@label} data-application-utility-navigation class={@class}>
      <ul class="flex flex-wrap items-center gap-1">
        <li :for={item <- @items}>
          <UI.link
            id={"#{@id}-item-#{item.key}"}
            href={item.href}
            aria-current={item.current && "page"}
            class="inline-flex min-h-[var(--touch-target)] items-center rounded-md px-2 py-2 text-sm text-muted-foreground no-underline hover:text-foreground"
          >
            {item.label}
          </UI.link>
        </li>
      </ul>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :form, :any, required: true
  attr :field, :any, required: true
  attr :action, :string, required: true
  attr :projects, :list, required: true
  attr :label, :string, default: "Current project"
  attr :help, :string, default: "Changing project follows ordinary navigation."
  attr :submit_label, :string, default: "Open"
  attr :class, :any, default: nil

  @doc "Renders a native GET form for an already-filtered project collection."
  def project_switcher(assigns) do
    id = dom_id!(assigns.id, :id)
    projects = normalize_options!(assigns.projects, :projects, @max_projects)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:projects, projects)
      |> assign(:action, form_action!(assigns.action, :action))
      |> assign(:label, text!(assigns.label, :label))
      |> assign(:help, text!(assigns.help, :help))
      |> assign(:submit_label, text!(assigns.submit_label, :submit_label))

    ~H"""
    <section id={@id} data-application-project-switcher class={@class}>
      <UI.form
        for={@form}
        id={"#{@id}-form"}
        action={@action}
        method="get"
        aria-label="Project switcher"
        class="flex w-full min-w-0 items-end gap-2 lg:w-auto"
      >
        <UI.select
          field={@field}
          id={"#{@id}-select"}
          options={@projects}
          size={:small}
          field_class="min-w-0 flex-1 lg:min-w-40 lg:flex-none"
        >
          <:label>{@label}</:label>
          <:help>{@help}</:help>
        </UI.select>
        <UI.button id={"#{@id}-submit"} type="submit" variant={:secondary} size={:small}>
          {@submit_label}
        </UI.button>
      </UI.form>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :items, :list, required: true
  attr :class, :any, default: nil

  @doc "Renders a bounded breadcrumb trail with exactly one current item."
  def breadcrumbs(assigns) do
    id = dom_id!(assigns.id, :id)
    items = normalize_breadcrumbs!(assigns.items)
    assigns = assigns |> assign(:id, id) |> assign(:items, items)

    ~H"""
    <nav id={@id} aria-label="Breadcrumbs" data-application-breadcrumbs class={@class}>
      <ol class="flex min-w-0 flex-wrap items-center gap-1 text-sm text-muted-foreground">
        <li :for={item <- @items} class="flex min-w-0 items-center gap-1">
          <UI.link
            :if={!item.current}
            id={"#{@id}-item-#{item.key}"}
            href={item.href}
            class="truncate no-underline hover:text-foreground"
          >
            {item.label}
          </UI.link>
          <span
            :if={item.current}
            id={"#{@id}-item-#{item.key}"}
            aria-current="page"
            class="truncate font-medium text-foreground"
          >
            {item.label}
          </span>
          <span :if={!item.last} aria-hidden="true">
            <.icon name="hero-chevron-right" class="size-4 shrink-0" />
          </span>
        </li>
      </ol>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :attempt, :map, required: true
  attr :class, :any, default: nil

  @doc "Renders one already-shaped attempt reference and its explicit state label."
  def attempt_context(assigns) do
    id = dom_id!(assigns.id, :id)
    attempt = normalize_attempt!(assigns.attempt)
    assigns = assigns |> assign(:id, id) |> assign(:attempt, attempt)

    ~H"""
    <aside
      id={@id}
      aria-labelledby={"#{@id}-title"}
      data-application-attempt-context
      data-attempt-state={@attempt.state}
      class={[
        "flex min-w-0 flex-wrap items-center gap-x-4 gap-y-2 rounded-lg border border-border bg-card px-4 py-3",
        @class
      ]}
    >
      <div class="flex min-w-0 items-center gap-2">
        <span aria-hidden="true">
          <.icon name={@attempt.presentation.icon} class="size-5 shrink-0" />
        </span>
        <div class="min-w-0">
          <p id={"#{@id}-title"} class="truncate text-sm font-semibold">{@attempt.label}</p>
          <p id={"#{@id}-reference"} class="truncate font-mono text-xs text-muted-foreground">
            {@attempt.reference}
          </p>
        </div>
      </div>
      <p id={"#{@id}-scope"} class="text-sm text-muted-foreground">{@attempt.scope_label}</p>
      <UI.badge id={"#{@id}-state"} variant={@attempt.presentation.badge}>
        {@attempt.state_label}
      </UI.badge>
    </aside>
    """
  end

  attr :id, :string, required: true
  attr :account, :map, required: true
  attr :actions, :list, required: true
  attr :class, :any, default: nil

  @doc "Renders a native account/session action disclosure plus ordinary-link fallback."
  def account_session_menu(assigns) do
    id = dom_id!(assigns.id, :id)
    account = normalize_account!(assigns.account)
    actions = normalize_links!(assigns.actions, :account_actions, @max_account_actions, false)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:account, account)
      |> assign(:actions, actions)

    ~H"""
    <section id={"#{@id}-region"} data-application-account-session class={@class}>
      <UI.menu id={@id} accessible_label={"Account and session for #{@account.display_name}"}>
        <:trigger>
          <span class="flex min-w-0 items-center gap-2">
            <span aria-hidden="true">
              <.icon name="hero-user-circle" class="size-5 shrink-0" />
            </span>
            <span class="min-w-0 text-left">
              <span class="block truncate">{@account.display_name}</span>
              <span class="block truncate text-xs opacity-80">{@account.session_label}</span>
            </span>
          </span>
        </:trigger>
        <:action
          :for={action <- @actions}
          key={action.key}
          label={action.label}
          kind={:link}
          destination={action.href}
          current={if(action.current, do: :page, else: :none)}
        />
        <:fallback>
          <details
            id={"#{@id}-fallback-disclosure"}
            data-enhancement-fallback="popover"
            class="mt-2 rounded-md border border-border px-3 py-2"
          >
            <summary id={"#{@id}-fallback-summary"} class="cursor-pointer text-sm font-medium">
              Direct account links
            </summary>
            <nav
              id={"#{@id}-fallback"}
              aria-label="Account and session fallback"
              class="mt-2"
            >
              <ul class="grid gap-2">
                <li :for={action <- @actions}>
                  <UI.link id={"#{@id}-fallback-#{action.key}"} href={action.href}>
                    {action.label}
                  </UI.link>
                </li>
              </ul>
            </nav>
          </details>
        </:fallback>
      </UI.menu>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :summary, :string, default: "Open navigation"
  attr :items, :list, required: true
  attr :class, :any, default: nil

  @doc "Renders compact navigation as a native details/summary disclosure."
  def responsive_navigation(assigns) do
    id = dom_id!(assigns.id, :id)

    items =
      normalize_links!(
        assigns.items,
        :responsive_navigation,
        @max_primary_items + @max_utility_items,
        false
      )

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:summary, text!(assigns.summary, :summary))
      |> assign(:items, items)

    ~H"""
    <UI.disclosure id={@id} mode={:independent} class={@class} data-application-responsive-navigation>
      <:item key="navigation" summary={@summary}>
        <nav id={"#{@id}-links"} aria-label="Compact navigation">
          <ul class="grid gap-1">
            <li :for={item <- @items}>
              <UI.link
                id={"#{@id}-item-#{item.key}"}
                href={item.href}
                aria-current={item.current && "page"}
                class="block min-h-[var(--touch-target)] rounded-md px-3 py-2 no-underline hover:bg-accent"
              >
                {item.label}
              </UI.link>
            </li>
          </ul>
        </nav>
      </:item>
    </UI.disclosure>
    """
  end

  attr :id, :string, required: true
  attr :context, :map, required: true
  attr :class, :any, default: nil

  @doc "Explains caller-shaped route, scope, role, assurance, and readiness labels."
  def context_explanation(assigns) do
    id = dom_id!(assigns.id, :id)
    context = normalize_context!(assigns.context)
    assigns = assigns |> assign(:id, id) |> assign(:context, context)

    ~H"""
    <aside
      id={@id}
      aria-labelledby={"#{@id}-title"}
      data-application-context-explanation
      data-readiness-state={@context.readiness}
      class={[
        "mx-auto grid w-full max-w-[var(--layout-content)] gap-3 px-4 py-4 sm:px-6 lg:px-8",
        @class
      ]}
    >
      <div>
        <h2 id={"#{@id}-title"} class="text-sm font-semibold">Current application context</h2>
        <p id={"#{@id}-explanation"} class="mt-1 text-sm text-muted-foreground">
          {@context.explanation}
        </p>
      </div>
      <dl class="grid gap-3 text-sm sm:grid-cols-2 lg:grid-cols-4">
        <div>
          <dt class="text-xs font-medium uppercase tracking-wide text-muted-foreground">Route</dt>
          <dd id={"#{@id}-route"} class="mt-1 font-medium">{@context.route_label}</dd>
        </div>
        <div>
          <dt class="text-xs font-medium uppercase tracking-wide text-muted-foreground">Scope</dt>
          <dd id={"#{@id}-scope"} class="mt-1 font-medium">{@context.scope_label}</dd>
        </div>
        <div>
          <dt class="text-xs font-medium uppercase tracking-wide text-muted-foreground">Role</dt>
          <dd id={"#{@id}-role"} class="mt-1 font-medium">{@context.role_label}</dd>
        </div>
        <div>
          <dt class="text-xs font-medium uppercase tracking-wide text-muted-foreground">
            Assurance
          </dt>
          <dd id={"#{@id}-assurance"} class="mt-1 font-medium">{@context.assurance_label}</dd>
        </div>
      </dl>
      <UI.status id={"#{@id}-readiness"} kind={@context.presentation.status}>
        <span class="inline-flex items-center gap-2">
          <span aria-hidden="true"><.icon name={@context.presentation.icon} class="size-5" /></span>
          <span><strong>Readiness:</strong> {@context.readiness_label}</span>
        </span>
      </UI.status>
    </aside>
    """
  end

  attr :id, :string, required: true
  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :summary, :string, required: true
  attr :actions, :list, default: []
  attr :class, :any, default: nil

  @doc "Renders a stable page title/focus target and bounded read-only action area."
  def page_header(assigns) do
    id = dom_id!(assigns.id, :id)
    actions = normalize_links!(assigns.actions, :page_actions, @max_page_actions, true)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:eyebrow, optional_text!(assigns.eyebrow, :eyebrow))
      |> assign(:title, text!(assigns.title, :title))
      |> assign(:summary, text!(assigns.summary, :summary))
      |> assign(:actions, actions)

    ~H"""
    <header
      id={@id}
      data-application-page-header
      class={["grid gap-5 border-b border-border pb-6 md:grid-cols-[minmax(0,1fr)_auto]", @class]}
    >
      <div class="min-w-0">
        <p :if={@eyebrow} id={"#{@id}-eyebrow"} class="text-sm font-medium text-primary">
          {@eyebrow}
        </p>
        <h1
          id={"#{@id}-title"}
          tabindex="-1"
          class="mt-1 break-words text-3xl font-semibold tracking-tight"
        >
          {@title}
        </h1>
        <p id={"#{@id}-summary"} class="mt-2 max-w-3xl break-words text-muted-foreground">
          {@summary}
        </p>
      </div>
      <nav :if={@actions != []} id={"#{@id}-actions"} aria-label="Page actions">
        <ul class="flex flex-wrap gap-2">
          <li :for={action <- @actions}>
            <UI.link
              id={"#{@id}-action-#{action.key}"}
              href={action.href}
              class="inline-flex min-h-[var(--touch-target)] items-center rounded-md border border-border px-4 py-2 no-underline hover:bg-accent"
            >
              {action.label}
            </UI.link>
          </li>
        </ul>
      </nav>
    </header>
    """
  end

  attr :id, :string, required: true
  attr :form, :any, required: true
  attr :query_field, :any, required: true
  attr :action, :string, required: true
  attr :search_label, :string, default: "Search"
  attr :placeholder, :string, default: "Search"
  attr :submit_label, :string, default: "Apply filters"
  attr :filters, :list, default: []
  attr :reset, :any, default: nil
  attr :class, :any, default: nil

  @doc "Renders native GET search/filter controls from pre-shaped fields and options."
  def filter_search(assigns) do
    id = dom_id!(assigns.id, :id)
    filters = normalize_filters!(assigns.filters)
    reset = normalize_optional_link!(assigns.reset, :reset)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:action, form_action!(assigns.action, :action))
      |> assign(:search_label, text!(assigns.search_label, :search_label))
      |> assign(:placeholder, text!(assigns.placeholder, :placeholder))
      |> assign(:submit_label, text!(assigns.submit_label, :submit_label))
      |> assign(:filters, filters)
      |> assign(:reset, reset)

    ~H"""
    <section
      id={@id}
      aria-labelledby={"#{@id}-title"}
      data-application-filter-search
      class={["rounded-lg border border-border bg-card p-4", @class]}
    >
      <h2 id={"#{@id}-title"} class="text-sm font-semibold">Filter and search</h2>
      <UI.form
        for={@form}
        id={"#{@id}-form"}
        action={@action}
        method="get"
        role="search"
        class="mt-4 grid items-end gap-4 md:grid-cols-2 lg:grid-cols-[minmax(16rem,1fr)_repeat(2,minmax(10rem,auto))_auto]"
      >
        <UI.input
          field={@query_field}
          id={"#{@id}-query"}
          type="search"
          label={@search_label}
          placeholder={@placeholder}
          autocomplete="off"
        />

        <UI.select
          :for={filter <- @filters}
          field={filter.field}
          id={"#{@id}-filter-#{filter.key}"}
          options={filter.options}
          size={:small}
        >
          <:label>{filter.label}</:label>
          <:help :if={filter.help}>{filter.help}</:help>
        </UI.select>

        <div id={"#{@id}-actions"} class="flex flex-wrap items-center gap-2">
          <UI.button id={"#{@id}-submit"} type="submit" size={:small}>
            {@submit_label}
          </UI.button>
          <UI.link
            :if={@reset}
            id={"#{@id}-reset"}
            href={@reset.href}
            class="inline-flex min-h-[var(--touch-target)] items-center px-2"
          >
            {@reset.label}
          </UI.link>
        </div>
      </UI.form>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :summary, :string, required: true
  attr :pages, :list, required: true
  attr :previous, :any, default: nil
  attr :next, :any, default: nil
  attr :class, :any, default: nil

  @doc "Renders bounded native pagination links and a textual result summary."
  def pagination(assigns) do
    id = dom_id!(assigns.id, :id)
    pages = normalize_pages!(assigns.pages)
    previous = normalize_optional_link!(assigns.previous, :previous)
    next = normalize_optional_link!(assigns.next, :next)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:summary, text!(assigns.summary, :summary))
      |> assign(:pages, pages)
      |> assign(:previous, previous)
      |> assign(:next, next)

    ~H"""
    <nav
      id={@id}
      aria-labelledby={"#{@id}-summary"}
      data-application-pagination
      class={["flex flex-wrap items-center justify-between gap-4", @class]}
    >
      <p id={"#{@id}-summary"} role="status" class="text-sm text-muted-foreground">
        {@summary}
      </p>
      <ul class="flex flex-wrap items-center gap-1">
        <li :if={@previous}>
          <UI.link id={"#{@id}-previous"} href={@previous.href} rel="prev">
            {@previous.label}
          </UI.link>
        </li>
        <li :for={page <- @pages}>
          <span
            :if={page.current}
            id={"#{@id}-page-#{page.key}"}
            aria-current="page"
            class="inline-flex min-h-[var(--touch-target)] min-w-[var(--touch-target)] items-center justify-center rounded-md bg-primary px-3 text-primary-foreground"
          >
            {page.label}
          </span>
          <UI.link
            :if={!page.current}
            id={"#{@id}-page-#{page.key}"}
            href={page.href}
            aria-label={"Page #{page.label}"}
            class="inline-flex min-h-[var(--touch-target)] min-w-[var(--touch-target)] items-center justify-center rounded-md px-3 no-underline hover:bg-accent"
          >
            {page.label}
          </UI.link>
        </li>
        <li :if={@next}>
          <UI.link id={"#{@id}-next"} href={@next.href} rel="next">
            {@next.label}
          </UI.link>
        </li>
      </ul>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, default: :empty
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :action, :any, default: nil
  attr :class, :any, default: nil

  @doc "Renders a closed empty/no-result/unavailable state with visible text."
  def empty_state(assigns) do
    id = dom_id!(assigns.id, :id)
    {state, icon} = closed_state!(assigns.state, @empty_states, :empty_state)
    action = normalize_optional_link!(assigns.action, :action)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(:icon, icon)
      |> assign(:title, text!(assigns.title, :title))
      |> assign(:message, text!(assigns.message, :message))
      |> assign(:action, action)

    ~H"""
    <section
      id={@id}
      aria-labelledby={"#{@id}-title"}
      data-application-empty-state
      data-empty-state={@state}
      class={[
        "grid justify-items-center gap-3 rounded-lg border border-dashed border-border px-6 py-10 text-center",
        @class
      ]}
    >
      <span aria-hidden="true"><.icon name={@icon} class="size-8 text-muted-foreground" /></span>
      <h2 id={"#{@id}-title"} class="text-lg font-semibold">{@title}</h2>
      <p id={"#{@id}-message"} class="max-w-xl break-words text-sm text-muted-foreground">
        {@message}
      </p>
      <UI.link
        :if={@action}
        id={"#{@id}-action"}
        href={@action.href}
        class="inline-flex min-h-[var(--touch-target)] items-center rounded-md border border-border px-4 py-2 no-underline hover:bg-accent"
      >
        {@action.label}
      </UI.link>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, default: "There is a problem"
  attr :errors, :list, required: true
  attr :class, :any, default: nil

  @doc "Renders a focusable, bounded error summary linked to stable field targets."
  def error_summary(assigns) do
    id = dom_id!(assigns.id, :id)
    errors = normalize_errors!(assigns.errors)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:title, text!(assigns.title, :title))
      |> assign(:errors, errors)

    ~H"""
    <section
      id={@id}
      role="alert"
      tabindex="-1"
      aria-labelledby={"#{@id}-title"}
      data-application-error-summary
      class={[
        "rounded-lg border border-destructive bg-destructive/10 px-4 py-4 text-foreground",
        @class
      ]}
    >
      <div class="flex items-start gap-3">
        <span aria-hidden="true">
          <.icon name="hero-exclamation-circle" class="mt-0.5 size-5 shrink-0" />
        </span>
        <div>
          <h2 id={"#{@id}-title"} class="font-semibold">{@title}</h2>
          <ul class="mt-2 list-disc space-y-1 pl-5 text-sm">
            <li :for={error <- @errors}>
              <UI.link id={"#{@id}-error-#{error.key}"} href={error.href}>
                {error.label}
              </UI.link>
            </li>
          </ul>
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :kind, :any, required: true
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :support, :any, default: nil
  attr :class, :any, default: nil

  @doc "Renders an explicit maintenance or degraded-service banner."
  def service_banner(assigns) do
    id = dom_id!(assigns.id, :id)
    {kind, presentation} = closed_state!(assigns.kind, @banner_kinds, :banner_kind)
    support = normalize_optional_link!(assigns.support, :support)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:kind, kind)
      |> assign(:presentation, presentation)
      |> assign(:title, text!(assigns.title, :title))
      |> assign(:message, text!(assigns.message, :message))
      |> assign(:support, support)

    ~H"""
    <section
      id={@id}
      role={@presentation.role}
      aria-labelledby={"#{@id}-title"}
      data-application-service-banner
      data-banner-kind={@kind}
      class={[
        "flex flex-wrap items-start gap-3 rounded-lg border border-border bg-muted px-4 py-3",
        @class
      ]}
    >
      <span aria-hidden="true">
        <.icon name={@presentation.icon} class="mt-0.5 size-5 shrink-0" />
      </span>
      <div class="min-w-0 flex-1">
        <h2 id={"#{@id}-title"} class="font-semibold">{@title}</h2>
        <p id={"#{@id}-message"} class="mt-1 break-words text-sm text-muted-foreground">
          {@message}
        </p>
      </div>
      <UI.link :if={@support} id={"#{@id}-support"} href={@support.href}>
        {@support.label}
      </UI.link>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :product_label, :string, required: true
  attr :metadata, :list, default: []
  attr :support_links, :list, default: []
  attr :class, :any, default: nil

  @doc "Renders bounded support links and already-shaped deployment metadata."
  def footer(assigns) do
    id = dom_id!(assigns.id, :id)
    metadata = normalize_metadata!(assigns.metadata)

    support_links =
      normalize_links!(assigns.support_links, :footer_links, @max_footer_links, true)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:product_label, text!(assigns.product_label, :product_label))
      |> assign(:metadata, metadata)
      |> assign(:support_links, support_links)

    ~H"""
    <footer
      id={@id}
      data-application-footer
      class={["border-t border-border bg-card text-card-foreground", @class]}
    >
      <div class="mx-auto grid w-full max-w-[var(--layout-content)] gap-5 px-4 py-6 text-sm sm:px-6 md:grid-cols-[minmax(0,1fr)_auto] lg:px-8">
        <div>
          <p id={"#{@id}-product"} class="font-semibold">{@product_label}</p>
          <dl id={"#{@id}-metadata"} class="mt-2 flex flex-wrap gap-x-5 gap-y-2 text-muted-foreground">
            <div :for={item <- @metadata} id={"#{@id}-metadata-#{item.key}"} class="flex gap-1">
              <dt>{item.label}:</dt>
              <dd>{item.value}</dd>
            </div>
          </dl>
        </div>
        <nav id={"#{@id}-support"} aria-label="Support">
          <ul class="flex flex-wrap gap-x-4 gap-y-2">
            <li :for={link <- @support_links}>
              <UI.link id={"#{@id}-support-#{link.key}"} href={link.href}>
                {link.label}
              </UI.link>
            </li>
          </ul>
        </nav>
      </div>
    </footer>
    """
  end

  defp normalize_brand!(brand) do
    brand =
      shaped_map!(brand, [:label, :href, :service_label], [:label, :href, :service_label], :brand)

    %{
      label: text!(brand.label, :brand_label),
      href: href!(brand.href, :brand_href),
      service_label: text!(brand.service_label, :service_label)
    }
  end

  defp normalize_account!(account) do
    account =
      shaped_map!(
        account,
        [:display_name, :session_label],
        [:display_name, :session_label],
        :account
      )

    %{
      display_name: text!(account.display_name, :display_name),
      session_label: text!(account.session_label, :session_label)
    }
  end

  defp normalize_attempt!(attempt) do
    attempt =
      shaped_map!(
        attempt,
        [:label, :reference, :scope_label, :state, :state_label],
        [:label, :reference, :scope_label, :state, :state_label],
        :attempt
      )

    {state, presentation} = closed_state!(attempt.state, @attempt_states, :attempt_state)

    %{
      label: text!(attempt.label, :attempt_label),
      reference: text!(attempt.reference, :attempt_reference),
      scope_label: text!(attempt.scope_label, :attempt_scope),
      state: state,
      state_label: text!(attempt.state_label, :attempt_state_label),
      presentation: presentation
    }
  end

  defp normalize_context!(context) do
    context =
      shaped_map!(
        context,
        [
          :route_label,
          :scope_label,
          :role_label,
          :assurance_label,
          :readiness,
          :readiness_label,
          :explanation
        ],
        [
          :route_label,
          :scope_label,
          :role_label,
          :assurance_label,
          :readiness,
          :readiness_label,
          :explanation
        ],
        :context
      )

    {readiness, presentation} =
      closed_state!(context.readiness, @readiness_states, :readiness)

    %{
      route_label: text!(context.route_label, :route_label),
      scope_label: text!(context.scope_label, :scope_label),
      role_label: text!(context.role_label, :role_label),
      assurance_label: text!(context.assurance_label, :assurance_label),
      readiness: readiness,
      readiness_label: text!(context.readiness_label, :readiness_label),
      explanation: text!(context.explanation, :explanation),
      presentation: presentation
    }
  end

  defp normalize_links!(items, name, maximum, allow_empty?) do
    items = bounded_list!(items, name, maximum, allow_empty?)

    normalized =
      Enum.map(items, fn item ->
        item = shaped_map!(item, [:key, :label, :href, :current], [:key, :label, :href], name)

        %{
          key: dom_key!(item.key, :key),
          label: text!(item.label, :label),
          href: href!(item.href, :href),
          current: boolean!(Map.get(item, :current, false), :current)
        }
      end)

    ensure_unique_keys!(normalized, name)
  end

  defp normalize_breadcrumbs!(items) do
    items = bounded_list!(items, :breadcrumbs, @max_breadcrumbs, false)

    normalized =
      Enum.map(items, fn item ->
        item =
          shaped_map!(
            item,
            [:key, :label, :href, :current],
            [:key, :label, :current],
            :breadcrumb
          )

        current = boolean!(item.current, :current)

        %{
          key: dom_key!(item.key, :key),
          label: text!(item.label, :label),
          href: if(current, do: nil, else: href!(Map.get(item, :href), :href)),
          current: current
        }
      end)

    normalized = ensure_unique_keys!(normalized, :breadcrumbs)

    if Enum.count(normalized, & &1.current) != 1 or not List.last(normalized).current do
      raise ArgumentError, "breadcrumbs require exactly one final current item"
    end

    last_index = length(normalized) - 1

    normalized
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> Map.put(item, :last, index == last_index) end)
  end

  defp normalize_options!(options, name, maximum) do
    options = bounded_list!(options, name, maximum, false)

    normalized =
      Enum.map(options, fn option ->
        option =
          shaped_map!(
            option,
            [:key, :value, :label, :disabled],
            [:key, :value, :label],
            name
          )

        %{
          key: dom_key!(option.key, :key),
          value: text!(option.value, :value),
          label: text!(option.label, :label),
          disabled: boolean!(Map.get(option, :disabled, false), :disabled)
        }
      end)

    ensure_unique_keys!(normalized, name)
  end

  defp normalize_filters!(filters) do
    filters = bounded_list!(filters, :filters, @max_filters, true)

    normalized =
      Enum.map(filters, fn filter ->
        filter =
          shaped_map!(
            filter,
            [:key, :label, :help, :field, :options],
            [:key, :label, :field, :options],
            :filter
          )

        %{
          key: dom_key!(filter.key, :key),
          label: text!(filter.label, :label),
          help: optional_text!(Map.get(filter, :help), :help),
          field: filter.field,
          options: normalize_options!(filter.options, :filter_options, @max_filter_options)
        }
      end)

    ensure_unique_keys!(normalized, :filters)
  end

  defp normalize_pages!(pages) do
    pages = bounded_list!(pages, :pages, @max_pagination_pages, false)

    normalized =
      Enum.map(pages, fn page ->
        page = shaped_map!(page, [:key, :label, :href, :current], [:key, :label, :current], :page)
        current = boolean!(page.current, :current)

        %{
          key: dom_key!(page.key, :key),
          label: text!(page.label, :label),
          href: if(current, do: nil, else: href!(Map.get(page, :href), :href)),
          current: current
        }
      end)

    normalized = ensure_unique_keys!(normalized, :pages)

    if Enum.count(normalized, & &1.current) != 1 do
      raise ArgumentError, "pages require exactly one current item"
    end

    normalized
  end

  defp normalize_errors!(errors) do
    errors = bounded_list!(errors, :errors, @max_errors, false)

    normalized =
      Enum.map(errors, fn error ->
        error = shaped_map!(error, [:key, :label, :target_id], [:key, :label, :target_id], :error)
        target_id = dom_id!(error.target_id, :target_id)

        %{
          key: dom_key!(error.key, :key),
          label: text!(error.label, :label),
          href: "##{target_id}"
        }
      end)

    ensure_unique_keys!(normalized, :errors)
  end

  defp normalize_metadata!(metadata) do
    metadata = bounded_list!(metadata, :metadata, @max_footer_metadata, true)

    normalized =
      Enum.map(metadata, fn item ->
        item = shaped_map!(item, [:key, :label, :value], [:key, :label, :value], :metadata)

        %{
          key: dom_key!(item.key, :key),
          label: text!(item.label, :label),
          value: text!(item.value, :value)
        }
      end)

    ensure_unique_keys!(normalized, :metadata)
  end

  defp normalize_optional_link!(nil, _name), do: nil

  defp normalize_optional_link!(link, name) do
    link = shaped_map!(link, [:label, :href], [:label, :href], name)
    %{label: text!(link.label, :label), href: href!(link.href, :href)}
  end

  defp closed_state!(state, states, name) when is_atom(state) do
    case Map.fetch(states, state) do
      {:ok, presentation} -> {state, presentation}
      :error -> raise ArgumentError, "unsupported #{name}: #{inspect(state)}"
    end
  end

  defp closed_state!(state, _states, name) do
    raise ArgumentError, "unsupported #{name}: #{inspect(state)}"
  end

  defp shaped_map!(value, allowed, required, name) when is_map(value) and not is_struct(value) do
    keys = Map.keys(value)
    unknown = keys -- allowed
    missing = required -- keys

    if unknown != [] or missing != [] do
      raise ArgumentError,
            "#{name} must be a closed presentation map; unknown=#{inspect(unknown)} missing=#{inspect(missing)}"
    end

    value
  end

  defp shaped_map!(value, _allowed, _required, name) do
    raise ArgumentError, "#{name} must be a plain presentation map, got: #{inspect(value)}"
  end

  defp bounded_list!(items, name, maximum, allow_empty?) when is_list(items) do
    cond do
      not allow_empty? and items == [] ->
        raise ArgumentError, "#{name} must not be empty"

      length(items) > maximum ->
        raise ArgumentError, "#{name} exceeds the maximum of #{maximum} items"

      true ->
        items
    end
  end

  defp bounded_list!(items, name, _maximum, _allow_empty?) do
    raise ArgumentError, "#{name} must be a list, got: #{inspect(items)}"
  end

  defp ensure_unique_keys!(items, name) do
    keys = Enum.map(items, & &1.key)

    if length(keys) != length(Enum.uniq(keys)) do
      raise ArgumentError, "#{name} keys must be unique"
    end

    items
  end

  defp dom_id!(value, name) when is_binary(value) do
    value = String.trim(value)

    if byte_size(value) <= @max_dom_id_bytes and
         Regex.match?(~r/^[A-Za-z][A-Za-z0-9_.:-]*$/u, value) do
      value
    else
      raise ArgumentError, "#{name} must be a stable DOM id"
    end
  end

  defp dom_id!(value, name),
    do: raise(ArgumentError, "#{name} must be a stable DOM id: #{inspect(value)}")

  defp dom_key!(value, name) when is_binary(value) do
    value = String.trim(value)

    if byte_size(value) <= @max_dom_key_bytes and
         Regex.match?(~r/^[A-Za-z0-9][A-Za-z0-9_.-]*$/u, value) do
      value
    else
      raise ArgumentError, "#{name} must be a stable DOM key"
    end
  end

  defp dom_key!(value, name),
    do: raise(ArgumentError, "#{name} must be a stable DOM key: #{inspect(value)}")

  defp text!(value, name) when is_binary(value) do
    case String.trim(value) do
      "" -> raise ArgumentError, "#{name} must be nonblank text"
      text when byte_size(text) > @max_text_bytes -> raise ArgumentError, "#{name} is too long"
      text -> text
    end
  end

  defp text!(value, name),
    do: raise(ArgumentError, "#{name} must be text, got: #{inspect(value)}")

  defp optional_text!(nil, _name), do: nil
  defp optional_text!(value, name), do: text!(value, name)

  defp boolean!(value, _name) when is_boolean(value), do: value

  defp boolean!(value, name),
    do: raise(ArgumentError, "#{name} must be boolean: #{inspect(value)}")

  defp href!(value, name) do
    href = text!(value, name)

    if safe_native_destination?(href) and
         ((String.starts_with?(href, "/") and not String.starts_with?(href, "//")) or
            String.starts_with?(href, "#") or String.starts_with?(href, "https://") or
            String.starts_with?(href, "http://") or String.starts_with?(href, "mailto:") or
            String.starts_with?(href, "tel:")) do
      href
    else
      raise ArgumentError, "#{name} must use a supported native destination"
    end
  end

  defp form_action!(value, name) do
    action = text!(value, name)

    if safe_native_destination?(action) and String.starts_with?(action, "/") and
         not String.starts_with?(action, "//") do
      action
    else
      raise ArgumentError, "#{name} must be an application-relative form action"
    end
  end

  defp safe_native_destination?(value) do
    not String.contains?(value, "\\") and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
  end
end
