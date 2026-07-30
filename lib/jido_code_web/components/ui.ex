defmodule JidoCodeWeb.Components.UI do
  @moduledoc """
  Application-owned boundary for HEEx components backed by SaladUI.

  LiveView templates should use this namespace for shadcn-aligned server-rendered
  primitives. If a component needs local customization later, keep this module as
  the public boundary and move the implementation behind it.
  """

  use Phoenix.Component

  defdelegate button(assigns), to: SaladUI.Button

  defdelegate card(assigns), to: SaladUI.Card
  defdelegate card_header(assigns), to: SaladUI.Card
  defdelegate card_title(assigns), to: SaladUI.Card
  defdelegate card_description(assigns), to: SaladUI.Card
  defdelegate card_content(assigns), to: SaladUI.Card
  defdelegate card_footer(assigns), to: SaladUI.Card

  defdelegate badge(assigns), to: SaladUI.Badge

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
end
