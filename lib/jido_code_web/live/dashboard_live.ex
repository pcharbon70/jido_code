defmodule JidoCodeWeb.DashboardLive do
  use JidoCodeWeb, :live_view

  @onboarding_next_actions [
    "Run your first workflow",
    "Review the security playbook",
    "Test the RPC client"
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :onboarding_next_actions, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    onboarding_next_actions =
      if Map.get(params, "onboarding") == "completed" do
        @onboarding_next_actions
      else
        []
      end

    {:noreply, assign(socket, :onboarding_next_actions, onboarding_next_actions)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}}>
      <div class="max-w-4xl mx-auto py-8">
        <h1 class="text-2xl font-bold mb-4">Dashboard</h1>
        <p class="text-base-content/70">Welcome, {@current_user.email}</p>

        <section
          :if={!Enum.empty?(@onboarding_next_actions)}
          id="dashboard-onboarding-next-actions"
          class="mt-6 rounded-lg border border-base-300 bg-base-100 p-4"
        >
          <h2 class="text-lg font-semibold">Onboarding next actions</h2>
          <ul class="mt-2 space-y-1 text-sm text-base-content/80">
            <li
              :for={{next_action, index} <- Enum.with_index(@onboarding_next_actions, 1)}
              id={"dashboard-next-action-#{index}"}
            >
              {next_action}
            </li>
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
