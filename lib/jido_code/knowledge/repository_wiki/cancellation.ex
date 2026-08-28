defmodule JidoCode.Knowledge.RepositoryWiki.Cancellation do
  @moduledoc "Authoritative repository-wiki disable plan and old-generation result fence."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract

  @maximum_items 200
  @required_keys ~w[
    repository_iri tenant_iri disable_command prior_enrollment_revision enrollment_revision
    prior_cancellation_generation cancellation_generation retained_read_policy current_edition_iri
    queued_triggers active_effects leases reservations attempts artifacts recorded_at
  ]a

  @spec plan(map()) :: {:ok, map()} | {:error, Error.t()}
  def plan(attributes) when is_map(attributes) do
    with true <- attributes |> Map.keys() |> Enum.sort() == Enum.sort(@required_keys),
         :ok <- Contract.resource(attributes[:repository_iri]),
         :ok <- Contract.resource(attributes[:tenant_iri]),
         :ok <- Contract.optional_resource(attributes[:current_edition_iri]),
         :ok <- disable_command(attributes),
         true <- successor?(attributes),
         true <- attributes[:retained_read_policy] in [:allow, :deny],
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         true <- recorded_at == DateTime.truncate(recorded_at, :microsecond),
         :ok <- bounded_collections(attributes),
         :ok <- scoped_collections(attributes),
         actions <- actions(attributes),
         retained_read <- retained_read(attributes),
         material <-
           attributes
           |> Map.drop([:disable_command])
           |> Map.put(:disable_command_iri, attributes.disable_command.command_iri)
           |> Map.put(:actions, actions)
           |> Map.put(:retained_read, retained_read),
         digest <- Contract.digest(material) do
      {:ok,
       material
       |> Map.put(:disable_command, attributes.disable_command)
       |> Map.put(:digest, digest)}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_cancellation_plan)
    end
  rescue
    _error -> invalid(:repository_wiki_cancellation_plan)
  end

  def plan(_attributes), do: invalid(:repository_wiki_cancellation_plan)

  @spec valid_plan?(term()) :: boolean()
  def valid_plan?(%{digest: digest} = plan) do
    material = Map.drop(plan, [:digest, :disable_command])
    Contract.digest?(digest) and digest == Contract.digest(material)
  end

  def valid_plan?(_plan), do: false

  @doc "Accepts results only at the exact live enrollment, lease, cancellation, and source fence."
  @spec result_current?(map(), map()) :: boolean()
  def result_current?(result, current) when is_map(result) and is_map(current) do
    current[:state] in [:manual, :automatic] and
      Enum.all?(
        ~w[
          repository_iri tenant_iri enrollment_revision cancellation_generation
          lease_generation source_fence
        ]a,
        &(result[&1] == current[&1])
      )
  end

  def result_current?(_result, _current), do: false

  defp disable_command(%{disable_command: %CommandEnvelope{} = command} = attributes) do
    effects = get_in(command.payload, [:disable_effects]) || []

    if command.command_type == "TransitionRepositoryWikiEnrollment" and
         command.command_version == "2.10.0" and
         command.scope_iri == attributes.repository_iri and
         :advance_cancellation_fence in effects and
         :reject_new_compilation in effects and
         :preserve_accounting_and_audit_history in effects and
         exact_disable_transition?(command, attributes) do
      :ok
    else
      invalid(:repository_wiki_disable_command)
    end
  end

  defp disable_command(_attributes), do: invalid(:repository_wiki_disable_command)

  defp exact_disable_transition?(command, attributes) do
    jf = "https://jido.run/ontology/factory#"

    statements =
      command.payload
      |> Map.get(:changes, [])
      |> Enum.flat_map(&Map.get(&1, :additions, []))

    statements
    |> Enum.group_by(fn {subject, _predicate, _object} -> subject end)
    |> Enum.any?(fn {_subject, values} ->
      triple?(values, jf <> "repositoryScope", RDF.iri(attributes.repository_iri)) and
        triple?(values, jf <> "enrollmentState", RDF.iri(Contract.concept(:wiki_off))) and
        triple?(
          values,
          jf <> "enrollmentRevision",
          RDF.XSD.NonNegativeInteger.new(attributes.enrollment_revision)
        ) and
        triple?(
          values,
          jf <> "wikiCancellationGeneration",
          RDF.XSD.NonNegativeInteger.new(attributes.cancellation_generation)
        )
    end)
  end

  defp triple?(values, predicate, object),
    do:
      Enum.any?(values, fn {_subject, current_predicate, current_object} ->
        current_predicate == predicate and current_object == object
      end)

  defp successor?(attributes) do
    integer_successor?(attributes[:prior_enrollment_revision], attributes[:enrollment_revision]) and
      integer_successor?(
        attributes[:prior_cancellation_generation],
        attributes[:cancellation_generation]
      )
  end

  defp integer_successor?(prior, successor),
    do: is_integer(prior) and prior >= 0 and successor == prior + 1

  defp bounded_collections(attributes) do
    if Enum.all?(collection_keys(), fn key ->
         is_list(attributes[key]) and length(attributes[key]) <= @maximum_items
       end),
       do: :ok,
       else: invalid(:repository_wiki_cancellation_collections)
  end

  defp scoped_collections(attributes) do
    if collection_keys()
       |> Enum.flat_map(&attributes[&1])
       |> Enum.all?(&scoped?(&1, attributes)),
       do: :ok,
       else: invalid(:repository_wiki_cancellation_scope)
  end

  defp scoped?(item, attributes) when is_map(item) do
    item[:repository_iri] == attributes.repository_iri and
      item[:tenant_iri] == attributes.tenant_iri and
      is_binary(item[:iri]) and
      item[:enrollment_revision] <= attributes.prior_enrollment_revision and
      item[:cancellation_generation] <= attributes.prior_cancellation_generation
  end

  defp scoped?(_item, _attributes), do: false

  defp actions(attributes) do
    %{
      stop_admission: %{
        repository_iri: attributes.repository_iri,
        tenant_iri: attributes.tenant_iri,
        enrollment_revision: attributes.enrollment_revision,
        cancellation_generation: attributes.cancellation_generation
      },
      terminal_pending_triggers:
        Enum.map(attributes.queued_triggers, &action(&1, :terminal_cancelled)),
      cancel_active_effects: Enum.map(attributes.active_effects, &action(&1, :cancel)),
      revoke_leases: Enum.map(attributes.leases, &lease_action(&1, attributes)),
      reconcile_accounting: %{
        reservations: Enum.map(attributes.reservations, &reservation_action/1),
        attempts: Enum.map(attributes.attempts, &attempt_action/1),
        preserve_usage_and_audit?: true
      },
      retain_artifacts:
        Enum.map(attributes.artifacts, fn artifact ->
          action(artifact, artifact_retention(artifact, attributes.retained_read_policy))
        end),
      stop_owner: %{
        repository_iri: attributes.repository_iri,
        tenant_iri: attributes.tenant_iri
      }
    }
  end

  defp action(item, action), do: %{iri: item.iri, action: action}

  defp lease_action(lease, attributes) do
    action =
      if lease[:state] == :active,
        do: :revoke,
        else: :preserve_terminal

    %{
      iri: lease.iri,
      action: action,
      cancellation_generation: attributes.cancellation_generation
    }
  end

  defp reservation_action(reservation) do
    action =
      case {reservation[:state], reservation[:invoked?]} do
        {:reserved, false} -> :release_unconsumed
        {:reserved, true} -> :retain_unknown_liability
        {:consumed, _invoked?} -> :retain_consumed_liability
        {:usage_pending, _invoked?} -> :retain_unknown_liability
        {:usage_unknown, _invoked?} -> :retain_unknown_liability
        {_state, _invoked?} -> :preserve_terminal
      end

    action(reservation, action)
  end

  defp attempt_action(attempt) do
    action =
      case {attempt[:generation_mode], attempt[:terminal_state], attempt[:effect_started?]} do
        {:deterministic_only, nil, _effect?} -> :record_cancelled_zero_usage
        {:synthesis_allowed, nil, false} -> :record_rejected_before_effect
        {:synthesis_allowed, nil, true} -> :record_usage_pending
        {_mode, _terminal, _effect?} -> :preserve_terminal
      end

    action(attempt, action)
  end

  defp artifact_retention(artifact, :allow) do
    if artifact[:readable?], do: :retain_readable, else: :retain_audit_only
  end

  defp artifact_retention(_artifact, :deny), do: :retain_audit_only

  defp retained_read(attributes) do
    readable? =
      attributes.retained_read_policy == :allow and not is_nil(attributes.current_edition_iri)

    %{
      readable?: readable?,
      edition_iri: if(readable?, do: attributes.current_edition_iri, else: nil),
      generation_enabled?: false,
      product_navigation?: false
    }
  end

  defp collection_keys,
    do: [:queued_triggers, :active_effects, :leases, :reservations, :attempts, :artifacts]

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
