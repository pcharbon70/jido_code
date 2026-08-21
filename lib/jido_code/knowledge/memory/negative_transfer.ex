defmodule JidoCode.Knowledge.Memory.NegativeTransfer do
  @moduledoc "Derives ranking penalties and governed lifecycle reactions from independent assessments."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ExperienceCase
  alias JidoCode.Knowledge.Memory.ExperienceTransition
  alias JidoCode.Knowledge.Memory.MemoryUseAssessment

  @revision "1.0.0"
  @harmful ~w[misleading stale unauthorized]a

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec evaluate(ExperienceCase.t(), [MemoryUseAssessment.t()], ExperienceTransition.t(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def evaluate(
        %ExperienceCase{} = experience,
        assessments,
        %ExperienceTransition{} = current,
        attributes
      )
      when is_list(assessments) and is_map(attributes) do
    with true <- assessments != [] and Enum.all?(assessments, &valid?(&1, experience)),
         true <- current.case_iri == experience.iri do
      harmful = Enum.count(assessments, &(&1.outcome in @harmful))

      immediate? =
        Enum.any?(assessments, fn assessment ->
          assessment.signals.poisoning_success? or
            assessment.signals.suspicious_trigger_concentration >= 0.8 or
            assessment.outcome == :unauthorized
        end)

      next_state =
        cond do
          immediate? -> :invalidated
          harmful >= 2 -> :stale
          true -> nil
        end

      with {:ok, transition} <- maybe_transition(experience, current, next_state, attributes) do
        {:ok,
         %{
           revision: @revision,
           harmful_count: harmful,
           assessment_count: length(assessments),
           negative_transfer: harmful / length(assessments),
           immediate_disablement?: immediate?,
           transition: transition,
           original_case: experience
         }}
      end
    else
      false -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def evaluate(_experience, _assessments, _current, _attributes), do: invalid()

  defp valid?(%MemoryUseAssessment{} = assessment, experience),
    do: assessment.case_iri == experience.iri

  defp valid?(_assessment, _experience), do: false

  defp maybe_transition(_experience, _current, nil, _attributes), do: {:ok, nil}

  defp maybe_transition(experience, current, next_state, attributes) do
    ExperienceTransition.new(%{
      case_iri: experience.iri,
      prior_state: current.next_state,
      next_state: next_state,
      revision: current.revision + 1,
      expected_predecessor: current.iri,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:cause_iri],
      reason: "independent negative-transfer assessment",
      recorded_at: attributes[:recorded_at]
    })
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :negative_transfer)}
end
