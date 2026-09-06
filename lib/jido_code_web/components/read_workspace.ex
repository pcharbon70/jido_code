defmodule JidoCodeWeb.Components.ReadWorkspace do
  @moduledoc """
  Stateless presentation components for bounded project and attempt workspaces.

  The components accept already-authorized display maps. They do not query,
  resolve identifiers, retain authority, or turn unsupported capabilities into
  controls.
  """

  use Phoenix.Component

  alias JidoCodeWeb.Components.Projection
  alias JidoCodeWeb.Components.UI

  @protected_states [:unauthorized, :unavailable, :maintenance, :recovery]
  @collection_limit 50
  @metadata_limit 24
  @label_limit 160
  @detail_limit 320
  @id_pattern ~r/^[A-Za-z][A-Za-z0-9_.:-]{0,95}$/u

  attr :id, :string, required: true
  attr :state, :any, required: true
  attr :title, :string, required: true
  attr :items, :list, default: []
  attr :class, :any, default: nil

  @doc "Renders a bounded definition list from already-shaped display scalars."
  def metadata_panel(assigns) do
    id = component_id!(assigns.id)
    state = canonical_state!(assigns.state)

    items =
      if state in @protected_states do
        []
      else
        assigns.items
        |> Enum.take(@metadata_limit)
        |> Enum.with_index(1)
        |> Enum.map(fn {item, index} ->
          %{
            id: "#{id}-item-#{index}",
            label: item |> field(:label) |> bounded_text("Detail", @label_limit),
            value: item |> field(:value) |> bounded_scalar("Unavailable")
          }
        end)
      end

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(:title, bounded_text(assigns.title, "Workspace details", @label_limit))
      |> assign(:items, items)

    ~H"""
    <section
      id={@id}
      aria-labelledby={@id <> "-title"}
      data-read-metadata
      data-projection-state={@state}
      class={["grid gap-4", @class]}
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h2 id={@id <> "-title"} class="text-xl font-semibold">{@title}</h2>
        <Projection.readiness_badge id={@id <> "-readiness"} state={@state} />
      </div>
      <Projection.projection_status
        :if={protected_state?(@state)}
        id={@id <> "-status"}
        state={@state}
      />
      <dl
        :if={@items != []}
        id={@id <> "-items"}
        class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3"
      >
        <div
          :for={item <- @items}
          id={item.id}
          class="rounded-lg border border-border bg-card px-4 py-4"
        >
          <dt class="text-sm font-medium text-muted-foreground">{item.label}</dt>
          <dd class="mt-1 break-words text-sm font-semibold">{item.value}</dd>
        </div>
      </dl>
      <p
        :if={@items == [] and not protected_state?(@state)}
        id={@id <> "-no-results"}
        data-no-results
        class="rounded-lg border border-dashed border-border px-4 py-6 text-sm text-muted-foreground"
      >
        No authorized details are available.
      </p>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :state, :any, required: true
  attr :title, :string, required: true
  attr :items, :list, default: []
  attr :empty_message, :string, default: "No authorized items are available."
  attr :retry_href, :string, default: nil
  attr :class, :any, default: nil

  @doc "Renders a bounded native-link collection for authorized workspace rows."
  def bounded_collection(assigns) do
    id = component_id!(assigns.id)
    state = canonical_state!(assigns.state)

    items =
      if state in @protected_states or state == :empty do
        []
      else
        assigns.items
        |> Enum.take(@collection_limit)
        |> Enum.with_index(1)
        |> Enum.map(fn {item, index} -> normalize_item(item, id, index) end)
      end

    assigns =
      assigns
      |> assign(:id, id)
      |> assign(:state, state)
      |> assign(:title, bounded_text(assigns.title, "Authorized items", @label_limit))
      |> assign(:items, items)
      |> assign(
        :empty_message,
        bounded_text(assigns.empty_message, "No authorized items are available.", @detail_limit)
      )

    ~H"""
    <section
      id={@id}
      aria-labelledby={@id <> "-title"}
      data-read-collection
      data-projection-state={@state}
      class={["grid gap-4", @class]}
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h2 id={@id <> "-title"} class="text-xl font-semibold">{@title}</h2>
        <Projection.readiness_badge id={@id <> "-readiness"} state={@state} />
      </div>
      <Projection.projection_status
        :if={protected_state?(@state)}
        id={@id <> "-status"}
        state={@state}
        retry_href={@retry_href}
      />
      <p
        :if={@items == [] and not protected_state?(@state)}
        id={@id <> "-no-results"}
        data-no-results
        class="rounded-lg border border-dashed border-border px-4 py-6 text-sm text-muted-foreground"
      >
        {@empty_message}
      </p>
      <ul :if={@items != []} id={@id <> "-items"} class="grid gap-3">
        <li
          :for={item <- @items}
          id={item.id}
          data-read-collection-item
          class="rounded-lg border border-border bg-card px-4 py-4"
        >
          <h3 class="break-words font-semibold">
            <UI.link :if={item.href} id={item.id <> "-link"} href={item.href}>{item.label}</UI.link>
            <span :if={is_nil(item.href)}>{item.label}</span>
          </h3>
          <p :if={item.detail} class="mt-1 break-words text-sm text-muted-foreground">
            {item.detail}
          </p>
          <dl :if={item.metadata != []} class="mt-3 grid gap-x-4 gap-y-2 text-sm sm:grid-cols-3">
            <div
              :for={{{label, value}, index} <- Enum.with_index(item.metadata)}
              id={item.id <> "-metadata-" <> Integer.to_string(index + 1)}
            >
              <dt class="font-medium text-muted-foreground">{label}</dt>
              <dd class="break-words">{value}</dd>
            </div>
          </dl>
        </li>
      </ul>
    </section>
    """
  end

  defp normalize_item(item, root_id, index) do
    metadata =
      item
      |> field(:metadata)
      |> list()
      |> Enum.take(8)
      |> Enum.map(fn item ->
        {
          item |> field(:label) |> bounded_text("Detail", @label_limit),
          item |> field(:value) |> bounded_scalar("Unavailable")
        }
      end)

    %{
      id: "#{root_id}-item-#{index}",
      label: item |> field(:label) |> bounded_text("Item", @label_limit),
      detail: item |> field(:detail) |> optional_text(@detail_limit),
      href: item |> field(:href) |> safe_href(),
      metadata: metadata
    }
  end

  defp canonical_state!(state) do
    case Projection.normalize_state(state) do
      {:ok, canonical} -> canonical
      {:error, _reason} -> raise ArgumentError, "unsupported workspace projection state"
    end
  end

  defp protected_state?(state), do: state in @protected_states

  defp component_id!(id) when is_binary(id) do
    id = String.trim(id)

    if Regex.match?(@id_pattern, id),
      do: id,
      else: raise(ArgumentError, "workspace component id must be stable and bounded")
  end

  defp component_id!(_id),
    do: raise(ArgumentError, "workspace component id must be stable and bounded")

  defp field(map, key) when is_map(map) and not is_struct(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp field(_map, _key), do: nil

  defp list(value) when is_list(value), do: value
  defp list(_value), do: []

  defp bounded_text(value, fallback, limit) when is_binary(value) do
    value = String.trim(value)

    cond do
      value == "" -> fallback
      String.length(value) <= limit -> value
      true -> String.slice(value, 0, limit - 1) <> "…"
    end
  end

  defp bounded_text(_value, fallback, _limit), do: fallback

  defp optional_text(value, limit) when is_binary(value), do: bounded_text(value, nil, limit)
  defp optional_text(_value, _limit), do: nil

  defp bounded_scalar(value, _fallback)
       when is_integer(value) or is_float(value) or is_atom(value) or is_boolean(value),
       do: value

  defp bounded_scalar(value, fallback) when is_binary(value),
    do: bounded_text(value, fallback, @detail_limit)

  defp bounded_scalar(_value, fallback), do: fallback

  defp safe_href(href) when is_binary(href) do
    href = String.trim(href)

    if byte_size(href) <= 320 and String.valid?(href) and
         String.starts_with?(href, ["/", "#", "?"]) and
         not String.starts_with?(href, "//") and not String.contains?(href, "\\") and
         not unsafe_bytes?(href),
       do: href,
       else: nil
  end

  defp safe_href(_href), do: nil

  defp unsafe_bytes?(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.any?(fn byte -> byte <= 0x1F or byte == 0x7F end)
  end
end
