defmodule JidoCodeWeb.HomeLive do
  use JidoCodeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Live Server")
     |> assign(:started_at, timestamp())
     |> assign(:heartbeat_count, 0)
     |> assign(:events, [])
     |> assign(:connected?, connected?(socket))}
  end

  @impl true
  def handle_event("ping", _params, socket) do
    {:noreply,
     socket
     |> update(:heartbeat_count, &(&1 + 1))
     |> push_event("heartbeat", %{})
     |> log_event("Heartbeat acknowledged")}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:heartbeat_count, 0)
     |> log_event("Heartbeat counter reset")}
  end

  def handle_event("runtime/semantic-event", %{"action" => "ping"}, socket) do
    handle_event("ping", %{}, socket)
  end

  def handle_event("runtime/semantic-event", %{"action" => "reset"}, socket) do
    handle_event("reset", %{}, socket)
  end

  def handle_event("runtime/semantic-event", _payload, socket) do
    {:noreply, log_event(socket, "Ignored runtime island event")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="runtime-workspace" class="min-h-full bg-background text-foreground">
        <section
          id="runtime-overview"
          aria-labelledby="runtime-overview-title"
          class="border-b border-border bg-card/70"
        >
          <div class="mx-auto grid w-full max-w-7xl gap-6 px-4 py-6 sm:px-6 lg:grid-cols-[1fr_22rem] lg:px-8">
            <div class="min-w-0">
              <div class="flex items-center gap-3">
                <span class="inline-flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary text-primary-foreground">
                  <.icon name="hero-bolt-solid" class="size-5" />
                </span>
                <div class="min-w-0">
                  <p class="text-xs font-medium uppercase text-muted-foreground">JidoCode</p>
                  <h1
                    id="runtime-overview-title"
                    class="mt-1 text-2xl font-semibold leading-tight tracking-normal text-foreground sm:text-3xl"
                  >
                    LiveView server
                  </h1>
                </div>
              </div>

              <p class="mt-4 max-w-3xl text-sm leading-6 text-muted-foreground sm:text-base">
                A Phoenix runtime workbench that keeps server state in LiveView while mounting
                client-side islands for focused interaction surfaces.
              </p>

              <div class="mt-5 flex flex-wrap gap-2">
                <UI.badge variant="secondary">SaladUI primitives</UI.badge>
                <UI.badge variant="outline">LiveVue islands</UI.badge>
                <UI.badge variant="outline">Vite pipeline</UI.badge>
              </div>
            </div>

            <UI.card id="runtime-connection-card" class="rounded-lg shadow-sm">
              <UI.card_header class="p-5 pb-3">
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <UI.card_description>Connection</UI.card_description>
                    <UI.card_title class="mt-1 text-xl">
                      <span :if={@connected?}>Connected</span>
                      <span :if={!@connected?}>Starting</span>
                    </UI.card_title>
                  </div>
                  <span
                    aria-hidden="true"
                    class={[
                      "mt-1 inline-flex size-3 rounded-full",
                      @connected? && "bg-status-healthy",
                      !@connected? && "bg-status-attention"
                    ]}
                  />
                </div>
              </UI.card_header>
              <UI.card_content class="px-5 pb-5">
                <UI.separator class="mb-4" />
                <dl class="space-y-2 text-sm">
                  <div class="flex justify-between gap-4">
                    <dt class="text-muted-foreground">Started</dt>
                    <dd>
                      <time datetime={DateTime.to_iso8601(@started_at)}>
                        {format_time(@started_at)}
                      </time>
                    </dd>
                  </div>
                  <div class="flex justify-between gap-4">
                    <dt class="text-muted-foreground">Uptime</dt>
                    <dd>{format_uptime(@started_at)}</dd>
                  </div>
                </dl>
              </UI.card_content>
            </UI.card>
          </div>
        </section>

        <div class="mx-auto grid w-full max-w-7xl gap-6 px-4 py-6 sm:px-6 lg:px-8">
          <section
            id="runtime-metrics"
            aria-label="Runtime metrics"
            class="grid gap-4 md:grid-cols-3"
          >
            <UI.card
              :for={metric <- runtime_metrics(@heartbeat_count)}
              id={"runtime-metric-#{metric.id}"}
              class="rounded-lg shadow-sm"
            >
              <UI.card_header class="p-5 pb-2">
                <UI.card_description>{metric.label}</UI.card_description>
              </UI.card_header>
              <UI.card_content class="px-5 pb-5">
                <p class="text-3xl font-semibold leading-none tracking-normal">
                  <span :if={metric.id == "heartbeats"} id="heartbeat-count">{metric.value}</span>
                  <span :if={metric.id != "heartbeats"}>{metric.value}</span>
                </p>
                <p class="mt-2 text-sm text-muted-foreground">{metric.detail}</p>
              </UI.card_content>
            </UI.card>
          </section>

          <section
            id="runtime-surfaces"
            aria-labelledby="runtime-surfaces-title"
            class="grid min-h-0 gap-6 xl:grid-cols-[0.82fr_1.18fr]"
          >
            <div class="grid min-h-0 gap-6">
              <UI.card id="runtime-control-plane" class="rounded-lg shadow-sm">
                <UI.card_header class="p-5 pb-3">
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <UI.card_description>LiveView surface</UI.card_description>
                      <UI.card_title id="runtime-surfaces-title" class="mt-1 text-xl">
                        Runtime controls
                      </UI.card_title>
                    </div>
                    <UI.badge variant="outline">server owned</UI.badge>
                  </div>
                </UI.card_header>
                <UI.card_content class="px-5 pb-5">
                  <p class="text-sm leading-6 text-muted-foreground">
                    These controls mutate assigns directly and emit the same server state consumed
                    by the Vue island.
                  </p>

                  <div id="runtime-actions" class="mt-4 flex flex-wrap gap-2">
                    <UI.button type="button" phx-click="ping">
                      <.icon name="hero-signal" class="size-4" /> Ping
                    </UI.button>
                    <UI.button
                      type="button"
                      variant="outline"
                      phx-click="reset"
                      aria-label="Reset heartbeats"
                    >
                      <.icon name="hero-arrow-path" class="size-4" /> Reset
                    </UI.button>
                  </div>
                </UI.card_content>
              </UI.card>

              <UI.card id="runtime-event-card" class="rounded-lg shadow-sm">
                <UI.card_header class="p-5 pb-3">
                  <div class="flex items-center justify-between gap-3">
                    <div>
                      <UI.card_description>Activity</UI.card_description>
                      <UI.card_title class="mt-1 text-xl">Event log</UI.card_title>
                    </div>
                    <UI.badge variant="secondary">{length(@events)} entries</UI.badge>
                  </div>
                </UI.card_header>
                <UI.card_content class="px-5 pb-5">
                  <ol id="event-log" class="space-y-3">
                    <li :if={@events == []} class="text-sm text-muted-foreground">
                      No events yet.
                    </li>
                    <li
                      :for={event <- @events}
                      id={"runtime-event-#{event.id}"}
                      class="flex items-center justify-between gap-4 rounded-md border border-border bg-background px-3 py-2 text-sm"
                    >
                      <span class="font-medium">{event.message}</span>
                      <time
                        class="font-mono text-xs text-muted-foreground"
                        datetime={DateTime.to_iso8601(event.at)}
                      >
                        {format_time(event.at)}
                      </time>
                    </li>
                  </ol>
                </UI.card_content>
              </UI.card>
            </div>

            <div class="grid min-h-0 gap-6">
              <section
                id="runtime-status-island-region"
                aria-label="Runtime status island"
                class="rounded-lg border border-border bg-background p-4 shadow-sm"
              >
                <.vue_surface
                  id="runtime-status-island"
                  component="runtime/HeartbeatStatusIsland"
                  events={semantic_event("runtime/semantic-event")}
                  props={
                    %{
                      connected: @connected?,
                      heartbeatCount: @heartbeat_count,
                      startedAt: format_time(@started_at),
                      events: event_views(@events)
                    }
                  }
                  socket={@socket}
                  ssr={true}
                />
              </section>

              <section
                id="toolchain-status-island-region"
                aria-label="Toolchain status island"
                class="rounded-lg border border-border bg-background p-4 shadow-sm"
              >
                <.vue_surface
                  id="toolchain-status-island"
                  component="runtime/ToolchainStatusIsland"
                  props={%{entries: toolchain_entries()}}
                  socket={@socket}
                  ssr={true}
                />
              </section>
            </div>
          </section>

          <section
            id="runtime-boundary-map"
            aria-labelledby="runtime-boundary-map-title"
            class="grid gap-4 md:grid-cols-3"
          >
            <div class="md:col-span-3">
              <h2 id="runtime-boundary-map-title" class="text-sm font-semibold">
                Surface boundaries
              </h2>
            </div>

            <div
              :for={surface <- surface_boundaries()}
              id={"runtime-boundary-#{surface.id}"}
              class="rounded-lg border border-border bg-card p-4 text-card-foreground shadow-sm"
            >
              <div class="flex items-center justify-between gap-3">
                <h3 class="text-sm font-semibold">{surface.label}</h3>
                <span class="inline-flex size-2 rounded-full bg-status-informational" />
              </div>
              <p class="mt-2 text-sm leading-6 text-muted-foreground">{surface.detail}</p>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp log_event(socket, message) do
    event = %{id: System.unique_integer([:positive]), message: message, at: timestamp()}

    update(socket, :events, fn events ->
      [event | events] |> Enum.take(6)
    end)
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S UTC")
  end

  defp format_uptime(started_at) do
    seconds = DateTime.diff(timestamp(), started_at, :second)

    cond do
      seconds < 60 -> "#{seconds}s"
      seconds < 3_600 -> "#{div(seconds, 60)}m #{rem(seconds, 60)}s"
      true -> "#{div(seconds, 3_600)}h #{div(rem(seconds, 3_600), 60)}m"
    end
  end

  defp event_views(events) do
    Enum.map(events, fn event ->
      %{
        id: Integer.to_string(event.id),
        message: event.message,
        at: format_time(event.at)
      }
    end)
  end

  defp runtime_metrics(heartbeat_count) do
    [
      %{id: "heartbeats", label: "Heartbeats", value: heartbeat_count, detail: "LiveView assign"},
      %{id: "runtime", label: "Runtime", value: System.otp_release(), detail: "OTP release"},
      %{
        id: "framework",
        label: "Framework",
        value: "Phoenix #{Application.spec(:phoenix, :vsn)}",
        detail: "LiveView #{Application.spec(:phoenix_live_view, :vsn)}"
      }
    ]
  end

  defp toolchain_entries do
    [
      %{id: "vite", label: "Vite", status: "ready", detail: "Client and SSR bundles"},
      %{
        id: "tailwind",
        label: "Tailwind v4",
        status: "ready",
        detail: "Token-driven theme source"
      },
      %{
        id: "salad-ui",
        label: "SaladUI",
        status: "ready",
        detail: "Server-rendered shadcn primitives"
      },
      %{id: "live-vue", label: "LiveVue", status: "ready", detail: "Mounted island registry"}
    ]
  end

  defp surface_boundaries do
    [
      %{
        id: "liveview",
        label: "LiveView shell",
        detail: "Owns routing, assigns, flash, and server events for the workbench."
      },
      %{
        id: "salad-ui",
        label: "SaladUI boundary",
        detail: "HEEx surfaces consume UI primitives through JidoCodeWeb.Components.UI."
      },
      %{
        id: "live-vue",
        label: "LiveVue islands",
        detail: "Client components mount through vue_surface/1 with explicit props and emits."
      }
    ]
  end
end
