defmodule JidoCodeWeb.CodingAgentLive do
  use JidoCodeWeb, :live_view

  alias JidoCode.Product.AgentCatalogGateway
  alias JidoCode.Product.AgentOffering
  alias JidoCode.Product.CodingSubmissionGateway
  alias JidoCode.Product.WorkflowOutcome

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Coding agents")
     |> assign(:catalog_form, catalog_form())
     |> assign(:submission_form, submission_form())
     |> assign(:offering_index, %{})
     |> assign(:offering_count, 0)
     |> assign(:offerings_empty?, true)
     |> assign(:selected_offering, nil)
     |> assign(:submission_outcome, nil)
     |> stream_configure(:offerings, dom_id: &"agent-offering-#{&1.reference}")
     |> stream(:offerings, [])}
  end

  @impl true
  def handle_event("discover", %{"catalog" => params}, socket) do
    gateway = Application.get_env(:jido_code, :agent_catalog_gateway, AgentCatalogGateway)

    case invoke_catalog(gateway, socket, params) do
      {:ok, offerings} ->
        index = Map.new(offerings, &{&1.reference, &1})

        {:noreply,
         socket
         |> assign(:catalog_form, to_form(params, as: :catalog))
         |> assign(:submission_form, submission_form(params))
         |> assign(:offering_index, index)
         |> assign(:offering_count, length(offerings))
         |> assign(:offerings_empty?, offerings == [])
         |> assign(:selected_offering, nil)
         |> assign(:submission_outcome, nil)
         |> stream(:offerings, offerings, reset: true)}

      {:error, _error} ->
        {:noreply,
         socket
         |> assign(:catalog_form, to_form(params, as: :catalog))
         |> assign(:offering_index, %{})
         |> assign(:offering_count, 0)
         |> assign(:offerings_empty?, true)
         |> assign(:selected_offering, nil)
         |> stream(:offerings, [], reset: true)
         |> put_flash(:error, "Agent offerings are unavailable for that scope.")}
    end
  end

  def handle_event("select-offering", %{"reference" => reference}, socket) do
    case Map.fetch(socket.assigns.offering_index, reference) do
      {:ok, %AgentOffering{selectable: true} = offering} ->
        params =
          socket.assigns.submission_form.params
          |> Map.put("offering_ref", offering.reference)
          |> Map.put("foreground_consent", "false")
          |> Map.put("billing_acknowledged", "false")

        {:noreply,
         socket
         |> assign(:selected_offering, offering)
         |> assign(:submission_form, to_form(params, as: :submission))
         |> assign(:submission_outcome, nil)}

      _unavailable ->
        {:noreply, put_flash(socket, :error, "That agent offering is not selectable.")}
    end
  end

  def handle_event("submit-task", %{"submission" => params}, socket) do
    gateway =
      Application.get_env(:jido_code, :coding_submission_gateway, CodingSubmissionGateway)

    params =
      params
      |> Map.put("offering_ref", selected_reference(socket))
      |> Map.put_new("idempotency_key", submission_key(socket, params))

    case invoke_submission(gateway, socket, params) do
      {:ok, %WorkflowOutcome{} = outcome} ->
        {:noreply,
         socket
         |> assign(:submission_form, to_form(params, as: :submission))
         |> assign(:submission_outcome, WorkflowOutcome.safe_map(outcome))
         |> put_flash(:info, submission_message(outcome.code))}

      {:error, _error} ->
        {:noreply,
         socket
         |> assign(:submission_form, to_form(params, as: :submission))
         |> assign(:submission_outcome, %{code: :rejected, retry: :never})
         |> put_flash(:error, "The task was not admitted; review the selection and consent.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <main id="coding-agent-workbench" class="min-h-full bg-frame-canvas text-foreground">
        <div class="mx-auto grid w-full max-w-7xl gap-8 px-4 py-8 sm:px-6 lg:px-8">
          <header class="grid gap-5 border-b border-frame-border pb-7 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-end">
            <div class="max-w-3xl">
              <div class="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-primary">
                <span class="size-2 rounded-full bg-primary shadow-[0_0_0_4px_hsl(var(--primary)/0.12)]">
                </span>
                Governed coding runtime
              </div>
              <h1
                id="coding-agent-title"
                class="mt-4 text-3xl font-semibold tracking-tight sm:text-4xl"
              >
                Choose the right execution boundary
              </h1>
              <p class="mt-3 max-w-2xl text-sm leading-6 text-muted-foreground">
                Native and delegated agents share one admission path. Runtime, billing, readiness,
                capability, and limitations remain explicit before any work begins.
              </p>
            </div>
            <.link
              id="coding-agent-back"
              navigate={~p"/?surface=execution"}
              class="inline-flex h-10 items-center justify-center gap-2 rounded-md border border-border bg-background px-4 text-sm font-medium transition-all hover:-translate-y-0.5 hover:bg-muted hover:shadow-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Factory execution
            </.link>
          </header>

          <section
            id="agent-scope"
            class="rounded-2xl border border-border bg-card p-5 shadow-sm sm:p-6"
          >
            <div class="flex items-start gap-3">
              <div class="grid size-9 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary">
                <.icon name="hero-funnel" class="size-4" />
              </div>
              <div>
                <h2 class="text-base font-semibold">Scope the catalog</h2>
                <p class="mt-1 text-sm text-muted-foreground">
                  Offerings are resolved for the current operator, tenant, repository, task, and time.
                </p>
              </div>
            </div>

            <.form
              for={@catalog_form}
              id="agent-catalog-form"
              phx-submit="discover"
              class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-3"
            >
              <.input field={@catalog_form[:repository_ref]} label="Repository reference" />
              <.input field={@catalog_form[:snapshot_ref]} label="Snapshot reference" />
              <.input field={@catalog_form[:task_class]} label="Task class" />
              <.input field={@catalog_form[:language_class]} label="Language class" />
              <.input field={@catalog_form[:capability_class]} label="Capability class" />
              <.input
                field={@catalog_form[:rollout_stage]}
                type="select"
                label="Rollout stage"
                options={[
                  Evaluation: "evaluation",
                  Shadow: "shadow",
                  Pilot: "pilot",
                  Production: "production"
                ]}
              />
              <button
                id="agent-catalog-discover"
                type="submit"
                phx-disable-with="Resolving offerings…"
                class="inline-flex h-11 items-center justify-center gap-2 rounded-md bg-primary px-5 text-sm font-semibold text-primary-foreground shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring md:col-span-2 xl:col-span-3 xl:justify-self-start"
              >
                <.icon name="hero-sparkles" class="size-4" /> Discover scoped agents
              </button>
            </.form>
          </section>

          <section id="agent-catalog" aria-labelledby="agent-catalog-title" class="grid gap-4">
            <div class="flex items-end justify-between gap-4">
              <div>
                <p class="text-xs font-medium uppercase tracking-[0.14em] text-muted-foreground">
                  {@offering_count} eligible profiles
                </p>
                <h2 id="agent-catalog-title" class="mt-1 text-xl font-semibold">Agent catalog</h2>
              </div>
              <span class="rounded-full border border-border bg-background px-3 py-1 font-mono text-xs text-muted-foreground">
                exact selection
              </span>
            </div>

            <div id="agent-offerings" phx-update="stream" class="grid gap-4 lg:grid-cols-2">
              <div
                id="agent-offerings-empty"
                class="hidden only:grid min-h-56 place-items-center rounded-2xl border border-dashed border-border bg-card/60 text-center lg:col-span-2"
              >
                <div class="max-w-sm px-6">
                  <.icon name="hero-cpu-chip" class="mx-auto size-7 text-muted-foreground" />
                  <p class="mt-3 text-sm font-semibold">No scoped offerings loaded</p>
                  <p class="mt-1 text-xs leading-5 text-muted-foreground">
                    Resolve the catalog to see profiles authorized for this exact repository snapshot.
                  </p>
                </div>
              </div>

              <article
                :for={{id, offering} <- @streams.offerings}
                id={id}
                class={[
                  "group grid gap-5 rounded-2xl border bg-card p-5 transition-all",
                  @selected_offering && @selected_offering.reference == offering.reference &&
                    "border-primary shadow-[0_14px_36px_-24px_hsl(var(--primary))]",
                  (!@selected_offering || @selected_offering.reference != offering.reference) &&
                    "border-border hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-md"
                ]}
              >
                <div class="flex items-start justify-between gap-4">
                  <div class="min-w-0">
                    <div class="flex flex-wrap items-center gap-2">
                      <span class="rounded-full bg-primary/10 px-2.5 py-1 text-[0.6875rem] font-semibold uppercase tracking-wide text-primary">
                        {offering.runtime_class}
                      </span>
                      <span class="rounded-full border border-border px-2.5 py-1 text-[0.6875rem] font-medium text-muted-foreground">
                        {offering.rollout_stage}
                      </span>
                    </div>
                    <h3 class="mt-3 truncate text-lg font-semibold">{offering.display_name}</h3>
                    <p class="mt-1 text-sm leading-5 text-muted-foreground">{offering.description}</p>
                  </div>
                  <span class={[
                    "mt-1 size-2.5 shrink-0 rounded-full",
                    offering.readiness == :ready &&
                      "bg-status-success shadow-[0_0_0_4px_hsl(var(--status-success)/0.12)]",
                    offering.readiness != :ready &&
                      "bg-status-attention shadow-[0_0_0_4px_hsl(var(--status-attention)/0.12)]"
                  ]}>
                  </span>
                </div>

                <dl class="grid grid-cols-2 gap-x-5 gap-y-3 border-y border-border py-4 text-xs sm:grid-cols-3">
                  <.offering_fact label="Provider" value={offering.provider} />
                  <.offering_fact label="Deployment" value={offering.deployment_class} />
                  <.offering_fact label="Billing" value={offering.billing_mode} />
                  <.offering_fact label="Capability" value={offering.capability_class} />
                  <.offering_fact label="Readiness" value={readiness_label(offering)} />
                  <.offering_fact label="Profile" value={"r#{offering.profile_revision}"} />
                </dl>

                <div>
                  <p class="text-xs font-semibold text-foreground">Material boundaries</p>
                  <p class="mt-2 rounded-md bg-muted px-2 py-1 text-[0.6875rem] leading-5 text-muted-foreground">
                    {limitations_label(offering)}
                  </p>
                </div>

                <button
                  id={"select-agent-#{offering.reference}"}
                  type="button"
                  phx-click="select-offering"
                  phx-value-reference={offering.reference}
                  disabled={!offering.selectable}
                  class={[
                    "inline-flex h-10 items-center justify-center gap-2 rounded-md px-4 text-sm font-semibold outline-none transition-all focus-visible:ring-2 focus-visible:ring-ring",
                    offering.selectable &&
                      "bg-foreground text-background hover:-translate-y-0.5 hover:shadow-md",
                    !offering.selectable &&
                      "cursor-not-allowed bg-muted text-muted-foreground opacity-70"
                  ]}
                >
                  <.icon
                    name={if(offering.selectable, do: "hero-check", else: "hero-lock-closed")}
                    class="size-4"
                  />
                  {if(offering.selectable, do: "Select exact profile", else: "Unavailable")}
                </button>
              </article>
            </div>
          </section>

          <section
            :if={@selected_offering}
            id="agent-task-submission"
            class="overflow-hidden rounded-2xl border border-primary/30 bg-card shadow-[0_20px_60px_-40px_hsl(var(--primary))]"
          >
            <div class="border-b border-border bg-primary/[0.04] px-5 py-4 sm:px-6">
              <p class="text-xs font-semibold uppercase tracking-[0.14em] text-primary">
                Selected profile
              </p>
              <div class="mt-1 flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
                <h2 class="text-lg font-semibold">{@selected_offering.display_name}</h2>
                <span class="font-mono text-xs text-muted-foreground">
                  {@selected_offering.provider} · {@selected_offering.billing_mode}
                </span>
              </div>
            </div>

            <.form
              for={@submission_form}
              id="agent-submission-form"
              phx-submit="submit-task"
              class="grid gap-5 p-5 sm:p-6"
            >
              <.hidden_field field={@submission_form[:offering_ref]} />
              <.hidden_field field={@submission_form[:repository_ref]} />
              <.hidden_field field={@submission_form[:snapshot_ref]} />
              <.hidden_field field={@submission_form[:task_class]} />
              <.hidden_field field={@submission_form[:idempotency_key]} />
              <.input
                field={@submission_form[:intent]}
                type="textarea"
                label="Semantic task intent"
                placeholder="Describe the bounded change and desired outcome"
              />
              <.input
                field={@submission_form[:acceptance_requirements]}
                type="textarea"
                label="Acceptance requirements"
                placeholder="One independently verifiable requirement per line"
              />

              <div class="grid gap-3 rounded-xl border border-status-attention/30 bg-status-attention/[0.04] p-4">
                <div class="flex items-start gap-3">
                  <.icon
                    name="hero-information-circle"
                    class="mt-0.5 size-5 shrink-0 text-status-attention"
                  />
                  <p class="text-xs leading-5 text-muted-foreground">
                    This foreground developer-local run uses your existing CLI session and declared
                    <strong class="text-foreground">{@selected_offering.billing_mode}</strong>
                    billing mode. It can produce a candidate but cannot publish or merge.
                  </p>
                </div>
                <.input
                  field={@submission_form[:foreground_consent]}
                  type="checkbox"
                  label="I consent to this exact foreground profile and repository task"
                />
                <.input
                  field={@submission_form[:billing_acknowledged]}
                  type="checkbox"
                  label="I acknowledge the displayed provider billing classification"
                />
              </div>

              <button
                id="agent-submit-task"
                type="submit"
                phx-disable-with="Submitting governed task…"
                class="inline-flex h-11 items-center justify-center gap-2 rounded-md bg-primary px-5 text-sm font-semibold text-primary-foreground shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring sm:justify-self-start"
              >
                <.icon name="hero-play" class="size-4" /> Submit governed task
              </button>
            </.form>
          </section>

          <div
            :if={@submission_outcome}
            id="agent-submission-outcome"
            role="status"
            class="flex flex-col gap-2 rounded-xl border border-border bg-card px-5 py-4 text-sm sm:flex-row sm:items-center sm:justify-between"
          >
            <span>Submission outcome: <strong>{@submission_outcome.code}</strong></span>
            <.link
              :if={@submission_outcome[:attempt_ref]}
              id="agent-submission-attempt-link"
              navigate={~p"/managed-coding/#{@submission_outcome.attempt_ref}"}
              class="inline-flex items-center gap-1 font-medium text-primary hover:underline"
            >
              Open attempt <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </div>
      </main>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp offering_fact(assigns) do
    ~H"""
    <div class="min-w-0">
      <dt class="text-muted-foreground">{@label}</dt>
      <dd class="mt-1 truncate font-medium text-foreground">{@value}</dd>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true

  defp hidden_field(assigns) do
    ~H"""
    <input id={@field.id} name={@field.name} type="hidden" value={@field.value} />
    """
  end

  defp invoke_catalog(gateway, socket, params) when is_atom(gateway),
    do: gateway.list(socket.assigns.authority, socket.assigns.product_identity, params)

  defp invoke_catalog(gateway, socket, params) when is_function(gateway, 3),
    do: gateway.(socket.assigns.authority, socket.assigns.product_identity, params)

  defp invoke_submission(gateway, socket, params) when is_atom(gateway),
    do: gateway.submit(socket.assigns.authority, socket.assigns.product_identity, params)

  defp invoke_submission(gateway, socket, params) when is_function(gateway, 3),
    do: gateway.(socket.assigns.authority, socket.assigns.product_identity, params)

  defp selected_reference(%{assigns: %{selected_offering: %AgentOffering{} = offering}}),
    do: offering.reference

  defp selected_reference(_socket), do: "unavailable"

  defp catalog_form do
    to_form(
      %{
        "repository_ref" => "",
        "snapshot_ref" => "",
        "task_class" => "focused_change",
        "language_class" => "elixir_phoenix",
        "capability_class" => "workspace_write_registered_checks",
        "rollout_stage" => "evaluation"
      },
      as: :catalog
    )
  end

  defp submission_form(catalog \\ %{}) do
    to_form(
      %{
        "intent" => "",
        "repository_ref" => catalog["repository_ref"] || "",
        "snapshot_ref" => catalog["snapshot_ref"] || "",
        "task_class" => catalog["task_class"] || "focused_change",
        "acceptance_requirements" => "",
        "offering_ref" => "",
        "idempotency_key" => submission_seed(),
        "foreground_consent" => "false",
        "billing_acknowledged" => "false"
      },
      as: :submission
    )
  end

  defp submission_key(socket, params) do
    :crypto.hash(
      :sha256,
      :erlang.term_to_binary(
        {socket.assigns.current_scope.nonce, selected_reference(socket), params["intent"]},
        [:deterministic]
      )
    )
    |> Base.url_encode64(padding: false)
  end

  defp submission_seed,
    do: Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)

  defp readiness_label(offering) do
    age =
      if is_integer(offering.readiness_age_seconds),
        do: "#{offering.readiness_age_seconds}s",
        else: "unknown age"

    "#{offering.readiness} · #{age}"
  end

  defp limitations_label(%AgentOffering{limitations: []}),
    do: "No current selection blockers"

  defp limitations_label(%AgentOffering{limitations: limitations}) do
    limitations
    |> Enum.map_join(" · ", &humanize/1)
  end

  defp humanize(value), do: value |> to_string() |> String.replace("_", " ")
  defp submission_message(:admitted), do: "The coding task was admitted."
  defp submission_message(:duplicate), do: "The existing coding attempt was returned."
  defp submission_message(_code), do: "The submission returned a bounded outcome."
end
