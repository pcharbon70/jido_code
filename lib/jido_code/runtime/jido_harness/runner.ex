defmodule JidoCode.Runtime.JidoHarness.Runner do
  @moduledoc "Runtime boundary implemented by a JidoHarness process controller."

  @callback start(map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback signal(map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback status(map(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback cancel(map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback terminate(map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
end
