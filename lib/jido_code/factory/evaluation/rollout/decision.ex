defmodule JidoCode.Factory.Evaluation.Rollout.Decision do
  @moduledoc "Digest-bound stage decision consumed by the rollout coordinator."

  alias JidoCode.Factory.Evaluation.Rollout.Evidence
  alias JidoCode.Factory.Evaluation.Rollout.Stage

  @enforce_keys [
    :evidence_iri,
    :model_access_profile_iri,
    :profile_revision,
    :from_stage,
    :requested_stage,
    :status,
    :reasons,
    :authorized_actions,
    :evidence_digest,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @statuses ~w[advance hold disabled]a

  @spec build(Evidence.t(), atom(), [atom()]) :: t()
  def build(%Evidence{} = evidence, status, reasons)
      when status in @statuses and is_list(reasons) do
    authorized_stage =
      if status == :advance, do: evidence.requested_stage, else: evidence.current_stage

    actions = if status == :disabled, do: [], else: Stage.actions(authorized_stage)

    frozen = %{
      evidence_iri: evidence.evidence_iri,
      model_access_profile_iri: evidence.model_access_profile_iri,
      profile_revision: evidence.profile_revision,
      from_stage: evidence.current_stage,
      requested_stage: evidence.requested_stage,
      status: status,
      reasons: reasons |> Enum.uniq() |> Enum.sort(),
      authorized_actions: actions,
      evidence_digest: evidence.digest
    }

    struct!(__MODULE__, Map.put(frozen, :digest, digest(frozen)))
  end

  @spec valid?(term()) :: boolean()
  def valid?(%__MODULE__{} = decision) do
    decision.digest ==
      decision
      |> Map.from_struct()
      |> Map.drop([:digest])
      |> digest()
  end

  def valid?(_decision), do: false

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
