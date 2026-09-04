defmodule JidoCodeWeb.Components.UI do
  @moduledoc """
  Application-owned boundary for qualified HEEx primitives.

  Product code uses stable JidoCode names from this module and does not import
  upstream component namespaces. Existing SaladUI delegates remain explicitly
  compatibility-only until HUI-H; qualified primitives are backed by the exact
  ShadcnUI source selected in HUI-B1.
  """

  use Phoenix.Component

  alias ShadcnUI.Components.Disclosure.Accordion
  alias ShadcnUI.Components.Forms.Input, as: ShadcnInput
  alias ShadcnUI.Components.Foundation.Badge
  alias ShadcnUI.Components.Foundation.Button
  alias ShadcnUI.Components.Overlays.Dialog

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

  defdelegate alert(assigns), to: SaladUI.Alert
  defdelegate alert_title(assigns), to: SaladUI.Alert
  defdelegate alert_description(assigns), to: SaladUI.Alert

  defdelegate separator(assigns), to: SaladUI.Separator
  defdelegate skeleton(assigns), to: SaladUI.Skeleton

  defdelegate tooltip(assigns), to: SaladUI.Tooltip
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
end
