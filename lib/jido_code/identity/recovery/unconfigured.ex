defmodule JidoCode.Identity.Recovery.Unconfigured do
  @moduledoc "Fail-closed recovery adapter used until a production provider is configured."

  @behaviour JidoCode.Identity.RecoveryAdapter

  @impl true
  def verify(_evidence, _account), do: {:error, :unavailable}
end
