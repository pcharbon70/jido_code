defmodule JidoCode.Factory.Observations.Worktree do
  @moduledoc "Ephemeral local Git materialization handle."

  @derive {Inspect, only: [:operation_id, :remote_digest, :ref, :created_at]}
  @enforce_keys [:operation_id, :remote_digest, :ref, :created_at, :path]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
end
