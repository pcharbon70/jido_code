defmodule JidoCode.Factory.Tool.ReferenceMonitor do
  @moduledoc "Complete-mediation authorization for every host-controlled tool effect."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Authorization
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.Catalog
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Factory.Tool.Proposal

  @spec authorize(Proposal.t(), Capability.t(), map()) ::
          {:ok, Authorization.t()} | {:error, AdapterError.t()}
  def authorize(%Proposal{} = proposal, %Capability{} = capability, current)
      when is_map(current) do
    with %DateTime{} = now <- current[:now],
         true <- Capability.valid_at?(capability, now),
         true <- proposal.invocation_iri == current[:invocation_iri],
         true <- proposal.tool_name in capability.permitted_tools,
         true <- proposal.classification in capability.data_classes,
         true <- MapSet.subset?(MapSet.new(proposal.input_refs), MapSet.new(capability.ref_iris)),
         true <- current_state?(capability, current),
         {:ok, {%Definition{} = definition, arguments}} <-
           Catalog.validate(
             proposal.tool_name,
             proposal.tool_version,
             proposal.arguments,
             constraints(capability)
           ),
         :ok <- approval(definition, arguments, current),
         :ok <- resource_ceiling(definition, capability),
         digest <- decision_digest(proposal, definition, capability) do
      {:ok,
       %Authorization{
         proposal: proposal,
         proposal_digest: proposal.proposal_digest,
         tool_name: proposal.tool_name,
         tool_version: proposal.tool_version,
         definition: definition,
         arguments: arguments,
         capability: capability,
         decision_digest: digest,
         authorized_at: DateTime.truncate(now, :microsecond)
       }}
    else
      _invalid -> denied()
    end
  rescue
    _error -> denied()
  end

  def authorize(_proposal, _capability, _current), do: denied()

  @spec revalidate(Authorization.t(), map()) ::
          {:ok, Authorization.t()} | {:error, AdapterError.t()}
  def revalidate(%Authorization{} = authorization, current) when is_map(current) do
    with {:ok, refreshed} <-
           authorize(authorization.proposal, authorization.capability, current),
         true <- refreshed.decision_digest == authorization.decision_digest do
      {:ok, refreshed}
    else
      _invalid -> denied()
    end
  end

  def revalidate(_authorization, _current), do: denied()

  defp current_state?(capability, current) do
    current[:lease_state] == :active and
      current[:policy_revision] == capability.policy_revision and
      current[:source_graph_revisions] == capability.source_graph_revisions and
      current[:snapshot_iri] == capability.snapshot_iri and
      current[:fencing_token] == capability.fencing_token and
      current[:revocation_generation] == capability.revocation_generation
  end

  defp constraints(capability) do
    %{
      allowed_path_prefixes: capability.path_prefixes,
      allowed_refs: capability.ref_iris,
      allowed_destinations: capability.network_destinations,
      registered_commands: capability.registered_commands
    }
  end

  defp approval(%Definition{approval_required: false}, _arguments, _current), do: :ok

  defp approval(%Definition{name: "submit_candidate"}, arguments, current) do
    if arguments.approval_ref in Map.get(current, :approval_refs, []), do: :ok, else: :error
  end

  defp approval(%Definition{name: name}, _arguments, current) do
    if name in Map.get(current, :approved_tools, []), do: :ok, else: :error
  end

  defp resource_ceiling(definition, capability) do
    output = Map.get(capability.resource_ceilings, :output_bytes, 0)
    timeout = Map.get(capability.resource_ceilings, :timeout_ms, 0)

    if output >= definition.max_output_bytes and timeout >= definition.timeout_ms,
      do: :ok,
      else: :error
  end

  defp decision_digest(proposal, definition, capability) do
    value = {
      proposal.proposal_digest,
      definition.iri,
      definition.input_schema_digest,
      definition.adapter_digest,
      capability.idempotency_namespace,
      capability.policy_revision,
      capability.fencing_token
    }

    :crypto.hash(:sha256, :erlang.term_to_binary(value, [:deterministic]))
    |> Base.encode16(case: :lower)
  end

  defp denied, do: {:error, AdapterError.new(:unauthorized, :tool_authorization)}
end
