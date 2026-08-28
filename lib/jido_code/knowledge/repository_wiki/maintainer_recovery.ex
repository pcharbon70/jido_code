defmodule JidoCode.Knowledge.RepositoryWiki.MaintainerRecovery do
  @moduledoc "Graph-derived maintainer restart, takeover, and exact-fence recovery planning."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract

  @dependencies [:store, :harness, :artifact, :profile, :accounting]
  @maximum_items 200

  @spec plan(map(), map(), DateTime.t()) :: {:ok, map()} | {:error, Error.t()}
  def plan(enrollment, facts, %DateTime{} = evaluated_at)
      when is_map(enrollment) and is_map(facts) do
    with :ok <- enrollment(enrollment),
         :ok <- facts(facts),
         true <- evaluated_at == DateTime.truncate(evaluated_at, :microsecond) do
      {:ok, build(enrollment, facts, evaluated_at)}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_maintainer_recovery)
    end
  rescue
    _error -> invalid(:repository_wiki_maintainer_recovery)
  end

  def plan(_enrollment, _facts, _evaluated_at),
    do: invalid(:repository_wiki_maintainer_recovery)

  defp build(enrollment, facts, evaluated_at) do
    unavailable =
      Enum.reject(@dependencies, &(facts.dependencies[&1] == :ready)) ++
        if(facts.worker_ready?, do: [], else: [:worker])

    cond do
      enrollment.state != :automatic ->
        result(enrollment, evaluated_at, :ineligible, [:not_automatic], [], [], false)

      unavailable != [] ->
        result(enrollment, evaluated_at, :degraded, Enum.uniq(unavailable), [], [], false)

      live_lease?(facts.lease, evaluated_at) ->
        result(enrollment, evaluated_at, :owned, [], [], [], false)

      true ->
        {recoverable, superseded} = recovery_actions(enrollment, facts)
        enqueue = if update_necessary?(enrollment, facts), do: [enqueue_action(facts)], else: []

        result(
          enrollment,
          evaluated_at,
          :recovering,
          [],
          [acquire_action(enrollment, facts) | recoverable ++ enqueue],
          superseded,
          enqueue != []
        )
    end
  end

  defp result(enrollment, evaluated_at, status, degraded, actions, superseded, necessary?) do
    material = %{
      repository_iri: enrollment.repository_iri,
      tenant_iri: enrollment.tenant_iri,
      enrollment_revision: enrollment.revision,
      cancellation_generation: enrollment.cancellation_generation,
      status: status,
      degraded_dependencies: Enum.sort(degraded),
      actions: actions,
      superseded: superseded,
      update_necessary?: necessary?,
      evaluated_at: evaluated_at
    }

    Map.put(material, :digest, Contract.digest(material))
  end

  defp recovery_actions(enrollment, facts) do
    candidates =
      Enum.map(facts.incomplete_editions, &candidate(:resume_edition, &1, enrollment, facts)) ++
        Enum.map(
          facts.reservations,
          &candidate(:reconcile_reservation, &1, enrollment, facts)
        ) ++
        Enum.map(facts.usage_pending_attempts, &accounting_candidate(&1, enrollment)) ++
        Enum.map(facts.metadata_refreshes, &candidate(:resume_metadata, &1, enrollment, facts)) ++
        Enum.map(
          facts.activation_candidates,
          &candidate(:qualify_activation, &1, enrollment, facts)
        )

    Enum.split_with(candidates, &(&1.disposition == :recover))
    |> then(fn {recoverable, superseded} ->
      {
        Enum.map(recoverable, &Map.delete(&1, :disposition)),
        Enum.map(superseded, &Map.put(Map.delete(&1, :disposition), :reason, :stale_fence))
      }
    end)
  end

  defp candidate(action, item, enrollment, facts) do
    %{
      action: action,
      iri: item.iri,
      original_fence: item.original_fence,
      disposition: if(current_item?(item, enrollment, facts), do: :recover, else: :supersede)
    }
  end

  defp accounting_candidate(item, enrollment) do
    %{
      action: :reconcile_usage,
      iri: item.iri,
      original_fence: item.original_fence,
      disposition:
        if(
          item[:repository_iri] == enrollment.repository_iri and
            item[:tenant_iri] == enrollment.tenant_iri and
            item[:original_fence_valid?] == true,
          do: :recover,
          else: :supersede
        )
    }
  end

  defp current_item?(item, enrollment, facts) do
    item[:repository_iri] == enrollment.repository_iri and
      item[:tenant_iri] == enrollment.tenant_iri and
      item[:enrollment_revision] == enrollment.revision and
      item[:cancellation_generation] == enrollment.cancellation_generation and
      item[:source_fence] == facts.current_source_fence and
      item[:original_fence_valid?] == true
  end

  defp update_necessary?(_enrollment, facts) do
    edition = facts.current_edition

    current_activation? =
      Enum.any?(facts.activation_candidates, fn candidate ->
        candidate[:source_fence] == facts.current_source_fence and
          candidate[:original_fence_valid?] == true
      end)

    current_success? =
      Enum.any?(facts.terminal_attempts, fn attempt ->
        attempt[:source_fence] == facts.current_source_fence and attempt[:state] == :success
      end)

    trigger_pending? =
      Enum.any?(facts.triggers, &(&1[:source_fence] == facts.current_source_fence))

    source_missing? =
      is_nil(edition) or edition[:stale?] == true or
        edition[:source_fence] != facts.current_source_fence

    trigger_pending? or (source_missing? and not (current_success? and current_activation?))
  end

  defp live_lease?(nil, _evaluated_at), do: false

  defp live_lease?(lease, evaluated_at) do
    lease[:state] == :active and match?(%DateTime{}, lease[:expires_at]) and
      DateTime.compare(evaluated_at, lease.expires_at) == :lt
  end

  defp acquire_action(enrollment, facts) do
    %{
      action: :acquire_owner,
      repository_iri: enrollment.repository_iri,
      tenant_iri: enrollment.tenant_iri,
      enrollment_revision: enrollment.revision,
      cancellation_generation: enrollment.cancellation_generation,
      profile_digest: facts.profile_digest
    }
  end

  defp enqueue_action(facts) do
    %{
      action: :enqueue_update,
      source_fence: facts.current_source_fence,
      causal_iris: facts.triggers |> Enum.map(& &1.iri) |> Enum.uniq() |> Enum.sort()
    }
  end

  defp enrollment(enrollment) do
    with :ok <- Contract.resource(enrollment[:repository_iri]),
         :ok <- Contract.resource(enrollment[:tenant_iri]),
         true <- enrollment[:state] in [:off, :manual, :automatic],
         true <- nonnegative?(enrollment[:revision]),
         true <- nonnegative?(enrollment[:cancellation_generation]) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_recovery_enrollment)
    end
  end

  defp facts(facts) do
    collections = [
      :incomplete_editions,
      :reservations,
      :usage_pending_attempts,
      :metadata_refreshes,
      :activation_candidates,
      :terminal_attempts,
      :triggers
    ]

    with true <- is_map(facts[:dependencies]),
         true <- Enum.all?(@dependencies, &(facts.dependencies[&1] in [:ready, :unavailable])),
         true <- is_boolean(facts[:worker_ready?]),
         true <- Contract.digest?(facts[:profile_digest]),
         true <- is_binary(facts[:current_source_fence]),
         true <- Enum.all?(collections, &bounded_resource_list?(facts[&1])),
         true <- is_nil(facts[:current_edition]) or is_map(facts[:current_edition]),
         true <- is_nil(facts[:lease]) or is_map(facts[:lease]) do
      :ok
    else
      _invalid -> invalid(:repository_wiki_recovery_facts)
    end
  end

  defp bounded_resource_list?(value) when is_list(value) and length(value) <= @maximum_items do
    Enum.all?(value, fn item -> is_map(item) and Contract.resource(item[:iri]) == :ok end)
  end

  defp bounded_resource_list?(_value), do: false
  defp nonnegative?(value), do: is_integer(value) and value >= 0
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
