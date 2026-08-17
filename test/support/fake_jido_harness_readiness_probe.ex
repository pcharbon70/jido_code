defmodule JidoCode.TestSupport.FakeJidoHarnessReadinessProbe do
  @moduledoc false

  @behaviour JidoCode.Runtime.JidoHarness.ReadinessProbe

  @impl true
  def discover(profile, options) do
    notify(options, {:jido_harness_readiness, :discover, profile.name})

    {:ok,
     Keyword.get(options, :discovery, %{
       installed: true,
       compatible: true,
       authenticated: :unknown,
       version: "pi/0.51.2",
       executable: "/sensitive/developer/path/pi",
       details: %{account: "must-not-be-reported"}
     })}
  end

  @impl true
  def live_smoke(profile, options) do
    notify(options, {:jido_harness_readiness, :live_smoke, profile.name})
    {:ok, Keyword.get(options, :live, %{result: :passed, authenticated: true})}
  end

  defp notify(options, message) do
    case Keyword.get(options, :owner) do
      owner when is_pid(owner) -> send(owner, message)
      _missing -> :ok
    end
  end
end
