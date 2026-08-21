defmodule JidoCode.Knowledge.Memory.Phase04IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ExperienceCase
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase03RetrievalFixture
  alias JidoCode.TestSupport.Phase04Fixture

  setup context do
    %{fixture: Phase03RetrievalFixture.complete!(context)}
  end

  test "persists, replays, retrieves, races, restarts, and rebuilds governed cases", %{
    fixture: fixture
  } do
    now = fixture.issued_at

    assert {:ok, built} =
             Knowledge.construct_experience_case(run(fixture), evidence(fixture), %{
               effective_at: now
             })

    experience = built.case

    assert {:ok, summary} =
             Knowledge.experience_candidate_summary(experience.iri, built.manifest, %{
               author_iri: resource(:authorization_grant, "phase-04-summary-author"),
               summary: "The reviewed executor rejected unsupported graph-local algebra.",
               claims: ["reviewed executor rejected unsupported graph-local algebra"],
               related_iris: [fixture.repository],
               triggers: ["unsupported-graph-algebra"],
               recorded_at: now
             })

    context = %{
      repository_iri: fixture.repository,
      repository_scope_iri: fixture.repository_scope,
      effective_at: now,
      supported_claims: ["reviewed executor rejected unsupported graph-local algebra"],
      allowed_related_iris: [fixture.repository],
      evaluator_iri: resource(:authorization_grant, "phase-04-quarantine-evaluator")
    }

    assert {:ok, report} =
             Knowledge.quarantine_experience_case(experience, summary, built.manifest, context)

    proposal_attributes = command_attributes(fixture, experience, 0, "proposal")

    assert {:ok, proposal} =
             Knowledge.propose_experience_case(
               experience,
               built.manifest,
               summary,
               report,
               proposal_attributes,
               clock: fn -> now end
             )

    assert {:ok, first_receipt} = Writer.execute(fixture.writer, proposal)
    assert first_receipt.outcome == :committed
    assert {:ok, replay_receipt} = Writer.execute(fixture.writer, proposal)
    assert replay_receipt.outcome == :already_committed
    assert replay_receipt.command_iri == first_receipt.command_iri

    validation = %{
      validator_iri: resource(:authorization_grant, "phase-04-independent-validator"),
      evidence_iri: fixture.evidence_resource,
      source_manifest_digest: built.manifest.digest,
      expected_graph_revisions: built.manifest.source_graph_revisions,
      recorded_at: DateTime.add(now, 1, :second)
    }

    assert {:ok, validated} =
             Knowledge.validate_experience_case(
               experience,
               summary,
               built.manifest,
               report,
               validation
             )

    assert {:ok, validation_command} =
             Knowledge.transition_experience_case(
               experience,
               validated.transition,
               command_attributes(fixture, experience, 1, "validation"),
               clock: fn -> DateTime.add(now, 1, :second) end
             )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, validation_command)

    assert {:ok, lifecycle} = query(fixture, :experience_case_lifecycle, experience, now, 2)

    assert Enum.map(lifecycle.data, &iri_label(value(&1, "state"))) == [
             "ExperienceCandidate",
             "ExperienceValidated"
           ]

    before_rebuild = projection(lifecycle)
    assert before_rebuild == [:candidate, :validated]

    transitions = [
      transition!(experience, validated.transition, :stale, now, "stale"),
      transition!(experience, validated.transition, :superseded, now, "superseded")
    ]

    dataset_revision = StoreServer.summary(fixture.store_server).dataset_revision

    graph_revision =
      Phase04Fixture.current_graph_revision!(fixture, experience.experience_graph_iri)

    outcomes =
      transitions
      |> Enum.map(fn transition ->
        {:ok, command} =
          Knowledge.transition_experience_case(
            experience,
            transition,
            command_attributes(
              fixture,
              experience,
              graph_revision,
              Atom.to_string(transition.next_state),
              dataset_revision
            ),
            clock: fn -> transition.recorded_at end
          )

        Task.async(fn -> Writer.execute(fixture.writer, command) end)
      end)
      |> Task.await_many()

    assert Enum.count(outcomes, &match?({:ok, %{outcome: :committed}}, &1)) == 1
    assert Enum.count(outcomes, &match?({:ok, %{outcome: :conflicted, retry: :refresh}}, &1)) == 1

    original_statements = MapSet.new(ExperienceCase.statements(experience))
    dataset = Phase04Fixture.export_dataset!(fixture)

    assert Enum.all?(original_statements, fn statement ->
             {subject, predicate, object} = RDF.Triple.new(statement)

             Enum.any?(dataset, fn {stored_subject, stored_predicate, stored_object, graph} ->
               RDF.Term.equal_value?(subject, stored_subject) and
                 RDF.Term.equal_value?(predicate, stored_predicate) and
                 RDF.Term.equal_value?(object, stored_object) and
                 to_string(graph) == experience.experience_graph_iri
             end)
           end)

    Phase04Fixture.kill_writer!(fixture)
    Phase04Fixture.restart_writer!(fixture)

    assert {:ok, rebuilt} = query(fixture, :experience_case_lifecycle, experience, now, 3)
    assert Enum.take(projection(rebuilt), 2) == before_rebuild
    assert length(rebuilt.data) == 3
  end

  test "covers every case class, fixed baselines, and fail-closed inputs", %{fixture: fixture} do
    cases =
      for case_class <- ExperienceCase.case_classes() do
        run = %{
          run(fixture)
          | case_class: case_class,
            delayed_outcome: delayed(fixture, case_class)
        }

        assert {:ok, built} =
                 Knowledge.construct_experience_case(run, evidence(fixture, case_class), %{
                   effective_at: fixture.issued_at
                 })

        built.case
      end

    assert Enum.map(cases, & &1.case_class) ==
             [:success, :failure, :revert, :flake, :infrastructure, :abandoned, :ambiguous]

    request = retrieval_request(fixture)
    candidates = Enum.map(cases, &candidate(&1, request))
    assert {:ok, retrieved} = Knowledge.retrieve_experience_cases(request, candidates)
    assert length(retrieved.selected) == 7

    baselines = %{
      no_memory: [],
      ordinary_lexical: Enum.take(candidates, request.max_cases),
      governed_case_retrieval: retrieved.selected
    }

    assert Map.new(baselines, fn {name, values} -> {name, {length(values), request.max_cases}} end) ==
             %{
               no_memory: {0, 7},
               ordinary_lexical: {7, 7},
               governed_case_retrieval: {7, 7}
             }

    future = DateTime.add(fixture.issued_at, 1, :second)

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.construct_experience_case(
               run(fixture),
               evidence(fixture, :success, future),
               %{effective_at: fixture.issued_at}
             )

    missing = %{run(fixture) | source_event_iris: []}

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.construct_experience_case(missing, evidence(fixture), %{
               effective_at: fixture.issued_at
             })
  end

  defp query(fixture, name, experience, now, seconds) do
    Knowledge.query(
      name,
      QueryCatalog.experience_version(),
      %{
        graph: experience.experience_graph_iri,
        resource: experience.iri,
        instant: DateTime.add(now, seconds, :second)
      },
      fixture.authority,
      fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: DateTime.add(now, seconds, :second)
    )
  end

  defp run(fixture) do
    {:ok, experience_graph} =
      GraphRegistry.graph_iri(:experience, %{repository: fixture.repository})

    %{
      closed?: true,
      finalization_state: :complete,
      repository_iri: fixture.repository,
      repository_scope_iri: fixture.repository_scope,
      experience_graph_iri: experience_graph,
      repository_version: "tree-phase-04",
      attempt_iri: fixture.memory_attempt,
      task_class: :repair,
      plan_phase: "memory-phase-04",
      environment: %{framework: "phoenix", version: "1.8", os: "linux", runtime: "otp-28"},
      dependencies: [%{name: "phoenix", version: "1.8.1"}],
      symptoms: ["reviewed query failed"],
      reproduction: ["execute reviewed query"],
      inspected_files: ["lib/jido_code/knowledge/query_source.ex"],
      inspected_symbols: ["QuerySource.fetch/1"],
      interventions: ["remove unsupported graph-local algebra"],
      disproved_assumptions: ["parsing guarantees execution"],
      terminal_intervention: "use executor-supported graph patterns",
      verification_iris: [fixture.evidence_resource],
      delayed_outcome: delayed(fixture, :success),
      exceptions: [],
      limitations: ["Phoenix and OTP fixture"],
      source_event_iris: [fixture.memory_event.iri],
      source_artifact_iris: [],
      semantic_event_digests: [fixture.failure_signature],
      source_graph_revisions: %{fixture.memory_segment_graph => 2},
      case_class: :success,
      recorded_at: fixture.issued_at,
      actor_iri: fixture.actor,
      cause_iri: fixture.evidence_resource
    }
  end

  defp evidence(fixture, outcome \\ :success, observed_at \\ nil) do
    [
      %{
        iri: fixture.evidence_resource,
        graph_iri: fixture.evidence_graph,
        graph_revision: Phase04Fixture.current_graph_revision!(fixture, fixture.evidence_graph),
        observed_at: observed_at || fixture.issued_at,
        outcome: outcome,
        semantic_digest: digest("#{outcome}-#{fixture.evidence_resource}")
      }
    ]
  end

  defp delayed(fixture, outcome) do
    %{outcome: outcome, evidence_iri: fixture.evidence_resource, observed_at: fixture.issued_at}
  end

  defp command_attributes(fixture, experience, revision, seed, dataset_revision \\ nil) do
    %{
      experience_graph_revision: revision,
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      delegated_agent_iri: nil,
      delegation_iri: nil,
      correlation_iri: resource(:command_request, "phase-04-#{seed}-correlation"),
      causation_iri: fixture.enrollment_envelope.command_iri,
      expected_dataset_revision:
        dataset_revision || StoreServer.summary(fixture.store_server).dataset_revision,
      expected_graph_revisions: %{experience.experience_graph_iri => revision},
      recorded_at: DateTime.add(fixture.issued_at, revision, :second),
      reason: "phase 4 #{seed} integration"
    }
  end

  defp transition!(experience, current, state, now, seed) do
    {:ok, transition} =
      Knowledge.experience_transition(%{
        case_iri: experience.iri,
        prior_state: current.next_state,
        next_state: state,
        revision: current.revision + 1,
        expected_predecessor: current.iri,
        actor_iri: resource(:authorization_grant, "phase-04-#{seed}-actor"),
        cause_iri: resource(:evidence_claim, "phase-04-#{seed}-cause"),
        reason: "competing #{seed} lifecycle decision",
        recorded_at: DateTime.add(now, 2, :second)
      })

    transition
  end

  defp retrieval_request(fixture) do
    %{
      repository_iri: fixture.repository,
      framework: "phoenix",
      framework_version: "1.8",
      environment: "otp-28",
      dependency: "phoenix@1.8.1",
      task_class: :repair,
      plan_phase: "memory-phase-04",
      effective_at: fixture.issued_at,
      max_cases: 7
    }
  end

  defp candidate(experience, request) do
    %{
      iri: experience.iri,
      repository_iri: request.repository_iri,
      framework: request.framework,
      framework_version: request.framework_version,
      environment: request.environment,
      dependency: request.dependency,
      task_class: request.task_class,
      plan_phase: request.plan_phase,
      case_class: experience.case_class,
      lifecycle_state: :validated,
      current_applicable?: true,
      negative_transfer: 0.0,
      recorded_at: experience.recorded_at,
      validated_at: experience.recorded_at,
      channel_scores: %{lexical: 0.5, graph: 0.5, failure_signature: 1.0, dense: nil}
    }
  end

  defp projection(result),
    do: Enum.map(result.data, &(value(&1, "state") |> iri_label() |> state()))

  defp value(row, key), do: row[key] || row[String.to_atom(key)]
  defp iri_label(%{value: value}), do: iri_label(value)
  defp iri_label(value), do: value |> to_string() |> String.split(["#", "/"]) |> List.last()
  defp state("ExperienceCandidate"), do: :candidate
  defp state("ExperienceValidated"), do: :validated
  defp state("ExperienceStale"), do: :stale
  defp state("ExperienceSuperseded"), do: :superseded

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
