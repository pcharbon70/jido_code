defmodule JidoCode.Knowledge.Memory.Phase06ContentLifecycleTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ContentErasurePlan
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-21 19:00:00Z]

  test "resolves append-only availability and erasure paths without rewriting content" do
    content = resource(:episode_content, "lifecycle-content")
    actor = resource(:authorization_grant, "lifecycle-actor")
    cause = resource(:authorization_grant, "lifecycle-cause")

    {:ok, active} = transition(content, nil, :active, 0, nil, actor, cause)
    {:ok, cold} = transition(content, :active, :cold, 1, active.iri, actor, cause)

    {:ok, requested} =
      transition(content, :cold, :erase_requested, 2, cold.iri, actor, cause)

    {:ok, crypto} =
      transition(content, :erase_requested, :crypto_erased, 3, requested.iri, actor, cause)

    {:ok, deleted} =
      transition(content, :crypto_erased, :physically_deleted, 4, crypto.iri, actor, cause)

    assert {:ok, endpoint} =
             Knowledge.resolve_content_lifecycle([deleted, active, requested, cold, crypto])

    assert endpoint.state == :physically_deleted

    for state <- [:externally_attested, :externally_unverifiable] do
      assert {:ok, terminal} =
               transition(content, :erase_requested, state, 3, requested.iri, actor, cause)

      assert terminal.next_state == state

      assert {:error, %{kind: :invalid_input}} =
               transition(content, state, :active, 4, terminal.iri, actor, cause)
    end

    assert {:error, %{kind: :corrupt}} =
             Knowledge.resolve_content_lifecycle([active, requested])
  end

  test "places, reviews, and releases case-specific holds through distinct approval" do
    attributes = %{
      case_iri: resource(:experience_case, "hold-case"),
      owner_iri: resource(:authorization_grant, "hold-owner"),
      approver_iri: resource(:authorization_grant, "hold-approver"),
      scope_iri: resource(:execution_context, "hold-scope"),
      purpose: "preserve incident evidence during investigation",
      affected_content_iris: [resource(:episode_content, "hold-content")],
      access_policy_iri: resource(:policy_version, "hold-policy"),
      review_at: DateTime.add(@now, 3_600, :second),
      recorded_at: @now
    }

    assert {:ok, hold} = Knowledge.place_content_hold(attributes)
    assert hold.state == :held

    assert {:ok, reviewed} =
             Knowledge.review_content_hold(hold, %{
               approver_iri: attributes.approver_iri,
               access_policy_iri: attributes.access_policy_iri,
               release?: true,
               review_at: DateTime.add(@now, 7_200, :second),
               recorded_at: DateTime.add(@now, 3_600, :second)
             })

    assert reviewed.state == :release_pending

    assert {:ok, released} =
             Knowledge.release_content_hold(reviewed, %{
               approver_iri: attributes.approver_iri,
               access_policy_iri: attributes.access_policy_iri,
               review_at: DateTime.add(@now, 10_800, :second),
               recorded_at: DateTime.add(@now, 7_200, :second)
             })

    assert released.state == :released

    assert {:error, %{kind: :invalid_input}} =
             attributes
             |> Map.put(:approver_iri, attributes.owner_iri)
             |> Knowledge.place_content_hold()
  end

  test "blocks retrieval first and inventories every derivative before classified erasure" do
    attributes = erasure_attributes()
    assert {:ok, plan} = Knowledge.plan_content_erasure(attributes)
    assert plan.retrieval_blocked?
    assert Enum.map(plan.actions, & &1.order) == [1, 2, 3, 4, 5, 6]
    assert hd(plan.actions).action == :block_retrieval
    assert plan.terminal_state == :externally_unverifiable

    assert Map.keys(plan.inventory) |> Enum.sort() ==
             ContentErasurePlan.categories() |> Enum.sort()

    assert {:error, %{kind: :conflict}} =
             attributes |> Map.put(:retrieval_blocked?, false) |> Knowledge.plan_content_erasure()

    assert {:error, %{kind: :conflict}} =
             attributes
             |> Map.put(:inventory, Map.delete(attributes.inventory, :exports))
             |> Knowledge.plan_content_erasure()

    assert {:error, %{kind: :conflict}} =
             attributes
             |> Map.put(:active_holds, [resource(:content_hold, "active-hold")])
             |> Knowledge.plan_content_erasure()
  end

  test "restore floors prevent erased ciphertext and keys from resurrection" do
    content = resource(:episode_content, "erased-content")
    key = resource(:content_key_reference, "erased-key")

    assert {:ok, manifest} =
             Knowledge.content_backup_manifest(%{
               backup_iri: resource(:content_backup_manifest, "backup-1"),
               erasure_generation: 12,
               excluded_content_iris: [content],
               excluded_key_iris: [key],
               created_at: @now
             })

    assert Knowledge.content_restore_allowed?(manifest, %{
             erasure_generation: 12,
             content_iris: [resource(:episode_content, "safe-content")],
             key_iris: []
           })

    refute Knowledge.content_restore_allowed?(manifest, %{
             erasure_generation: 11,
             content_iris: [],
             key_iris: []
           })

    refute Knowledge.content_restore_allowed?(manifest, %{
             erasure_generation: 12,
             content_iris: [content],
             key_iris: []
           })

    refute Knowledge.content_restore_allowed?(manifest, %{
             erasure_generation: 13,
             content_iris: [],
             key_iris: [key]
           })
  end

  test "rebuilds or invalidates every projection with erased lineage" do
    erased = resource(:episode_content, "projection-erased")
    safe = resource(:episode_content, "projection-safe")

    assert {:ok, cleanup} =
             Knowledge.plan_content_derivative_cleanup([erased], [
               %{
                 iri: resource(:derivative_cleanup, "rebuildable"),
                 lineage_content_iris: [erased, safe],
                 rebuildable?: true
               },
               %{
                 iri: resource(:derivative_cleanup, "invalidated"),
                 lineage_content_iris: [erased],
                 rebuildable?: false
               },
               %{
                 iri: resource(:derivative_cleanup, "unaffected"),
                 lineage_content_iris: [safe],
                 rebuildable?: true
               }
             ])

    assert cleanup.complete?
    assert Enum.map(cleanup.actions, & &1.action) |> Enum.sort() == [:invalidate, :rebuild]
    assert Enum.all?(cleanup.actions, &(erased in &1.erased_lineage))
  end

  test "publishes lifecycle, hold, and erasure commands without mutating payload graphs" do
    repository = resource(:repository_snapshot, "lifecycle-repository")
    content = resource(:episode_content, "command-content")
    actor = resource(:authorization_grant, "command-actor")
    cause = resource(:authorization_grant, "command-cause")
    {:ok, active} = transition(content, nil, :active, 0, nil, actor, cause)

    assert {:ok, lifecycle} =
             Knowledge.transition_content_lifecycle(
               active,
               repository,
               0,
               command_attributes(repository, 0),
               clock: fn -> @now end
             )

    assert lifecycle.command_type == "TransitionContentLifecycle"
    assert hd(lifecycle.payload.changes).family == :content_lifecycle

    {:ok, hold} =
      Knowledge.place_content_hold(%{
        case_iri: resource(:experience_case, "command-hold-case"),
        owner_iri: actor,
        approver_iri: resource(:authorization_grant, "command-approver"),
        scope_iri: resource(:execution_context, "command-hold-scope"),
        purpose: "incident hold",
        affected_content_iris: [content],
        access_policy_iri: resource(:policy_version, "command-hold-policy"),
        review_at: DateTime.add(@now, 3_600, :second),
        recorded_at: @now
      })

    assert {:ok, hold_command} =
             Knowledge.record_content_hold(
               hold,
               repository,
               1,
               command_attributes(repository, 1),
               clock: fn -> @now end
             )

    assert hold_command.command_type == "PlaceContentHold"

    {:ok, plan} = Knowledge.plan_content_erasure(erasure_attributes())

    assert {:ok, erasure} =
             Knowledge.record_content_erasure(
               plan,
               repository,
               2,
               command_attributes(repository, 2),
               clock: fn -> @now end
             )

    assert erasure.command_type == "RecordContentErasure"

    for command <- [lifecycle, hold_command, erasure] do
      assert command.command_version == CommandRegistry.content_version()
      assert Enum.all?(command.payload.changes, &(&1.family == :content_lifecycle))
    end
  end

  test "publishes bounded lifecycle, hold, and byte-free access audit queries" do
    for name <- [:content_lifecycle, :content_holds, :content_access_audit] do
      assert {:ok, query} = QueryCatalog.fetch(name, QueryCatalog.content_version())
      assert query.graph_families == [:content_lifecycle]
      assert String.contains?(query.source, "{{instant}}")
      refute String.contains?(query.source, "ciphertext>")
    end
  end

  defp transition(content, prior, next, revision, predecessor, actor, cause) do
    Knowledge.content_lifecycle_transition(%{
      content_iri: content,
      prior_state: prior,
      next_state: next,
      revision: revision,
      expected_predecessor: predecessor,
      actor_iri: actor,
      cause_iri: cause,
      reason: "record #{next} content state",
      recorded_at: DateTime.add(@now, revision, :second)
    })
  end

  defp erasure_attributes do
    provider = resource(:provider_object, "erasure-provider-object")

    inventory =
      Map.new(ContentErasurePlan.categories(), fn category ->
        values =
          case category do
            :provider_objects -> [provider]
            :bodies -> [resource(:content_body, "erasure-body")]
            :backup_keys -> [resource(:content_key_reference, "erasure-backup-key")]
            _other -> [resource(:derivative_cleanup, "erasure-#{category}")]
          end

        {category, values}
      end)

    %{
      request_iri: resource(:content_lifecycle_transition, "erase-request"),
      content_iri: resource(:episode_content, "erasure-content"),
      key_reference_iri: resource(:content_key_reference, "erasure-key"),
      erasure_generation: 12,
      retrieval_blocked?: true,
      active_holds: [],
      inventory: inventory,
      external_results: %{provider => :unverifiable}
    }
  end

  defp command_attributes(repository, revision) do
    {:ok, graph} = GraphRegistry.graph_iri(:content_lifecycle, %{repository: repository})

    %{
      repository_scope_iri: resource(:execution_context, "lifecycle-command-scope"),
      principal_iri: resource(:authorization_grant, "lifecycle-command-principal"),
      actor_iri: resource(:authorization_grant, "lifecycle-command-actor"),
      delegated_agent_iri: nil,
      delegation_iri: nil,
      correlation_iri: resource(:command_request, "lifecycle-correlation-#{revision}"),
      causation_iri: resource(:authorization_grant, "lifecycle-command-cause"),
      expected_dataset_revision: revision + 1,
      expected_graph_revisions: %{graph => revision},
      recorded_at: @now,
      reason: "record content lifecycle evidence"
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end
