defmodule AgentJidoWeb.DashboardLive do
  use AgentJidoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}}>
      <div class="max-w-4xl mx-auto py-8">
        <h1 class="text-2xl font-bold mb-4">Dashboard</h1>
        <p class="text-base-content/70">Welcome, {@current_user.email}</p>
      </div>
    </Layouts.app>
    """
  end
end
