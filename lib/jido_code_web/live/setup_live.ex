defmodule JidoCodeWeb.SetupLive do
  use JidoCodeWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     assign(socket,
       onboarding_step: parse_step(params["step"]),
       redirect_reason: params["reason"] || "onboarding_incomplete",
       diagnostic:
         params["diagnostic"] ||
           "Setup is required before protected routes are available."
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={%{}}>
      <section id="setup-gate" class="mx-auto w-full max-w-3xl space-y-4">
        <h1 class="text-2xl font-semibold">Setup required</h1>
        <p class="text-base-content/80">
          Complete onboarding before accessing protected routes.
        </p>

        <dl class="space-y-3 rounded-lg border border-base-300 bg-base-100 p-4">
          <div class="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
            <dt class="font-medium">Resolved onboarding step</dt>
            <dd id="resolved-onboarding-step" class="font-mono">Step {@onboarding_step}</dd>
          </div>
          <div class="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
            <dt class="font-medium">Redirect reason</dt>
            <dd id="setup-redirect-reason" class="font-mono">{@redirect_reason}</dd>
          </div>
        </dl>

        <div id="setup-diagnostic" class="alert alert-warning">
          <.icon name="hero-exclamation-triangle-mini" class="size-5" />
          <span>{@diagnostic}</span>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp parse_step(step) when is_integer(step) and step > 0, do: step

  defp parse_step(step) when is_binary(step) do
    case Integer.parse(step) do
      {parsed_step, ""} when parsed_step > 0 -> parsed_step
      _ -> 1
    end
  end

  defp parse_step(_), do: 1
end
