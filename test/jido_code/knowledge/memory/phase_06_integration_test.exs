defmodule JidoCode.Knowledge.Memory.Phase06IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ContentAccessOutcome
  alias JidoCode.Knowledge.Memory.ContentErasurePlan
  alias JidoCode.Knowledge.Memory.ContentStorageDecision
  alias JidoCode.Knowledge.Memory.EpisodeContent
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.Memory.InMemoryContentKeyProvider
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Security.DataPolicy
  alias JidoCode.TestSupport.Phase03RetrievalFixture
  alias JidoCode.TestSupport.Phase04Fixture

  setup context do
    fixture = Phase03RetrievalFixture.complete!(context)

    {:ok, keys} =
      start_supervised(
        {InMemoryContentKeyProvider,
         random_bytes: fn count -> :crypto.hash(:sha256, "phase-6-key-#{count}") end}
      )

    %{fixture: fixture, keys: keys}
  end

  test "persists, releases once, audits, restarts, holds, and cryptographically erases content",
       %{fixture: fixture, keys: keys} do
    now = fixture.issued_at
    plaintext = "bounded exact tool output for a governed recovery task"
    cipher_attributes = cipher_attributes()
    identity_attributes = identity_attributes(fixture, "real-store")
    {:ok, content_iri} = EpisodeContent.identity(identity_attributes)

    assert {:ok, encrypted} =
             Knowledge.encrypt_content(
               InMemoryContentKeyProvider,
               keys,
               fixture.factory_scope,
               content_iri,
               plaintext,
               cipher_attributes,
               random_bytes: fn 12 -> String.duplicate(<<11>>, 12) end
             )

    content = content!(identity_attributes, encrypted, now)
    assert content.iri == content_iri
    content_graph = content_graph!(content)

    assert {:ok, store_command} =
             Knowledge.store_episode_content(
               content,
               command_attributes(fixture, content_graph, 0, now, "store-content"),
               clock: fn -> now end
             )

    assert_committed!(fixture, store_command)

    assert {:ok, metadata} =
             QueryRunner.graph_metadata(content_graph, server: fixture.query_runner)

    assert metadata.lifecycle_state == :closed
    assert metadata.completeness_state == :complete

    lifecycle_graph = lifecycle_graph!(fixture)
    active = transition!(content.iri, nil, :active, 0, nil, fixture, now)
    commit_lifecycle!(fixture, lifecycle_graph, active, now, "active")

    permit = permit!(fixture, content, now, "agent-context/main")
    commit_permit!(fixture, lifecycle_graph, permit, DateTime.add(now, 1, :second))

    context = access_context(permit, DateTime.add(now, 2, :second))
    consume = real_consumer(fixture, lifecycle_graph, DateTime.add(now, 2, :second))

    options = [
      consume_permit: consume,
      key_provider: InMemoryContentKeyProvider,
      key_server: keys,
      cipher_attributes: cipher_attributes,
      release: fn _bytes -> :ok end
    ]

    results =
      1..2
      |> Task.async_stream(
        fn _attempt -> Knowledge.release_content(permit, encrypted, context, options) end,
        max_concurrency: 2,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert [{:ok, ^plaintext, %ContentAccessOutcome{} = released}] =
             Enum.filter(results, &match?({:ok, _, _}, &1))

    assert released.status == :released
    assert released.byte_count == byte_size(plaintext)
    assert Enum.count(results, &match?({:error, %Error{kind: :conflict}, _}, &1)) == 1

    commit_outcome!(fixture, lifecycle_graph, permit, released, DateTime.add(now, 3, :second))

    assert {:error, %Error{kind: :conflict}, denied_replay} =
             Knowledge.release_content(permit, encrypted, context, options)

    assert denied_replay.status == :denied

    crash_permit = permit!(fixture, content, DateTime.add(now, 4, :second), "agent-context/crash")
    commit_permit!(fixture, lifecycle_graph, crash_permit, DateTime.add(now, 4, :second))

    crash_options = Keyword.put(options, :crash_after_consumption, true)

    assert {:error, %Error{kind: :persistence_failure}, ambiguous} =
             Knowledge.release_content(
               crash_permit,
               encrypted,
               access_context(crash_permit, DateTime.add(now, 5, :second)),
               Keyword.put(
                 crash_options,
                 :consume_permit,
                 real_consumer(fixture, lifecycle_graph, DateTime.add(now, 5, :second))
               )
             )

    assert ambiguous.status == :ambiguous

    commit_outcome!(
      fixture,
      lifecycle_graph,
      crash_permit,
      ambiguous,
      DateTime.add(now, 6, :second)
    )

    assert {:ok, audit} =
             query(fixture, :content_access_audit, %{
               graph: lifecycle_graph,
               resource: content.iri,
               instant: DateTime.add(now, 7, :second)
             })

    assert Enum.any?(audit.data, &(value(&1, "status") =~ "Released"))
    refute inspect(audit.data, limit: :infinity) =~ plaintext

    cold =
      transition!(
        content.iri,
        :active,
        :cold,
        1,
        active.iri,
        fixture,
        DateTime.add(now, 7, :second)
      )

    commit_lifecycle!(fixture, lifecycle_graph, cold, DateTime.add(now, 7, :second), "cold")

    hold = hold!(fixture, content, now)
    commit_hold!(fixture, lifecycle_graph, hold, DateTime.add(now, 8, :second))

    {:ok, reviewed} =
      Knowledge.review_content_hold(hold, %{
        approver_iri: hold.approver_iri,
        access_policy_iri: hold.access_policy_iri,
        release?: true,
        review_at: DateTime.add(now, 10, :hour),
        recorded_at: DateTime.add(now, 2, :hour)
      })

    commit_hold!(fixture, lifecycle_graph, reviewed, DateTime.add(now, 9, :second))

    {:ok, released_hold} =
      Knowledge.release_content_hold(reviewed, %{
        approver_iri: hold.approver_iri,
        access_policy_iri: hold.access_policy_iri,
        review_at: DateTime.add(now, 12, :hour),
        recorded_at: DateTime.add(now, 10, :hour)
      })

    commit_hold!(fixture, lifecycle_graph, released_hold, DateTime.add(now, 10, :second))

    active_again =
      transition!(
        content.iri,
        :cold,
        :active,
        2,
        cold.iri,
        fixture,
        DateTime.add(now, 11, :second)
      )

    commit_lifecycle!(
      fixture,
      lifecycle_graph,
      active_again,
      DateTime.add(now, 11, :second),
      "reactivate"
    )

    erase_requested =
      transition!(
        content.iri,
        :active,
        :erase_requested,
        3,
        active_again.iri,
        fixture,
        DateTime.add(now, 12, :second)
      )

    commit_lifecycle!(
      fixture,
      lifecycle_graph,
      erase_requested,
      DateTime.add(now, 12, :second),
      "erase-request"
    )

    plan = erasure_plan!(content, encrypted, erase_requested)
    assert hd(plan.actions).action == :block_retrieval
    assert :ok = InMemoryContentKeyProvider.destroy_key(keys, encrypted.key_reference_iri)

    crypto_erased =
      transition!(
        content.iri,
        :erase_requested,
        :crypto_erased,
        4,
        erase_requested.iri,
        fixture,
        DateTime.add(now, 13, :second)
      )

    commit_lifecycle!(
      fixture,
      lifecycle_graph,
      crypto_erased,
      DateTime.add(now, 13, :second),
      "crypto-erased"
    )

    commit_erasure!(fixture, lifecycle_graph, plan, DateTime.add(now, 14, :second))

    erased_permit =
      permit!(fixture, content, DateTime.add(now, 15, :second), "agent-context/erased")

    erased_context =
      erased_permit
      |> access_context(DateTime.add(now, 16, :second))
      |> Map.put(:lifecycle_state, :crypto_erased)

    assert {:error, %Error{kind: :unauthorized}, denied_erased} =
             Knowledge.release_content(
               erased_permit,
               encrypted,
               erased_context,
               Keyword.put(
                 options,
                 :consume_permit,
                 fn _permit -> flunk("erased content reached permit consumption") end
               )
             )

    assert denied_erased.status == :denied
    assert denied_erased.byte_count == 0

    assert {:error, %Error{kind: :unavailable}} =
             JidoCode.Knowledge.Memory.ContentCipher.decrypt(
               InMemoryContentKeyProvider,
               keys,
               encrypted,
               cipher_attributes
             )

    backup = backup_manifest!(content, encrypted, now)

    refute Knowledge.content_restore_allowed?(backup, %{
             erasure_generation: 9,
             content_iris: [content.iri],
             key_iris: [encrypted.key_reference_iri]
           })

    Phase04Fixture.kill_writer!(fixture)
    Phase04Fixture.restart_writer!(fixture)

    assert {:ok, lifecycle} =
             query(fixture, :content_lifecycle, %{
               graph: lifecycle_graph,
               resource: content.iri,
               instant: DateTime.add(now, 20, :second)
             })

    assert length(lifecycle.data) == 5
    assert value(List.last(lifecycle.data), "state") =~ "CryptoErased"
  end

  test "rejects secret and scope attacks and reproduces the signed benchmark branch", %{
    fixture: fixture,
    keys: keys
  } do
    safe_attributes = cipher_attributes()
    tenant = fixture.factory_scope

    for {seed, plaintext, additions} <- [
          {"canary", "prefix PHASE6-CANARY-SECRET suffix",
           %{secret_canaries: ["PHASE6-CANARY-SECRET"]}},
          {"entropy", "token=abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG", %{}},
          {"provider", "provider-private-internal-state",
           %{provider_private_markers: ["provider-private-internal-state"]}},
          {"reasoning", "private reasoning", %{hidden_reasoning?: true}}
        ] do
      attributes = Map.merge(safe_attributes, additions)

      assert {:error, %Error{kind: :unauthorized}} =
               Knowledge.encrypt_content(
                 InMemoryContentKeyProvider,
                 keys,
                 tenant,
                 resource(:episode_content, "hostile-#{seed}"),
                 plaintext,
                 attributes
               )
    end

    identity_attributes = identity_attributes(fixture, "adversarial")
    {:ok, content_iri} = EpisodeContent.identity(identity_attributes)

    {:ok, encrypted} =
      Knowledge.encrypt_content(
        InMemoryContentKeyProvider,
        keys,
        tenant,
        content_iri,
        "safe bounded payload",
        safe_attributes,
        random_bytes: fn 12 -> String.duplicate(<<12>>, 12) end
      )

    content = content!(identity_attributes, encrypted, fixture.issued_at)
    permit = permit!(fixture, content, fixture.issued_at, "agent-context/adversarial")
    base = access_context(permit, DateTime.add(fixture.issued_at, 1, :second))

    for changed <- [
          %{base | now: permit.expires_at},
          %{base | authorization_revoked?: true},
          %{base | byte_range: %{offset: 0, length: 1}},
          %{base | sink: :approved_export},
          %{base | destination: "wrong-destination"},
          %{base | agent_context: %{permit.agent_context | fence: permit.agent_context.fence + 1}}
        ] do
      assert {:error, %Error{kind: :unauthorized}, denied} =
               Knowledge.release_content(permit, encrypted, changed,
                 consume_permit: fn _permit -> flunk("denied access reached consumption") end,
                 key_provider: InMemoryContentKeyProvider,
                 key_server: keys,
                 cipher_attributes: safe_attributes
               )

      assert denied.status == :denied
    end

    assert Guardrails.benchmark_corpus_digest() ==
             "6a63d96c7f60d84c8ca195a2b77c2f4afdce8301a7285402dccf9666b1aea13a"

    assert Enum.reduce(Guardrails.benchmark_corpus(), 0, fn item, total ->
             total + item.plaintext_bytes * item.objects
           end) == 25_395_200

    signer = fn material -> :crypto.mac(:hmac, :sha256, benchmark_key(), material) end
    verifier = fn material, signature -> :crypto.hash_equals(signer.(material), signature) end

    assert {:ok, decision} = Knowledge.decide_content_storage(benchmark_metrics(), signer)
    assert {:ok, posture} = Knowledge.accept_content_storage(decision, verifier)
    assert posture.branch == :graph_native
    refute posture.vault_authorized?
    assert ContentStorageDecision.revision() == "1.0.0"
  end

  defp identity_attributes(fixture, seed),
    do: %{
      repository_iri: fixture.repository,
      source_event_iri: fixture.memory_event.iri,
      content_identity: digest("opaque-content-#{seed}"),
      segment_index: 0
    }

  defp content!(identity, encrypted, now) do
    attributes =
      Map.merge(identity, %{
        policy_revision: DataPolicy.revision(),
        classification: :encrypted_content,
        media_type: "application/octet-stream",
        representation: :ciphertext,
        key_reference_iri: encrypted.key_reference_iri,
        key_generation: encrypted.key_generation,
        encryption_algorithm: encrypted.algorithm,
        nonce: encrypted.nonce,
        authentication_tag: encrypted.authentication_tag,
        aad_digest: encrypted.aad_digest,
        ciphertext_chunks: encrypted.ciphertext_chunks,
        ciphertext_digest: encrypted.ciphertext_digest,
        closed_at: now,
        encrypted_before_command?: true
      })

    {:ok, content} = Knowledge.episode_content(attributes)
    content
  end

  defp permit!(fixture, content, issued_at, destination) do
    {:ok, permit} =
      Knowledge.content_access_permit(%{
        actor_iri: fixture.actor,
        purpose: :managed_continuity,
        task_iri: resource(:task_proposal, "phase-06-content-task"),
        scope_iri: fixture.repository_scope,
        authorization_iri: resource(:authorization_grant, "phase-06-content-authorization"),
        authorization_revision: 1,
        reviewed_query: :content_lifecycle,
        query_version: QueryCatalog.content_version(),
        parameters: %{content_iri: content.iri},
        content_iri: content.iri,
        content_version: content.revision,
        representation: :exact_binary,
        byte_range: %{offset: 0, length: content.byte_count},
        sink: :agent_context,
        destination: destination,
        method: :read,
        issued_at: issued_at,
        expires_at: DateTime.add(issued_at, 120, :second),
        data_ceiling: :encrypted_content,
        agent_context: %{
          attempt_iri: fixture.memory_attempt,
          lease_iri: resource(:execution_lease, "phase-06-content-lease"),
          fence: 4,
          context_iri: resource(:execution_context, "phase-06-content-context"),
          invocation_iri: resource(:model_invocation, "phase-06-content-invocation"),
          model_access_profile_iri:
            resource(:model_access_profile, "phase-06-content-model-profile")
        }
      })

    permit
  end

  defp access_context(permit, now),
    do: %{
      permit_consumed?: false,
      authorization_decision: :allowed,
      authorization_iri: permit.authorization_iri,
      authorization_revision: permit.authorization_revision,
      authorization_revoked?: false,
      actor_iri: permit.actor_iri,
      scope_iri: permit.scope_iri,
      purpose: permit.purpose,
      content_iri: permit.content_iri,
      content_version: permit.content_version,
      representation: permit.representation,
      byte_range: permit.byte_range,
      sink: permit.sink,
      destination: permit.destination,
      method: permit.method,
      data_ceiling: permit.data_ceiling,
      lifecycle_state: :active,
      hold_access_allowed?: true,
      maximum_release_bytes: 131_072,
      agent_context: permit.agent_context,
      now: now
    }

  defp real_consumer(fixture, lifecycle_graph, recorded_at) do
    fn permit ->
      revision = graph_revision!(fixture, lifecycle_graph)

      with {:ok, command} <-
             Knowledge.consume_content_access(
               permit,
               fixture.repository,
               revision,
               command_attributes(
                 fixture,
                 lifecycle_graph,
                 revision,
                 recorded_at,
                 "consume-#{permit.iri}"
               ),
               clock: fn -> recorded_at end
             ),
           {:ok, receipt} <- Writer.execute(fixture.writer, command),
           :committed <- receipt.outcome do
        :ok
      else
        {:ok, %{outcome: :already_committed}} ->
          {:error, Error.new(:conflict, :content_permit_consumed)}

        {:ok, _receipt} ->
          {:error, Error.new(:conflict, :content_permit_consumed)}

        {:error, %Error{} = error} ->
          {:error, error}

        _failure ->
          {:error, Error.new(:conflict, :content_permit_consumed)}
      end
    end
  end

  defp transition!(content, prior, next, revision, predecessor, fixture, recorded_at) do
    {:ok, transition} =
      Knowledge.content_lifecycle_transition(%{
        content_iri: content,
        prior_state: prior,
        next_state: next,
        revision: revision,
        expected_predecessor: predecessor,
        actor_iri: fixture.actor,
        cause_iri: fixture.enrollment_envelope.command_iri,
        reason: "phase 6 #{next} lifecycle transition",
        recorded_at: recorded_at
      })

    transition
  end

  defp commit_lifecycle!(fixture, graph, transition, recorded_at, seed) do
    revision = graph_revision_or_zero(fixture, graph)

    assert {:ok, command} =
             Knowledge.transition_content_lifecycle(
               transition,
               fixture.repository,
               revision,
               command_attributes(fixture, graph, revision, recorded_at, seed),
               clock: fn -> recorded_at end
             )

    assert_committed!(fixture, command)
  end

  defp commit_permit!(fixture, graph, permit, recorded_at) do
    revision = graph_revision!(fixture, graph)

    assert {:ok, command} =
             Knowledge.authorize_content_access(
               permit,
               fixture.repository,
               revision,
               command_attributes(
                 fixture,
                 graph,
                 revision,
                 recorded_at,
                 "authorize-#{permit.iri}"
               ),
               clock: fn -> recorded_at end
             )

    assert_committed!(fixture, command)
  end

  defp commit_outcome!(fixture, graph, permit, outcome, recorded_at) do
    revision = graph_revision!(fixture, graph)

    assert {:ok, command} =
             Knowledge.record_content_access_outcome(
               permit,
               outcome,
               fixture.repository,
               revision,
               command_attributes(
                 fixture,
                 graph,
                 revision,
                 recorded_at,
                 "outcome-#{outcome.iri}"
               ),
               clock: fn -> recorded_at end
             )

    assert_committed!(fixture, command)
  end

  defp hold!(fixture, content, now) do
    {:ok, hold} =
      Knowledge.place_content_hold(%{
        case_iri: resource(:experience_case, "phase-06-incident-case"),
        owner_iri: fixture.actor,
        approver_iri: resource(:authorization_grant, "phase-06-hold-approver"),
        scope_iri: fixture.repository_scope,
        purpose: "preserve exact incident evidence",
        affected_content_iris: [content.iri],
        access_policy_iri: resource(:policy_version, "phase-06-hold-policy"),
        review_at: DateTime.add(now, 2, :hour),
        recorded_at: now
      })

    hold
  end

  defp commit_hold!(fixture, graph, hold, recorded_at) do
    revision = graph_revision!(fixture, graph)

    assert {:ok, command} =
             Knowledge.record_content_hold(
               hold,
               fixture.repository,
               revision,
               command_attributes(fixture, graph, revision, recorded_at, "hold-#{hold.iri}"),
               clock: fn -> recorded_at end
             )

    assert_committed!(fixture, command)
  end

  defp erasure_plan!(content, encrypted, erase_requested) do
    provider = resource(:provider_object, "phase-06-provider-object")

    inventory =
      Map.new(ContentErasurePlan.categories(), fn category ->
        resources =
          case category do
            :bodies -> Enum.map(content.chunks, & &1.iri)
            :backup_keys -> [encrypted.key_reference_iri]
            :provider_objects -> [provider]
            _category -> [resource(:derivative_cleanup, "phase-06-#{category}")]
          end

        {category, resources}
      end)

    {:ok, plan} =
      Knowledge.plan_content_erasure(%{
        request_iri: erase_requested.iri,
        content_iri: content.iri,
        key_reference_iri: encrypted.key_reference_iri,
        erasure_generation: 10,
        retrieval_blocked?: true,
        active_holds: [],
        inventory: inventory,
        external_results: %{provider => :unverifiable}
      })

    plan
  end

  defp commit_erasure!(fixture, graph, plan, recorded_at) do
    revision = graph_revision!(fixture, graph)

    assert {:ok, command} =
             Knowledge.record_content_erasure(
               plan,
               fixture.repository,
               revision,
               command_attributes(fixture, graph, revision, recorded_at, "erasure-plan"),
               clock: fn -> recorded_at end
             )

    assert_committed!(fixture, command)
  end

  defp backup_manifest!(content, encrypted, now) do
    {:ok, manifest} =
      Knowledge.content_backup_manifest(%{
        backup_iri: resource(:content_backup_manifest, "phase-06-backup"),
        erasure_generation: 10,
        excluded_content_iris: [content.iri],
        excluded_key_iris: [encrypted.key_reference_iri],
        created_at: now
      })

    manifest
  end

  defp assert_committed!(fixture, command) do
    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed
  end

  defp content_graph!(content) do
    {:ok, graph} =
      GraphRegistry.graph_iri(:episode_content, %{
        repository: content.repository_iri,
        content: content.iri
      })

    graph
  end

  defp lifecycle_graph!(fixture) do
    {:ok, graph} =
      GraphRegistry.graph_iri(:content_lifecycle, %{repository: fixture.repository})

    graph
  end

  defp graph_revision_or_zero(fixture, graph) do
    case QueryRunner.graph_metadata(graph, server: fixture.query_runner) do
      {:ok, nil} -> 0
      {:ok, metadata} -> metadata.graph_revision
    end
  end

  defp graph_revision!(fixture, graph) do
    {:ok, metadata} = QueryRunner.graph_metadata(graph, server: fixture.query_runner)
    metadata.graph_revision
  end

  defp command_attributes(fixture, graph, revision, recorded_at, seed),
    do: %{
      repository_scope_iri: fixture.repository_scope,
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      delegated_agent_iri: nil,
      delegation_iri: nil,
      correlation_iri: resource(:command_request, "phase-06-#{seed}-correlation"),
      causation_iri: fixture.enrollment_envelope.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: %{graph => revision},
      recorded_at: recorded_at,
      reason: "phase 6 #{seed} integration"
    }

  defp query(fixture, name, parameters),
    do:
      Knowledge.query(
        name,
        QueryCatalog.content_version(),
        parameters,
        fixture.authority,
        fixture.repository_scope,
        server: fixture.query_runner,
        evaluated_at: parameters.instant
      )

  defp value(row, key) do
    case row[key] || row[String.to_atom(key)] do
      %{value: value} -> value
      nil -> ""
      value -> to_string(value)
    end
  end

  defp cipher_attributes,
    do: %{
      classification: :encrypted_content,
      media_type: "application/octet-stream",
      policy_revision: DataPolicy.revision(),
      provider_private_state?: false,
      hidden_reasoning?: false,
      secret_canaries: [],
      provider_private_markers: []
    }

  defp benchmark_metrics,
    do: %{
      capture_latency_ratio: 1.5,
      query_latency_ratio: 1.75,
      backup_latency_ratio: 1.25,
      restore_latency_ratio: 1.4,
      rebuild_latency_ratio: 1.9,
      storage_amplification_ratio: 3.5,
      integrity_failures: 0,
      orphaned_objects: 0,
      unerased_objects: 0
    }

  defp benchmark_key, do: "phase-6-integration-benchmark-key"

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
