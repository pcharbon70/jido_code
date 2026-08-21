defmodule JidoCode.Knowledge.Memory.ProcedureValidation do
  @moduledoc "Independent execution validation, applicability counts, and drift evaluation for procedures."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ProcedureRevision
  alias JidoCode.Knowledge.Memory.ProcedureTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @outcomes ~w[success failure revert incident negative_transfer delayed_survival]a

  def revision, do: @revision
  def outcomes, do: @outcomes

  def validate(
        %ProcedureRevision{} = procedure,
        %{clear?: true, reasons: []},
        executions,
        attributes
      )
      when is_list(executions) and is_map(attributes) do
    with true <- length(executions) >= 2,
         true <- Enum.all?(executions, &execution?(&1, procedure, attributes)),
         true <- Enum.all?(executions, &(&1.actor_iri != procedure.transition.actor_iri)),
         :ok <- ResourceIdentity.validate(attributes[:validator_iri]),
         true <- attributes[:validator_iri] != procedure.transition.actor_iri,
         true <- attributes[:current_applicability] == procedure.applicability,
         true <- attributes[:source_revisions] == expected_sources(executions),
         counts <- counts(executions),
         true <- counts.success + counts.delayed_survival > 0,
         {:ok, transition} <-
           ProcedureTransition.new(%{
             procedure_iri: procedure.iri,
             prior_state: :candidate,
             next_state: :validated,
             revision: 1,
             expected_predecessor: procedure.transition.iri,
             actor_iri: attributes.validator_iri,
             cause_iri: attributes[:evidence_iri],
             reason: "independent executions validated procedure applicability",
             recorded_at: attributes[:recorded_at]
           }) do
      {:ok,
       %{
         revision: @revision,
         procedure: procedure,
         transition: transition,
         counts: counts,
         execution_iris: Enum.map(executions, & &1.iri),
         source_revisions: attributes.source_revisions,
         validator_iri: attributes.validator_iri,
         evidence_iri: attributes.evidence_iri
       }}
    else
      _invalid -> {:error, Error.new(:unauthorized, :procedure_validation)}
    end
  rescue
    _error -> {:error, Error.new(:unauthorized, :procedure_validation)}
  end

  def validate(_, _, _, _), do: {:error, Error.new(:unauthorized, :procedure_validation)}

  def drift(
        %ProcedureRevision{} = procedure,
        current,
        %ProcedureTransition{} = transition,
        attributes
      ) do
    drifted =
      current[:applicability] != procedure.applicability or
        current[:framework] != procedure.framework or
        current[:framework_version] != procedure.framework_version or
        current[:required_tools] != procedure.required_tools or
        current[:policy_version] != procedure.applicability.policy_version or
        current[:artifact_current?] != true

    next_state = if drifted, do: :stale, else: nil

    if next_state do
      ProcedureTransition.new(%{
        procedure_iri: procedure.iri,
        prior_state: transition.next_state,
        next_state: next_state,
        revision: transition.revision + 1,
        expected_predecessor: transition.iri,
        actor_iri: attributes[:actor_iri],
        cause_iri: attributes[:cause_iri],
        reason: "procedure applicability precondition drift",
        recorded_at: attributes[:recorded_at]
      })
    else
      {:ok, nil}
    end
  end

  defp execution?(execution, procedure, attributes) do
    is_map(execution) and ResourceIdentity.validate(execution[:iri]) == :ok and
      ResourceIdentity.validate(execution[:actor_iri]) == :ok and execution[:outcome] in @outcomes and
      execution[:applicability] == procedure.applicability and
      execution[:framework] == procedure.framework and
      execution[:framework_version] == procedure.framework_version and
      execution[:tools] == procedure.required_tools and
      execution[:policy_version] == procedure.applicability.policy_version and
      execution[:source_revisions] == attributes[:source_revisions]
  end

  defp counts(executions),
    do:
      Map.new(@outcomes, fn outcome ->
        {outcome, Enum.count(executions, &(&1.outcome == outcome))}
      end)

  defp expected_sources([first | _]), do: first.source_revisions
end
