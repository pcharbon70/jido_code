defmodule JidoCode.Knowledge.RepositoryWiki.SynthesisReconciliationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.RepositoryWiki.AccountingReconciler
  alias JidoCode.Factory.RepositoryWiki.SynthesisBoundary
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-28 17:00:00Z]

  setup do
    repository = resource(:repository_reconciliation, "synthesis-repository")
    tenant = resource(:authorization_grant, "synthesis-tenant")
    actor = resource(:authorization_grant, "synthesis-actor")
    session = resource(:interaction_session, "synthesis-session")
    attempt = resource(:wiki_compilation_attempt, "synthesis-attempt")
    edition = resource(:wiki_edition, "synthesis-edition")
    reservation = resource(:wiki_reservation, "synthesis-reservation")
    invocation = resource(:model_invocation, "synthesis-invocation")
    profile = resource(:wiki_generation_profile, "synthesis-profile")
    price = resource(:wiki_budget, "synthesis-price")
    provider_request = resource(:provider_object, "synthesis-provider-request")
    {:ok, control_graph} = GraphRegistry.graph_iri(:repository_control, %{repository: repository})
    {:ok, run_graph} = GraphRegistry.graph_iri(:run_attempt, %{attempt: attempt})

    request_attributes = %{
      repository_iri: repository,
      tenant_iri: tenant,
      actor_iri: actor,
      session_iri: session,
      attempt_iri: attempt,
      edition_iri: edition,
      reservation_iri: reservation,
      invocation_iri: invocation,
      profile_iri: profile,
      price_iri: price,
      provider: "fake-provider",
      model: "fake-model-v1",
      source_fence: "synthesis-source-1",
      source_facts: [
        %{
          resource_iri: resource(:source_artifact, "synthesis-source"),
          digest: digest("source"),
          kind: :source
        }
      ],
      retrieval_context: [resource(:knowledge_assertion, "retrieval-fact")],
      prompt_digest: digest("fixed-prompt"),
      output_schema: :wiki_synthesis_fragment_v1,
      token_limits: %{input: 1_000, output: 500, cached: 250, reasoning: 100},
      redaction_policy: :secrets_and_private_content,
      recorded_at: @now
    }

    request_context = %{
      controller_authenticated?: true,
      repository_iri: repository,
      tenant_iri: tenant,
      profile_iri: profile,
      price_iri: price,
      provider: "fake-provider",
      model: "fake-model-v1"
    }

    {:ok, request} =
      Knowledge.repository_wiki_synthesis_request(request_attributes, request_context)

    %{
      repository: repository,
      tenant: tenant,
      actor: actor,
      attempt: attempt,
      edition: edition,
      reservation: reservation,
      invocation: invocation,
      profile: profile,
      price: price,
      provider_request: provider_request,
      control_graph: control_graph,
      run_graph: run_graph,
      request: request,
      request_attributes: request_attributes,
      request_context: request_context
    }
  end

  test "constructs only the closed controller-owned request", context do
    assert context.request.output_schema == :wiki_synthesis_fragment_v1
    assert context.request.redaction_policy == :secrets_and_private_content
    assert byte_size(context.request.digest) == 64

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.repository_wiki_synthesis_request(
               Map.put(context.request_attributes, :endpoint, "https://attacker.invalid"),
               context.request_context
             )

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.repository_wiki_synthesis_request(
               context.request_attributes,
               %{context.request_context | provider: "caller-selected"}
             )
  end

  test "production remains unavailable before invocation or adapter effect", context do
    test_pid = self()
    ports = effect_ports(context, test_pid)

    assert SynthesisBoundary.production_adapter_catalog() == []

    assert {:error, %{outcome: :unavailable, effect_started?: false}} =
             SynthesisBoundary.invoke(
               context.request,
               boundary_context(context, :production),
               ports
             )

    refute_receive {:effect, _stage}

    assert {:error, %{outcome: :missing_opt_in, effect_started?: false}} =
             SynthesisBoundary.invoke(
               context.request,
               %{boundary_context(context, :test) | synthesis_opt_in?: false},
               ports
             )

    refute_receive {:effect, _stage}
  end

  test "fake boundary commits invocation before effect and normalizes bounded observations",
       context do
    test_pid = self()
    ports = effect_ports(context, test_pid)

    assert {:ok, outcome} =
             SynthesisBoundary.invoke(context.request, boundary_context(context, :test), ports)

    assert outcome.outcome == :observed
    assert outcome.effect_started?
    refute outcome.activation_eligible?
    assert outcome.usage.input == 100

    assert_receive {:effect, :commit_invocation}
    assert_receive {:effect, :adapter}
    assert_receive {:effect, :normalize}
    assert_receive {:effect, :lint}
    assert_receive {:effect, :review}

    failing = Map.put(ports, :adapter, fn _request, _current -> {:error, :provider_failure} end)

    assert {:error, %{outcome: :provider_failure, effect_started?: true}} =
             SynthesisBoundary.invoke(
               context.request,
               boundary_context(context, :test),
               failing
             )
  end

  test "records invocation-before-effect through the reviewed semantic command", context do
    attributes = %{
      run_graph_iri: context.run_graph,
      control_graph_iri: context.control_graph,
      expected_run_revision: 2,
      expected_control_revision: 6,
      expected_dataset_revision: 13,
      enrollment_revision: 4,
      principal_iri: resource(:authorization_grant, "synthesis-principal"),
      actor_iri: context.actor,
      scope_iri: context.repository,
      correlation_iri: resource(:authorization_grant, "synthesis-correlation"),
      causation_iri: resource(:authorization_grant, "synthesis-causation"),
      reason: "record invocation before fake effect"
    }

    assert {:ok, command} =
             Knowledge.invoke_repository_wiki_synthesis_command(
               context.request,
               attributes,
               clock: fn -> @now end
             )

    assert command.command_type == "InvokeWikiSynthesis"
    assert command.command_version == "2.11.0"

    assert command.expected_graph_revisions == %{
             context.control_graph => 6,
             context.run_graph => 2
           }
  end

  test "reconciles pending and late usage without erasing unknown liability", context do
    attempt = accounting_attempt(context)
    test_pid = self()

    ports = %{
      retrieve_usage: fn provider_request ->
        send(test_pid, {:retrieved, provider_request})
        {:ok, %{raw_digest: digest("provider-usage")}}
      end,
      normalize_usage: fn _observation, current, accounting_context ->
        {:ok, exact_usage(current, accounting_context)}
      end,
      record_terminal: fn usage, _accounting_context ->
        send(test_pid, {:terminal, usage.state})
        {:ok, %{outcome: :committed}}
      end
    }

    accounting_context = accounting_context(context)
    assert [^attempt] = AccountingReconciler.pending([attempt], DateTime.add(@now, 1, :second))

    assert {:ok, reconciled} =
             AccountingReconciler.reconcile(attempt, accounting_context, ports)

    assert reconciled.outcome == :reconciled
    assert_receive {:retrieved, provider_request}
    assert provider_request == context.provider_request
    assert_receive {:terminal, :success}

    assert {:ok, unknown} =
             AccountingReconciler.reconcile(
               attempt,
               %{accounting_context | retrieval_supported?: false},
               ports
             )

    assert unknown.outcome == :usage_unknown
    assert unknown.usage.costs.unknown == attempt.reserved_cost
    assert_receive {:terminal, :usage_unknown}

    usage = exact_usage(attempt, accounting_context)

    assert {:ok, %{late?: true}} =
             AccountingReconciler.late_usage(usage, attempt, accounting_context)

    assert {:duplicate, ^usage} =
             AccountingReconciler.late_usage(
               usage,
               attempt,
               Map.put(accounting_context, :usage_records, [usage])
             )

    assert {:error, :mismatched_late_usage} =
             AccountingReconciler.late_usage(
               %{usage | model: "wrong-model"},
               attempt,
               accounting_context
             )
  end

  test "builds bounded exact rollups, alerts, and reviewed accounting queries", context do
    record = %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      actor_iri: context.actor,
      profile_iri: context.profile,
      trigger: "automatic",
      edition_iri: context.edition,
      period_key: "2026-08",
      currency: "CAD",
      tokens: %{input: 10, output: 20, cached: 5, reasoning: 2},
      costs: %{charged: 12, unknown: 0}
    }

    assert [rollup] = AccountingReconciler.rollups([record, record])
    assert rollup.record_count == 2
    assert rollup.totals.input == 20
    assert rollup.totals.charged == 24

    attempt =
      context
      |> accounting_attempt()
      |> Map.merge(%{
        reservation_state: :reserved,
        reservation_expires_at: @now,
        cost_arithmetic_error?: true,
        profile_price_drift?: true,
        generation_mode: :deterministic_only,
        total_tokens: 1
      })

    alerts = AccountingReconciler.alerts([attempt], @now)
    kinds = MapSet.new(alerts, & &1.kind)
    assert :expired_live_reservation in kinds
    assert :invocation_without_terminal_usage in kinds
    assert :cost_arithmetic_error in kinds
    assert :profile_price_drift in kinds
    assert :impossible_token_combination in kinds

    names = QueryCatalog.names("2.11.0")
    assert :repository_wiki_pending_accounting in names
    assert :repository_wiki_cost_records in names
    refute :repository_wiki_pending_accounting in QueryCatalog.names("2.10.0")
    assert :ok = QueryCatalog.verify()
  end

  defp effect_ports(context, test_pid) do
    %{
      commit_invocation: fn _request, _current ->
        send(test_pid, {:effect, :commit_invocation})
        {:ok, %{outcome: :committed}}
      end,
      adapter: fn _request, _current ->
        send(test_pid, {:effect, :adapter})
        {:ok, %{provider_request_iri: context.provider_request}}
      end,
      normalize: fn _observation, request, _current ->
        send(test_pid, {:effect, :normalize})

        {:ok,
         %{
           output: %{sections: [%{title: "Bounded", body: "Observed"}]},
           usage: %{
             provider_request_iri: context.provider_request,
             provider: request.provider,
             model: request.model,
             reservation_iri: request.reservation_iri,
             invocation_iri: request.invocation_iri,
             input: 100,
             output: 50,
             cached: 10,
             reasoning: 5
           }
         }}
      end,
      lint: fn _output, _request, _current ->
        send(test_pid, {:effect, :lint})
        {:ok, %{status: :passed, blocking_count: 0}}
      end,
      review: fn _output, _lint, _request, _current ->
        send(test_pid, {:effect, :review})
        {:ok, %{decision: :pending_human_review}}
      end
    }
  end

  defp boundary_context(context, deployment) do
    %{
      deployment: deployment,
      adapter_catalog: if(deployment == :test, do: [:fake_provider], else: []),
      wiki_enrolled?: true,
      synthesis_opt_in?: true,
      profile_enabled?: true,
      price_enabled?: true,
      worker_ready?: true,
      reservation_state: :reserved,
      reservation_current?: true,
      reservation_iri: context.reservation,
      profile_iri: context.profile,
      price_iri: context.price,
      source_fence: context.request.source_fence,
      provider: context.request.provider,
      model: context.request.model,
      provider_request_iri: context.provider_request
    }
  end

  defp accounting_attempt(context) do
    %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      actor_iri: context.actor,
      attempt_iri: context.attempt,
      usage_iri: resource(:wiki_usage_record, "pending-usage"),
      reservation_iri: context.reservation,
      invocation_iri: context.invocation,
      provider_request_iri: context.provider_request,
      model: context.request.model,
      price_revision: 3,
      accounting_fence: "accounting-fence-3",
      invoked_at: @now,
      terminal_usage_iri: nil,
      reserved_cost: 100
    }
  end

  defp accounting_context(context) do
    %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      accounting_fence: "accounting-fence-3",
      price_revision: 3,
      retrieval_supported?: true,
      retrieval_attempt: 0,
      maximum_retrieval_attempts: 2,
      usage_records: []
    }
  end

  defp exact_usage(attempt, accounting_context) do
    %{
      usage_iri: attempt.usage_iri,
      attempt_iri: attempt.attempt_iri,
      reservation_iri: attempt.reservation_iri,
      invocation_iri: attempt.invocation_iri,
      provider_request_iri: attempt.provider_request_iri,
      model: attempt.model,
      price_revision: attempt.price_revision,
      accounting_fence: accounting_context.accounting_fence,
      state: :success
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
