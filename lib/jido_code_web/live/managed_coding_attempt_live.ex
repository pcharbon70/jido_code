defmodule JidoCodeWeb.ManagedCodingAttemptLive do
  use JidoCodeWeb, :live_view

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Product.GraphManagedCodingAttemptProvider
  alias JidoCode.Product.ManagedCodingAttempt
  alias JidoCode.Product.ManagedCodingControlGateway

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Managed coding attempt")
     |> assign(:attempt, nil)
     |> assign(:attempt_view, unavailable_view())
     |> assign(:control_form, control_form())
     |> assign(:control_outcome, nil)
     |> stream(:interactions, [])
     |> stream(:tools, [])
     |> stream(:checks, [])}
  end

  @impl true
  def handle_params(%{"attempt_ref" => reference}, _uri, socket) do
    {:noreply, load_attempt(socket, reference)}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_attempt(socket, socket.assigns.attempt_view.presentation_ref)}
  end

  def handle_event("control", %{"action" => action, "control" => params}, socket) do
    with {:ok, operation} <- control_action(action),
         %ManagedCodingAttempt{} = attempt <- socket.assigns.attempt,
         params <- Map.put(params, "idempotency_key", control_key(attempt, operation, params)),
         gateway <-
           Application.get_env(
             :jido_code,
             :managed_coding_control_gateway,
             ManagedCodingControlGateway
           ),
         {:ok, outcome} <-
           gateway.submit(
             socket.assigns.authority,
             socket.assigns.product_identity,
             attempt,
             operation,
             params,
             []
           ) do
      {:noreply,
       socket
       |> assign(:control_outcome, %{state: outcome.state, sequence: outcome.sequence})
       |> assign(:control_form, control_form())
       |> put_flash(:info, "Managed coding command accepted.")
       |> load_attempt(attempt.presentation_ref)}
    else
      {:error, %AdapterError{}} ->
        {:noreply, put_flash(socket, :error, "The command was rejected; refresh the attempt.")}

      _invalid ->
        {:noreply, put_flash(socket, :error, "That managed coding control is unavailable.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <main
        id="managed-coding-attempt"
        class="min-h-full bg-frame-canvas px-4 py-6 text-foreground sm:px-6"
      >
        <div class="mx-auto grid w-full max-w-6xl gap-5">
          <header class="flex flex-col gap-4 border-b border-frame-border pb-5 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.16em] text-muted-foreground">
                Managed coding
              </p>
              <h1 id="managed-attempt-title" class="mt-2 text-2xl font-semibold tracking-tight">
                {@attempt_view.task_label}
              </h1>
              <p id="managed-attempt-reference" class="mt-2 font-mono text-xs text-muted-foreground">
                ref {@attempt_view.presentation_ref}
              </p>
            </div>
            <button
              id="managed-attempt-refresh"
              type="button"
              phx-click="refresh"
              class="inline-flex h-10 items-center justify-center gap-2 rounded-md border border-border bg-background px-4 text-sm font-medium transition-colors hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <.icon name="hero-arrow-path" class="size-4 phx-click-loading:animate-spin" /> Refresh
            </button>
          </header>

          <section
            id="managed-attempt-status"
            class="grid gap-px overflow-hidden rounded-xl border border-border bg-border sm:grid-cols-2 lg:grid-cols-4"
          >
            <.status_cell label="Runtime" value={@attempt_view.state} />
            <.status_cell label="Wait" value={@attempt_view.wait_reason || "none"} />
            <.status_cell label="Verification" value={@attempt_view.verification} />
            <.status_cell label="Disposition" value={@attempt_view.disposition || "pending"} />
          </section>

          <section id="managed-attempt-evidence" class="grid gap-4 lg:grid-cols-3">
            <.summary_stream
              id="managed-interactions"
              title="Interactions"
              stream={@streams.interactions}
              icon="hero-chat-bubble-left-right"
            />
            <.summary_stream
              id="managed-tools"
              title="Tool effects"
              stream={@streams.tools}
              icon="hero-wrench-screwdriver"
            />
            <.summary_stream
              id="managed-checks"
              title="Checks"
              stream={@streams.checks}
              icon="hero-check-circle"
            />
          </section>

          <section id="managed-attempt-controls" class="rounded-xl border border-border bg-card p-5">
            <div class="flex items-start justify-between gap-4">
              <div>
                <h2 class="text-base font-semibold">Operator controls</h2>
                <p class="mt-1 text-sm text-muted-foreground">
                  Commands are bound to the current graph-projected fence.
                </p>
              </div>
              <span
                :if={@control_outcome}
                id="managed-control-outcome"
                class="rounded-full bg-muted px-3 py-1 font-mono text-xs"
              >
                {@control_outcome.state} · {@control_outcome.sequence}
              </span>
            </div>

            <.form
              for={@control_form}
              id="managed-control-form"
              phx-submit="control"
              class="mt-5 grid gap-4"
            >
              <.input
                field={@control_form[:message]}
                type="textarea"
                label="Steering or clarification response"
              />
              <.input
                field={@control_form[:confirmed]}
                type="checkbox"
                label="Confirm cancellation or retry"
              />
              <div class="flex flex-wrap gap-2">
                <button
                  :for={
                    {action, label} <- [
                      {"steer", "Steer"},
                      {"answer", "Answer"},
                      {"cancel", "Cancel"},
                      {"retry", "Retry"}
                    ]
                  }
                  id={"managed-control-#{action}"}
                  name="action"
                  value={action}
                  type="submit"
                  class="rounded-md border border-border bg-background px-4 py-2 text-sm font-medium transition-colors hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                >
                  {label}
                </button>
              </div>
            </.form>
          </section>
        </div>
      </main>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp status_cell(assigns) do
    ~H"""
    <div class="bg-card p-4">
      <p class="text-xs font-medium text-muted-foreground">{@label}</p>
      <p class="mt-2 text-sm font-semibold">{@value}</p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :stream, :any, required: true
  attr :icon, :string, required: true

  defp summary_stream(assigns) do
    ~H"""
    <article class="rounded-xl border border-border bg-card p-4">
      <div class="flex items-center gap-2">
        <.icon name={@icon} class="size-4 text-muted-foreground" />
        <h2 class="text-sm font-semibold">{@title}</h2>
      </div>
      <div id={@id} phx-update="stream" class="mt-4 grid gap-2">
        <p id={"#{@id}-empty"} class="hidden only:block text-xs text-muted-foreground">
          No graph-visible summaries.
        </p>
        <div
          :for={{id, item} <- @stream}
          id={id}
          class="flex items-center justify-between gap-3 border-t border-border py-2 text-xs first:border-0"
        >
          <span class="truncate">{item.label}</span>
          <span class="font-mono text-muted-foreground">{item.status}</span>
        </div>
      </div>
    </article>
    """
  end

  defp load_attempt(socket, reference) do
    provider =
      Application.get_env(
        :jido_code,
        :managed_coding_attempt_provider,
        GraphManagedCodingAttemptProvider
      )

    case provider.load(socket.assigns.authority, socket.assigns.product_identity, reference) do
      {:ok, %ManagedCodingAttempt{} = attempt} ->
        view = ManagedCodingAttempt.view(attempt)

        socket
        |> assign(:attempt, attempt)
        |> assign(:attempt_view, view)
        |> stream(:interactions, stream_items(view.interactions, "interaction"), reset: true)
        |> stream(:tools, stream_items(view.tools, "tool"), reset: true)
        |> stream(:checks, stream_items(view.checks, "check"), reset: true)

      _unavailable ->
        socket
        |> assign(:attempt, nil)
        |> assign(:attempt_view, Map.put(unavailable_view(), :presentation_ref, reference))
        |> stream(:interactions, [], reset: true)
        |> stream(:tools, [], reset: true)
        |> stream(:checks, [], reset: true)
        |> put_flash(:error, "This attempt is unavailable in the current scope.")
    end
  end

  defp stream_items(values, prefix) do
    values
    |> Enum.with_index()
    |> Enum.map(fn {value, index} -> Map.put(value, :id, "#{prefix}-#{index}") end)
  end

  defp control_action("steer"), do: {:ok, :steer}
  defp control_action("answer"), do: {:ok, :answer}
  defp control_action("cancel"), do: {:ok, :cancel}
  defp control_action("retry"), do: {:ok, :retry}
  defp control_action(_action), do: :error

  defp control_key(attempt, action, params) do
    :crypto.hash(
      :sha256,
      :erlang.term_to_binary(
        {attempt.presentation_ref, attempt.fencing_token, action,
         Map.drop(params, ["idempotency_key"])},
        [:deterministic]
      )
    )
    |> Base.url_encode64(padding: false)
  end

  defp control_form, do: to_form(%{"message" => "", "confirmed" => "false"}, as: :control)

  defp unavailable_view do
    %{
      presentation_ref: "unavailable",
      task_label: "Attempt unavailable",
      state: :unavailable,
      wait_reason: nil,
      budgets: %{},
      interactions: [],
      tools: [],
      checks: [],
      candidate_ref: nil,
      verification: :unavailable,
      disposition: nil,
      evidence_refs: [],
      updated_at: nil
    }
  end
end
