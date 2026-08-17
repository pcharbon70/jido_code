defmodule JidoCode.Runtime.JidoHarness.ReadinessProbe do
  @moduledoc "Probe contract separating non-billable discovery from consented live work."

  @callback discover(map(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback live_smoke(map(), keyword()) :: {:ok, map()} | {:error, term()}
end
