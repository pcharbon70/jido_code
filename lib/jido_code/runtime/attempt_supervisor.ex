defmodule JidoCode.Runtime.AttemptSupervisor do
  @moduledoc "Ephemeral worker supervisor keyed by attempt identity and fence."

  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Runtime.AttemptRegistry
  alias JidoCode.Runtime.AttemptWorker

  @spec start_attempt(Request.t(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_attempt(%Request{} = request, options) when is_list(options) do
    case AttemptRegistry.lookup(request) do
      {:ok, pid} -> {:error, {:already_started, pid}}
      :error -> start_child(request, options, 10)
    end
  end

  @spec stop_attempt(Request.t()) :: :ok | {:error, :not_found}
  def stop_attempt(%Request{} = request) do
    case AttemptRegistry.lookup(request) do
      {:ok, pid} -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      :error -> {:error, :not_found}
    end
  end

  @spec active() :: [pid()]
  def active do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
    |> Enum.sort()
  end

  defp start_child(request, options, attempts) do
    case DynamicSupervisor.start_child(__MODULE__, {AttemptWorker, {request, options}}) do
      {:error, {:already_started, pid}} when attempts > 0 ->
        if Process.alive?(pid) do
          {:error, {:already_started, pid}}
        else
          Process.sleep(1)
          start_child(request, options, attempts - 1)
        end

      result ->
        result
    end
  end
end
