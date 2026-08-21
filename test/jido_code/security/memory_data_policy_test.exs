defmodule JidoCode.Security.MemoryDataPolicyTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Retention.Policy, as: RetentionPolicy
  alias JidoCode.Security.DataPolicy

  test "enables only semantic history and keeps alternative profiles gated" do
    assert DataPolicy.revision() == "2.1.0"

    assert DataPolicy.profiles() == [
             :diagnostic_capture,
             :incident_hold,
             :project_total_history,
             :semantic_history
           ]

    assert DataPolicy.profile_enabled?(:semantic_history)
    refute DataPolicy.profile_enabled?(:diagnostic_capture)
    refute DataPolicy.profile_enabled?(:project_total_history)
    refute DataPolicy.profile_enabled?(:incident_hold)
    refute DataPolicy.profile_enabled?(:unknown)

    assert {:ok, semantic} = DataPolicy.profile(:semantic_history)
    assert semantic.exact_prompt == :omit
    assert semantic.raw_provider_response == :omit
    assert semantic.raw_tool_body == :omit
  end

  test "covers every graph family, representation, sink, and egress posture" do
    assert :ok = DataPolicy.verify()

    for family <- GraphRegistry.families() do
      assert Enum.any?(DataPolicy.classifications(), fn classification ->
               DataPolicy.durable_allowed?(classification, family)
             end)
    end

    assert DataPolicy.durable_allowed?(
             :prompt_representation,
             :run_attempt,
             :normalized_text,
             :semantic_history
           )

    refute DataPolicy.durable_allowed?(
             :tool_output,
             :run_attempt,
             :exact_text,
             :semantic_history
           )

    assert DataPolicy.durable_allowed?(
             :encrypted_content,
             :episode_content,
             :ciphertext,
             :semantic_history
           )

    refute DataPolicy.durable_allowed?(:secret_value, :factory_policy)
    refute DataPolicy.output_allowed?(:personal, :approved_export)
    refute DataPolicy.provider_egress_allowed?(:personal, :approved_restricted)
    assert DataPolicy.output_allowed?(:encrypted_content, :content_gateway)
  end

  test "models capture, representation, storage, availability, retention, and hold independently" do
    dimensions = DataPolicy.dimensions()

    assert Map.keys(dimensions) |> Enum.sort() ==
             [
               :availability,
               :capture_outcome,
               :hold,
               :representation,
               :retention,
               :storage_location
             ]

    assert :omitted in dimensions.capture_outcome
    assert :ciphertext in dimensions.representation
    assert :episode_content_graph in dimensions.storage_location
    assert :cold in dimensions.availability
    assert :archived in dimensions.retention
    assert :physically_deleted in dimensions.retention
    assert :externally_unverifiable in dimensions.retention
    assert :held in dimensions.hold
  end

  test "admits only protected new sensitive commitments" do
    assert DataPolicy.new_commitment_allowed?(:ciphertext_commitment, :confidential, %{
             encrypted_before_commit: true
           })

    refute DataPolicy.new_commitment_allowed?(:ciphertext_commitment, :confidential, %{
             encrypted_before_commit: false
           })

    assert DataPolicy.new_commitment_allowed?(:keyed_commitment, :prompt_representation, %{
             purpose: :equality_verification,
             key_location: :external
           })

    refute DataPolicy.new_commitment_allowed?(:legacy_unkeyed_digest, :prompt_representation, %{})

    refute DataPolicy.new_commitment_allowed?(:ciphertext_commitment, :secret_value, %{
             encrypted_before_commit: true
           })
  end

  test "retains semantic shells longer than exact payload classes" do
    assert :ok = RetentionPolicy.verify()
    assert RetentionPolicy.classes().semantic_shell.minimum_days == 2_555
    assert RetentionPolicy.classes().exact_payload.minimum_days == 30
    assert RetentionPolicy.classes().governed_content.disposition == :retain
  end
end
