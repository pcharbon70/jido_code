defmodule JidoCode.Knowledge.PhaseH01HarnessResourcesTest do
  @moduledoc """
  Phase H01 Section 1.1 - harness graph resources and access profiles.

  Proves each mapped resource round-trips through its owning semantic
  command, obeys its closed shapes and graph-family write rules, and is
  rejected from any other family or writer.
  """

  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture

  @jf "https://jido.run/ontology/factory#"

  setup context do
    fixture =
      context
      |> Phase04Fixture.start!()
      |> Phase04Fixture.bootstrap!()
      |> Phase04Fixture.enroll!()
      |> Phase04Fixture.assert_outcome!()

    %{fixture: fixture}
  end

  describe "ModelAccessProfile enrollment" do
    test "enrolls, replays idempotently, and rejects duplicate enrollment", %{fixture: fixture} do
      profile = model_access_profile(fixture)

      attributes = policy_attributes(fixture)

      assert {:ok, command} =
               Knowledge.enroll_model_access_profile(profile, attributes, clock: clock(fixture))

      assert {:ok, receipt} = Writer.execute(fixture.writer, command)
      assert receipt.outcome == :committed

      assert {:ok, replay} = Writer.execute(fixture.writer, command)
      assert replay.outcome == :already_committed

      # A second, divergent enrollment of the same profile identity conflicts
      # with the committed subject guard.
      {:ok, duplicate} =
        Knowledge.enroll_model_access_profile(profile, policy_attributes(fixture),
          clock: clock(fixture)
        )

      assert {:ok, conflict} = Writer.execute(fixture.writer, duplicate)
      assert conflict.outcome == :conflicted
    end

    test "rejects invalid access modes, credential classes, and billing modes", %{
      fixture: fixture
    } do
      for bad <- [
            %{access_mode: :ambient},
            %{credential_class: :raw_token},
            %{billing_mode: :free},
            %{readiness: [:hallucinated]},
            %{revocation_generation: 0}
          ] do
        assert {:error, _error} =
                 Knowledge.model_access_profile(Map.merge(profile_attrs(fixture), bad))
      end
    end
  end

  describe "ModelAccessProfile revocation" do
    test "records a monotonic revocation generation", %{fixture: fixture} do
      profile = enrolled_profile!(fixture)

      attributes =
        policy_attributes(fixture)
        |> Map.merge(%{revoked_at: fixture.issued_at})

      assert {:ok, command} =
               Knowledge.revoke_model_access_profile(profile, 1, attributes,
                 clock: clock(fixture)
               )

      assert {:ok, receipt} = Writer.execute(fixture.writer, command)
      assert receipt.outcome == :committed

      assert {:ok, replay} = Writer.execute(fixture.writer, command)
      assert replay.outcome == :already_committed
    end

    test "rejects revocation against a stale generation", %{fixture: fixture} do
      profile = enrolled_profile!(fixture)

      attributes = Map.merge(policy_attributes(fixture), %{revoked_at: fixture.issued_at})

      assert {:ok, command} =
               Knowledge.revoke_model_access_profile(profile, 4, attributes,
                 clock: clock(fixture)
               )

      assert {:ok, receipt} = Writer.execute(fixture.writer, command)
      assert receipt.outcome == :conflicted
    end
  end

  describe "HarnessProfile adoption" do
    test "adopts a profile pinned to an enrolled model-access profile", %{fixture: fixture} do
      access = enrolled_profile!(fixture)

      assert {:ok, harness} =
               Knowledge.harness_profile(%{
                 name: "harness-baseline",
                 version: "1.0.0",
                 owner_iri: fixture.actor,
                 scope_iri: fixture.factory_scope,
                 model_access_profile_iri: access.iri,
                 workflow_version: "workflow-1",
                 prompt_template_version: "prompt-1",
                 tool_catalog_version: "catalog-1",
                 policy_revision: "policy-1",
                 budget_profile: "budget-standard"
               })

      assert {:ok, command} =
               Knowledge.adopt_harness_profile(harness, policy_attributes(fixture),
                 clock: clock(fixture)
               )

      assert {:ok, receipt} = Writer.execute(fixture.writer, command)
      assert receipt.outcome == :committed
    end

    test "rejects adoption when the model-access profile is absent", %{fixture: fixture} do
      assert {:ok, harness} =
               Knowledge.harness_profile(%{
                 name: "harness-orphan",
                 version: "1.0.0",
                 owner_iri: fixture.actor,
                 scope_iri: fixture.factory_scope,
                 model_access_profile_iri: Phase04Fixture.local!(:activity, 77),
                 workflow_version: "workflow-1",
                 prompt_template_version: "prompt-1",
                 tool_catalog_version: "catalog-1",
                 policy_revision: "policy-1",
                 budget_profile: "budget-standard"
               })

      assert {:ok, command} =
               Knowledge.adopt_harness_profile(harness, policy_attributes(fixture),
                 clock: clock(fixture)
               )

      assert {:ok, receipt} = Writer.execute(fixture.writer, command)
      assert receipt.outcome == :conflicted
    end
  end

  describe "ToolDefinition publication" do
    test "publishes a pinned tool contract and rejects malformed identities", %{fixture: fixture} do
      assert {:ok, definition} =
               Knowledge.tool_definition(%{
                 tool_name: "read_file",
                 tool_version: "1.0.0",
                 input_schema_digest: "sha256:" <> String.duplicate("0a", 32),
                 output_schema_digest: "sha256:" <> String.duplicate("0b", 32),
                 effect_class: :read,
                 adapter_digest: "sha256:" <> String.duplicate("0c", 32),
                 approval_required: false,
                 timeout_ms: 30_000
               })

      assert {:ok, command} =
               Knowledge.publish_tool_definition(definition, policy_attributes(fixture),
                 clock: clock(fixture)
               )

      assert {:ok, receipt} = Writer.execute(fixture.writer, command)
      assert receipt.outcome == :committed

      for bad <- [
            %{tool_name: "Read File"},
            %{tool_name: "9bad"},
            %{tool_version: "v1"},
            %{input_schema_digest: "md5:abc"},
            %{effect_class: :arbitrary},
            %{timeout_ms: 0}
          ] do
        assert {:error, _error} =
                 Knowledge.tool_definition(
                   Map.merge(
                     %{
                       tool_name: "read_file",
                       tool_version: "1.0.0",
                       input_schema_digest: "sha256:" <> String.duplicate("0a", 32),
                       output_schema_digest: "sha256:" <> String.duplicate("0b", 32),
                       effect_class: :read,
                       adapter_digest: "sha256:" <> String.duplicate("0c", 32),
                       approval_required: false,
                       timeout_ms: 30_000
                     },
                     bad
                   )
                 )
      end
    end
  end

  describe "ApprovalRequest creation" do
    test "creates a digest-bound approval request in the repository control graph", %{
      fixture: fixture
    } do
      assert {:ok, request} =
               Knowledge.approval_request(%{
                 action_digest: String.duplicate("ab", 32),
                 approver_iri: fixture.actor,
                 expires_at: DateTime.add(fixture.issued_at, 3600, :second),
                 evidence_iris: [fixture.goal]
               })

      attributes = control_attributes(fixture)

      assert {:ok, command} =
               Knowledge.create_approval_request(request, attributes, clock: clock(fixture))

      assert {:ok, receipt} = Writer.execute(fixture.writer, command)
      assert receipt.outcome == :committed

      assert {:ok, replay} = Writer.execute(fixture.writer, command)
      assert replay.outcome == :already_committed
    end

    test "rejects malformed action digests", %{fixture: fixture} do
      for bad <- ["xyz", String.duplicate("a", 63), nil] do
        assert {:error, _error} =
                 Knowledge.approval_request(%{
                   action_digest: bad,
                   approver_iri: fixture.actor,
                   expires_at: fixture.issued_at,
                   evidence_iris: []
                 })
      end
    end
  end

  describe "graph-family write rules" do
    test "rejects harness classes outside their owning families", %{fixture: fixture} do
      profile = model_access_profile(fixture)

      statements =
        Enum.map(
          JidoCode.Knowledge.Control.ModelAccessProfile.statements(profile),
          fn {subject, predicate, object} -> {subject, predicate, object} end
        )

      envelope =
        Phase04Fixture.envelope!(
          fixture,
          "EnrollRepository",
          Phase04Fixture.local!(:command, 88),
          fixture.factory_scope,
          "harness-family-rejection",
          %{
            fixture.graphs.catalog =>
              Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.catalog)
          },
          [
            %{
              family: :factory_catalog,
              graph_iri: fixture.graphs.catalog,
              operation: :append,
              metadata: %{lifecycle_state: :open},
              additions: statements,
              supersessions: [],
              invalidations: [],
              removals: []
            }
          ]
        )

      assert {:ok, receipt} = Writer.execute(fixture.writer, envelope)
      assert receipt.outcome == :invalid
    end
  end

  defp profile_attrs(fixture) do
    %{
      owner_iri: fixture.actor,
      scope_iri: fixture.factory_scope,
      access_mode: :host_api,
      credential_reference_iri: Phase04Fixture.local!(:activity, 60),
      credential_class: :static_reusable,
      billing_mode: :metered_api,
      provider: "openai",
      model: "gpt-test",
      endpoint: "https://api.example.test/v1",
      readiness: [:installed, :credential_available],
      revocation_generation: 1
    }
  end

  defp model_access_profile(fixture) do
    assert {:ok, profile} = Knowledge.model_access_profile(profile_attrs(fixture))
    profile
  end

  defp enrolled_profile!(fixture) do
    profile = model_access_profile(fixture)

    assert {:ok, command} =
             Knowledge.enroll_model_access_profile(profile, policy_attributes(fixture),
               clock: clock(fixture)
             )

    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed
    profile
  end

  defp policy_attributes(fixture) do
    %{
      policy_graph_iri: fixture.graphs.policy,
      expected_policy_revision:
        Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.policy),
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      scope_iri: fixture.factory_scope,
      correlation_iri: Phase04Fixture.local!(:activity, 61),
      causation_iri: fixture.bootstrap_command_iri,
      expected_dataset_revision: summary_revision(fixture),
      reason: "harness phase 1 contract test"
    }
  end

  defp control_attributes(fixture) do
    %{
      control_graph_iri: fixture.control_graph,
      expected_control_revision:
        Phase04Fixture.current_graph_revision!(fixture, fixture.control_graph),
      repository_scope_iri: fixture.repository_scope,
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      correlation_iri: Phase04Fixture.local!(:activity, 62),
      causation_iri: fixture.bootstrap_command_iri,
      expected_dataset_revision: summary_revision(fixture),
      recorded_at: fixture.issued_at,
      reason: "harness phase 1 contract test"
    }
  end

  defp clock(fixture), do: fn -> fixture.issued_at end

  defp summary_revision(fixture) do
    fixture.store_server
    |> JidoCode.Knowledge.StoreServer.summary()
    |> Map.get(:dataset_revision)
  end
end
