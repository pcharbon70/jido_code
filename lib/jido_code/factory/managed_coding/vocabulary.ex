defmodule JidoCode.Factory.ManagedCoding.Vocabulary do
  @moduledoc "Closed managed coding protocol vocabularies. No caller value becomes an atom."

  @values %{
    runtime_phase:
      ~w[admitted preparing awaiting_model awaiting_tool awaiting_actor assembling_candidate candidate_ready cancelling completed cancelled failed]a,
    terminal_classification:
      ~w[success failure cancelled rejected timed_out budget_exhausted superseded incompatible_revision indeterminate]a,
    model_result_kind: ~w[tool_proposal completion_proposal clarification abstention failure]a,
    tool_result_kind: ~w[completed denied failed timed_out cancelled ambiguous]a,
    retry_class: ~w[replayable query_reconcilable compensatable manual_resolution_only never]a,
    cancellation_state:
      ~w[not_requested requested propagating cancelled late_result quarantined]a,
    candidate_handoff_state: ~w[not_started assembling ready handed_off rejected failed]a,
    enforcement_class: ~w[hard next_effect observed_only unavailable]a,
    profile_state: ~w[disabled enabled revoked superseded]a,
    rollout_stage: ~w[disabled evaluation shadow pilot production]a
  }

  @spec values(atom()) :: [atom()]
  def values(kind) when is_atom(kind), do: Map.get(@values, kind, [])

  @spec valid?(atom(), term()) :: boolean()
  def valid?(kind, value) when is_atom(kind) and is_atom(value), do: value in values(kind)
  def valid?(_kind, _value), do: false
end
