defmodule JidoCode.Factory.ManagedCoding.RolloutGovernance do
  @moduledoc "Accountable release decisions and fail-closed disable controls for managed coding."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity

  @disable_scopes ~w[global tenant repository provider adapter tool profile]a
  @decisions ~w[accept extend restrict reject]a
  @enforce_keys ~w[owner_actor_iris approver_actor_iris on_call_actor_iris dashboard_iris alert_route_iris review_cadence_hours escalation_policy_revision evidence_retention_days disabled release_decisions incidents]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes[:owner_actor_iris]),
         :ok <- resources(attributes[:approver_actor_iris]),
         :ok <- resources(attributes[:on_call_actor_iris]),
         :ok <- resources(attributes[:dashboard_iris]),
         :ok <- resources(attributes[:alert_route_iris]),
         cadence when is_integer(cadence) and cadence > 0 <- attributes[:review_cadence_hours],
         revision when is_binary(revision) and byte_size(revision) in 1..128 <-
           attributes[:escalation_policy_revision],
         retention when is_integer(retention) and retention > 0 <-
           attributes[:evidence_retention_days] do
      {:ok,
       %__MODULE__{
         owner_actor_iris: normalized(attributes.owner_actor_iris),
         approver_actor_iris: normalized(attributes.approver_actor_iris),
         on_call_actor_iris: normalized(attributes.on_call_actor_iris),
         dashboard_iris: normalized(attributes.dashboard_iris),
         alert_route_iris: normalized(attributes.alert_route_iris),
         review_cadence_hours: cadence,
         escalation_policy_revision: revision,
         evidence_retention_days: retention,
         disabled: [],
         release_decisions: [],
         incidents: []
       }}
    else
      _invalid -> invalid(:managed_coding_rollout_governance)
    end
  end

  def new(_attributes), do: invalid(:managed_coding_rollout_governance)

  @spec disable(t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def disable(%__MODULE__{} = state, command) when is_map(command) do
    with scope when scope in @disable_scopes <- command[:scope],
         :ok <- scope_identity(scope, command[:target]),
         true <- command[:actor_iri] in (state.owner_actor_iris ++ state.on_call_actor_iris),
         reason when is_binary(reason) and byte_size(reason) in 1..512 <- command[:reason],
         %DateTime{} = disabled_at <- command[:disabled_at] do
      record = %{
        scope: scope,
        target: command.target,
        actor_iri: command.actor_iri,
        reason: reason,
        disabled_at: disabled_at,
        new_effects_blocked: true,
        recovery_allowed: true,
        cancellation_allowed: true,
        evidence_preserved: true
      }

      {:ok, %{state | disabled: [record | state.disabled]}}
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :managed_coding_disable)}
    end
  end

  def disable(_state, _command), do: invalid(:managed_coding_disable)

  @spec effect_allowed?(t(), map()) :: boolean()
  def effect_allowed?(%__MODULE__{} = state, context) when is_map(context) do
    Enum.all?(state.disabled, fn record ->
      case record.scope do
        :global -> false
        scope -> context[scope] != record.target
      end
    end)
  end

  def effect_allowed?(_state, _context), do: false

  @spec incident(t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def incident(%__MODULE__{} = state, evidence) when is_map(evidence) do
    required =
      ~w[incident_iri actor_iri triage cancellation_drain credential_revocation evidence_preservation tenant_notification candidate_quarantine rollback safe_reenable status]a

    with true <- Enum.sort(Map.keys(evidence)) == Enum.sort(required),
         :ok <- Identity.validate_resource(evidence.incident_iri),
         true <- evidence.actor_iri in (state.owner_actor_iris ++ state.on_call_actor_iris),
         true <- evidence.status in [:open, :resolved],
         true <-
           Enum.all?(required -- [:incident_iri, :actor_iri, :status], &is_boolean(evidence[&1])),
         true <- evidence.evidence_preservation do
      {:ok, %{state | incidents: [evidence | state.incidents]}}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_incident)}
    end
  end

  def incident(_state, _evidence), do: invalid(:managed_coding_incident)

  @spec decide(t(), map()) :: {:ok, map(), t()} | {:error, AdapterError.t()}
  def decide(%__MODULE__{} = state, attributes) when is_map(attributes) do
    with decision when decision in @decisions <- attributes[:decision],
         true <- attributes[:actor_iri] in state.approver_actor_iris,
         true <- attributes[:independent] == true,
         true <- attributes[:runtime_actor_iri] != attributes[:actor_iri],
         true <- attributes[:verifier_actor_iri] != attributes[:actor_iri],
         :ok <- Identity.validate_resource(attributes[:evidence_bundle_iri]),
         true <- is_boolean(attributes[:thresholds_passed]),
         unresolved when is_list(unresolved) <- attributes[:unresolved_findings],
         true <- Enum.all?(unresolved, &is_binary/1),
         :ok <- decision_contract(decision, attributes) do
      record = %{
        decision: decision,
        actor_iri: attributes.actor_iri,
        evidence_bundle_iri: attributes.evidence_bundle_iri,
        thresholds_passed: attributes.thresholds_passed,
        unresolved_findings: unresolved,
        drills_passed: attributes.drills_passed,
        restrictions: Map.get(attributes, :restrictions, []),
        automatic_approval: false,
        automatic_merge: false,
        general_multi_agent: false,
        decided_at: attributes.decided_at
      }

      {:ok, record, %{state | release_decisions: [record | state.release_decisions]}}
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :managed_coding_release_decision)}
    end
  end

  def decide(_state, _attributes), do: invalid(:managed_coding_release_decision)

  defp decision_contract(:accept, attributes) do
    if attributes.thresholds_passed and attributes.unresolved_findings == [] and
         attributes[:drills_passed] == true and match?(%DateTime{}, attributes[:decided_at]),
       do: :ok,
       else: :error
  end

  defp decision_contract(:extend, attributes) do
    if attributes[:drills_passed] == true and match?(%DateTime{}, attributes[:decided_at]),
      do: :ok,
      else: :error
  end

  defp decision_contract(:restrict, attributes) do
    if is_list(attributes[:restrictions]) and attributes.restrictions != [] and
         match?(%DateTime{}, attributes[:decided_at]),
       do: :ok,
       else: :error
  end

  defp decision_contract(:reject, attributes),
    do: if(match?(%DateTime{}, attributes[:decided_at]), do: :ok, else: :error)

  defp scope_identity(:global, :all), do: :ok
  defp scope_identity(_scope, target), do: Identity.validate_resource(target)

  defp resources(values) when is_list(values) and values != [] and length(values) <= 128 do
    if Enum.all?(values, &(Identity.validate_resource(&1) == :ok)), do: :ok, else: :error
  end

  defp resources(_values), do: :error
  defp normalized(values), do: values |> Enum.uniq() |> Enum.sort()
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
