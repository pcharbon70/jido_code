defmodule JidoCode.Knowledge.ManagedCodingPhase01IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.ManagedCoding.Recovery
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Runtime.ExecutionAgent
  alias JidoCode.Runtime.JidoInstance
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07SchedulingFixture
  alias JidoCode.TestSupport.Phase08AttemptFixture

  @digest_b String.duplicate("b", 64)

  test "runs exact profile and attempt contracts through an isolated graph dataset", context do
    fixture = Phase07SchedulingFixture.leased!(context)
    access = enroll_model_access!(fixture)
    profile = managed_profile!(fixture, access, "primary")

    {fixture, registration, resolution} = register_profile!(fixture, profile)
    assert registration.outcome == :committed

    assert {:ok, replay} = Writer.execute(fixture.writer, registration.command)
    assert replay.outcome == :already_committed

    {fixture, resolution} = transition_profile!(fixture, profile, resolution, :enabled)
    assert resolution.current_state == :enabled

    assert {:ok, stale_command} =
             Knowledge.transition_managed_coding_profile(
               profile,
               resolution,
               :disabled,
               policy_attributes(fixture, expected_policy_revision: 1),
               clock: clock(fixture)
             )

    assert {:ok, %{outcome: :conflicted}} = Writer.execute(fixture.writer, stale_command)

    context_map =
      fixture
      |> Phase08AttemptFixture.execution_context!()
      |> Map.merge(%{
        managed_coding_profile_iri: profile.iri,
        coding_strategy_revision: profile.strategy_revision,
        reconstruction_watermark: digest("watermark-start")
      })

    attempt = Phase08AttemptFixture.attempt!(fixture, context_map)
    start = Phase08AttemptFixture.start!(fixture, attempt, context_map)

    assert {:ok, start_receipt} = Writer.execute(fixture.writer, start.command)
    assert start_receipt.outcome == :committed
    assert {:ok, %{outcome: :already_committed}} = Writer.execute(fixture.writer, start.command)

    assert attempt.managed_coding_profile_iri == profile.iri
    assert attempt.coding_strategy_revision == profile.strategy_revision
    assert attempt.reconstruction_watermark == digest("watermark-start")
    refute inspect(attempt) =~ "provider_session"
    refute inspect(attempt) =~ "agent_state"

    {:ok, attempt_resolution} = Transition.resolve(start.attempt_transitions)

    {:ok, lease_resolution} =
      Transition.resolve(fixture.lease_transitions ++ [start.lease_transition])

    {:ok, task_resolution} =
      Transition.resolve(fixture.schedulable_task_transitions ++ [start.task_transition])

    attempt_fixture =
      Map.merge(fixture, %{
        execution_context: context_map,
        attempt: attempt,
        attempt_start: start,
        attempt_start_receipt: start_receipt,
        attempt_transitions: start.attempt_transitions,
        attempt_resolution: attempt_resolution,
        lease_transitions: fixture.lease_transitions ++ [start.lease_transition],
        lease_resolution: lease_resolution,
        schedulable_task_transitions:
          fixture.schedulable_task_transitions ++ [start.task_transition],
        schedulable_task_resolution: task_resolution
      })
      |> Phase08AttemptFixture.transition!(:running, 921, %{
        runtime_event: runtime_event(attempt, 1, :pending)
      })
      |> Phase08AttemptFixture.transition!(:completed, 922, %{
        runtime_event: runtime_event(attempt, 2, :success)
      })

    assert attempt_fixture.attempt_resolution.current_state == :completed
    assert attempt_fixture.attempt_transition_receipt.outcome == :committed

    {fixture, resolution} = transition_profile!(attempt_fixture, profile, resolution, :revoked)
    assert resolution.current_state == :revoked

    superseded = managed_profile!(fixture, access, "superseded")
    {fixture, _registration, superseded_resolution} = register_profile!(fixture, superseded)

    {fixture, superseded_resolution} =
      transition_profile!(fixture, superseded, superseded_resolution, :enabled)

    {_fixture, superseded_resolution} =
      transition_profile!(fixture, superseded, superseded_resolution, :superseded)

    assert superseded_resolution.current_state == :superseded
  end

  test "runtime loss in each non-effecting phase has one graph-derived classification" do
    profile_iri = Phase04Fixture.resource!("managed-coding-recovery-profile")
    strategy = digest("recovery-strategy")
    watermark = digest("recovery-watermark")
    baseline = %{profile_iri: profile_iri, strategy_revision: strategy}

    for {phase, expected} <- [
          admitted: :restart_from_admission,
          preparing: :rebuild_context,
          assembling_candidate: :rebuild_candidate,
          candidate_ready: :handoff_candidate
        ] do
      id = "managed-recovery-#{phase}-#{System.unique_integer([:positive])}"

      assert {:ok, pid} =
               JidoInstance.start_agent(ExecutionAgent,
                 id: id,
                 state: %{
                   attempt_iri: Phase04Fixture.resource!("attempt-#{id}"),
                   fencing_token: 1
                 }
               )

      assert :ok = JidoInstance.stop_agent(pid)
      refute Process.alive?(pid)

      projection = %{
        attempt_iri: Phase04Fixture.resource!("attempt-#{phase}"),
        profile_iri: profile_iri,
        strategy_revision: strategy,
        reconstruction_watermark: watermark,
        phase: phase
      }

      assert {:ok, ^expected} = Recovery.classify(projection, baseline)
      assert {:ok, ^expected} = Recovery.classify(projection, baseline)
    end

    incompatible = %{
      attempt_iri: Phase04Fixture.resource!("attempt-incompatible"),
      profile_iri: profile_iri,
      strategy_revision: @digest_b,
      reconstruction_watermark: watermark,
      phase: :preparing
    }

    assert {:ok, {:supersede, :incompatible_strategy}} =
             Recovery.classify(incompatible, baseline)
  end

  defp enroll_model_access!(fixture) do
    {:ok, access} =
      Knowledge.model_access_profile(%{
        owner_iri: fixture.actor,
        scope_iri: fixture.factory_scope,
        access_mode: :host_api,
        credential_reference_iri: Phase04Fixture.local!(:activity, 1_601),
        credential_class: :short_lived_bearer,
        billing_mode: :metered_api,
        provider: "deterministic-fixture",
        model: "managed-coding-phase-01",
        endpoint: "https://api.example.test/v1",
        readiness: [:installed, :credential_available, :policy_allowed],
        revocation_generation: 1
      })

    {:ok, command} =
      Knowledge.enroll_model_access_profile(access, policy_attributes(fixture),
        clock: clock(fixture)
      )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, command)
    access
  end

  defp managed_profile!(fixture, access, seed) do
    {:ok, profile} =
      Knowledge.managed_coding_profile(%{
        iri: resource(:harness_profile, "managed-profile-#{seed}"),
        revision: 1,
        profile_digest: digest("profile-#{seed}"),
        jido_version: "2.3.2",
        strategy_revision: digest("strategy-#{seed}"),
        prompt_bundle_revision: digest("prompt-#{seed}"),
        model_access_profile_iri: access.iri,
        context_policy_revision: digest("context-#{seed}"),
        memory_policy_revision: digest("memory-#{seed}"),
        tool_catalog_revision: digest("tools-#{seed}"),
        adapter_set_revision: digest("adapters-#{seed}"),
        sandbox_profile_revision: digest("sandbox-#{seed}"),
        verifier_profile_revision: digest("verifier-#{seed}"),
        candidate_schema_revision: digest("candidate-#{seed}"),
        budget_contract: %{turns: %{limit: 20, enforcement: "hard"}},
        task_classes: ["focused_change"],
        actor_iris: [fixture.actor],
        tenant_iris: [fixture.factory_scope],
        repository_iris: [fixture.repository],
        capability_iris: [fixture.capability]
      })

    profile
  end

  defp register_profile!(fixture, profile) do
    {:ok, command} =
      Knowledge.register_managed_coding_profile(profile, policy_attributes(fixture),
        clock: clock(fixture)
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)
    resolution = resolution!(profile, [:disabled])
    {fixture, Map.put(receipt, :command, command), resolution}
  end

  defp transition_profile!(fixture, profile, resolution, next_state) do
    {:ok, command} =
      Knowledge.transition_managed_coding_profile(
        profile,
        resolution,
        next_state,
        policy_attributes(fixture),
        clock: clock(fixture)
      )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, command)
    transitions = resolution.transitions ++ [transition_from_command(command)]
    {fixture, resolution!(profile, transitions)}
  end

  defp resolution!(profile, states) when is_list(states) and is_atom(hd(states)) do
    transitions =
      states
      |> Enum.with_index()
      |> Enum.map(fn {state, revision} ->
        transition = transition_iri(profile, revision, state)

        %{
          transition_iri: transition,
          state: state,
          revision: revision,
          predecessor_iri:
            if(revision == 0,
              do: nil,
              else: transition_iri(profile, revision - 1, Enum.at(states, revision - 1))
            )
        }
      end)

    resolution!(profile, transitions)
  end

  defp resolution!(_profile, transitions) do
    current = List.last(transitions)

    %{
      domain: :managed_coding_profile,
      current_state: current.state,
      current_revision: current.revision,
      current_transition: current.transition_iri,
      transitions: transitions
    }
  end

  defp transition_from_command(command) do
    change = List.first(command.payload.changes)

    transition_iri =
      change.additions
      |> Enum.map(&RDF.Triple.new/1)
      |> Enum.find_value(fn {subject, predicate, _object} ->
        if to_string(predicate) == "https://jido.run/ontology/factory#transitionSubject" do
          to_string(subject)
        end
      end)

    state =
      change.additions
      |> Enum.map(&RDF.Triple.new/1)
      |> Enum.find_value(fn {subject, predicate, object} ->
        if to_string(subject) == transition_iri and
             to_string(predicate) == "https://jido.run/ontology/factory#nextState" do
          object |> to_string() |> String.split("ManagedCodingProfile") |> List.last()
        end
      end)
      |> Macro.underscore()
      |> String.to_existing_atom()

    revision =
      change.additions
      |> Enum.map(&RDF.Triple.new/1)
      |> Enum.find_value(fn {subject, predicate, object} ->
        if to_string(subject) == transition_iri and
             to_string(predicate) == "https://jido.run/ontology/factory#subjectRevision" do
          RDF.Literal.value(object)
        end
      end)

    predecessor =
      change.additions
      |> Enum.map(&RDF.Triple.new/1)
      |> Enum.find_value(fn {subject, predicate, object} ->
        if to_string(subject) == transition_iri and
             to_string(predicate) == "https://jido.run/ontology/factory#expectedPredecessor" do
          to_string(object)
        end
      end)

    %{
      transition_iri: transition_iri,
      state: state,
      revision: revision,
      predecessor_iri: predecessor
    }
  end

  defp policy_attributes(fixture, overrides \\ []) do
    attributes = %{
      policy_graph_iri: fixture.graphs.policy,
      expected_policy_revision:
        Phase07SchedulingFixture.graph_revision!(fixture, fixture.graphs.policy),
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      scope_iri: fixture.factory_scope,
      correlation_iri: Phase04Fixture.local!(:activity, System.unique_integer([:positive])),
      causation_iri: fixture.bootstrap_command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      reason: "managed coding phase 1 integration",
      recorded_at: fixture.issued_at
    }

    Map.merge(attributes, Map.new(overrides))
  end

  defp runtime_event(attempt, sequence, outcome) do
    %{
      attempt_iri: attempt.iri,
      sequence: sequence,
      outcome_class: outcome,
      usage: %{turns: sequence}
    }
  end

  defp transition_iri(profile, revision, state) do
    resource(
      :control_transition,
      Enum.join([profile.iri, "managed_coding_profile", revision, state], "\n")
    )
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp clock(fixture), do: fn -> fixture.issued_at end
end
