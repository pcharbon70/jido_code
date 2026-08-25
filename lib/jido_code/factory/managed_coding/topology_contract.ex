defmodule JidoCode.Factory.ManagedCoding.TopologyContract do
  @moduledoc """
  Closed, graph-authoritative contract for an optional managed coding Pod.

  Running Pod processes, mailboxes, monitors, registries, and their state are
  disposable projections; they never become topology history or acceptance
  evidence.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity

  @jido_version "2.3.2"
  @pod_revision "jido-pod/2.3.2"
  @roles ~w[investigator coder reviewer]
  @activations ~w[eager lazy]
  @entities ~w[topology_instance specialist_role delegation evidence_packet handoff conflict completion cancellation reconstruction_watermark]
  @transitions ~w[declare project delegate reply handoff conflict complete cancel supersede quarantine reconstruct]
  @packet_types ~w[request reply evidence artifact error terminal_proposal]
  @digest ~r/^[a-f0-9]{64}$/
  @role_keys ~w[name module manager activation capability_refs budget]a
  @budget_keys ~w[max_messages max_input_bytes max_output_bytes max_tokens max_cost_microunits timeout_ms]a
  @packet_keys ~w[packet_type topology_iri delegation_iri task_iri attempt_iri fence role sequence payload_digest payload]a
  @enforce_keys ~w[topology_iri revision profile_digest jido_version pod_revision roles max_fan_out max_depth max_message_bytes restart_limit timeout_ms state]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Identity.validate_resource(attributes[:topology_iri]),
         revision when is_integer(revision) and revision > 0 <- attributes[:revision],
         true <- valid_digest?(attributes[:profile_digest]),
         @jido_version <- attributes[:jido_version],
         @pod_revision <- attributes[:pod_revision],
         {:ok, roles} <- roles(attributes[:roles]),
         fan_out when is_integer(fan_out) and fan_out in 1..3 <- attributes[:max_fan_out],
         depth when is_integer(depth) and depth in 1..2 <- attributes[:max_depth],
         bytes when is_integer(bytes) and bytes in 1..262_144 <- attributes[:max_message_bytes],
         restarts when is_integer(restarts) and restarts in 0..5 <- attributes[:restart_limit],
         timeout when is_integer(timeout) and timeout in 1..300_000 <- attributes[:timeout_ms],
         state when state in [:evaluation, :restricted, :accepted, :rejected] <-
           attributes[:state] do
      {:ok,
       struct!(__MODULE__, %{
         topology_iri: attributes.topology_iri,
         revision: revision,
         profile_digest: attributes.profile_digest,
         jido_version: @jido_version,
         pod_revision: @pod_revision,
         roles: roles,
         max_fan_out: fan_out,
         max_depth: depth,
         max_message_bytes: bytes,
         restart_limit: restarts,
         timeout_ms: timeout,
         state: state
       })}
    else
      _invalid -> invalid(:managed_coding_topology_contract)
    end
  rescue
    _error -> invalid(:managed_coding_topology_contract)
  end

  def new(_attributes), do: invalid(:managed_coding_topology_contract)

  @spec validate_packet(t(), map()) :: :ok | {:error, AdapterError.t()}
  def validate_packet(%__MODULE__{} = contract, packet) when is_map(packet) do
    with true <- exact_keys?(packet, @packet_keys),
         true <- packet.packet_type in @packet_types,
         true <- packet.topology_iri == contract.topology_iri,
         :ok <- Identity.validate_resource(packet.delegation_iri),
         :ok <- Identity.validate_resource(packet.task_iri),
         :ok <- Identity.validate_resource(packet.attempt_iri),
         fence when is_integer(fence) and fence > 0 <- packet.fence,
         true <- packet.role in @roles,
         sequence when is_integer(sequence) and sequence > 0 <- packet.sequence,
         true <- valid_digest?(packet.payload_digest),
         true <- is_binary(packet.payload),
         true <- byte_size(packet.payload) <= contract.max_message_bytes,
         true <- digest(packet.payload) == packet.payload_digest do
      :ok
    else
      _invalid -> invalid(:managed_coding_topology_packet)
    end
  rescue
    _error -> invalid(:managed_coding_topology_packet)
  end

  def validate_packet(_contract, _packet), do: invalid(:managed_coding_topology_packet)

  @spec projection(t(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def projection(%__MODULE__{} = contract, graph_projection) when is_map(graph_projection) do
    with true <-
           exact_keys?(
             graph_projection,
             ~w[topology_iri revision profile_digest watermark state]a
           ),
         true <- graph_projection.topology_iri == contract.topology_iri,
         true <- graph_projection.revision == contract.revision,
         true <- graph_projection.profile_digest == contract.profile_digest,
         true <- valid_digest?(graph_projection.watermark),
         true <- graph_projection.state in [:declared, :active, :cancelling, :cancelled] do
      {:ok,
       %{
         topology_iri: contract.topology_iri,
         revision: contract.revision,
         watermark: graph_projection.watermark,
         desired_state: graph_projection.state,
         roles: contract.roles
       }}
    else
      _invalid -> invalid(:managed_coding_topology_projection)
    end
  end

  def projection(_contract, _projection), do: invalid(:managed_coding_topology_projection)

  @spec entities() :: [String.t()]
  def entities, do: @entities

  @spec transitions() :: [String.t()]
  def transitions, do: @transitions

  @spec packet_types() :: [String.t()]
  def packet_types, do: @packet_types

  @spec versions() :: map()
  def versions, do: %{jido: @jido_version, pod: @pod_revision}

  defp roles(values) when is_list(values) and values != [] and length(values) <= 3 do
    normalized = Enum.sort_by(values, & &1.name)

    valid =
      Enum.all?(normalized, fn role ->
        exact_keys?(role, @role_keys) and role.name in @roles and is_atom(role.module) and
          is_atom(role.manager) and role.activation in @activations and
          is_list(role.capability_refs) and role.capability_refs != [] and
          length(role.capability_refs) <= 32 and
          Enum.all?(role.capability_refs, &valid_digest?/1) and valid_budget?(role.budget)
      end) and
        normalized |> Enum.map(& &1.name) |> Enum.uniq() |> length() == length(normalized)

    if valid, do: {:ok, normalized}, else: :error
  end

  defp roles(_values), do: :error

  defp valid_budget?(budget) when is_map(budget) do
    exact_keys?(budget, @budget_keys) and
      Enum.all?(@budget_keys, fn key -> is_integer(budget[key]) and budget[key] > 0 end)
  end

  defp valid_budget?(_budget), do: false
  defp exact_keys?(map, keys), do: Enum.sort(Map.keys(map)) == Enum.sort(keys)
  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
