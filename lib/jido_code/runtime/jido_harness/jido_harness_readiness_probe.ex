defmodule JidoCode.Runtime.JidoHarness.JidoHarnessReadinessProbe do
  @moduledoc false

  @behaviour JidoCode.Runtime.JidoHarness.ReadinessProbe

  @impl true
  def discover(profile, _options), do: Jido.Harness.status(profile.provider)

  @impl true
  def live_smoke(_profile, _options), do: {:error, :protected_live_probe_not_configured}
end
