defmodule JidoCode.Factory.ManagedCoding.TopologyCoordinator do
  @moduledoc """
  Host-owned reconciliation and delegation admission for managed coding Pods.

  The coordinator consumes an exact graph projection and returns correlated
  intents. It has no graph handle and specialists receive no direct gateway,
  credential, policy, publication, verification, or acceptance capability.
  """

  alias Jido.Agent.InstanceManager
  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.TopologyContract
  alias JidoCode.Runtime.ManagedCodingCompatibility

  @pod_manager JidoCode.Runtime.ManagedCoding.PodManager
  @request_keys ~w[delegation_iri task_iri attempt_iri role fence depth parent_role policy_current capability_ref context_digest profile_digest shared_remaining role_remaining concurrent active_roles]a
  @remaining_keys ~w[messages input_bytes output_bytes tokens cost_microunits timeout_ms]a
  @gateway_routes %{
    "context" => :managed_coding_context,
    "model" => :managed_coding_model,
    "tool" => :managed_coding_tool,
    "memory" => :managed_coding_memory
  }
  @gateway_values Map.values(@gateway_routes)

  @spec reconcile(TopologyContract.t(), map(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def reconcile(contract, graph_projection, options \\ [])

  def reconcile(%TopologyContract{} = contract, graph_projection, options)
      when is_map(graph_projection) and is_list(options) do
    with {:ok, compatible} <- ManagedCodingCompatibility.verify(),
         true <- compatible.jido_version == contract.jido_version,
         {:ok, projection} <- TopologyContract.projection(contract, graph_projection),
         true <- projection.desired_state == :active,
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
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:managed_coding_topology_reconciliation)
    end
  rescue
    _error -> invalid(:managed_coding_topology_reconciliation)
  end

  def reconcile(_contract, _projection, _options),
    do: invalid(:managed_coding_topology_reconciliation)

  @spec admit_delegation(TopologyContract.t(), map(), map()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def admit_delegation(%TopologyContract{} = contract, runtime, request)
      when is_map(runtime) and is_map(request) do
    with true <- exact_keys?(request, @request_keys),
         true <- runtime[:topology_iri] == contract.topology_iri,
         true <- runtime[:profile_digest] == contract.profile_digest,
         true <- is_pid(runtime[:pod_pid]) and Process.alive?(runtime.pod_pid),
         role when not is_nil(role) <- Enum.find(contract.roles, &(&1.name == request.role)),
         :ok <- identities(request),
         true <- request.policy_current,
         true <- request.capability_ref in role.capability_refs,
         true <- request.profile_digest == contract.profile_digest,
         true <- valid_digest?(request.context_digest),
         true <- is_integer(request.fence) and request.fence > 0,
         true <- is_integer(request.depth) and request.depth in 1..contract.max_depth,
         true <- request.parent_role != request.role,
         true <- is_integer(request.concurrent) and request.concurrent < contract.max_fan_out,
         true <- request.role not in request.active_roles,
         :ok <- remaining(request.shared_remaining, role.budget),
         :ok <- remaining(request.role_remaining, role.budget) do
      {:ok,
       %{
         delegation_iri: request.delegation_iri,
         topology_iri: contract.topology_iri,
         task_iri: request.task_iri,
         attempt_iri: request.attempt_iri,
         role: request.role,
         fence: request.fence,
         depth: request.depth,
         context_digest: request.context_digest,
         profile_digest: contract.profile_digest,
         gateway_routes: @gateway_routes,
         remaining: %{
           shared: debit_message(request.shared_remaining),
           role: debit_message(request.role_remaining)
         },
         unavailable_authorities: unavailable_authorities()
       }}
    else
      _invalid -> invalid(:managed_coding_delegation_admission)
    end
  rescue
    _error -> invalid(:managed_coding_delegation_admission)
  end

  def admit_delegation(_contract, _runtime, _request),
    do: invalid(:managed_coding_delegation_admission)

  @spec route_effect(map(), String.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def route_effect(admission, kind) when is_map(admission) and is_binary(kind) do
    case Map.fetch(admission[:gateway_routes], kind) do
      {:ok, route} when route in @gateway_values ->
        {:ok,
         %{
           route: route,
           delegation_iri: admission.delegation_iri,
           attempt_iri: admission.attempt_iri,
           fence: admission.fence,
           direct_credentials: false,
           direct_graph_access: false
         }}

      _unknown ->
        invalid(:managed_coding_specialist_effect_route)
    end
  end

  def route_effect(_admission, _kind), do: invalid(:managed_coding_specialist_effect_route)

  @spec classify_signal(
          non_neg_integer(),
          integer(),
          String.t(),
          String.t(),
          integer(),
          integer()
        ) ::
          :next | :duplicate | :stale | :gap | :forged | :superseded
  def classify_signal(
        current_sequence,
        incoming_sequence,
        expected_role,
        incoming_role,
        fence,
        incoming_fence
      ) do
    cond do
      expected_role != incoming_role -> :forged
      fence != incoming_fence -> :superseded
      true -> ManagedCodingCompatibility.signal_sequence(current_sequence, incoming_sequence)
    end
  end

  @spec stop(TopologyContract.t(), keyword()) :: :ok | {:error, AdapterError.t()}
  def stop(%TopologyContract{} = contract, options \\ []) when is_list(options) do
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

  @spec unavailable_authorities() :: [atom()]
  def unavailable_authorities do
    [:graph, :policy, :credential, :verification, :acceptance, :publication, :merge, :topology]
  end

  defp ensure_roles(pod_pid, contract, projection) do
    roles = Enum.map(contract.roles, & &1.name)

    Enum.reduce_while(roles, {:ok, %{}}, fn role, {:ok, running} ->
      delegation_iri = contract.topology_iri <> "/projection/" <> role

      initial_state = %{
        topology_iri: contract.topology_iri,
        delegation_iri: delegation_iri,
        task_iri: contract.topology_iri <> "/task",
        attempt_iri: contract.topology_iri <> "/attempt",
        role: role,
        fencing_token: 1,
        reconstruction_watermark: projection.watermark,
        sequence: 0
      }

      case Jido.Pod.ensure_node(pod_pid, role,
             initial_state: initial_state,
             timeout: contract.timeout_ms,
             max_concurrency: contract.max_fan_out
           ) do
        {:ok, pid} -> {:cont, {:ok, Map.put(running, role, pid)}}
        _error -> {:halt, invalid(:managed_coding_topology_reconciliation)}
      end
    end)
  end

  defp identities(request) do
    with :ok <- Identity.validate_resource(request.delegation_iri),
         :ok <- Identity.validate_resource(request.task_iri),
         :ok <- Identity.validate_resource(request.attempt_iri) do
      :ok
    end
  end

  defp remaining(values, budget) when is_map(values) do
    exact = exact_keys?(values, @remaining_keys)

    sufficient =
      Enum.all?(@remaining_keys, fn key ->
        is_integer(values[key]) and values[key] > 0 and
          values[key] <= budget[budget_key(key)]
      end)

    if exact and sufficient, do: :ok, else: :error
  end

  defp remaining(_values, _budget), do: :error
  defp budget_key(:messages), do: :max_messages
  defp budget_key(:input_bytes), do: :max_input_bytes
  defp budget_key(:output_bytes), do: :max_output_bytes
  defp budget_key(:tokens), do: :max_tokens
  defp budget_key(:cost_microunits), do: :max_cost_microunits
  defp budget_key(:timeout_ms), do: :timeout_ms
  defp debit_message(remaining), do: Map.update!(remaining, :messages, &(&1 - 1))
  defp exact_keys?(map, keys), do: Enum.sort(Map.keys(map)) == Enum.sort(keys)
  defp valid_digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
