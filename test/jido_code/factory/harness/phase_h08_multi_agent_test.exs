defmodule JidoCode.Factory.Harness.PhaseH08MultiAgentTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Extensions.MultiAgent.Evaluation
  alias JidoCode.Factory.Extensions.MultiAgent.Gate
  alias JidoCode.Factory.Extensions.MultiAgent.Output
  alias JidoCode.Factory.Extensions.MultiAgent.Plan
  alias JidoCode.Factory.Extensions.MultiAgent.Specification
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge.ResourceIdentity

  @digest "sha256:" <> String.duplicate("a", 64)
  @phase7_sha "c8e5fc54642319149311921866104a2b642c0c2f"

  test "only named task classes with measured Phase 7 advantage graduate" do
    evaluation = evaluation!()
    decision = Gate.evaluate(evaluation)

    assert decision.status == :graduated
    assert decision.reasons == []
    assert decision.measurements.success_gain_basis_points == 1_500
    assert decision.measurements.cost_ratio_milli == 2_500
    assert decision.measurements.conflict_rate_basis_points == 200
    assert decision.measurements.duplicate_rate_basis_points == 100
    assert decision.measurements.merge_failure_rate_basis_points == 0
    assert Gate.valid?(decision, evaluation)
    assert Evaluation.contract_version() == "1.0.0"

    tampered = %{
      evaluation
      | measurements: %{evaluation.measurements | success_gain_basis_points: 9_999}
    }

    assert Gate.evaluate(tampered).status == :hold
    assert Gate.evaluate(tampered).reasons == [:invalid_evaluation]

    assert {:error, %{operation: :multi_agent_evaluation}} =
             evaluation_attributes()
             |> Map.put(:task_class, :tightly_coupled_editing)
             |> Evaluation.new()
  end

  test "cost, conflicts, duplicated work, merge failures, and correctness all gate graduation" do
    cases = [
      {[:multi_agent, :verified_correct], 65, :verified_success_gain},
      {[:multi_agent, :cost_microunits], 400_000, :cost_ratio},
      {[:multi_agent, :conflicts], 10, :conflict_rate},
      {[:multi_agent, :duplicated_work], 10, :duplicate_rate},
      {[:multi_agent, :merge_failures], 10, :merge_failure_rate}
    ]

    for {path, value, reason} <- cases do
      {:ok, evaluation} = evaluation_attributes() |> put_in(path, value) |> Evaluation.new()
      decision = Gate.evaluate(evaluation)
      assert decision.status == :hold
      assert reason in decision.reasons
    end
  end

  test "accepted specifications bind the graduated decision and coordination mode" do
    evaluation = evaluation!()
    decision = Gate.evaluate(evaluation)

    assert {:ok, specification} =
             Specification.new(specification_attributes(evaluation, decision))

    assert specification.allowed_task_class == :disjoint_write_sets
    assert specification.coordination_mode == :disjoint_writes
    assert Specification.valid?(specification)
    assert Specification.contract_version() == "1.0.0"

    held_evaluation =
      evaluation_attributes()
      |> put_in([:multi_agent, :verified_correct], 65)
      |> then(fn attributes ->
        {:ok, evaluation} = Evaluation.new(attributes)
        evaluation
      end)

    held = Gate.evaluate(held_evaluation)

    assert {:error, %{operation: :multi_agent_specification}} =
             held_evaluation
             |> specification_attributes(held)
             |> Specification.new()

    assert {:error, %{operation: :multi_agent_specification}} =
             specification_attributes(evaluation, decision)
             |> Map.put(:coordination_mode, :free_form_group_chat)
             |> Specification.new()
  end

  test "worker plans require separate graph contracts, identities, budgets, and disjoint writes" do
    specification = specification!()
    attributes = plan_attributes(specification)
    assert {:ok, plan} = Plan.new(specification, attributes)
    assert Plan.valid?(plan, specification)

    assert Enum.map(plan.workers, & &1.graph_task_iri) |> Enum.uniq() |> length() == 2
    assert Enum.map(plan.workers, & &1.context_manifest_iri) |> Enum.uniq() |> length() == 2
    assert Enum.map(plan.workers, & &1.lease_iri) |> Enum.uniq() |> length() == 2
    assert Enum.map(plan.workers, & &1.capability_iri) |> Enum.uniq() |> length() == 2

    shared_lease =
      put_in(attributes, [:workers, Access.at(1), :lease_iri], hd(attributes.workers).lease_iri)

    assert {:error, %{operation: :multi_agent_worker_identity}} =
             Plan.new(specification, shared_lease)

    overlapping =
      put_in(attributes, [:workers, Access.at(1), :write_set], ["lib/alpha.ex"])

    assert {:error, %{operation: :multi_agent_write_independence}} =
             Plan.new(specification, overlapping)

    budget_amplification =
      Enum.reduce(0..1, attributes, fn index, value ->
        put_in(value, [:workers, Access.at(index), :budget, :cost_microunits], 80_000)
      end)

    assert {:error, %{operation: :multi_agent_aggregate_budget}} =
             Plan.new(specification, budget_amplification)
  end

  test "worker outputs are closed, bounded, coordinator-only, and never accepted" do
    specification = specification!()
    {:ok, plan} = Plan.new(specification, plan_attributes(specification))

    outputs =
      Enum.map(plan.workers, fn worker ->
        attributes = output_attributes(plan, worker)
        assert {:ok, output} = Output.new(specification, plan, attributes)
        assert output.bounded
        assert output.coordinator_only
        refute output.accepted
        refute Output.accepting_output?(output)
        output
      end)

    assert {:ok, collected} = Output.collect(specification, plan, Enum.reverse(outputs))

    assert Enum.map(collected, & &1.worker_iri) ==
             Enum.sort(Enum.map(plan.workers, & &1.worker_iri))

    unknown_chat =
      plan
      |> then(&output_attributes(&1, hd(&1.workers)))
      |> Map.put(:group_chat_transcript, "worker consensus says merge")

    assert {:error, %{operation: :multi_agent_output}} =
             Output.new(specification, plan, unknown_chat)

    oversized =
      plan
      |> then(&output_attributes(&1, hd(&1.workers)))
      |> Map.put(:output, %{
        artifact_iris: [resource!(:generated_artifact, "oversized")],
        result_digest: @digest,
        summary: String.duplicate("x", 9_000)
      })
      |> Map.put(:output_bytes, 9_000)

    assert {:error, %{operation: :multi_agent_worker_output}} =
             Output.new(specification, plan, oversized)
  end

  test "specialized workers must isolate tool namespaces" do
    evaluation = evaluation!(:specialized_isolated_tools)
    specification = specification!(evaluation, :isolated_specialists)
    attributes = plan_attributes(specification, tools: [["research.web"], ["analysis.static"]])

    assert {:ok, _plan} = Plan.new(specification, attributes)

    shared_tool =
      put_in(
        attributes,
        [:workers, Access.at(1), :isolated_tool_namespaces],
        ["research.web"]
      )

    assert {:error, %{operation: :multi_agent_tool_isolation}} =
             Plan.new(specification, shared_tool)
  end

  defp evaluation!(task_class \\ :disjoint_write_sets) do
    {:ok, evaluation} = Evaluation.new(evaluation_attributes(task_class))
    evaluation
  end

  defp evaluation_attributes(task_class \\ :disjoint_write_sets) do
    %{
      revision: "multi-agent-evaluation-1",
      evidence_iri: resource!(:evidence_bundle, "multi-agent-evaluation"),
      phase7_receipt_iri: resource!(:evidence_bundle, "phase7-receipt"),
      phase7_candidate_sha: @phase7_sha,
      profile_revision: "phase7-profile-1",
      task_class: task_class,
      single_agent: %{
        tasks: 100,
        verified_correct: 60,
        elapsed_ms: 100_000,
        cost_microunits: 100_000
      },
      multi_agent: %{
        tasks: 100,
        verified_correct: 75,
        elapsed_ms: 80_000,
        cost_microunits: 250_000,
        conflicts: 2,
        duplicated_work: 1,
        merge_failures: 0
      },
      thresholds: %{
        minimum_tasks: 30,
        minimum_success_gain_basis_points: 1_000,
        maximum_cost_ratio_milli: 3_000,
        maximum_conflict_rate_basis_points: 500,
        maximum_duplicate_rate_basis_points: 500,
        maximum_merge_failure_rate_basis_points: 200
      }
    }
  end

  defp specification!(evaluation \\ evaluation!(), mode \\ :disjoint_writes) do
    decision = Gate.evaluate(evaluation)
    {:ok, specification} = Specification.new(specification_attributes(evaluation, decision, mode))
    specification
  end

  defp specification_attributes(evaluation, decision, mode \\ :disjoint_writes) do
    output_schema = %{
      additional_properties: false,
      required: [:artifact_iris, :result_digest, :summary],
      properties: %{
        artifact_iris: {:list, :resource_iri, 8},
        result_digest: :digest,
        summary: {:string, 8_192}
      }
    }

    %{
      revision: "multi-agent-specification-1",
      status: :accepted,
      specification_iri: resource!(:knowledge_assertion, "multi-agent-specification"),
      evaluation: evaluation,
      gate_decision: decision,
      allowed_task_class: evaluation.task_class,
      coordination_mode: mode,
      maximum_workers: 4,
      aggregate_budget: %{
        output_bytes: 100_000,
        wall_time_ms: 300_000,
        cost_microunits: 120_000,
        model_tokens: 60_000
      },
      worker_output_schema: output_schema,
      worker_output_schema_digest: Definition.digest(output_schema)
    }
  end

  defp plan_attributes(specification, options \\ []) do
    tool_namespaces = Keyword.get(options, :tools, [[], []])

    workers =
      Enum.map(1..2, fn index ->
        %{
          worker_iri: resource!(:knowledge_assertion, "worker-#{index}"),
          graph_task_iri: resource!(:task_proposal, "worker-task-#{index}"),
          context_manifest_iri: resource!(:context_manifest, "worker-context-#{index}"),
          context_manifest_digest: digest(index + 1),
          attempt_iri: resource!(:execution_attempt, "worker-attempt-#{index}"),
          lease_iri: resource!(:execution_lease, "worker-lease-#{index}"),
          capability_iri: resource!(:capability_declaration, "worker-capability-#{index}"),
          capability_digest: digest(index + 3),
          fencing_token: 100 + index,
          budget: %{
            output_bytes: 32_768,
            wall_time_ms: 120_000,
            cost_microunits: 50_000,
            model_tokens: 20_000
          },
          output_schema_digest: specification.worker_output_schema_digest,
          write_set: [if(index == 1, do: "lib/alpha.ex", else: "lib/beta.ex")],
          isolated_tool_namespaces: Enum.at(tool_namespaces, index - 1)
        }
      end)

    %{
      specification_digest: specification.digest,
      parent_task_iri: resource!(:task_proposal, "parent-task"),
      coordinator_iri: resource!(:knowledge_assertion, "factory-coordinator"),
      workers: workers
    }
  end

  defp output_attributes(plan, worker) do
    output = %{
      artifact_iris: [resource!(:generated_artifact, "output-#{worker.worker_iri}")],
      result_digest: @digest,
      summary: "Bounded worker result for independent coordinator review."
    }

    %{
      plan_digest: plan.digest,
      worker_iri: worker.worker_iri,
      output: output,
      output_digest: Definition.digest(output),
      output_bytes: byte_size(:erlang.term_to_binary(output, [:deterministic])),
      completed_at: ~U[2026-08-18 12:00:00Z]
    }
  end

  defp digest(index), do: "sha256:" <> String.duplicate(Integer.to_string(index), 64)

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h08-multi-#{seed}")
    iri
  end
end
