defmodule JidoCode.Knowledge.Memory.ContractTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Memory.Contract

  test "inventories every current durable content and derivative class" do
    assert Contract.revision() == "2.1.0"

    assert Contract.content_inventory()
           |> Enum.map(& &1.content_class)
           |> MapSet.new() ==
             MapSet.new([
               :instruction_content,
               :interaction_message,
               :model_outcome,
               :tool_stdout_stderr,
               :embedded_artifact,
               :command_receipt_commitment,
               :export,
               :backup_derivative
             ])

    assert {:ok, instruction} = Contract.content_contract(:instruction_content)
    assert instruction.classification == :prompt_representation
    assert instruction.limitation == :not_exact_assembled_prompt

    assert {:ok, output} = Contract.content_contract(:tool_stdout_stderr)
    assert output.current_representation == :legacy_bounded_exact_text_and_digest
    assert output.semantic_history == :normalized_result_digest_and_capture_state

    assert :error = Contract.content_contract(:unknown_content)
  end

  test "excludes content that cannot enter observable memory" do
    assert Contract.forbidden_content() == [
             :secret_value,
             :provider_private_state,
             :hidden_reasoning
           ]
  end

  test "requires one explicit capture outcome for every expected body" do
    expected = ["urn:body:instruction", "urn:body:stdout", "urn:body:stderr"]

    assert Contract.completely_accounted?(expected, %{
             "urn:body:instruction" => :captured,
             "urn:body:stdout" => :omitted,
             "urn:body:stderr" => :unavailable
           })

    refute Contract.completely_accounted?(expected, %{
             "urn:body:instruction" => :captured,
             "urn:body:stdout" => :omitted
           })

    refute Contract.completely_accounted?(expected, %{
             "urn:body:instruction" => :captured,
             "urn:body:stdout" => :omitted,
             "urn:body:stderr" => :unknown
           })

    refute Contract.completely_accounted?(["urn:body:stdout", "urn:body:stdout"], %{
             "urn:body:stdout" => :captured
           })
  end

  test "labels legacy runs honestly without authorizing rewrites" do
    contract = Contract.legacy_run_contract()

    assert contract.protocol_line == "1.x"
    assert contract.immutable_after_closure
    refute contract.rewrite_allowed
    assert contract.completeness_claim == :bounded_observable_subset
    assert contract.event_accounting == :not_claimed
    assert contract.reconstruction == :stored_representations_only
  end
end
