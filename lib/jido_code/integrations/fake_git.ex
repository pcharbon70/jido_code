defmodule JidoCode.Integrations.FakeGit do
  @moduledoc """
  Deterministic Git port for force-push, missing-ref, stale-advertisement, and
  materialization-failure tests.
  """

  @behaviour JidoCode.Factory.Ports.Git

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Observations.GitSnapshot
  alias JidoCode.Factory.Observations.Worktree

  @enforce_keys [:root, :snapshots, :failures, :clock]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(keyword()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(options) when is_list(options) do
    root = Keyword.get(options, :root, "/tmp/jido-code-fake-git")
    snapshots = Keyword.get(options, :snapshots, %{})
    failures = Keyword.get(options, :failures, %{})
    clock = Keyword.get(options, :clock, fn -> ~U[2026-08-01 00:00:00Z] end)

    if is_binary(root) and is_map(snapshots) and is_map(failures) and is_function(clock, 0) do
      {:ok, %__MODULE__{root: root, snapshots: snapshots, failures: failures, clock: clock}}
    else
      {:error, AdapterError.new(:invalid_input, :fake_git)}
    end
  end

  @impl true
  def materialize(%__MODULE__{} = adapter, request) when is_map(request) do
    key = {request[:remote], request[:ref], request[:operation_id]}

    case Map.get(adapter.failures, {:materialize, key}) do
      nil ->
        {:ok,
         %Worktree{
           operation_id: request[:operation_id],
           remote_digest: digest(request[:remote]),
           ref: request[:ref],
           created_at: adapter.clock.(),
           path: Path.join(adapter.root, request[:operation_id])
         }}

      kind ->
        {:error, AdapterError.new(kind, :fake_git_materialize)}
    end
  end

  @impl true
  def inspect_snapshot(%__MODULE__{} = adapter, %Worktree{} = worktree) do
    case Map.get(adapter.failures, {:inspect, worktree.operation_id}) do
      nil ->
        case Map.get(adapter.snapshots, worktree.operation_id) do
          %GitSnapshot{} = snapshot -> {:ok, snapshot}
          nil -> {:error, AdapterError.new(:unavailable, :fake_git_missing_snapshot)}
        end

      kind ->
        {:error, AdapterError.new(kind, :fake_git_inspect)}
    end
  end

  @impl true
  def cleanup(%__MODULE__{}, %Worktree{}), do: :ok

  defp digest(value) when is_binary(value) do
    value |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end
end
