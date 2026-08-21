defmodule JidoCode.Knowledge.Memory.Contract do
  @moduledoc """
  Executable boundary for total semantic accounting and selective memory.

  The contract inventories the content that the legacy execution protocol can
  persist and states the managed `semantic_history` posture for the `2.0.0`
  memory protocol. It grants no capture, retrieval, or write capability.
  """

  @revision "2.1.0"
  @capture_outcomes ~w[captured omitted unavailable redacted failed expired erased]a
  @forbidden_content ~w[secret_value provider_private_state hidden_reasoning]a

  @content_inventory [
    %{
      content_class: :instruction_content,
      current_graphs: [:run_attempt],
      current_representation: :bounded_instruction_text,
      classification: :prompt_representation,
      semantic_history: :selected_normalized_text,
      limitation: :not_exact_assembled_prompt
    },
    %{
      content_class: :interaction_message,
      current_graphs: [:repository_control, :run_attempt],
      current_representation: :bounded_normalized_or_redacted_text,
      classification: :interaction_content,
      semantic_history: :selected_normalized_text,
      limitation: :provider_internal_turns_unobserved
    },
    %{
      content_class: :model_outcome,
      current_graphs: [:run_attempt],
      current_representation: :normalized_outcome_digest_and_bounded_diagnostic,
      classification: :model_result,
      semantic_history: :normalized_result_and_digest,
      limitation: :raw_provider_response_unavailable
    },
    %{
      content_class: :tool_stdout_stderr,
      current_graphs: [:run_attempt],
      current_representation: :legacy_bounded_exact_text_and_digest,
      classification: :tool_output,
      semantic_history: :normalized_result_digest_and_capture_state,
      limitation: :legacy_body_not_automatically_recalled
    },
    %{
      content_class: :embedded_artifact,
      current_graphs: [:run_attempt],
      current_representation: :bounded_exact_public_or_internal_text,
      classification: :artifact_content,
      semantic_history: :governed_artifact,
      limitation: :external_content_requires_digest_verification
    },
    %{
      content_class: :command_receipt_commitment,
      current_graphs: [:security_audit],
      current_representation: :canonical_assertion_digest,
      classification: :integrity_commitment,
      semantic_history: :ciphertext_or_protected_keyed_commitment,
      limitation: :legacy_plaintext_derived_commitment_may_persist
    },
    %{
      content_class: :export,
      current_graphs: [:memory_dataset],
      current_representation: :external_reference_digest_and_lineage,
      classification: :export_derivative,
      semantic_history: :purpose_bound_export_only,
      limitation: :inherits_every_source_classification
    },
    %{
      content_class: :backup_derivative,
      current_graphs: [],
      current_representation: :external_exact_store_derivative,
      classification: :backup_derivative,
      semantic_history: :restore_only,
      limitation: :physical_erasure_not_yet_guaranteed
    }
  ]

  @legacy_run_contract %{
    protocol_line: "1.x",
    graph_family: :run_attempt,
    immutable_after_closure: true,
    rewrite_allowed: false,
    completeness_claim: :bounded_observable_subset,
    event_accounting: :not_claimed,
    reconstruction: :stored_representations_only
  }

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec capture_outcomes() :: [atom()]
  def capture_outcomes, do: @capture_outcomes

  @spec forbidden_content() :: [atom()]
  def forbidden_content, do: @forbidden_content

  @spec content_inventory() :: [map()]
  def content_inventory, do: @content_inventory

  @spec content_contract(atom()) :: {:ok, map()} | :error
  def content_contract(content_class) when is_atom(content_class) do
    case Enum.find(@content_inventory, &(&1.content_class == content_class)) do
      nil -> :error
      contract -> {:ok, contract}
    end
  end

  def content_contract(_content_class), do: :error

  @spec legacy_run_contract() :: map()
  def legacy_run_contract, do: @legacy_run_contract

  @doc """
  Checks exact accounting for an expected set of body identities.

  This validation deliberately checks capture outcome only. Representation,
  location, availability, retention, and hold become independent dimensions in
  the shared policy contract; an outcome never implies one of those states.
  """
  @spec completely_accounted?([String.t()], %{optional(String.t()) => atom()}) :: boolean()
  def completely_accounted?(expected_body_ids, captures)
      when is_list(expected_body_ids) and is_map(captures) do
    expected = MapSet.new(expected_body_ids)

    length(expected_body_ids) == MapSet.size(expected) and
      Enum.all?(expected_body_ids, &valid_body_id?/1) and
      MapSet.new(Map.keys(captures)) == expected and
      Enum.all?(captures, fn {_body_id, outcome} -> outcome in @capture_outcomes end)
  end

  def completely_accounted?(_expected_body_ids, _captures), do: false

  defp valid_body_id?(value), do: is_binary(value) and value != "" and byte_size(value) <= 512
end
