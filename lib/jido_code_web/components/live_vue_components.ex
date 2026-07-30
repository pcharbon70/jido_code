defmodule JidoCodeWeb.LiveVueComponents do
  @moduledoc """
  Shared helpers for bounded LiveVue mounts inside the LiveView shell.

  Every island declares an explicit SSR policy. Browser-only interaction surfaces
  should pass `ssr={false}`; DOM-only islands can opt into SSR. The wrapper sends
  full props by default because it flattens a product-owned `props` map into the
  direct attributes expected by LiveVue.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @semantic_emit "semantic-event"

  attr :component, :string, required: true
  attr :socket, :any, required: true
  attr :props, :map, default: %{}
  attr :events, :map, default: %{}
  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :ssr, :boolean, required: true
  attr :diff, :boolean, default: false

  def vue_surface(assigns) do
    event_bindings = normalize_events!(assigns.events)

    vue_assigns =
      assigns
      |> Map.take([:__changed__])
      |> Map.put(:"v-component", assigns.component)
      |> Map.put(:"v-socket", assigns.socket)
      |> Map.put(:"v-ssr", assigns.ssr)
      |> Map.put(:"v-diff", assigns.diff)
      |> maybe_put(:id, assigns.id)
      |> maybe_put(:class, assigns.class)
      |> Map.merge(assigns.props)

    vue_assigns =
      Enum.reduce(event_bindings, vue_assigns, fn {emit, handler}, acc ->
        Map.put(acc, "v-on:#{emit}", handler)
      end)

    LiveVue.vue(vue_assigns)
  end

  def semantic_event(push_event_name) when is_binary(push_event_name) do
    %{@semantic_emit => normalize_semantic_push_event!(push_event_name)}
  end

  defp maybe_put(assigns, _key, nil), do: assigns
  defp maybe_put(assigns, key, value), do: Map.put(assigns, key, value)

  defp normalize_events!(events) when is_map(events) do
    Map.new(events, fn {emit, handler} ->
      normalized_emit = emit |> to_string() |> String.trim()

      if normalized_emit == "" do
        raise ArgumentError, "expected Vue emit name to be present"
      end

      normalized_handler =
        case handler do
          %JS{} = js -> js
          event_name when is_binary(event_name) -> JS.push(event_name)
          other -> raise ArgumentError, "unsupported LiveVue event handler: #{inspect(other)}"
        end

      {normalized_emit, normalized_handler}
    end)
  end

  defp normalize_events!(other) do
    raise ArgumentError, "expected :events to be a map, got: #{inspect(other)}"
  end

  defp normalize_semantic_push_event!(push_event_name) do
    normalized = String.trim(push_event_name)

    if normalized == "" or not String.ends_with?(normalized, "/semantic-event") do
      raise ArgumentError,
            "expected semantic LiveVue event handler to end with /semantic-event, got: #{inspect(push_event_name)}"
    end

    normalized
  end
end
