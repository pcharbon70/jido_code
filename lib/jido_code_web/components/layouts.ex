defmodule JidoCodeWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use JidoCodeWeb, :html

  @appearance_cookie "jido_appearance"
  @resolved_theme_cookie "jido_resolved_theme"
  @appearances ~w(system light dark)
  @resolved_themes ~w(light dark)
  @appearance_labels %{"system" => "System", "light" => "Light", "dark" => "Dark"}

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc "Returns presentation-only theme attributes from closed, non-authority cookies."
  @spec theme_attributes(Plug.Conn.t()) :: map()
  def theme_attributes(%Plug.Conn{} = conn) do
    cookies = request_cookies(conn)
    appearance = closed_value(cookies[@appearance_cookie], @appearances, "system")
    resolved = closed_value(cookies[@resolved_theme_cookie], @resolved_themes, nil)
    theme = if(appearance == "system", do: resolved, else: appearance)

    %{
      appearance: appearance,
      theme: theme,
      shadcn_theme: theme
    }
  end

  defp request_cookies(%Plug.Conn{req_cookies: %Plug.Conn.Unfetched{}} = conn),
    do: Plug.Conn.fetch_cookies(conn).req_cookies

  defp request_cookies(%Plug.Conn{req_cookies: cookies}) when is_map(cookies), do: cookies

  defp closed_value(value, allowed, fallback),
    do: if(value in allowed, do: value, else: fallback)

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :frame, :atom,
    values: [:application, :content],
    default: :application,
    doc: "closed outer frame; content lets an application-owned shell provide landmarks"

  slot :inner_block, required: true

  def app(assigns) do
    case closed_frame!(assigns.frame) do
      :application -> application_frame(assigns)
      :content -> content_frame(assigns)
    end
  end

  defp application_frame(assigns) do
    ~H"""
    <div
      id="application-shell"
      class="grid h-screen grid-rows-[3rem_minmax(0,1fr)_1.75rem] overflow-hidden bg-frame-canvas text-frame-text"
    >
      <header
        id="application-context-bar"
        class="flex items-center justify-between border-b border-frame-border bg-frame-chrome px-4 sm:px-6"
      >
        <div class="flex min-w-0 items-center gap-3">
          <a
            id="application-product-home"
            href="/"
            aria-label="JidoCode home"
            class="flex min-h-11 items-center gap-2 rounded-md text-sm font-semibold tracking-tight outline-none focus-visible:ring-2 focus-visible:ring-frame-focus"
          >
            <img src={~p"/images/logo.svg"} width="26" height="26" alt="" aria-hidden="true" />
            <span>JidoCode</span>
          </a>

          <span class="hidden h-4 w-px bg-frame-border sm:block" />
          <span class="hidden truncate text-xs text-frame-text-muted sm:block">
            Secure hypermedia control plane
          </span>
        </div>

        <div class="flex items-center gap-2">
          <.theme_toggle />
          <.link
            :if={@current_scope}
            id="application-sign-out"
            href={~p"/sign-out"}
            method="delete"
            aria-label="Sign out"
            title="Sign out"
            class="inline-flex size-9 items-center justify-center rounded-md border border-frame-border bg-frame-chrome-elevated text-frame-text-muted outline-none transition-colors hover:text-frame-text focus-visible:ring-2 focus-visible:ring-frame-focus"
          >
            <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" />
          </.link>
        </div>
      </header>

      <main id="application-outlet" class="min-h-0 overflow-auto">
        {render_slot(@inner_block)}
      </main>

      <footer
        id="application-status-bar"
        class="flex items-center justify-between border-t border-frame-border bg-frame-chrome px-4 font-mono text-[0.6875rem] text-frame-text-muted sm:px-6"
      >
        <span>{if(@current_scope, do: "session: authenticated", else: "session: public")}</span>
        <span>authority: graph-scoped</span>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp content_frame(assigns) do
    ~H"""
    <div id="application-content-frame" data-layout-frame="content">
      {render_slot(@inner_block)}
      <.flash_group flash={@flash} />
    </div>
    """
  end

  defp closed_frame!(frame) when frame in [:application, :content], do: frame

  defp closed_frame!(frame) do
    raise ArgumentError, "unsupported layout frame: #{inspect(frame)}"
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides System, Light, and Dark appearance controls backed by semantic tokens.
  The application bundle initializes and persists selection.
  """
  attr :appearance, :string, default: nil

  def theme_toggle(assigns) do
    appearance = closed_value(assigns.appearance, @appearances, "system")

    assigns =
      assigns
      |> assign(:appearance, appearance)
      |> assign(:appearance_label, Map.fetch!(@appearance_labels, appearance))

    ~H"""
    <div
      id="application-theme-toggle"
      role="group"
      aria-label="Appearance"
      aria-describedby="application-theme-current"
      class="flex items-center"
    >
      <span id="application-theme-current" data-theme-current class="sr-only">
        Current appearance: {@appearance_label}. Controls require scripting.
      </span>
      <div
        id="application-theme-controls"
        data-theme-controls
        hidden
        class="min-h-[var(--touch-target)] items-center rounded-md border border-frame-border bg-frame-chrome-elevated lg:h-9 lg:min-h-0"
      >
        <button
          id="application-theme-system"
          type="button"
          class={theme_control_class()}
          data-theme-choice
          data-phx-theme="system"
          aria-pressed={if(@appearance == "system", do: "true", else: "false")}
          aria-label="Use system theme"
        >
          <.icon name="hero-computer-desktop-micro" class="size-4" />
        </button>

        <button
          id="application-theme-light"
          type="button"
          class={theme_control_class()}
          data-theme-choice
          data-phx-theme="light"
          aria-pressed={if(@appearance == "light", do: "true", else: "false")}
          aria-label="Use light theme"
        >
          <.icon name="hero-sun-micro" class="size-4" />
        </button>

        <button
          id="application-theme-dark"
          type="button"
          class={theme_control_class()}
          data-theme-choice
          data-phx-theme="dark"
          aria-pressed={if(@appearance == "dark", do: "true", else: "false")}
          aria-label="Use dark theme"
        >
          <.icon name="hero-moon-micro" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  defp theme_control_class do
    [
      "flex size-9 cursor-pointer items-center justify-center text-frame-text-muted outline-none",
      "transition-colors hover:text-frame-text focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-frame-focus motion-reduce:transition-none"
    ]
  end
end
