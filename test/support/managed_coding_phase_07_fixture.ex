defmodule JidoCode.TestSupport.ManagedCodingPhase07Fixture do
  @moduledoc false

  alias JidoCode.Factory.ManagedCoding.AgentOSDecision
  alias JidoCode.Factory.ManagedCoding.SpecialistEvaluation
  alias JidoCode.Factory.ManagedCoding.TopologyContract
  alias JidoCode.Runtime.ManagedCoding.Pod
  alias JidoCode.Runtime.ManagedCoding.PodManager
  alias JidoCode.Runtime.ManagedCoding.SpecialistAgent
  alias JidoCode.Runtime.ManagedCoding.SpecialistManager

  @profile "d2042eb2dfd52d1572cff7c7621042f37a524e113b3f266e0a2161ac8bec088d"
  @corpus String.duplicate("c", 64)
  @watermark String.duplicate("e", 64)

  def manager_specs do
    [
      Jido.Agent.InstanceManager.child_spec(
        name: SpecialistManager,
        agent: SpecialistAgent,
        jido: JidoCode.Runtime.JidoInstance,
        storage: nil,
        partition: :managed_coding_specialists,
        idle_timeout: :infinity
      ),
      Jido.Agent.InstanceManager.child_spec(
        name: PodManager,
        agent: Pod,
        jido: JidoCode.Runtime.JidoInstance,
        storage: nil,
        partition: :managed_coding_pods,
        idle_timeout: :infinity
      )
    ]
  end

  def contract do
    {:ok, contract} =
      TopologyContract.new(%{
        topology_iri: "https://jido.run/id/topology/phase-7-integration",
        revision: 1,
        profile_digest: @profile,
        jido_version: "2.3.2",
        pod_revision: "jido-pod/2.3.2",
        roles: Enum.map(~w[investigator coder reviewer], &role/1),
        max_fan_out: 3,
        max_depth: 1,
        max_message_bytes: 8_192,
        restart_limit: 2,
        timeout_ms: 30_000,
        state: :evaluation
      })

    contract
  end

  def projection do
    %{
      topology_iri: contract().topology_iri,
      revision: 1,
      profile_digest: @profile,
      watermark: @watermark,
      state: :active
    }
  end

  def delegation(overrides \\ %{}) do
    remaining = %{
      messages: 4,
      input_bytes: 8_192,
      output_bytes: 8_192,
      tokens: 2_000,
      cost_microunits: 10_000,
      timeout_ms: 30_000
    }

    Map.merge(
      %{
        delegation_iri: "https://jido.run/id/delegation/phase-7-integration",
        task_iri: "https://jido.run/id/task/phase-7-integration",
        attempt_iri: "https://jido.run/id/attempt/phase-7-integration",
        role: "coder",
        fence: 9,
        depth: 1,
        parent_role: "host",
        policy_current: true,
        capability_ref: @profile,
        context_digest: @profile,
        profile_digest: @profile,
        shared_remaining: remaining,
        role_remaining: remaining,
        concurrent: 0,
        active_roles: []
      },
      overrides
    )
  end

  def evidence do
    body = "lib/runtime.ex:42 preserves the current fence"

    {:ok, packet} =
      SpecialistEvaluation.evidence_packet(%{
        delegation_iri: delegation().delegation_iri,
        attempt_iri: delegation().attempt_iri,
        role: "investigator",
        fence: 9,
        source_complete: true,
        sources: [
          %{
            source_iri: "https://jido.run/id/source/phase-7-integration",
            revision: String.duplicate("1", 64),
            digest: String.duplicate("2", 64),
            classification: "internal"
          }
        ],
        body: body,
        body_digest: sha256(body)
      })

    packet
  end

  def evaluation_program do
    {:ok, program} =
      SpecialistEvaluation.new(%{
        revision: "specialist-evaluation/phase-7",
        baseline_profile_digest: @profile,
        corpus_digest: @corpus,
        role_specs: Enum.map(~w[investigator coder reviewer], &role_spec/1),
        thresholds: %{
          min_correctness_delta: 0.1,
          min_abstention_delta: 0.0,
          min_recovery_delta: 0.0,
          max_unsafe_delta: 0.0,
          max_regression_delta: 0.0,
          max_latency_ratio: 1.25,
          max_token_ratio: 1.25,
          max_cost_ratio: 1.25,
          max_operator_burden_ratio: 1.25
        },
        minimum_sample_size: 2
      })

    program
  end

  def trials(variant) do
    for number <- 1..2 do
      overhead = if variant == "specialists", do: 150, else: 100

      %{
        trial_id: "https://jido.run/id/trial/phase-7-#{number}",
        corpus_digest: @corpus,
        profile_digest: @profile,
        variant: variant,
        blinded: true,
        correctness: true,
        abstention: true,
        recovery: true,
        unsafe_behavior: 0,
        regressions: 0,
        latency_ms: overhead,
        tokens: overhead,
        cost_microunits: overhead,
        operator_burden_minutes: if(variant == "specialists", do: 15, else: 10)
      }
    end
  end

  def agent_os_decision do
    {:ok, decision} =
      AgentOSDecision.evaluate(%{
        source_revision: "548b2a345765ba33e687341c661bbbcbdda73d94",
        dependency_present: false,
        capabilities:
          Enum.map(AgentOSDecision.candidate_capabilities(), fn name ->
            %{name: name, benefit: :duplicative, evidence_digest: nil}
          end),
        persistence_modes: [:ecto, :ephemeral],
        measured_benefits: %{latency_delta_ms: 0, operator_minutes_saved: 0},
        operational_cost: %{new_datastores: 1, new_reconcilers: 1},
        owner: "JidoCode runtime maintainers"
      })

    decision
  end

  def agent_os_scenarios do
    Enum.map(AgentOSDecision.faults(), fn fault ->
      %{
        fault: fault,
        graph_outcome: :accepted_baseline,
        agent_os_outcome: :irrelevant,
        duplicate_effect: false,
        split_authority: false
      }
    end)
  end

  def digest do
    %{
      contract: contract(),
      projection: projection(),
      delegation: delegation(),
      evidence: evidence(),
      evaluation: evaluation_program(),
      baseline: trials("single_agent"),
      topology: trials("specialists"),
      agent_os: agent_os_decision(),
      faults: agent_os_scenarios()
    }
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp role(name) do
    %{
      name: name,
      module: SpecialistAgent,
      manager: SpecialistManager,
      activation: "lazy",
      capability_refs: [@profile],
      budget: %{
        max_messages: 4,
        max_input_bytes: 8_192,
        max_output_bytes: 8_192,
        max_tokens: 2_000,
        max_cost_microunits: 10_000,
        timeout_ms: 30_000
      }
    }
  end

  defp role_spec(role) do
    %{
      role: role,
      inputs: ["content_addressed_context"],
      outputs: ["terminal_proposal"],
      tools: [@profile],
      context_limit: 8_192,
      budget: %{messages: 4, tokens: 2_000, cost_microunits: 10_000, timeout_ms: 30_000},
      termination: ["complete", "abstain", "cancelled"],
      unavailable_authorities: ~w[acceptance graph merge policy publication topology verification]
    }
  end

  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
