defmodule JidoCode.Factory.Evaluation.Rollout.Coordinator do
  @moduledoc "Enforces rollout authority from an untampered recorded gate decision."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Evaluation.Rollout.Decision

  @spec authorize(Decision.t(), atom()) :: :ok | {:error, AdapterError.t()}
  def authorize(%Decision{} = decision, action) when is_atom(action) do
    cond do
      not Decision.valid?(decision) -> unauthorized(:rollout_decision_digest)
      decision.status == :disabled -> unauthorized(:rollout_profile_disabled)
      action not in decision.authorized_actions -> unauthorized(:rollout_stage_authority)
      true -> :ok
    end
  end

  def authorize(_decision, _action), do: unauthorized(:rollout_stage_authority)

  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end
