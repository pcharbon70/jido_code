defmodule JidoCodeWeb.Components.Projection do
  @moduledoc """
  Stateless presentation components for bounded, already-authorized projections.

  These components never query data, resolve resources, select authority, or
  retain browser state. Callers provide a shaped presentation view after every
  required authorization and redaction boundary.
  """

  use Phoenix.Component

  import JidoCodeWeb.CoreComponents, only: [icon: 1]

  alias JidoCodeWeb.Components.UI

  @canonical_states [
    :ready,
    :empty,
    :stale,
    :incomplete,
    :contradicted,
    :truncated,
    :unauthorized,
    :unavailable,
    :maintenance,
    :recovery
  ]

  @canonical_by_name Map.new(@canonical_states, &{Atom.to_string(&1), &1})
  @aliases %{
    partial: :incomplete,
    contradiction: :contradicted,
    concealed: :unauthorized,
    denied: :unauthorized,
    unconfigured: :unavailable
  }
  @aliases_by_name Map.new(@aliases, fn {alias_name, canonical} ->
                     {Atom.to_string(alias_name), canonical}
                   end)

  @protected_states [:unauthorized, :unavailable, :maintenance, :recovery]
  @retryable_states [
    :stale,
    :incomplete,
    :contradicted,
    :truncated,
    :unavailable,
    :maintenance,
    :recovery
  ]
  @attention_limit 24
  @health_limit 12
  @fleet_limit 50
  @rail_limit 12
  @label_limit 160
  @detail_limit 320
  @href_byte_limit 320
  @budget_numeric_limit 1_000_000_000_000_000
  @id_pattern ~r/^[A-Za-z][A-Za-z0-9_.:-]{0,95}$/u

  @state_presentation %{
    ready: %{
      label: "Ready",
      message: "Current projection data is ready.",
      icon: "hero-check-circle",
      variant: :default
    },
    empty: %{
      label: "No results",
      message: "No authorized results match this view.",
      icon: "hero-inbox",
      variant: :outline
    },
    stale: %{
      label: "Stale",
      message: "The displayed data is older than the accepted freshness target.",
      icon: "hero-clock",
      variant: :secondary
    },
    incomplete: %{
      label: "Incomplete",
      message: "The projection is usable but does not contain every expected fact.",
      icon: "hero-ellipsis-horizontal-circle",
      variant: :secondary
    },
    contradicted: %{
      label: "Contradicted",
      message: "Current sources disagree. Review provenance before relying on this view.",
      icon: "hero-exclamation-circle",
      variant: :destructive
    },
    truncated: %{
      label: "Truncated",
      message: "The projection reached an accepted display bound.",
      icon: "hero-bars-arrow-down",
      variant: :secondary
    },
    unauthorized: %{
      label: "Not available",
      message: "This projection is not available.",
      icon: "hero-lock-closed",
      variant: :outline
    },
    unavailable: %{
      label: "Unavailable",
      message:
        "Projection data is currently unavailable. Previously displayed rows were cleared.",
      icon: "hero-no-symbol",
      variant: :destructive
    },
    maintenance: %{
      label: "Maintenance",
      message:
        "Projection data is unavailable during maintenance. Previously displayed rows were cleared.",
      icon: "hero-wrench-screwdriver",
      variant: :secondary
    },
    recovery: %{
      label: "Recovery",
      message: "Projection recovery is in progress. Previously displayed rows were cleared.",
      icon: "hero-arrow-path",
      variant: :secondary
    }
  }

  @doc "Returns the exact projection-state vocabulary emitted into rendered DOM contracts."
  @spec canonical_states() :: [atom()]
  def canonical_states, do: @canonical_states

  @doc """
  Normalizes a closed canonical state or one documented compatibility alias.

  Aliases are accepted only through this function. Rendered state attributes
  always contain the returned canonical state. Loading and generic error are
  deliberately absent because connection/composition state is not projection
  truth and an error must be shaped to a canonical safe outcome by the caller.
  """
  @spec normalize_state(atom() | String.t()) ::
          {:ok, atom()} | {:error, :unsupported_projection_state}
  def normalize_state(state) when is_atom(state) do
    cond do
      state in @canonical_states -> {:ok, state}
      Map.has_key?(@aliases, state) -> {:ok, Map.fetch!(@aliases, state)}
      true -> {:error, :unsupported_projection_state}
    end
  end

  def normalize_state(state) when is_binary(state) do
    case Map.fetch(@canonical_by_name, state) do
      {:ok, canonical} -> {:ok, canonical}
      :error -> normalize_alias_name(state)
    end
  end

  def normalize_state(_state), do: {:error, :unsupported_projection_state}

  @doc "Returns the defensive presentation ceilings owned by this component layer."
  @spec limits() :: map()
  def limits do
    %{
      attention_items: @attention_limit,
      health_items: @health_limit,
      fleet_rows: @fleet_limit,
      rail_items: @rail_limit,
      label_graphemes: @label_limit,
      detail_graphemes: @detail_limit,
      href_bytes: @href_byte_limit,
      budget_numeric_max: @budget_numeric_limit
    }
  end

  attr :id, :string, required: true
  attr :state, :any, required: true
  attr :title, :string, default: nil
  attr :message, :string, default: nil
  attr :retry_href, :string, default: nil
  attr :retry_label, :string, default: "Retry this projection"
  attr :class, :any, default: nil

  @doc "Renders one canonical projection outcome and an optional safe native retry."
  def projection_status(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    presentation = Map.fetch!(@state_presentation, state)
    protected? = protected_state?(state)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(:state_label, presentation.label)
      |> assign(:state_icon, presentation.icon)
      |> assign(
        :title_text,
        if(protected?,
          do: presentation.label,
          else: bounded_text(assigns.title, presentation.label, @label_limit)
        )
      )
      |> assign(
        :message_text,
        if(protected?,
          do: presentation.message,
          else: bounded_text(assigns.message, presentation.message, @detail_limit)
        )
      )
      |> assign(:retry_href, retry_href(assigns.retry_href, state))
      |> assign(
        :retry_label,
        protected_text(
          state,
          assigns.retry_label,
          "Retry this projection",
          @label_limit
        )
      )

    ~H"""
    <section
      id={@id}
      role="status"
      aria-labelledby={@id <> "-title"}
      aria-describedby={@id <> "-message"}
      data-projection-status
      data-projection-state={@state}
      class={[
        "rounded-lg border border-border bg-card px-4 py-3 text-card-foreground",
        @class
      ]}
    >
      <div class="flex items-start gap-3">
        <.icon name={@state_icon} class="mt-0.5 size-5 shrink-0" />
        <div class="min-w-0 flex-1">
          <h3 id={@id <> "-title"} class="text-sm font-semibold">{@title_text}</h3>
          <p id={@id <> "-message"} class="mt-1 break-words text-sm text-muted-foreground">
            {@message_text}
          </p>
          <UI.link :if={@retry_href} id={@id <> "-retry"} href={@retry_href} class="mt-2 inline-flex">
            {@retry_label}
          </UI.link>
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, required: true
  attr :title, :string, default: "Projection trust"
  attr :revision, :any, default: nil
  attr :freshness, :any, default: nil
  attr :source, :any, default: nil
  attr :as_of, :any, default: nil
  attr :completeness, :any, default: nil
  attr :class, :any, default: nil

  @doc "Renders bounded provenance and freshness metadata for one projection."
  def trust_header(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    protected? = protected_state?(state)

    metadata =
      if protected? do
        []
      else
        [
          {"Revision", bounded_optional(assigns.revision, @label_limit)},
          {"Freshness", bounded_optional(assigns.freshness, @label_limit)},
          {"Source", bounded_optional(assigns.source, @label_limit)},
          {"As of", bounded_optional(assigns.as_of, @label_limit)},
          {"Completeness", bounded_optional(assigns.completeness, @detail_limit)}
        ]
        |> Enum.reject(fn {_label, value} -> is_nil(value) end)
      end

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(
        :title,
        protected_text(state, assigns.title, "Projection trust", @label_limit)
      )
      |> assign(:metadata, metadata)

    ~H"""
    <header
      id={@id}
      aria-labelledby={@id <> "-title"}
      data-projection-trust
      data-projection-state={@state}
      class={[
        "grid gap-3 rounded-lg border border-border bg-card px-4 py-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-start",
        @class
      ]}
    >
      <div class="min-w-0">
        <h2 id={@id <> "-title"} class="text-base font-semibold">{@title}</h2>
        <.readiness_badge id={@id <> "-state"} state={@state} class="mt-2" />
      </div>
      <dl
        :if={@metadata != []}
        id={@id <> "-metadata"}
        class="grid gap-x-5 gap-y-2 text-sm sm:grid-cols-2"
      >
        <div
          :for={{{label, value}, index} <- Enum.with_index(@metadata)}
          id={@id <> "-metadata-" <> Integer.to_string(index + 1)}
        >
          <dt class="font-medium text-muted-foreground">{label}</dt>
          <dd class="break-words text-foreground">{value}</dd>
        </div>
      </dl>
    </header>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, required: true
  attr :label, :string, default: nil
  attr :class, :any, default: nil

  @doc "Renders a passive, text-and-icon readiness label."
  def readiness_badge(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    presentation = Map.fetch!(@state_presentation, state)

    label =
      if protected_state?(state),
        do: presentation.label,
        else: bounded_text(assigns.label, presentation.label, @label_limit)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(:label, label)
      |> assign(:icon_name, presentation.icon)
      |> assign(:variant, presentation.variant)

    ~H"""
    <UI.badge
      id={@id}
      variant={@variant}
      data-readiness-badge
      data-projection-state={@state}
      class={["inline-flex items-center gap-1.5", @class]}
    >
      <.icon name={@icon_name} class="size-4" />
      <span>{@label}</span>
    </UI.badge>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, required: true
  attr :title, :string, default: "Needs attention"
  attr :items, :list, default: []
  attr :empty_message, :string, default: "No authorized items need attention."
  attr :retry_href, :string, default: nil
  attr :class, :any, default: nil

  @doc "Renders a bounded list of already-authorized attention items."
  def attention_list(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    {items, truncated?} = visible_items(assigns.items, state, @attention_limit)

    items =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} ->
        %{
          list_id: "#{id}-item-#{index}",
          card_id: "#{id}-card-#{index}",
          source: item
        }
      end)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(
        :title,
        protected_text(state, assigns.title, "Needs attention", @label_limit)
      )
      |> assign(:items, items)
      |> assign(:truncated?, truncated?)
      |> assign(:limit, @attention_limit)
      |> assign(
        :empty_message,
        bounded_text(assigns.empty_message, "No authorized items need attention.", @detail_limit)
      )

    ~H"""
    <section
      id={@id}
      aria-labelledby={@id <> "-title"}
      data-attention-list
      data-projection-state={@state}
      class={["grid gap-4", @class]}
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h2 id={@id <> "-title"} class="text-xl font-semibold">{@title}</h2>
        <.readiness_badge id={@id <> "-readiness"} state={@state} />
      </div>

      <.projection_status
        :if={@state != :ready and @state != :empty}
        id={@id <> "-status"}
        state={@state}
        retry_href={@retry_href}
      />

      <p
        :if={@state == :empty or (@items == [] and not protected_state?(@state))}
        id={@id <> "-no-results"}
        data-no-results
        class="rounded-lg border border-dashed border-border px-4 py-6 text-sm text-muted-foreground"
      >
        {@empty_message}
      </p>

      <ul :if={@items != []} id={@id <> "-items"} class="grid gap-3" aria-label={@title}>
        <li :for={item <- @items} id={item.list_id}>
          <.attention_card id={item.card_id} item={item.source} />
        </li>
      </ul>

      <p
        :if={@truncated?}
        id={@id <> "-bounded-notice"}
        role="status"
        data-bounded-notice
        class="text-sm font-medium text-muted-foreground"
      >
        Showing the first {@limit} authorized attention items. Refine the current view to see a smaller result set.
      </p>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :item, :map, required: true
  attr :class, :any, default: nil

  @doc "Renders one bounded attention card from a shaped presentation map."
  def attention_card(assigns) do
    id = component_id!(assigns.id)
    item = normalize_attention(assigns.item)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:item, item)

    ~H"""
    <article
      id={@id}
      aria-labelledby={@id <> "-title"}
      data-attention-item
      data-severity={@item.severity}
      class={[
        "rounded-lg border border-border bg-card px-4 py-4 text-card-foreground",
        @class
      ]}
    >
      <div class="flex items-start gap-3">
        <.icon name={@item.icon} class="mt-0.5 size-5 shrink-0" />
        <div class="min-w-0 flex-1">
          <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            {@item.severity_label}
          </p>
          <h3 id={@id <> "-title"} class="mt-1 break-words font-semibold">{@item.title}</h3>
          <p id={@id <> "-reason"} class="mt-2 break-words text-sm text-muted-foreground">
            {@item.reason}
          </p>
          <dl :if={@item.metadata != []} class="mt-3 grid gap-x-4 gap-y-2 text-sm sm:grid-cols-3">
            <div
              :for={{{label, value}, index} <- Enum.with_index(@item.metadata)}
              id={@id <> "-metadata-" <> Integer.to_string(index + 1)}
            >
              <dt class="font-medium text-muted-foreground">{label}</dt>
              <dd class="break-words">{value}</dd>
            </div>
          </dl>
          <div
            :if={@item.destination_href || @item.evidence_href}
            class="mt-4 flex flex-wrap gap-4 text-sm"
          >
            <UI.link
              :if={@item.destination_href}
              id={@id <> "-destination"}
              href={@item.destination_href}
            >
              {@item.destination_label}
            </UI.link>
            <.evidence_link
              :if={@item.evidence_href}
              id={@id <> "-evidence"}
              href={@item.evidence_href}
              label={@item.evidence_label}
            />
          </div>
        </div>
      </div>
    </article>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, required: true
  attr :title, :string, default: "Factory health"
  attr :items, :list, default: []
  attr :retry_href, :string, default: nil
  attr :class, :any, default: nil

  @doc "Renders a bounded health metric summary without deriving health from color."
  def health_summary(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    {items, truncated?} = visible_items(assigns.items, state, @health_limit)

    items =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} -> normalize_health(item, id, index) end)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(
        :title,
        protected_text(state, assigns.title, "Factory health", @label_limit)
      )
      |> assign(:items, items)
      |> assign(:truncated?, truncated?)
      |> assign(:limit, @health_limit)

    ~H"""
    <section
      id={@id}
      aria-labelledby={@id <> "-title"}
      data-health-summary
      data-projection-state={@state}
      class={["grid gap-4", @class]}
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h2 id={@id <> "-title"} class="text-xl font-semibold">{@title}</h2>
        <.readiness_badge id={@id <> "-readiness"} state={@state} />
      </div>

      <.projection_status
        :if={protected_state?(@state)}
        id={@id <> "-status"}
        state={@state}
        retry_href={@retry_href}
      />

      <p
        :if={@state == :empty or (@items == [] and not protected_state?(@state))}
        id={@id <> "-no-results"}
        data-no-results
        class="rounded-lg border border-dashed border-border px-4 py-6 text-sm text-muted-foreground"
      >
        No authorized health metrics are available for this view.
      </p>

      <dl :if={@items != []} id={@id <> "-items"} class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <div
          :for={item <- @items}
          id={item.id}
          data-health-item
          data-health-status={item.status}
          class="rounded-lg border border-border bg-card px-4 py-4"
        >
          <dt class="flex items-center gap-2 text-sm font-medium text-muted-foreground">
            <.icon name={item.icon} class="size-4" />
            <span class="break-words">{item.label}</span>
          </dt>
          <dd class="mt-2 break-words text-2xl font-semibold">{item.value}</dd>
          <p class="mt-1 text-sm font-medium">{item.status_label}</p>
          <p :if={item.detail} class="mt-1 break-words text-sm text-muted-foreground">
            {item.detail}
          </p>
        </div>
      </dl>

      <p
        :if={@truncated?}
        id={@id <> "-bounded-notice"}
        role="status"
        data-bounded-notice
        class="text-sm text-muted-foreground"
      >
        Showing the first {@limit} authorized health metrics.
      </p>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, required: true
  attr :title, :string, default: "Fleet and projects"
  attr :caption, :string, default: "Authorized fleet and project summary"
  attr :rows, :list, default: []
  attr :sort_column, :any, default: nil
  attr :sort_direction, :any, default: :none
  attr :sort_hrefs, :map, default: %{}
  attr :page, :integer, default: 1
  attr :page_count, :any, default: nil
  attr :previous_href, :string, default: nil
  attr :next_href, :string, default: nil
  attr :page_summary, :string, default: nil
  attr :retry_href, :string, default: nil
  attr :class, :any, default: nil

  @doc "Renders one bounded fleet/project collection as a table and narrow-screen cards."
  def fleet_project_table(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    {rows, truncated?} = visible_items(assigns.rows, state, @fleet_limit)

    rows =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, index} -> normalize_fleet_row(row, id, index) end)

    sort_column = normalize_sort_column(assigns.sort_column)
    sort_direction = normalize_sort_direction(assigns.sort_direction)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(
        :title,
        protected_text(state, assigns.title, "Fleet and projects", @label_limit)
      )
      |> assign(
        :caption,
        protected_text(
          state,
          assigns.caption,
          "Authorized fleet and project summary",
          @detail_limit
        )
      )
      |> assign(:rows, rows)
      |> assign(:truncated?, truncated?)
      |> assign(:limit, @fleet_limit)
      |> assign(:sort_column, sort_column)
      |> assign(:sort_direction, sort_direction)
      |> assign(:sort_hrefs, normalize_sort_hrefs(assigns.sort_hrefs))

    ~H"""
    <section
      id={@id}
      aria-labelledby={@id <> "-title"}
      data-fleet-project-collection
      data-projection-state={@state}
      class={["grid gap-4", @class]}
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h2 id={@id <> "-title"} class="text-xl font-semibold">{@title}</h2>
        <.readiness_badge id={@id <> "-readiness"} state={@state} />
      </div>

      <.projection_status
        :if={protected_state?(@state)}
        id={@id <> "-status"}
        state={@state}
        retry_href={@retry_href}
      />

      <p
        :if={@state == :empty or (@rows == [] and not protected_state?(@state))}
        id={@id <> "-no-results"}
        data-no-results
        class="rounded-lg border border-dashed border-border px-4 py-6 text-sm text-muted-foreground"
      >
        No authorized fleet or project rows match this view.
      </p>

      <div
        :if={@rows != []}
        id={@id <> "-wide"}
        data-collection-layout="table"
        class="hidden md:block"
      >
        <UI.table id={@id <> "-table"} caption={@caption}>
          <:head>
            <tr>
              <.sort_header
                id={@id <> "-project-heading"}
                column={:project}
                label="Project"
                current={@sort_column}
                direction={@sort_direction}
                href={Map.get(@sort_hrefs, :project)}
              />
              <.sort_header
                id={@id <> "-work-heading"}
                column={:work}
                label="Work"
                current={@sort_column}
                direction={@sort_direction}
                href={Map.get(@sort_hrefs, :work)}
                class="hidden lg:table-cell"
              />
              <.sort_header
                id={@id <> "-agent-heading"}
                column={:agent}
                label="Agent"
                current={@sort_column}
                direction={@sort_direction}
                href={Map.get(@sort_hrefs, :agent)}
                class="hidden xl:table-cell"
              />
              <.sort_header
                id={@id <> "-stage-heading"}
                column={:stage}
                label="Stage"
                current={@sort_column}
                direction={@sort_direction}
                href={Map.get(@sort_hrefs, :stage)}
              />
              <.sort_header
                id={@id <> "-health-heading"}
                column={:health}
                label="Health"
                current={@sort_column}
                direction={@sort_direction}
                href={Map.get(@sort_hrefs, :health)}
              />
              <.sort_header
                id={@id <> "-freshness-heading"}
                column={:freshness}
                label="Freshness"
                current={@sort_column}
                direction={@sort_direction}
                href={Map.get(@sort_hrefs, :freshness)}
                class="hidden lg:table-cell"
              />
            </tr>
          </:head>
          <tr
            :for={row <- @rows}
            id={row.table_id}
            data-fleet-row
            class="border-b border-border last:border-b-0"
          >
            <th scope="row" class="px-3 py-3 font-medium">
              <UI.link :if={row.project_href} id={row.table_id <> "-project"} href={row.project_href}>{row.project}</UI.link>
              <span :if={is_nil(row.project_href)}>{row.project}</span>
            </th>
            <td class="hidden px-3 py-3 lg:table-cell">{row.work}</td>
            <td class="hidden px-3 py-3 xl:table-cell">{row.agent}</td>
            <td class="px-3 py-3">{row.stage}</td>
            <td class="px-3 py-3">
              <.readiness_badge
                id={row.table_id <> "-health"}
                state={row.health_state}
                label={row.health}
              />
            </td>
            <td class="hidden px-3 py-3 lg:table-cell">{row.freshness}</td>
          </tr>
        </UI.table>
      </div>

      <ul
        :if={@rows != []}
        id={@id <> "-cards"}
        data-collection-layout="cards"
        class="grid gap-3 md:hidden"
        aria-label={@caption <> " narrow-screen alternative"}
      >
        <li
          :for={row <- @rows}
          id={row.card_id}
          data-fleet-card
          class="rounded-lg border border-border bg-card px-4 py-4"
        >
          <h3 class="font-semibold">
            <UI.link :if={row.project_href} id={row.card_id <> "-project"} href={row.project_href}>{row.project}</UI.link>
            <span :if={is_nil(row.project_href)}>{row.project}</span>
          </h3>
          <dl class="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
            <div>
              <dt class="text-muted-foreground">Work</dt><dd>{row.work}</dd>
            </div>
            <div>
              <dt class="text-muted-foreground">Agent</dt><dd>{row.agent}</dd>
            </div>
            <div>
              <dt class="text-muted-foreground">Stage</dt><dd>{row.stage}</dd>
            </div>
            <div>
              <dt class="text-muted-foreground">Freshness</dt><dd>{row.freshness}</dd>
            </div>
          </dl>
          <.readiness_badge
            id={row.card_id <> "-health"}
            state={row.health_state}
            label={row.health}
            class="mt-3"
          />
        </li>
      </ul>

      <p
        :if={@truncated?}
        id={@id <> "-bounded-notice"}
        role="status"
        data-bounded-notice
        class="text-sm text-muted-foreground"
      >
        Showing the first {@limit} authorized rows. Refine the current view to continue.
      </p>

      <.pagination
        :if={@rows != []}
        id={@id <> "-pagination"}
        page={@page}
        page_count={@page_count}
        previous_href={@previous_href}
        next_href={@next_href}
        summary={@page_summary}
      />
    </section>
    """
  end

  attr :id, :string, required: true
  attr :column, :atom, required: true
  attr :label, :string, required: true
  attr :current, :any, default: nil
  attr :direction, :any, default: :none
  attr :href, :string, default: nil
  attr :class, :any, default: nil

  @doc false
  def sort_header(assigns) do
    id = component_id!(assigns.id)
    current? = assigns.current == assigns.column
    direction = if(current?, do: normalize_sort_direction(assigns.direction), else: :none)
    href = safe_href(assigns.href)
    label = bounded_text(assigns.label, "Column", @label_limit)

    next_direction = if(current? and direction == :ascending, do: "descending", else: "ascending")

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:direction, direction)
      |> assign(:href, href)
      |> assign(:label, label)
      |> assign(:next_direction, next_direction)

    ~H"""
    <th
      id={@id}
      scope="col"
      aria-sort={@direction}
      class={["px-3 py-2 text-left text-xs font-semibold uppercase tracking-wide", @class]}
    >
      <UI.link :if={@href} id={@id <> "-sort"} href={@href}>
        <span>{@label}</span>
        <span class="sr-only">, sort {@next_direction}</span>
      </UI.link>
      <span :if={is_nil(@href)}>{@label}</span>
    </th>
    """
  end

  attr :id, :string, required: true
  attr :page, :integer, default: 1
  attr :page_count, :any, default: nil
  attr :previous_href, :string, default: nil
  attr :next_href, :string, default: nil
  attr :summary, :string, default: nil
  attr :class, :any, default: nil

  @doc "Renders bounded native previous/next pagination with an explicit summary."
  def pagination(assigns) do
    id = component_id!(assigns.id)
    page = bounded_positive_integer(assigns.page, 1, 100_000)
    page_count = optional_page_count(assigns.page_count, page)

    default_summary =
      if page_count,
        do: "Page #{page} of #{page_count}",
        else: "Page #{page}; total page count is unavailable"

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:page, page)
      |> assign(:page_count, page_count)
      |> assign(:summary, bounded_text(assigns.summary, default_summary, @detail_limit))
      |> assign(:previous_href, safe_href(assigns.previous_href))
      |> assign(:next_href, safe_href(assigns.next_href))

    ~H"""
    <nav
      id={@id}
      aria-label="Pagination"
      data-pagination
      class={["flex flex-wrap items-center justify-between gap-3", @class]}
    >
      <p id={@id <> "-summary"} class="text-sm text-muted-foreground">{@summary}</p>
      <div class="flex items-center gap-3">
        <UI.link :if={@previous_href} id={@id <> "-previous"} href={@previous_href}>Previous page</UI.link>
        <span
          :if={is_nil(@previous_href)}
          id={@id <> "-previous"}
          aria-disabled="true"
          class="text-sm text-muted-foreground"
        >Previous page</span>
        <UI.link :if={@next_href} id={@id <> "-next"} href={@next_href}>Next page</UI.link>
        <span
          :if={is_nil(@next_href)}
          id={@id <> "-next"}
          aria-disabled="true"
          class="text-sm text-muted-foreground"
        >Next page</span>
      </div>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, required: true
  attr :attempt, :map, default: %{}
  attr :retry_href, :string, default: nil
  attr :class, :any, default: nil

  @doc "Renders one read-only, already-authorized attempt summary."
  def attempt_summary(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    visible? = not protected_state?(state) and state != :empty and map_size(assigns.attempt) > 0
    attempt = if(visible?, do: normalize_attempt(assigns.attempt), else: nil)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(:visible?, visible?)
      |> assign(:attempt, attempt)

    ~H"""
    <section
      id={@id}
      aria-labelledby={@id <> "-title"}
      data-attempt-summary
      data-projection-state={@state}
      class={["grid gap-5 rounded-xl border border-border bg-card px-5 py-5", @class]}
    >
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p class="text-sm font-medium text-muted-foreground">Attempt summary</p>
          <h2 id={@id <> "-title"} class="mt-1 break-words text-xl font-semibold">
            {if(@visible?, do: @attempt.label, else: "Attempt details unavailable")}
          </h2>
        </div>
        <.readiness_badge id={@id <> "-readiness"} state={@state} />
      </div>

      <.projection_status
        :if={protected_state?(@state)}
        id={@id <> "-status"}
        state={@state}
        retry_href={@retry_href}
      />

      <p
        :if={@state == :empty}
        id={@id <> "-no-results"}
        data-no-results
        class="text-sm text-muted-foreground"
      >
        No authorized attempt matches this view.
      </p>

      <div :if={@visible?} id={@id <> "-details"} data-attempt-details class="grid gap-5">
        <dl class="grid gap-x-5 gap-y-3 text-sm sm:grid-cols-2 lg:grid-cols-4">
          <div
            :for={{{label, value}, index} <- Enum.with_index(@attempt.metadata)}
            id={@id <> "-metadata-" <> Integer.to_string(index + 1)}
          >
            <dt class="font-medium text-muted-foreground">{label}</dt>
            <dd class="break-words">{value}</dd>
          </div>
        </dl>

        <.lifecycle_rail id={@id <> "-lifecycle"} state={@state} steps={@attempt.lifecycle_steps} />
        <.outcome_rail id={@id <> "-outcomes"} state={@state} items={@attempt.outcomes} />
        <.budget_meter
          :if={@attempt.budget}
          id={@id <> "-budget"}
          state={@state}
          label={@attempt.budget.label}
          value={@attempt.budget.value}
          max={@attempt.budget.max}
          unit={@attempt.budget.unit}
        />
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, default: :ready
  attr :title, :string, default: "Lifecycle"
  attr :steps, :list, default: []
  attr :class, :any, default: nil

  @doc "Renders a bounded ordered lifecycle rail with text and icon state."
  def lifecycle_rail(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    {steps, truncated?} = visible_items(assigns.steps, state, @rail_limit)

    steps =
      steps
      |> Enum.with_index(1)
      |> Enum.map(fn {step, index} -> normalize_lifecycle_step(step, id, index) end)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(:title, protected_text(state, assigns.title, "Lifecycle", @label_limit))
      |> assign(:steps, steps)
      |> assign(:truncated?, truncated?)
      |> assign(:limit, @rail_limit)

    ~H"""
    <section
      id={@id}
      aria-labelledby={@id <> "-title"}
      data-lifecycle-rail
      data-projection-state={@state}
      class={["grid gap-3", @class]}
    >
      <h3 id={@id <> "-title"} class="font-semibold">{@title}</h3>
      <ol :if={@steps != []} class="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
        <li
          :for={step <- @steps}
          id={step.id}
          data-rail-item
          data-step-state={step.state}
          aria-current={if(step.state == :current, do: "step", else: nil)}
          class="flex items-start gap-2 rounded-md border border-border px-3 py-3"
        >
          <.icon name={step.icon} class="mt-0.5 size-4 shrink-0" />
          <span class="min-w-0">
            <span class="block break-words text-sm font-medium">{step.label}</span>
            <span class="block text-xs text-muted-foreground">{step.state_label}</span>
          </span>
        </li>
      </ol>
      <p
        :if={@steps == []}
        id={@id <> "-no-results"}
        data-no-results
        class="text-sm text-muted-foreground"
      >
        No lifecycle stages are available.
      </p>
      <p
        :if={@truncated?}
        id={@id <> "-bounded-notice"}
        role="status"
        data-bounded-notice
        class="text-sm text-muted-foreground"
      >
        Showing the first {@limit} lifecycle stages.
      </p>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, default: :ready
  attr :title, :string, default: "Outcomes"
  attr :items, :list, default: []
  attr :class, :any, default: nil

  @doc "Renders a bounded ordered outcome rail without implying lifecycle from color."
  def outcome_rail(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    {items, truncated?} = visible_items(assigns.items, state, @rail_limit)

    items =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, index} -> normalize_outcome(item, id, index) end)

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(:title, protected_text(state, assigns.title, "Outcomes", @label_limit))
      |> assign(:items, items)
      |> assign(:truncated?, truncated?)
      |> assign(:limit, @rail_limit)

    ~H"""
    <section
      id={@id}
      aria-labelledby={@id <> "-title"}
      data-outcome-rail
      data-projection-state={@state}
      class={["grid gap-3", @class]}
    >
      <h3 id={@id <> "-title"} class="font-semibold">{@title}</h3>
      <ol :if={@items != []} class="grid gap-2">
        <li
          :for={item <- @items}
          id={item.id}
          data-outcome-item
          data-outcome-state={item.state}
          class="flex items-start gap-3 rounded-md border border-border px-3 py-3"
        >
          <.icon name={item.icon} class="mt-0.5 size-4 shrink-0" />
          <span class="min-w-0 flex-1">
            <span class="block break-words text-sm font-medium">{item.label}</span>
            <span class="block text-xs text-muted-foreground">{item.state_label}</span>
            <span :if={item.as_of} class="mt-1 block break-words text-xs text-muted-foreground">{item.as_of}</span>
          </span>
        </li>
      </ol>
      <p
        :if={@items == []}
        id={@id <> "-no-results"}
        data-no-results
        class="text-sm text-muted-foreground"
      >
        No outcomes are available.
      </p>
      <p
        :if={@truncated?}
        id={@id <> "-bounded-notice"}
        role="status"
        data-bounded-notice
        class="text-sm text-muted-foreground"
      >
        Showing the first {@limit} outcomes.
      </p>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, default: :ready
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :max, :any, required: true
  attr :unit, :string, default: "units"
  attr :class, :any, default: nil

  @doc "Renders scalar utilization with a native meter and visible numeric/state text."
  def budget_meter(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    protected? = protected_state?(state)

    {value, maximum} =
      if protected?,
        do: {0.0, 1.0},
        else: normalized_meter_values!(assigns.value, assigns.max)

    ratio = value / maximum

    {posture, posture_label, icon_name} =
      cond do
        protected? -> {:unavailable, "Budget unavailable", "hero-no-symbol"}
        ratio >= 1.0 -> {:exceeded, "Budget exceeded", "hero-x-circle"}
        ratio >= 0.8 -> {:near, "Budget nearly used", "hero-exclamation-triangle"}
        true -> {:within, "Within budget", "hero-check-circle"}
      end

    label =
      if(protected?, do: "Budget", else: bounded_text(assigns.label, "Budget", @label_limit))

    unit = if(protected?, do: "units", else: bounded_text(assigns.unit, "units", 48))

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(:protected?, protected?)
      |> assign(:label, label)
      |> assign(:value, value)
      |> assign(:meter_value, min(value, maximum))
      |> assign(:maximum, maximum)
      |> assign(:unit, unit)
      |> assign(:posture, posture)
      |> assign(:posture_label, posture_label)
      |> assign(:icon_name, icon_name)

    ~H"""
    <section
      id={@id}
      aria-labelledby={@id <> "-label"}
      aria-describedby={@id <> "-description"}
      data-budget-meter
      data-budget-posture={@posture}
      data-projection-state={@state}
      class={["grid gap-2", @class]}
    >
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h3 id={@id <> "-label"} class="text-sm font-semibold">{@label}</h3>
        <p class="flex items-center gap-1.5 text-sm font-medium">
          <.icon name={@icon_name} class="size-4" />{@posture_label}
        </p>
      </div>
      <meter
        :if={not @protected?}
        id={@id <> "-meter"}
        aria-labelledby={@id <> "-label"}
        aria-describedby={@id <> "-description"}
        min="0"
        max={@maximum}
        value={@meter_value}
        class="h-3 w-full"
      >
        {@meter_value} of {@maximum}
      </meter>
      <p id={@id <> "-description"} class="text-sm text-muted-foreground">
        <%= if @protected? do %>
          Budget information is unavailable.
        <% else %>
          {format_number(@value)} of {format_number(@maximum)} {@unit} used.
        <% end %>
      </p>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, default: :ready
  attr :href, :string, default: nil
  attr :label, :string, default: "View evidence"
  attr :kind, :atom, values: [:evidence, :receipt], default: :evidence
  attr :class, :any, default: nil

  @doc "Renders a safe native evidence/receipt destination or an explicit unavailable label."
  def evidence_link(assigns) do
    id = component_id!(assigns.id)
    state = normalize_state!(assigns.state)
    kind = normalize_evidence_kind!(assigns.kind)
    protected? = protected_state?(state)
    href = if(protected?, do: nil, else: safe_href(assigns.href))

    label =
      if(protected?,
        do: "Evidence unavailable",
        else: bounded_text(assigns.label, "View evidence", @label_limit)
      )

    kind_label =
      cond do
        protected? -> "Evidence"
        kind == :receipt -> "Receipt"
        true -> "Evidence"
      end

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(:kind, kind)
      |> assign(:href, href)
      |> assign(:label, label)
      |> assign(:kind_label, kind_label)

    ~H"""
    <UI.link
      :if={@href}
      id={@id}
      href={@href}
      data-evidence-link
      data-evidence-kind={@kind}
      class={@class}
    >
      <.icon name="hero-document-magnifying-glass" class="mr-1 inline size-4" />
      {@label}
    </UI.link>
    <span
      :if={is_nil(@href)}
      id={@id}
      data-evidence-unavailable
      data-projection-state={@state}
      class={["inline-flex items-center gap-1 text-sm text-muted-foreground", @class]}
    >
      <.icon name="hero-document" class="size-4" />
      {@kind_label} unavailable
    </span>
    """
  end

  defp normalize_alias_name(state) do
    case Map.fetch(@aliases_by_name, state) do
      {:ok, canonical} -> {:ok, canonical}
      :error -> {:error, :unsupported_projection_state}
    end
  end

  defp normalize_state!(state) do
    case normalize_state(state) do
      {:ok, canonical} ->
        canonical

      {:error, :unsupported_projection_state} ->
        raise ArgumentError,
              "unsupported projection state; expected a documented canonical state or alias"
    end
  end

  defp protected_state?(state), do: state in @protected_states

  defp visible_items(_items, state, _limit) when state in @protected_states or state == :empty,
    do: {[], false}

  defp visible_items(items, _state, limit) when is_list(items) do
    sampled = Enum.take(items, limit + 1)
    {Enum.take(sampled, limit), length(sampled) > limit}
  end

  defp visible_items(_items, _state, _limit), do: {[], false}

  defp normalize_attention(item) do
    item = plain_map(item)
    severity = normalize_severity(field(item, :severity))

    metadata =
      [
        {"Scope", map_optional(item, :scope_label, @label_limit)},
        {"Owner", map_optional(item, :owner, @label_limit)},
        {"Age", map_optional(item, :age, @label_limit)}
      ]
      |> Enum.reject(fn {_label, value} -> is_nil(value) end)

    %{
      severity: severity,
      severity_label: severity_label(severity),
      icon: severity_icon(severity),
      title: map_text(item, :title, "Attention item", @label_limit),
      reason: map_text(item, :reason, "No additional detail is available.", @detail_limit),
      metadata: metadata,
      destination_href: item |> field(:destination_href) |> safe_href(),
      destination_label:
        map_text(item, :destination_label, "Open authorized destination", @label_limit),
      evidence_href: item |> field(:evidence_href) |> safe_href(),
      evidence_label: map_text(item, :evidence_label, "View evidence", @label_limit)
    }
  end

  defp normalize_health(item, root_id, index) do
    item = plain_map(item)
    status = normalize_health_status(field(item, :status))

    %{
      id: "#{root_id}-item-#{index}",
      label: map_text(item, :label, "Health metric", @label_limit),
      value: item |> field(:value) |> bounded_scalar("Not provided"),
      detail: map_optional(item, :detail, @detail_limit),
      status: status,
      status_label: health_status_label(status),
      icon: health_status_icon(status)
    }
  end

  defp normalize_fleet_row(row, root_id, index) do
    row = plain_map(row)
    health_state = normalize_row_health_state(field(row, :health_state))

    %{
      table_id: "#{root_id}-table-row-#{index}",
      card_id: "#{root_id}-card-#{index}",
      project: map_text(row, :project, "Project not provided", @label_limit),
      project_href: row |> field(:project_href) |> safe_href(),
      work: map_text(row, :work, "Not provided", @label_limit),
      agent: map_text(row, :agent, "Not provided", @label_limit),
      stage: map_text(row, :stage, "Not provided", @label_limit),
      health:
        map_text(row, :health, Map.fetch!(@state_presentation, health_state).label, @label_limit),
      health_state: health_state,
      freshness: map_text(row, :freshness, "Not provided", @label_limit)
    }
  end

  defp normalize_attempt(attempt) do
    attempt = plain_map(attempt)

    metadata = [
      {"Project", map_text(attempt, :project, "Not provided", @label_limit)},
      {"Task", map_text(attempt, :task, "Not provided", @label_limit)},
      {"Agent", map_text(attempt, :agent, "Not provided", @label_limit)},
      {"Profile", map_text(attempt, :profile, "Not provided", @label_limit)},
      {"Runtime", map_text(attempt, :runtime, "Not provided", @label_limit)},
      {"Revision", map_text(attempt, :revision, "Not provided", @label_limit)},
      {"Fence", map_text(attempt, :fence, "Not provided", @label_limit)},
      {"Freshness", map_text(attempt, :freshness, "Not provided", @label_limit)}
    ]

    %{
      label: map_text(attempt, :label, "Attempt", @label_limit),
      metadata: metadata,
      lifecycle_steps: list_field(attempt, :lifecycle_steps),
      outcomes: list_field(attempt, :outcomes),
      budget: normalize_optional_budget(field(attempt, :budget))
    }
  end

  defp normalize_lifecycle_step(step, root_id, index) do
    step = plain_map(step)
    state = normalize_lifecycle_state(field(step, :state))

    %{
      id: "#{root_id}-step-#{index}",
      label: map_text(step, :label, "Lifecycle stage", @label_limit),
      state: state,
      state_label: lifecycle_state_label(state),
      icon: lifecycle_state_icon(state)
    }
  end

  defp normalize_outcome(item, root_id, index) do
    item = plain_map(item)
    state = normalize_outcome_state(field(item, :state))

    %{
      id: "#{root_id}-item-#{index}",
      label: map_text(item, :label, "Outcome", @label_limit),
      state: state,
      state_label: outcome_state_label(state),
      icon: outcome_state_icon(state),
      as_of: map_optional(item, :as_of, @label_limit)
    }
  end

  defp normalize_optional_budget(budget) when is_map(budget) and not is_struct(budget) do
    value = field(budget, :value)
    maximum = field(budget, :max)

    if is_number(value) and is_number(maximum) and value >= 0 and maximum > 0 and
         value <= @budget_numeric_limit and maximum <= @budget_numeric_limit do
      %{
        label: map_text(budget, :label, "Budget", @label_limit),
        value: value,
        max: maximum,
        unit: map_text(budget, :unit, "units", 48)
      }
    end
  end

  defp normalize_optional_budget(_budget), do: nil

  defp normalize_severity(value) when value in [:critical, "critical"], do: :critical
  defp normalize_severity(value) when value in [:high, "high"], do: :high
  defp normalize_severity(value) when value in [:medium, "medium"], do: :medium
  defp normalize_severity(value) when value in [:low, "low"], do: :low
  defp normalize_severity(_value), do: :information

  defp severity_label(:critical), do: "Critical attention"
  defp severity_label(:high), do: "High attention"
  defp severity_label(:medium), do: "Medium attention"
  defp severity_label(:low), do: "Low attention"
  defp severity_label(:information), do: "Information"

  defp severity_icon(:critical), do: "hero-x-circle"
  defp severity_icon(:high), do: "hero-exclamation-triangle"
  defp severity_icon(:medium), do: "hero-exclamation-circle"
  defp severity_icon(:low), do: "hero-information-circle"
  defp severity_icon(:information), do: "hero-information-circle"

  defp normalize_health_status(value) when value in [:healthy, "healthy"], do: :healthy
  defp normalize_health_status(value) when value in [:attention, "attention"], do: :attention
  defp normalize_health_status(value) when value in [:failure, "failure"], do: :failure
  defp normalize_health_status(_value), do: :unknown

  defp health_status_label(:healthy), do: "Healthy"
  defp health_status_label(:attention), do: "Needs attention"
  defp health_status_label(:failure), do: "Failure"
  defp health_status_label(:unknown), do: "Status unknown"

  defp health_status_icon(:healthy), do: "hero-check-circle"
  defp health_status_icon(:attention), do: "hero-exclamation-triangle"
  defp health_status_icon(:failure), do: "hero-x-circle"
  defp health_status_icon(:unknown), do: "hero-question-mark-circle"

  defp normalize_row_health_state(value) do
    case normalize_state(value || :ready) do
      {:ok, state} when state in [:ready, :stale, :incomplete, :contradicted, :truncated] -> state
      _other -> :unavailable
    end
  end

  defp normalize_lifecycle_state(value) when value in [:complete, "complete"], do: :complete
  defp normalize_lifecycle_state(value) when value in [:current, "current"], do: :current
  defp normalize_lifecycle_state(value) when value in [:upcoming, "upcoming"], do: :upcoming
  defp normalize_lifecycle_state(value) when value in [:blocked, "blocked"], do: :blocked
  defp normalize_lifecycle_state(_value), do: :unknown

  defp lifecycle_state_label(:complete), do: "Complete"
  defp lifecycle_state_label(:current), do: "Current stage"
  defp lifecycle_state_label(:upcoming), do: "Upcoming"
  defp lifecycle_state_label(:blocked), do: "Blocked"
  defp lifecycle_state_label(:unknown), do: "State unknown"

  defp lifecycle_state_icon(:complete), do: "hero-check-circle"
  defp lifecycle_state_icon(:current), do: "hero-play-circle"
  defp lifecycle_state_icon(:upcoming), do: "hero-clock"
  defp lifecycle_state_icon(:blocked), do: "hero-no-symbol"
  defp lifecycle_state_icon(:unknown), do: "hero-question-mark-circle"

  defp normalize_outcome_state(value) when value in [:accepted, "accepted"], do: :accepted
  defp normalize_outcome_state(value) when value in [:observed, "observed"], do: :observed
  defp normalize_outcome_state(value) when value in [:pending, "pending"], do: :pending
  defp normalize_outcome_state(value) when value in [:failed, "failed"], do: :failed

  defp normalize_outcome_state(value) when value in [:unavailable, "unavailable"],
    do: :unavailable

  defp normalize_outcome_state(_value), do: :unknown

  defp normalize_evidence_kind!(:evidence), do: :evidence
  defp normalize_evidence_kind!(:receipt), do: :receipt

  defp normalize_evidence_kind!(_kind) do
    raise ArgumentError, "evidence kind must be :evidence or :receipt"
  end

  defp outcome_state_label(:accepted), do: "Accepted"
  defp outcome_state_label(:observed), do: "Observed"
  defp outcome_state_label(:pending), do: "Pending"
  defp outcome_state_label(:failed), do: "Failed"
  defp outcome_state_label(:unavailable), do: "Unavailable"
  defp outcome_state_label(:unknown), do: "State unknown"

  defp outcome_state_icon(:accepted), do: "hero-check-badge"
  defp outcome_state_icon(:observed), do: "hero-eye"
  defp outcome_state_icon(:pending), do: "hero-clock"
  defp outcome_state_icon(:failed), do: "hero-x-circle"
  defp outcome_state_icon(:unavailable), do: "hero-no-symbol"
  defp outcome_state_icon(:unknown), do: "hero-question-mark-circle"

  defp normalized_meter_values!(value, maximum)
       when is_number(value) and is_number(maximum) and value >= 0 and maximum > 0 and
              value <= @budget_numeric_limit and maximum <= @budget_numeric_limit,
       do: {value / 1, maximum / 1}

  defp normalized_meter_values!(_value, _maximum) do
    raise ArgumentError,
          "budget meter requires bounded non-negative numeric values and a positive numeric max"
  end

  defp normalize_sort_column(value)
       when value in [:project, :work, :agent, :stage, :health, :freshness],
       do: value

  defp normalize_sort_column(_value), do: nil

  defp normalize_sort_direction(value) when value in [:ascending, "ascending"], do: :ascending
  defp normalize_sort_direction(value) when value in [:descending, "descending"], do: :descending
  defp normalize_sort_direction(_value), do: :none

  defp normalize_sort_hrefs(hrefs) when is_map(hrefs) and not is_struct(hrefs) do
    [:project, :work, :agent, :stage, :health, :freshness]
    |> Map.new(fn column -> {column, hrefs |> field(column) |> safe_href()} end)
  end

  defp normalize_sort_hrefs(_hrefs), do: %{}

  defp retry_href(href, state) when state in @retryable_states, do: safe_href(href)
  defp retry_href(_href, _state), do: nil

  defp safe_href(href) when is_binary(href) do
    cond do
      byte_size(href) > @href_byte_limit ->
        nil

      not String.valid?(href) ->
        nil

      unsafe_href_bytes?(href) ->
        nil

      true ->
        href = String.trim(href)

        cond do
          href == "" -> nil
          String.starts_with?(href, "//") -> nil
          String.starts_with?(href, ["/", "#", "?"]) -> href
          true -> nil
        end
    end
  end

  defp safe_href(_href), do: nil

  defp unsafe_href_bytes?(href) do
    String.contains?(href, "\\") or
      href
      |> :binary.bin_to_list()
      |> Enum.any?(fn byte -> byte <= 0x1F or byte == 0x7F end)
  end

  defp component_id!(id) when is_binary(id) do
    id = String.trim(id)

    if Regex.match?(@id_pattern, id),
      do: id,
      else: raise(ArgumentError, "component id must be a stable bounded DOM identifier")
  end

  defp component_id!(_id),
    do: raise(ArgumentError, "component id must be a stable bounded DOM identifier")

  defp bounded_text(nil, fallback, _limit), do: fallback

  defp bounded_text(value, fallback, limit) when is_binary(value) do
    value = String.trim(value)

    cond do
      value == "" -> fallback
      String.length(value) <= limit -> value
      true -> String.slice(value, 0, limit - 1) <> "…"
    end
  end

  defp bounded_text(value, fallback, limit) when is_atom(value) or is_integer(value),
    do: bounded_text(to_string(value), fallback, limit)

  defp bounded_text(value, fallback, limit) when is_float(value),
    do: bounded_text(format_number(value), fallback, limit)

  defp bounded_text(_value, fallback, _limit), do: fallback

  defp bounded_optional(value, limit), do: bounded_text(value, nil, limit)

  defp protected_text(state, _value, fallback, _limit) when state in @protected_states,
    do: fallback

  defp protected_text(_state, value, fallback, limit),
    do: bounded_text(value, fallback, limit)

  defp bounded_scalar(value, fallback)
       when is_binary(value) or is_atom(value) or is_integer(value) or is_float(value),
       do: bounded_text(value, fallback, @label_limit)

  defp bounded_scalar(_value, fallback), do: fallback

  defp bounded_positive_integer(value, _fallback, maximum)
       when is_integer(value) and value > 0,
       do: min(value, maximum)

  defp bounded_positive_integer(_value, fallback, _maximum), do: fallback

  defp optional_page_count(value, page) when is_integer(value) and value > 0,
    do: max(page, min(value, 100_000))

  defp optional_page_count(_value, _page), do: nil

  defp format_number(value) when is_integer(value), do: Integer.to_string(value)
  defp format_number(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)

  defp plain_map(value) when is_map(value) and not is_struct(value), do: value
  defp plain_map(_value), do: %{}

  defp field(map, key) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  defp field(_map, _key), do: nil

  defp map_text(map, key, fallback, limit),
    do: map |> field(key) |> bounded_text(fallback, limit)

  defp map_optional(map, key, limit),
    do: map |> field(key) |> bounded_optional(limit)

  defp list_field(map, key) do
    case field(map, key) do
      value when is_list(value) -> value
      _value -> []
    end
  end
end
