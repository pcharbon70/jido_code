defmodule JidoCode.Factory.Extensions.AutonomousMerge.Policy do
  @moduledoc "Pinned blocker and future-pilot constraints for autonomous merge."

  alias JidoCode.Factory.Tool.Definition

  @contract_version "1.0.0"
  @prerequisites [
    :separate_accepted_adr,
    :release_gate,
    :production_shadow_evidence,
    :pull_request_evidence
  ]
  @pilot_task_classes [:documentation, :dependency_patch, :mechanical_refactor, :test_only]
  @disable_triggers [
    :evidence_mismatch,
    :protected_branch_mutation,
    :sandbox_escape,
    :secret_exposure,
    :stale_fence
  ]

  @enforce_keys [
    :revision,
    :status,
    :adr_status,
    :autonomous_merge_authorized,
    :prerequisites,
    :pilot_task_classes,
    :immediate_disable_triggers,
    :human_merge_required,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec current() :: t()
  def current do
    attributes = %{
      revision: "autonomous-merge-blocker-1",
      status: :blocked,
      adr_status: :missing,
      autonomous_merge_authorized: false,
      prerequisites: @prerequisites,
      pilot_task_classes: @pilot_task_classes,
      immediate_disable_triggers: @disable_triggers,
      human_merge_required: true
    }

    struct!(__MODULE__, Map.put(attributes, :digest, Definition.digest(attributes)))
  end

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = policy), do: policy == current()
  def valid?(_policy), do: false
end
