defmodule JidoCode.Runtime.ManagedCoding.TopologyAdapter do
  @moduledoc "Jido.Pod implementation of the product-owned disposable topology runtime port."

  @behaviour JidoCode.Factory.Ports.ManagedCodingTopologyRuntime

  alias Jido.Agent.InstanceManager
  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.TopologyContract
  alias JidoCode.Runtime.ManagedCodingCompatibility

  @pod_manager JidoCode.Runtime.ManagedCoding.PodManager

  @impl true
  def reconcile(%TopologyContract{} = contract, projection, options)
      when is_map(projection) and is_list(options) do
    with {:ok, compatible} <- ManagedCodingCompatibility.verify(),
         true <- compatible.jido_version == contract.jido_version,
         manager when is_atom(manager) <- Keyword.get(options, :manager, @pod_manager),
         {:ok, pod_pid} <-
           Jido.Pod.get(manager, contract.topology_iri,
             initial_state: %{
               topology_iri: contract.topology_iri,
               profile_digest: contract.profile_digest,
               reconstruction_watermark: projection.watermark
             }
           ),
         {:ok, roles} <- ensure_roles(pod_pid, contract, projection) do
      {:ok,
       %{
         pod_pid: pod_pid,
         topology_iri: contract.topology_iri,
         profile_digest: contract.profile_digest,
         watermark: projection.watermark,
         roles: roles,
         authority: :graph_projection,
         persistence: :none
       }}
    else
      _invalid -> invalid(:managed_coding_topology_reconciliation)
    end
  rescue
    _error -> invalid(:managed_coding_topology_reconciliation)
  end

  def reconcile(_contract, _projection, _options),
    do: invalid(:managed_coding_topology_reconciliation)

  @impl true
  def stop(%TopologyContract{} = contract, options) when is_list(options) do
    manager = Keyword.get(options, :manager, @pod_manager)

    case InstanceManager.lookup(manager, contract.topology_iri) do
      {:ok, pod_pid} -> Jido.Pod.Runtime.teardown_runtime(pod_pid, timeout: contract.timeout_ms)
      :error -> :ok
    end

    case InstanceManager.stop(manager, contract.topology_iri) do
      :ok -> :ok
      {:error, :not_found} -> :ok
      _error -> invalid(:managed_coding_topology_stop)
    end
  end

  def stop(_contract, _options), do: invalid(:managed_coding_topology_stop)

  defp ensure_roles(pod_pid, contract, projection) do
    Enum.reduce_while(contract.roles, {:ok, %{}}, fn role, {:ok, running} ->
      initial_state = %{
        topology_iri: contract.topology_iri,
        delegation_iri: contract.topology_iri <> "/projection/" <> role.name,
        task_iri: contract.topology_iri <> "/task",
        attempt_iri: contract.topology_iri <> "/attempt",
        role: role.name,
        fencing_token: 1,
        reconstruction_watermark: projection.watermark,
        sequence: 0
      }

      case Jido.Pod.ensure_node(pod_pid, role.name,
             initial_state: initial_state,
             timeout: contract.timeout_ms,
             max_concurrency: contract.max_fan_out
           ) do
        {:ok, pid} -> {:cont, {:ok, Map.put(running, role.name, pid)}}
        _error -> {:halt, invalid(:managed_coding_topology_reconciliation)}
      end
    end)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
