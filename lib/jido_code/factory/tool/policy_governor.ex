defmodule JidoCode.Factory.Tool.PolicyGovernor do
  @moduledoc "Deterministically attenuates lease, task, policy, and actor authority."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Capability

  @dimensions ~w[lease task policy actor]a
  @list_fields ~w[
    permitted_tools path_prefixes ref_iris graph_scope_iris network_destinations
    registered_commands data_classes credential_reference_iris
  ]a
  @forbidden_authorities ~w[
    decision acceptance ontology security_policy durable_memory verification publication
  ]a

  @spec derive(map()) :: {:ok, Capability.t()} | {:error, AdapterError.t()}
  def derive(context) when is_map(context) do
    dimensions = Enum.map(@dimensions, &Map.fetch!(context, &1))

    authorities =
      dimensions |> Enum.flat_map(&Map.get(&1, :requested_authorities, [])) |> Enum.uniq()

    with true <- Enum.all?(dimensions, &is_map/1),
         false <- Enum.any?(authorities, &(&1 in @forbidden_authorities)),
         true <- authorities != [] and Enum.all?(authorities, &(&1 == :tool_execution)),
         {:ok, attenuated} <- attenuate_lists(dimensions),
         true <- attenuated.permitted_tools != [],
         {:ok, ceilings} <- attenuate_ceilings(dimensions),
         %DateTime{} = expires_at <- earliest_expiry(dimensions),
         fence when is_integer(fence) and fence > 0 <- context.lease[:fencing_token],
         policy_revision when is_integer(policy_revision) and policy_revision > 0 <-
           context.policy[:revision],
         generation when is_integer(generation) and generation > 0 <-
           context.lease[:revocation_generation],
         namespace <-
           namespace(
             context.attempt_iri,
             context.task.snapshot_iri,
             fence,
             policy_revision
           ) do
      Capability.new(%{
        attempt_iri: context.attempt_iri,
        lease_iri: context.lease.iri,
        task_iri: context.task.iri,
        repository_iri: context.task.repository_iri,
        actor_iri: context.actor.iri,
        agent_iri: context.agent_iri,
        profile_iri: context.profile.iri,
        model: context.profile.model,
        tool_catalog_version: context.profile.tool_catalog_version,
        snapshot_iri: context.task.snapshot_iri,
        source_graph_revisions: context.policy.source_graph_revisions,
        permitted_tools: attenuated.permitted_tools,
        path_prefixes: attenuated.path_prefixes,
        ref_iris: attenuated.ref_iris,
        graph_scope_iris: attenuated.graph_scope_iris,
        network_destinations: attenuated.network_destinations,
        registered_commands: attenuated.registered_commands,
        data_classes: attenuated.data_classes,
        resource_ceilings: ceilings,
        credential_reference_iris: attenuated.credential_reference_iris,
        expires_at: expires_at,
        fencing_token: fence,
        idempotency_namespace: namespace,
        policy_revision: policy_revision,
        revocation_generation: generation,
        authority_classes: [:tool_execution]
      })
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def derive(_context), do: invalid()

  defp attenuate_lists(dimensions) do
    attenuated =
      Map.new(@list_fields, fn field ->
        values = Enum.map(dimensions, &Map.get(&1, field, []))
        {field, intersection(values)}
      end)

    if Enum.all?(attenuated, fn {_field, values} -> is_list(values) end),
      do: {:ok, attenuated},
      else: :error
  end

  defp intersection([first | rest]) when is_list(first) do
    rest
    |> Enum.reduce(MapSet.new(first), fn
      values, set when is_list(values) -> MapSet.intersection(set, MapSet.new(values))
      _invalid, _set -> MapSet.new()
    end)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp intersection(_values), do: []

  defp attenuate_ceilings(dimensions) do
    ceilings = Enum.map(dimensions, &Map.get(&1, :resource_ceilings, %{}))

    with [first | rest] when map_size(first) > 0 <- ceilings,
         true <-
           Enum.all?(rest, fn value ->
             is_map(value) and MapSet.new(Map.keys(value)) == MapSet.new(Map.keys(first))
           end) do
      {:ok,
       Map.new(first, fn {key, value} ->
         {key, Enum.min([value | Enum.map(rest, &Map.fetch!(&1, key))])}
       end)}
    else
      _invalid -> :error
    end
  end

  defp earliest_expiry(dimensions) do
    expiries = Enum.map(dimensions, &Map.get(&1, :expires_at))

    if Enum.all?(expiries, &match?(%DateTime{}, &1)),
      do: Enum.min_by(expiries, &DateTime.to_unix(&1, :microsecond)),
      else: nil
  end

  defp namespace(attempt_iri, snapshot_iri, fence, policy_revision) do
    seed = Enum.join([attempt_iri, snapshot_iri, fence, policy_revision], "\n")
    "sha256:" <> (:crypto.hash(:sha256, seed) |> Base.encode16(case: :lower))
  end

  defp invalid, do: {:error, AdapterError.new(:unauthorized, :tool_policy)}
end
