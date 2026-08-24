defmodule JidoCode.Runtime.ManagedCodingCompatibility do
  @moduledoc """
  Executable compatibility boundary for the Jido APIs used by managed coding.

  Passing this probe is necessary but not sufficient to adopt another Jido
  release. The managed coding profile remains pinned to exactly 2.3.2 until a
  new compatibility receipt is reviewed.
  """

  alias Jido.Agent.Strategy.Snapshot

  @version "2.3.2"
  @required_exports [
    {Jido.AgentServer, :call, 2},
    {Jido.AgentServer, :state, 1},
    {Jido.Agent.InstanceManager, :child_spec, 1},
    {Jido.Agent.InstanceManager, :get, 3},
    {Jido.Agent.InstanceManager, :lookup, 3},
    {Jido.Agent.Strategy.Direct, :cmd, 3},
    {Jido.Signal, :new, 2},
    {JidoCode.Runtime.JidoInstance, :start_agent, 2},
    {JidoCode.Runtime.JidoInstance, :stop_agent, 1}
  ]
  @snapshot_fields Snapshot.__struct__() |> Map.keys() |> Enum.reject(&(&1 == :__struct__))

  @spec version() :: String.t()
  def version, do: @version

  @spec verify() :: {:ok, map()} | {:error, map()}
  def verify do
    actual_version = Application.spec(:jido, :vsn) |> to_string()

    missing =
      Enum.reject(@required_exports, fn {module, function, arity} ->
        Code.ensure_loaded?(module) and function_exported?(module, function, arity)
      end)

    if actual_version == @version and missing == [] do
      {:ok,
       %{
         jido_version: actual_version,
         required_exports: @required_exports,
         storage: Jido.Storage.ETS,
         persistence: :ephemeral_only
       }}
    else
      {:error, %{expected_version: @version, actual_version: actual_version, missing: missing}}
    end
  end

  @spec snapshot(map()) :: {:ok, map()} | {:error, :incompatible_snapshot}
  def snapshot(%Snapshot{} = snapshot) do
    public = Map.from_struct(snapshot)

    if Enum.sort(Map.keys(public)) == Enum.sort(@snapshot_fields) do
      {:ok, public}
    else
      {:error, :incompatible_snapshot}
    end
  end

  def snapshot(_snapshot), do: {:error, :incompatible_snapshot}

  @spec signal_sequence(non_neg_integer(), non_neg_integer()) ::
          :next | :duplicate | :stale | :gap
  def signal_sequence(current, incoming)
      when is_integer(current) and current >= 0 and is_integer(incoming) and incoming >= 0 do
    cond do
      incoming == current + 1 -> :next
      incoming == current -> :duplicate
      incoming < current -> :stale
      true -> :gap
    end
  end
end
