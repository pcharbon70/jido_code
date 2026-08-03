defmodule JidoCode.Factory.Ports.Git do
  @moduledoc "Disposable Git materialization and exact snapshot inspection port."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Observations.GitSnapshot
  alias JidoCode.Factory.Observations.Worktree

  @callback materialize(adapter :: term(), request :: map()) ::
              {:ok, Worktree.t()} | {:error, AdapterError.t()}
  @callback inspect_snapshot(adapter :: term(), Worktree.t()) ::
              {:ok, GitSnapshot.t()} | {:error, AdapterError.t()}
  @callback cleanup(adapter :: term(), Worktree.t()) :: :ok | {:error, AdapterError.t()}
end
