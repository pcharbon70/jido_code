defmodule JidoCodeWeb.HomeLive do
  use JidoCodeWeb, :live_view

  require Logger

  alias JidoCode.Setup.SystemConfig

  @impl true
  def mount(_params, _session, socket) do
    case SystemConfig.load() do
      {:ok, %SystemConfig{onboarding_completed: false, onboarding_step: onboarding_step}} ->
        redirect_to_setup(
          socket,
          onboarding_step,
          "onboarding_incomplete",
          "Setup is incomplete. Resume onboarding to continue."
        )

      {:ok, %SystemConfig{onboarding_completed: true}} ->
        if socket.assigns[:current_user] do
          {:ok, Phoenix.LiveView.redirect(socket, to: ~p"/dashboard")}
        else
          {:ok, socket}
        end

      {:error, %{diagnostic: diagnostic, detail: detail, onboarding_step: onboarding_step}} ->
        redirect_to_setup(
          socket,
          onboarding_step,
          "system_config_unavailable",
          diagnostic,
          detail
        )
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-base-200 to-base-300">
      <div class="w-full max-w-md px-6">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-base-content">Jido Code</h1>
          <p class="mt-2 text-base-content/70">AI Agent Platform</p>
        </div>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <%= if @current_user do %>
              <p class="text-center text-lg mb-4">Welcome, {@current_user.email}</p>
              <a href="/dashboard" class="btn btn-primary btn-block">Go to Dashboard</a>
              <a href="/sign-out" class="btn btn-outline btn-block mt-2">Sign Out</a>
            <% else %>
              <a href="/sign-in" class="btn btn-primary btn-block">Sign In</a>
              <div class="divider">OR</div>
              <a href="/register" class="btn btn-outline btn-block">Create Account</a>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp redirect_to_setup(socket, onboarding_step, reason, diagnostic, detail \\ nil) do
    log_onboarding_redirect(reason, onboarding_step, diagnostic, detail)

    if onboarding_step <= 2 do
      {:ok, Phoenix.LiveView.redirect(socket, to: ~p"/welcome")}
    else
      path = ~p"/setup?diagnostic=#{diagnostic}&reason=#{reason}&step=#{onboarding_step}"
      {:ok, Phoenix.LiveView.redirect(socket, to: path)}
    end
  end

  defp log_onboarding_redirect(reason, onboarding_step, diagnostic, nil) do
    Logger.warning(
      "onboarding_redirect route=/ reason=#{reason} step=#{onboarding_step} diagnostic=#{inspect(diagnostic)}"
    )
  end

  defp log_onboarding_redirect(reason, onboarding_step, diagnostic, detail) do
    Logger.warning(
      "onboarding_redirect route=/ reason=#{reason} step=#{onboarding_step} diagnostic=#{inspect(diagnostic)} detail=#{inspect(detail)}"
    )
  end
end
