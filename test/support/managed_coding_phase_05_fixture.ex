defmodule JidoCode.TestSupport.ManagedCodingPhase05Fixture do
  @moduledoc false

  @crash_points ~w[coordinator agent dispatcher adapter workspace provider verifier]a
  @effect_points ~w[before_dispatch during_effect after_outcome terminal_race]a
  @faults ~w[ambiguity duplicate late_output cancellation lease_expiry graph_contention corrupt_evidence tenant_isolation sandbox_escape secret_leak output_flood]a

  def crash_matrix do
    for component <- @crash_points, point <- @effect_points do
      %{component: component, point: point, outcome: expected_crash_outcome(point)}
    end
  end

  def fault_matrix do
    Enum.map(@faults, &%{fault: &1, outcome: expected_fault_outcome(&1), authoritative: false})
  end

  defp expected_crash_outcome(:before_dispatch), do: :safe_replay
  defp expected_crash_outcome(:during_effect), do: :reconcile_or_quarantine
  defp expected_crash_outcome(:after_outcome), do: :resume_from_outcome
  defp expected_crash_outcome(:terminal_race), do: :compare_and_commit

  defp expected_fault_outcome(fault)
       when fault in [
              :ambiguity,
              :duplicate,
              :late_output,
              :cancellation,
              :lease_expiry,
              :graph_contention
            ],
       do: :contained

  defp expected_fault_outcome(_fault), do: :denied
end
