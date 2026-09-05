defmodule JidoCodeWeb.Components.UI do
  @moduledoc """
  Application-owned boundary for qualified HEEx primitives.

  Product code uses stable JidoCode names from this module and does not import
  upstream component namespaces. Existing SaladUI delegates remain explicitly
  compatibility-only until HUI-H; qualified primitives are backed by the exact
  ShadcnUI source selected in HUI-B1.

  The supported HUI-C2 catalog is `form`, `input`, `field_input`, `select`,
  `checkbox`, `radio_group`, `button`, `link`, `badge`, `table`, `disclosure`,
  `dialog`, `menu`, `tooltip`, `toast`, `status`, and `skeleton`. Semantic
  variants are closed; caller classes are layout hooks and must not encode
  status, authority, or hidden product state. Removal requires a deprecation
  cycle, migrated-consumer evidence, and a renewed dependency/API diff.
  """

  use Phoenix.Component

  alias JidoCodeWeb.CoreComponents
  alias ShadcnUI.Components.Disclosure.Accordion
  alias ShadcnUI.Components.Forms.Checkbox
  alias ShadcnUI.Components.Forms.Input, as: ShadcnInput
  alias ShadcnUI.Components.Forms.NativeSelect
  alias ShadcnUI.Components.Forms.RadioGroup
  alias ShadcnUI.Components.Foundation.Badge
  alias ShadcnUI.Components.Foundation.Button
  alias ShadcnUI.Components.Foundation.Skeleton
  alias ShadcnUI.Components.Overlays.Dialog
  alias ShadcnUI.Components.Overlays.DropdownActions
  alias ShadcnUI.Components.Overlays.Tooltip

  @button_variants %{
    "default" => :default,
    "secondary" => :secondary,
    "destructive" => :destructive,
    "outline" => :outline,
    "ghost" => :ghost,
    "link" => :link
  }
  @button_sizes %{"small" => :small, "default" => :default, "large" => :large, "icon" => :icon}

  attr :type, :string, values: ~w(button submit reset), default: "button"
  attr :variant, :any, default: :default
  attr :size, :any, default: :default
  attr :disabled, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :accessible_label, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(autofocus form name value)
  slot :leading
  slot :inner_block, required: true
  slot :trailing

  def button(assigns) do
    assigns
    |> assign(:variant, closed_atom!(assigns.variant, @button_variants, :variant))
    |> assign(:size, closed_atom!(assigns.size, @button_sizes, :size))
    |> Button.button()
  end

  @doc "Native Phoenix form boundary; project `<.form>` remains the default local spelling."
  attr :for, :any, required: true
  attr :action, :string
  attr :as, :atom
  attr :csrf_token, :any
  attr :errors, :list
  attr :method, :string
  attr :multipart, :boolean, default: false
  attr :rest, :global, include: ~w(autocomplete name rel enctype novalidate target)
  slot :inner_block, required: true

  def form(assigns), do: Phoenix.Component.form(assigns)

  @doc "Project input contract under the explicit facade namespace."
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    values:
      ~w(checkbox color date datetime-local email file month number password search select tel text textarea time url week),
    default: "text"

  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :checked, :boolean
  attr :prompt, :string, default: nil
  attr :options, :list
  attr :multiple, :boolean, default: false
  attr :class, :string, default: nil
  attr :error_class, :string, default: nil

  attr :rest, :global,
    include:
      ~w(accept autocomplete capture cols disabled form list max maxlength min minlength multiple pattern placeholder readonly required rows size step)

  def input(assigns), do: CoreComponents.input(assigns)

  defdelegate card(assigns), to: SaladUI.Card
  defdelegate card_header(assigns), to: SaladUI.Card
  defdelegate card_title(assigns), to: SaladUI.Card
  defdelegate card_description(assigns), to: SaladUI.Card
  defdelegate card_content(assigns), to: SaladUI.Card
  defdelegate card_footer(assigns), to: SaladUI.Card

  attr :variant, :any, default: :default
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    variants = Map.take(@button_variants, ~w(default secondary destructive outline))

    assigns
    |> assign(:variant, closed_atom!(assigns.variant, variants, :variant))
    |> Badge.badge()
  end

  @doc """
  Qualification-only ShadcnUI text input.

  The unqualified `<.input>` remains the application form default. This remote
  name avoids collisions while preserving `Phoenix.Component.to_form/2` fields.
  """
  attr :type, :string, default: "text"
  attr :size, :atom, default: :default
  attr :field, :any, default: nil
  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :value, :any, default: {:shadcn_ui, :not_provided}
  attr :errors, :any, default: {:shadcn_ui, :not_provided}
  attr :error_mode, :atom, default: :used_input
  attr :used, :boolean, default: false
  attr :translate_error, :any, default: nil
  attr :pending, :boolean, default: false
  attr :required, :boolean, default: false
  attr :optional, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :readonly, :boolean, default: false
  attr :autocomplete, :string, default: nil
  attr :inputmode, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :minlength, :integer, default: nil
  attr :maxlength, :integer, default: nil
  attr :pattern, :string, default: nil
  attr :min, :any, default: nil
  attr :max, :any, default: nil
  attr :step, :any, default: nil
  attr :form, :string, default: nil
  attr :describedby, :any, default: nil
  attr :class, :any, default: nil
  attr :field_class, :any, default: nil
  attr :rest, :global, include: ~w(autocapitalize autofocus list spellcheck)
  slot :label, required: true
  slot :help
  slot :leading
  slot :trailing

  def field_input(assigns), do: ShadcnInput.input(assigns)

  @doc "Native select with deterministic label, help, error, and option identities."
  attr :field, :any, default: nil
  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :value, :any, default: {:shadcn_ui, :not_provided}
  attr :options, :list, required: true
  attr :errors, :any, default: {:shadcn_ui, :not_provided}
  attr :error_mode, :atom, values: [:used_input, :always, :hidden], default: :used_input
  attr :used, :boolean, default: false
  attr :translate_error, :any, default: nil
  attr :pending, :boolean, default: false
  attr :required, :boolean, default: false
  attr :optional, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :multiple, :boolean, default: false
  attr :size, :atom, values: [:small, :default, :large], default: :default
  attr :form, :string, default: nil
  attr :describedby, :any, default: nil
  attr :class, :any, default: nil
  attr :field_class, :any, default: nil
  attr :rest, :global, include: ~w(autofocus)
  slot :label, required: true
  slot :help

  def select(assigns), do: NativeSelect.native_select(assigns)

  @doc "Native checkbox with Phoenix boolean or repeated-value submission semantics."
  attr :field, :any, default: nil
  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :mode, :atom, values: [:boolean, :multiple], default: :boolean
  attr :value, :any, default: {:shadcn_ui, :not_provided}
  attr :checked, :boolean, default: nil
  attr :checked_value, :string, default: "true"
  attr :unchecked_value, :string, default: "false"
  attr :errors, :any, default: {:shadcn_ui, :not_provided}
  attr :error_mode, :atom, values: [:used_input, :always, :hidden], default: :used_input
  attr :used, :boolean, default: false
  attr :translate_error, :any, default: nil
  attr :pending, :boolean, default: false
  attr :required, :boolean, default: false
  attr :optional, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :form, :string, default: nil
  attr :describedby, :any, default: nil
  attr :class, :any, default: nil
  attr :field_class, :any, default: nil
  attr :label_class, :any, default: nil
  attr :rest, :global, include: ~w(autofocus)
  slot :label, required: true
  slot :help

  def checkbox(assigns), do: Checkbox.checkbox(assigns)

  @doc "Native radio fieldset with deterministic exclusive-choice identities."
  attr :field, :any, default: nil
  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :selected, :any, default: {:shadcn_ui, :not_provided}
  attr :options, :list, required: true
  attr :errors, :any, default: {:shadcn_ui, :not_provided}
  attr :error_mode, :atom, values: [:used_input, :always, :hidden], default: :used_input
  attr :used, :boolean, default: false
  attr :translate_error, :any, default: nil
  attr :pending, :boolean, default: false
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :form, :string, default: nil
  attr :layout, :atom, values: [:vertical, :inline], default: :vertical
  attr :describedby, :any, default: nil
  attr :class, :any, default: nil
  attr :options_class, :any, default: nil
  attr :option_class, :any, default: nil
  attr :legend_class, :any, default: nil
  attr :rest, :global
  slot :legend, required: true
  slot :help

  def radio_group(assigns), do: RadioGroup.radio_group(assigns)

  attr :id, :string, required: true
  attr :href, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(download hreflang referrerpolicy rel target type)
  slot :inner_block, required: true

  def link(assigns) do
    ~H"""
    <a
      id={@id}
      data-ui-link
      href={@href}
      class={[
        "underline decoration-primary/50 underline-offset-4 transition-colors hover:text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  attr :id, :string, required: true
  attr :caption, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :head, required: true
  slot :inner_block, required: true

  def table(assigns) do
    ~H"""
    <div id={@id} data-ui-table class={["max-w-full overflow-x-auto", @class]} {@rest}>
      <table class="w-full border-collapse text-left text-sm">
        <caption class="sr-only">{@caption}</caption>
        <thead class="border-b border-border">{render_slot(@head)}</thead>
        <tbody>{render_slot(@inner_block)}</tbody>
      </table>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :mode, :atom, default: :independent
  attr :class, :any, default: nil
  attr :rest, :global

  slot :item, required: true do
    attr :key, :string, required: true
    attr :summary, :string, required: true
    attr :open, :boolean
    attr :class, :any
    attr :summary_class, :any
    attr :content_class, :any
    attr :details_rest, :map
    attr :summary_rest, :map
    attr :content_rest, :map
  end

  def disclosure(assigns), do: Accordion.accordion(assigns)

  attr :id, :string, required: true
  attr :accessible_label, :string, default: nil
  attr :dismissal, :atom, default: :close_request
  attr :initial_focus, :atom, default: :auto
  attr :size, :atom, default: :default
  attr :alignment, :atom, default: :start
  attr :density, :atom, default: :comfortable
  attr :class, :any, default: nil
  attr :trigger_class, :any, default: nil
  attr :content_class, :any, default: nil
  attr :close_class, :any, default: nil
  attr :rest, :global
  attr :trigger_rest, :map, default: %{}
  attr :dialog_rest, :map, default: %{}
  attr :content_rest, :map, default: %{}
  attr :close_rest, :map, default: %{}
  slot :trigger, required: true
  slot :title
  slot :description
  slot :inner_block, required: true
  slot :close, required: true
  slot :fallback

  def dialog(assigns), do: Dialog.dialog(assigns)

  @doc "Native dropdown action list; deliberately uses ordinary links/buttons, not ARIA menu roles."
  attr :id, :string, required: true
  attr :accessible_label, :string, required: true

  attr :placement, :atom,
    values: [:block_start, :block_end, :inline_start, :inline_end],
    default: :block_end

  attr :class, :any, default: nil
  attr :trigger_class, :any, default: nil
  attr :rest, :global
  attr :trigger_rest, :map, default: %{}
  attr :surface_rest, :map, default: %{}
  slot :trigger, required: true
  slot :fallback

  slot :action, required: true do
    attr :key, :string, required: true
    attr :label, :string, required: true
    attr :kind, :atom
    attr :destination, :string
    attr :target, :string
    attr :rel, :string
    attr :download, :any
    attr :current, :atom
    attr :type, :string
    attr :disabled, :boolean
    attr :name, :string
    attr :value, :string
    attr :form, :string
    attr :group, :string
    attr :destructive, :boolean
    attr :class, :any
    attr :rest, :map
  end

  slot :group_label do
    attr :key, :string, required: true
    attr :label, :string, required: true
  end

  slot :separator do
    attr :after_key, :string, required: true
    attr :decorative, :boolean
  end

  def menu(assigns), do: DropdownActions.dropdown_actions(assigns)

  @doc "CSS-first supplemental description for one complete native link or button."
  attr :id, :string, required: true
  attr :text, :string, required: true
  attr :describedby, :string, default: nil

  attr :placement, :atom,
    values: [:block_start, :block_end, :inline_start, :inline_end],
    default: :block_end

  attr :class, :any, default: nil
  attr :rest, :global
  attr :surface_rest, :map, default: %{}

  slot :trigger, required: true do
    attr :label, :string, required: true
    attr :kind, :atom
    attr :type, :string
    attr :disabled, :boolean
    attr :name, :string
    attr :value, :string
    attr :form, :string
    attr :href, :string
    attr :target, :string
    attr :rel, :string
    attr :download, :any
    attr :current, :string
    attr :class, :any
    attr :rest, :map
  end

  def tooltip(assigns), do: Tooltip.tooltip(assigns)

  @doc "Decorative loading geometry; the surrounding region owns its visible loading label."
  attr :shape, :atom, values: [:rectangle, :circle, :text], default: :rectangle
  attr :size, :atom, values: [:small, :default, :large], default: :default
  attr :pulse, :boolean, default: true
  attr :class, :any, default: nil
  attr :rest, :global

  def skeleton(assigns), do: Skeleton.skeleton(assigns)

  attr :id, :string, required: true
  attr :kind, :atom, values: [:neutral, :success, :attention, :failure], default: :neutral
  attr :live, :atom, values: [:polite, :assertive], default: :polite
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def status(assigns) do
    ~H"""
    <div
      id={@id}
      role="status"
      aria-live={@live}
      aria-atomic="true"
      data-ui-status
      data-status-kind={@kind}
      class={[
        "rounded-md border border-border bg-card px-3 py-2 text-sm text-card-foreground",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Transient visible feedback; never a durable acknowledgement or authority decision."
  attr :id, :string, required: true
  attr :kind, :atom, values: [:neutral, :success, :attention, :failure], default: :neutral
  attr :title, :string, required: true
  attr :live, :atom, values: [:polite, :assertive], default: :polite
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true
  slot :actions

  def toast(assigns) do
    assigns =
      assigns
      |> assign(:role, if(assigns.live == :assertive, do: "alert", else: "status"))
      |> assign(:icon, status_icon(assigns.kind))

    ~H"""
    <section
      id={@id}
      role={@role}
      aria-live={@live}
      aria-atomic="true"
      data-ui-toast
      data-status-kind={@kind}
      class={[
        "grid max-w-md grid-cols-[auto_minmax(0,1fr)] gap-3 rounded-lg border border-border bg-card px-4 py-3 text-card-foreground shadow-[var(--elevation-overlay)]",
        @class
      ]}
      {@rest}
    >
      <CoreComponents.icon name={@icon} class="mt-0.5 size-5" />
      <div class="min-w-0">
        <h2 class="text-sm font-semibold">{@title}</h2>
        <div class="mt-1 break-words text-sm text-muted-foreground">
          {render_slot(@inner_block)}
        </div>
        <div :if={@actions != []} class="mt-3 flex flex-wrap gap-2">
          {render_slot(@actions)}
        </div>
      </div>
    </section>
    """
  end

  defdelegate alert(assigns), to: SaladUI.Alert
  defdelegate alert_title(assigns), to: SaladUI.Alert
  defdelegate alert_description(assigns), to: SaladUI.Alert

  defdelegate separator(assigns), to: SaladUI.Separator
  @doc false
  @deprecated "Use the qualified skeleton/1 facade primitive"
  def compatibility_skeleton(assigns), do: SaladUI.Skeleton.skeleton(assigns)

  @doc false
  @deprecated "Use the qualified tooltip/1 facade primitive"
  def compatibility_tooltip(assigns), do: SaladUI.Tooltip.tooltip(assigns)
  defdelegate tooltip_trigger(assigns), to: SaladUI.Tooltip
  defdelegate tooltip_content(assigns), to: SaladUI.Tooltip

  defdelegate popover(assigns), to: SaladUI.Popover
  defdelegate popover_trigger(assigns), to: SaladUI.Popover
  defdelegate popover_content(assigns), to: SaladUI.Popover

  defdelegate command(assigns), to: SaladUI.Command
  defdelegate command_input(assigns), to: SaladUI.Command
  defdelegate command_empty(assigns), to: SaladUI.Command
  defdelegate command_list(assigns), to: SaladUI.Command
  defdelegate command_group(assigns), to: SaladUI.Command
  defdelegate command_item(assigns), to: SaladUI.Command
  defdelegate command_shortcut(assigns), to: SaladUI.Command

  defdelegate tabs(assigns), to: SaladUI.Tabs
  defdelegate tabs_list(assigns), to: SaladUI.Tabs
  defdelegate tabs_trigger(assigns), to: SaladUI.Tabs
  defdelegate tabs_content(assigns), to: SaladUI.Tabs

  defp closed_atom!(value, allowed, name) when is_atom(value) do
    if value in Map.values(allowed) do
      value
    else
      raise ArgumentError, "unsupported #{name}: #{inspect(value)}"
    end
  end

  defp closed_atom!(value, allowed, name) when is_binary(value) do
    case Map.fetch(allowed, value) do
      {:ok, atom} -> atom
      :error -> raise ArgumentError, "unsupported #{name}: #{inspect(value)}"
    end
  end

  defp closed_atom!(value, _allowed, name) do
    raise ArgumentError, "unsupported #{name}: #{inspect(value)}"
  end

  defp status_icon(:success), do: "hero-check-circle"
  defp status_icon(:attention), do: "hero-exclamation-triangle"
  defp status_icon(:failure), do: "hero-x-circle"
  defp status_icon(:neutral), do: "hero-information-circle"
end
