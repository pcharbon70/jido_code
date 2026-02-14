defmodule JidoCodeWeb.WorkbenchLive do
  use JidoCodeWeb, :live_view

  alias JidoCode.Workbench.Inventory

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:inventory_count, 0)
      |> assign(:stale_warning, nil)
      |> stream(:inventory_rows, [], reset: true)
      |> load_inventory()

    {:ok, socket}
  end

  @impl true
  def handle_event("retry_fetch", _params, socket) do
    {:noreply, load_inventory(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}}>
      <section class="space-y-2">
        <h1 class="text-2xl font-bold">Workbench</h1>
        <p class="text-base-content/70">
          Unified cross-project inventory for issue and pull request triage.
        </p>
      </section>

      <section
        :if={@stale_warning}
        id="workbench-stale-warning"
        class="rounded-lg border border-warning/60 bg-warning/10 p-4 space-y-2"
      >
        <p id="workbench-stale-warning-label" class="font-semibold">Workbench data may be stale</p>
        <p id="workbench-stale-warning-type" class="text-sm">
          Typed warning: {@stale_warning.error_type}
        </p>
        <p id="workbench-stale-warning-detail" class="text-sm">{@stale_warning.detail}</p>
        <p id="workbench-stale-warning-remediation" class="text-sm">{@stale_warning.remediation}</p>
        <div class="flex flex-wrap gap-3 pt-1">
          <button
            id="workbench-retry-fetch"
            type="button"
            class="btn btn-sm btn-warning"
            phx-click="retry_fetch"
          >
            Retry workbench fetch
          </button>
          <.link
            id="workbench-open-setup-recovery"
            class="btn btn-sm btn-outline"
            navigate={~p"/setup?step=7&reason=workbench_data_stale"}
          >
            Review setup diagnostics
          </.link>
        </div>
      </section>

      <section class="rounded-lg border border-base-300 bg-base-100 overflow-x-auto">
        <table id="workbench-project-table" class="table table-zebra w-full">
          <thead>
            <tr>
              <th>Project</th>
              <th>Open issues</th>
              <th>Open PRs</th>
              <th>Recent activity</th>
            </tr>
          </thead>
          <tbody id="workbench-project-rows" phx-update="stream">
            <tr :if={@inventory_count == 0} id="workbench-empty-state">
              <td colspan="4" class="text-center text-sm text-base-content/70 py-8">
                No imported projects available yet.
              </td>
            </tr>
            <tr :for={{dom_id, project} <- @streams.inventory_rows} id={dom_id}>
              <td>
                <p id={"workbench-project-name-#{project.id}"} class="font-medium">
                  {project.github_full_name}
                </p>
                <p class="text-xs text-base-content/60">{project.name}</p>
              </td>
              <td id={"workbench-project-open-issues-#{project.id}"}>{project.open_issue_count}</td>
              <td id={"workbench-project-open-prs-#{project.id}"}>{project.open_pr_count}</td>
              <td id={"workbench-project-recent-activity-#{project.id}"} class="text-sm">
                {project.recent_activity_summary}
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </Layouts.app>
    """
  end

  defp load_inventory(socket) do
    case Inventory.load() do
      {:ok, rows, stale_warning} ->
        socket
        |> assign(:inventory_count, length(rows))
        |> assign(:stale_warning, stale_warning)
        |> stream(:inventory_rows, rows, reset: true)

      {:error, stale_warning} ->
        socket
        |> assign(:inventory_count, 0)
        |> assign(:stale_warning, stale_warning)
        |> stream(:inventory_rows, [], reset: true)
    end
  end
end
