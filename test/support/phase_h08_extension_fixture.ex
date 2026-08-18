defmodule JidoCode.TestSupport.PhaseH08ExtensionFixture do
  @moduledoc false

  alias JidoCode.Factory.Extensions.MCP.Specification, as: MCPSpecification
  alias JidoCode.Factory.Extensions.MultiAgent.Evaluation
  alias JidoCode.Factory.Extensions.MultiAgent.Gate
  alias JidoCode.Factory.Extensions.MultiAgent.Specification, as: MultiAgentSpecification
  alias JidoCode.Factory.Extensions.RemoteAgent.Specification, as: RemoteAgentSpecification
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge.ResourceIdentity

  @digest "sha256:" <> String.duplicate("a", 64)
  @phase7_sha "c8e5fc54642319149311921866104a2b642c0c2f"

  def specifications do
    %{
      mcp: mcp_specification(),
      remote_agent: remote_agent_specification(),
      multi_agent: multi_agent_specification()
    }
  end

  def mcp_specification do
    input_schema = %{
      additional_properties: false,
      required: [:query],
      properties: %{query: {:string, 128}}
    }

    output_schema = %{
      additional_properties: false,
      required: [:external_reference],
      properties: %{external_reference: :resource_iri}
    }

    adapter = "JidoCode.TestSupport.FakeMCPTransport/1"

    {:ok, specification} =
      MCPSpecification.new(%{
        revision: "integration-mcp-1",
        status: :accepted,
        specification_iri: resource!(:knowledge_assertion, "mcp-spec"),
        evidence_iri: resource!(:evidence_bundle, "mcp-evidence"),
        protocol_version: "2025-06-18",
        server_package: "integration-mcp@1.0.0",
        server_package_digest: @digest,
        server_identity: "integration-mcp",
        transport: :https,
        adapter_identity: adapter,
        adapter_digest: Definition.digest(adapter),
        descriptor_digest: digest("b"),
        discovery: %{
          origin: "https://mcp.example.test",
          discovery_url: "https://mcp.example.test/.well-known/mcp",
          redirect_origins: ["https://mcp.example.test"],
          max_redirects: 2,
          reject_private_addresses: true,
          pin_connection_address: true
        },
        oauth: %{
          issuer: "https://auth.example.test",
          audience: "integration-mcp",
          scopes: ["mcp:invoke"],
          redirect_uris: ["https://factory.example.test/oauth/callback"],
          pkce_method: :s256,
          token_passthrough: false
        },
        sandbox: :not_applicable,
        tools: [
          %{
            name: "search",
            namespaced_name: "integration-mcp/search",
            descriptor_digest: digest("c"),
            input_schema: input_schema,
            input_schema_digest: Definition.digest(input_schema),
            output_schema: output_schema,
            output_schema_digest: Definition.digest(output_schema),
            max_output_bytes: 8_192,
            approval_required: true,
            phase3_tool: "run_governed_command"
          }
        ]
      })

    specification
  end

  def remote_agent_specification do
    output_schema = %{
      additional_properties: false,
      required: [:external_references, :result_digest],
      properties: %{
        external_references: {:list, :resource_iri, 8},
        result_digest: :digest
      }
    }

    adapter = "JidoCode.RemoteAgent.IntegrationAdapter/1"

    {:ok, specification} =
      RemoteAgentSpecification.new(%{
        revision: "integration-remote-agent-1",
        status: :accepted,
        specification_iri: resource!(:knowledge_assertion, "remote-spec"),
        evidence_iri: resource!(:evidence_bundle, "remote-evidence"),
        remote_agent_iri: resource!(:knowledge_assertion, "remote-agent"),
        remote_identity: "provider.example/agents/integration",
        protocol_versions: %{delegation: "0.3", artifact: "1.0"},
        adapter_identity: adapter,
        adapter_digest: Definition.digest(adapter),
        maximum_budget: %{
          output_bytes: 65_536,
          wall_time_ms: 300_000,
          cost_microunits: 100_000,
          model_tokens: 50_000
        },
        output_schema: output_schema,
        output_schema_digest: Definition.digest(output_schema)
      })

    specification
  end

  def multi_agent_specification do
    {:ok, evaluation} =
      Evaluation.new(%{
        revision: "integration-multi-evaluation-1",
        evidence_iri: resource!(:evidence_bundle, "multi-evaluation"),
        phase7_receipt_iri: resource!(:evidence_bundle, "phase7-receipt"),
        phase7_candidate_sha: @phase7_sha,
        profile_revision: "phase7-profile-1",
        task_class: :independent_research,
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
      })

    output_schema = %{
      additional_properties: false,
      required: [:artifact_iris, :result_digest],
      properties: %{artifact_iris: {:list, :resource_iri, 8}, result_digest: :digest}
    }

    {:ok, specification} =
      MultiAgentSpecification.new(%{
        revision: "integration-multi-spec-1",
        status: :accepted,
        specification_iri: resource!(:knowledge_assertion, "multi-spec"),
        evaluation: evaluation,
        gate_decision: Gate.evaluate(evaluation),
        allowed_task_class: :independent_research,
        coordination_mode: :independent_branches,
        maximum_workers: 4,
        aggregate_budget: %{
          output_bytes: 100_000,
          wall_time_ms: 300_000,
          cost_microunits: 120_000,
          model_tokens: 60_000
        },
        worker_output_schema: output_schema,
        worker_output_schema_digest: Definition.digest(output_schema)
      })

    specification
  end

  defp digest(character), do: "sha256:" <> String.duplicate(character, 64)

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h08-integration-#{seed}")
    iri
  end
end
