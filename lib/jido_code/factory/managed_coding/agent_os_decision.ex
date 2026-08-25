defmodule JidoCode.Factory.ManagedCoding.AgentOSDecision do
  @moduledoc """
  Reproducible AgentOS capability inventory and adoption decision.

  The current release rejects AgentOS integration because no measured service
  gap justifies another runtime dependency and its persistence model cannot be
  allowed to compete with the knowledge graph.
  """

  alias JidoCode.Factory.AdapterError

  @candidate_capabilities ~w[lifecycle persistence registry scheduling telemetry operations]a
  @existing_services %{
    lifecycle: JidoCode.Factory.ManagedCoding.Lifecycle,
    persistence: JidoCode.Knowledge,
    registry: JidoCode.Runtime.AttemptRegistry,
    scheduling: JidoCode.Factory.Scheduler,
    telemetry: JidoCode.Observability,
    operations: JidoCode.Factory.ManagedCoding.RolloutGovernance
  }
  @authoritative_domains ~w[task attempt topology delegation budget candidate verification disposition recovery]a
  @faults ~w[restart split_state lag duplicate conflict migration backup_restore disable]a
  @digest ~r/^[a-f0-9]{40}$/
  @input_keys ~w[source_revision dependency_present capabilities persistence_modes measured_benefits operational_cost owner]a
  @capability_keys ~w[name benefit evidence_digest]a

  @spec evaluate(map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def evaluate(attributes) when is_map(attributes) do
    with true <- exact_keys?(attributes, @input_keys),
         true <-
           is_binary(attributes.source_revision) and
             Regex.match?(@digest, attributes.source_revision),
         true <- is_boolean(attributes.dependency_present),
         {:ok, capabilities} <- capabilities(attributes.capabilities),
         true <- is_list(attributes.persistence_modes),
         true <-
           Enum.all?(attributes.persistence_modes, &(&1 in [:ecto, :file, :redis, :ephemeral])),
         true <- is_map(attributes.measured_benefits),
         true <- is_map(attributes.operational_cost),
         true <- is_binary(attributes.owner) and byte_size(attributes.owner) in 1..128 do
      persistence_conflict =
        Enum.any?(attributes.persistence_modes, &(&1 in [:ecto, :file, :redis]))

      novel_benefits =
        Enum.filter(capabilities, fn capability ->
          capability.benefit == :material and capability.evidence_digest != nil
        end)

      result = %{
        source_revision: attributes.source_revision,
        dependency_present: attributes.dependency_present,
        capability_inventory: capabilities,
        existing_services: @existing_services,
        authoritative_domains: @authoritative_domains,
        persistence_conflict: persistence_conflict,
        novel_benefits: novel_benefits,
        measured_benefits: attributes.measured_benefits,
        operational_cost: attributes.operational_cost,
        owner: attributes.owner,
        decision: decision(attributes.dependency_present, persistence_conflict, novel_benefits),
        adapter: :none,
        graph_authority: :exclusive,
        graph_only_reconstruction: :required
      }

      {:ok, Map.put(result, :digest, digest(result))}
    else
      _invalid -> invalid(:managed_coding_agent_os_evaluation)
    end
  rescue
    _error -> invalid(:managed_coding_agent_os_evaluation)
  end

  def evaluate(_attributes), do: invalid(:managed_coding_agent_os_evaluation)

  @spec verify_reconstruction(map(), [map()]) :: :ok | {:error, AdapterError.t()}
  def verify_reconstruction(%{decision: :reject, adapter: :none}, scenarios)
      when is_list(scenarios) do
    names = Enum.map(scenarios, & &1[:fault])

    valid =
      Enum.sort(names) == Enum.sort(@faults) and
        Enum.all?(scenarios, fn scenario ->
          exact_keys?(
            scenario,
            ~w[fault graph_outcome agent_os_outcome duplicate_effect split_authority]a
          ) and
            scenario.fault in @faults and scenario.graph_outcome == :accepted_baseline and
            scenario.agent_os_outcome == :irrelevant and scenario.duplicate_effect == false and
            scenario.split_authority == false
        end)

    if valid, do: :ok, else: invalid(:managed_coding_agent_os_reconstruction)
  end

  def verify_reconstruction(_decision, _scenarios),
    do: invalid(:managed_coding_agent_os_reconstruction)

  @spec candidate_capabilities() :: [atom()]
  def candidate_capabilities, do: @candidate_capabilities

  @spec authoritative_domains() :: [atom()]
  def authoritative_domains, do: @authoritative_domains

  @spec faults() :: [atom()]
  def faults, do: @faults

  defp capabilities(values)
       when is_list(values) and length(values) == length(@candidate_capabilities) do
    normalized = Enum.sort_by(values, & &1.name)

    valid =
      Enum.map(normalized, & &1.name) == Enum.sort(@candidate_capabilities) and
        Enum.all?(normalized, fn capability ->
          exact_keys?(capability, @capability_keys) and
            capability.benefit in [:none, :duplicative, :material] and
            (is_nil(capability.evidence_digest) or
               valid_evidence_digest?(capability.evidence_digest))
        end)

    if valid, do: {:ok, normalized}, else: :error
  end

  defp capabilities(_values), do: :error
  defp decision(false, _conflict, []), do: :reject
  defp decision(_present, true, _benefits), do: :reject
  defp decision(_present, false, []), do: :defer
  defp decision(_present, false, _benefits), do: :adopt_ephemeral_only
  defp exact_keys?(map, keys), do: Enum.sort(Map.keys(map)) == Enum.sort(keys)

  defp valid_evidence_digest?(value),
    do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
