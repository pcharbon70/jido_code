defmodule JidoCodeWeb.ArchitectureFixture.Dashboard do
  def route, do: live_dashboard("/dashboard", metrics: JidoCodeWeb.Telemetry)
end
