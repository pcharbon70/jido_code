defmodule JidoCode.Factory.Harness.PhaseH03PolicyGovernorTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Authorization
  alias JidoCode.Factory.Tool.PolicyGovernor
  alias JidoCode.Factory.Tool.Proposal
  alias JidoCode.Factory.Tool.ReferenceMonitor
  alias JidoCode.Knowledge.ResourceIdentity

  test "normalizes Jido directives and model tool calls to the same bounded proposal" do
    invocation = resource!(:tool_invocation, "proposal")
    directive = directive("read_file", read_arguments())

    model_call = %{
      "name" => "read_file",
      "version" => "1.0.0",
      "classification" => "internal",
      "input_refs" => directive.input_refs,
      "arguments" => stringify_keys(directive.arguments)
    }

    assert {:ok, from_directive} = Proposal.from_directive(invocation, directive)
    assert {:ok, from_model} = Proposal.from_model_call(invocation, model_call)

    assert from_directive.proposal_digest == from_model.proposal_digest
    assert from_directive.arguments_digest == from_model.arguments_digest
    assert from_directive.input_refs == from_model.input_refs

    secret_bearing = "token=raw-value-must-remain-transient"
    edit = directive("apply_edit", Map.put(edit_arguments(), :new_text, secret_bearing))
    assert {:ok, proposal} = Proposal.from_directive(invocation, edit)

    refute inspect(proposal) =~ secret_bearing
    refute inspect(Proposal.persistent_attributes(proposal)) =~ secret_bearing
    refute Map.has_key?(Proposal.persistent_attributes(proposal), :arguments)
  end

  test "rejects open proposal envelopes, unknown tools, bad classifications, and unbounded arguments" do
    invocation = resource!(:tool_invocation, "invalid-proposal")

    for invalid <- [
          Map.put(directive("read_file", read_arguments()), :unknown, true),
          %{directive("read_file", read_arguments()) | tool_name: "raw_shell"},
          %{directive("read_file", read_arguments()) | classification: :secret},
          %{
            directive("read_file", read_arguments())
            | arguments: %{content: String.duplicate("x", 40_000)}
          }
        ] do
      assert {:error, %AdapterError{operation: :action_proposal}} =
               Proposal.from_directive(invocation, invalid)
    end
  end

  test "deterministically intersects lease, task, policy, and actor authority" do
    context = governor_context()
    narrowed = put_in(context.actor.resource_ceilings.output_bytes, 262_144)

    assert {:ok, capability} = PolicyGovernor.derive(narrowed)

    assert capability.permitted_tools == ["apply_edit", "read_file", "run_registered_check"]
    assert capability.path_prefixes == ["lib"]
    assert capability.ref_iris == [resource!(:knowledge_assertion, "source")]
    assert capability.network_destinations == []
    assert capability.registered_commands == ["mix-test"]
    assert capability.data_classes == [:internal]

    assert capability.resource_ceilings == %{
             calls: 4,
             output_bytes: 262_144,
             timeout_ms: 300_000
           }

    assert capability.authority_classes == [:tool_execution]
    assert capability.fencing_token == 17
    assert capability.policy_revision == 41
    assert capability.revocation_generation == 3
    assert capability.idempotency_namespace =~ ~r/^sha256:[a-f0-9]{64}$/

    assert {:ok, same} = PolicyGovernor.derive(narrowed)
    assert same == capability
  end

  test "refuses decision, acceptance, ontology, policy, memory, verification, and publication authority" do
    for forbidden <- [
          :decision,
          :acceptance,
          :ontology,
          :security_policy,
          :durable_memory,
          :verification,
          :publication
        ] do
      context =
        put_in(governor_context().task.requested_authorities, [:tool_execution, forbidden])

      assert {:error, %AdapterError{operation: :tool_policy}} = PolicyGovernor.derive(context)
    end
  end

  test "authorizes a closed proposal and requires the same live facts immediately before effect" do
    assert {:ok, capability} = PolicyGovernor.derive(governor_context())
    proposal = proposal!("read_file", read_arguments())
    current = current(capability, proposal)

    assert {:ok, %Authorization{} = authorization} =
             ReferenceMonitor.authorize(proposal, capability, current)

    assert authorization.arguments == read_arguments()
    assert authorization.definition.name == "read_file"
    assert authorization.decision_digest =~ ~r/^[a-f0-9]{64}$/
    refute inspect(authorization) =~ "lib/jido_code.ex"

    assert {:ok, refreshed} = ReferenceMonitor.revalidate(authorization, current)
    assert refreshed.decision_digest == authorization.decision_digest
  end

  test "race-time policy, graph, snapshot, fence, lease, and revocation changes all deny" do
    assert {:ok, capability} = PolicyGovernor.derive(governor_context())
    proposal = proposal!("read_file", read_arguments())
    current = current(capability, proposal)
    assert {:ok, authorization} = ReferenceMonitor.authorize(proposal, capability, current)

    races = [
      %{current | policy_revision: current.policy_revision + 1},
      %{
        current
        | source_graph_revisions: %{resource!(:graph_revision_reference, "policy") => 99}
      },
      %{current | snapshot_iri: resource!(:repository_snapshot, "other")},
      %{current | fencing_token: current.fencing_token + 1},
      %{current | lease_state: :revoked},
      %{current | revocation_generation: current.revocation_generation + 1}
    ]

    for raced <- races do
      assert {:error, %AdapterError{operation: :tool_authorization}} =
               ReferenceMonitor.revalidate(authorization, raced)
    end
  end

  test "never falls back to an unpermitted tool, data class, ref, command, or destination" do
    assert {:ok, capability} = PolicyGovernor.derive(governor_context())

    denied = [
      proposal!("apply_edit", edit_arguments(), classification: :restricted),
      proposal!("show_candidate_diff", %{snapshot_ref: resource!(:knowledge_assertion, "source")}),
      proposal!("run_governed_command", %{command: "format-check"}),
      proposal!("submit_candidate", submit_arguments())
    ]

    for proposal <- denied do
      assert {:error, %AdapterError{operation: :tool_authorization}} =
               ReferenceMonitor.authorize(proposal, capability, current(capability, proposal))
    end
  end

  test "approval-bearing tools require the exact current approval evidence" do
    context =
      governor_context(
        permitted_tools: ["run_governed_command", "submit_candidate"],
        network_destinations: ["github_pull_request"],
        registered_commands: ["format-check"]
      )

    assert {:ok, capability} = PolicyGovernor.derive(context)

    governed = proposal!("run_governed_command", %{command: "format-check"})
    governed_current = current(capability, governed)

    assert {:error, %AdapterError{operation: :tool_authorization}} =
             ReferenceMonitor.authorize(governed, capability, governed_current)

    assert {:ok, %Authorization{}} =
             ReferenceMonitor.authorize(
               governed,
               capability,
               %{governed_current | approved_tools: ["run_governed_command"]}
             )

    submit = proposal!("submit_candidate", submit_arguments())
    submit_current = current(capability, submit)

    assert {:error, %AdapterError{operation: :tool_authorization}} =
             ReferenceMonitor.authorize(submit, capability, submit_current)

    assert {:ok, %Authorization{}} =
             ReferenceMonitor.authorize(
               submit,
               capability,
               %{submit_current | approval_refs: [submit.arguments.approval_ref]}
             )
  end

  defp governor_context(overrides \\ []) do
    expires_at = DateTime.add(DateTime.utc_now(), 600, :second)
    source_ref = resource!(:knowledge_assertion, "source")
    graph = resource!(:graph_revision_reference, "policy")

    common = %{
      permitted_tools:
        Keyword.get(overrides, :permitted_tools, [
          "apply_edit",
          "read_file",
          "run_registered_check"
        ]),
      path_prefixes: ["lib"],
      ref_iris: [source_ref],
      graph_scope_iris: [graph],
      network_destinations: Keyword.get(overrides, :network_destinations, []),
      registered_commands: Keyword.get(overrides, :registered_commands, ["mix-test"]),
      data_classes: [:internal],
      resource_ceilings: %{calls: 8, output_bytes: 262_144, timeout_ms: 300_000},
      credential_reference_iris: [],
      requested_authorities: [:tool_execution],
      expires_at: expires_at
    }

    %{
      attempt_iri: resource!(:execution_attempt, "attempt"),
      agent_iri: resource!(:knowledge_assertion, "agent"),
      lease:
        Map.merge(common, %{
          iri: resource!(:execution_lease, "lease"),
          fencing_token: 17,
          revocation_generation: 3
        }),
      task:
        Map.merge(common, %{
          iri: resource!(:knowledge_assertion, "task"),
          repository_iri: resource!(:knowledge_assertion, "repository"),
          snapshot_iri: resource!(:repository_snapshot, "snapshot"),
          resource_ceilings: %{calls: 4, output_bytes: 524_288, timeout_ms: 300_000}
        }),
      policy:
        Map.merge(common, %{
          revision: 41,
          source_graph_revisions: %{graph => 9},
          resource_ceilings: %{calls: 6, output_bytes: 524_288, timeout_ms: 300_000}
        }),
      actor: Map.merge(common, %{iri: resource!(:knowledge_assertion, "actor")}),
      profile: %{
        iri: resource!(:harness_profile, "profile"),
        model: "openai:gpt-4.1-mini",
        tool_catalog_version: "1.0.0"
      }
    }
  end

  defp current(capability, proposal) do
    %{
      now: DateTime.utc_now(),
      invocation_iri: proposal.invocation_iri,
      lease_state: :active,
      policy_revision: capability.policy_revision,
      source_graph_revisions: capability.source_graph_revisions,
      snapshot_iri: capability.snapshot_iri,
      fencing_token: capability.fencing_token,
      revocation_generation: capability.revocation_generation,
      approval_refs: [],
      approved_tools: []
    }
  end

  defp proposal!(name, arguments, options \\ []) do
    directive =
      directive(name, arguments)
      |> Map.put(:classification, Keyword.get(options, :classification, :internal))

    assert {:ok, proposal} =
             Proposal.from_directive(resource!(:tool_invocation, "#{name}-invocation"), directive)

    proposal
  end

  defp directive(name, arguments) do
    %{
      tool_name: name,
      tool_version: "1.0.0",
      classification: :internal,
      input_refs: [resource!(:knowledge_assertion, "source")],
      arguments: arguments
    }
  end

  defp read_arguments do
    %{
      path: "lib/jido_code.ex",
      expected_digest: "sha256:" <> String.duplicate("a", 64)
    }
  end

  defp edit_arguments do
    %{
      path: "lib/jido_code.ex",
      expected_digest: "sha256:" <> String.duplicate("a", 64),
      old_text: "old",
      new_text: "new",
      expected_matches: 1
    }
  end

  defp submit_arguments do
    %{
      candidate_ref: resource!(:knowledge_assertion, "source"),
      approval_ref: resource!(:knowledge_assertion, "source"),
      destination: "github_pull_request",
      expected_revision: 41
    }
  end

  defp stringify_keys(arguments),
    do: Map.new(arguments, fn {key, value} -> {Atom.to_string(key), value} end)

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h03-#{seed}")
    iri
  end
end
