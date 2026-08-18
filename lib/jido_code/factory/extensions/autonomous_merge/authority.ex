defmodule JidoCode.Factory.Extensions.AutonomousMerge.Authority do
  @moduledoc "Fail-closed autonomous-merge authority; no current policy can grant merge."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.AutonomousMerge.Pilot
  alias JidoCode.Factory.Extensions.AutonomousMerge.Policy

  @spec authorize(Policy.t(), Pilot.t()) :: {:error, AdapterError.t()}
  def authorize(%Policy{} = policy, %Pilot{} = pilot) do
    if Policy.valid?(policy) and Pilot.valid?(pilot, policy) do
      blocked()
    else
      blocked()
    end
  end

  def authorize(_policy, _pilot), do: blocked()

  @spec shadow_review(Policy.t(), Pilot.t()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def shadow_review(%Policy{} = policy, %Pilot{} = pilot) do
    if Policy.valid?(policy) and Pilot.valid?(pilot, policy) do
      {:ok,
       %{
         status: :human_merge_required,
         authority: :shadow_only,
         autonomous_merge_authorized: false,
         immediate_disable_triggers: policy.immediate_disable_triggers,
         pilot_digest: pilot.digest
       }}
    else
      {:error, AdapterError.new(:invalid_input, :autonomous_merge_shadow)}
    end
  end

  def shadow_review(_policy, _pilot),
    do: {:error, AdapterError.new(:invalid_input, :autonomous_merge_shadow)}

  defp blocked, do: {:error, AdapterError.new(:unauthorized, :autonomous_merge_blocked)}
end
