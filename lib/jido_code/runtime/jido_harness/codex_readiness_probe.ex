defmodule JidoCode.Runtime.JidoHarness.CodexReadinessProbe do
  @moduledoc "Prompt-free Codex local-login discovery boundary."

  @callback login_status(map(), keyword()) :: {:ok, atom()} | {:error, term()}
end
