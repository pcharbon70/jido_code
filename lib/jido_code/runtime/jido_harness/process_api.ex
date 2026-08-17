defmodule JidoCode.Runtime.JidoHarness.ProcessAPI do
  @moduledoc "Injectable facade over the pinned JidoHarness managed-process API."

  @callback start(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  @callback send_input(String.t(), binary(), keyword()) :: :ok | {:error, term()}
  @callback info(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback await(String.t(), timeout(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback replay(String.t(), keyword(), keyword()) :: {:ok, [map()]} | {:error, term()}
  @callback cancel(String.t(), keyword()) :: :ok | {:error, term()}
  @callback kill(String.t(), keyword()) :: :ok | {:error, term()}
  @callback prune(String.t(), keyword()) :: :ok | {:error, term()}
end
