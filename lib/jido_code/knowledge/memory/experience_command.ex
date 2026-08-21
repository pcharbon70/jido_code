defmodule JidoCode.Knowledge.Memory.ExperienceCommand do
  @moduledoc "Versioned proposal, validation, quarantine, and lifecycle command builder."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.CandidateFactOrSummary
  alias JidoCode.Knowledge.Memory.ExperienceCase
  alias JidoCode.Knowledge.Memory.ExperienceGraph
  alias JidoCode.Knowledge.Memory.ExperienceQuarantine
  alias JidoCode.Knowledge.Memory.ExperienceSourceManifest
  alias JidoCode.Knowledge.Memory.ExperienceTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @version "2.1.0"

  @spec propose(
          ExperienceCase.t(),
          ExperienceSourceManifest.t(),
          CandidateFactOrSummary.t(),
          map(),
          map(),
          keyword()
        ) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def propose(experience, manifest, summary, report, attributes, options \\ [])

  def propose(
        %ExperienceCase{} = experience,
        %ExperienceSourceManifest{} = manifest,
        %CandidateFactOrSummary{} = summary,
        %{clear?: true, reasons: []} = report,
        attributes,
        options
      )
      when is_map(attributes) and is_list(options) do
    statements =
      ExperienceCase.statements(experience) ++
        ExperienceSourceManifest.statements(manifest) ++
        CandidateFactOrSummary.statements(summary) ++ ExperienceQuarantine.statements(report)

    build("ProposeExperienceCase", experience, statements, attributes, options,
      guards: [{:subject_absent, experience.experience_graph_iri, experience.iri}]
    )
  end

  def propose(_experience, _manifest, _summary, _report, _attributes, _options),
    do: invalid(:propose_experience_case)

  @spec quarantine(ExperienceCase.t(), map(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def quarantine(experience, report, attributes, options \\ [])

  def quarantine(
        %ExperienceCase{} = experience,
        %{clear?: false, reasons: [_ | _]} = report,
        attributes,
        options
      )
      when is_map(attributes) and is_list(options) do
    build(
      "QuarantineExperienceCase",
      experience,
      ExperienceQuarantine.statements(report),
      attributes,
      options,
      guards: [{:subject_absent, experience.experience_graph_iri, report.iri}]
    )
  end

  def quarantine(_experience, _report, _attributes, _options),
    do: invalid(:quarantine_experience_case)

  @spec transition(ExperienceCase.t(), ExperienceTransition.t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def transition(experience, transition, attributes, options \\ [])

  def transition(
        %ExperienceCase{} = experience,
        %ExperienceTransition{} = transition,
        attributes,
        options
      )
      when is_map(attributes) and is_list(options) do
    command_type =
      if transition.next_state == :validated,
        do: "ValidateExperienceCase",
        else: "TransitionExperienceCase"

    build(
      command_type,
      experience,
      ExperienceTransition.statements(transition),
      attributes,
      options,
      guards: [
        {:subject_present, experience.experience_graph_iri, experience.iri},
        {:subject_present, experience.experience_graph_iri, transition.expected_predecessor},
        {:subject_absent, experience.experience_graph_iri, transition.iri}
      ]
    )
  end

  def transition(_experience, _transition, _attributes, _options),
    do: invalid(:transition_experience_case)

  defp build(command_type, experience, statements, attributes, options, build_options) do
    revision = attributes[:experience_graph_revision]
    recorded_at = attributes[:recorded_at]
    command_iri = command_iri(command_type, experience.iri, statements)

    with true <- is_integer(revision) and revision >= 0,
         true <-
           attributes[:expected_graph_revisions] == %{experience.experience_graph_iri => revision},
         {:ok, target} <-
           ExperienceGraph.target(
             experience.experience_graph_iri,
             revision,
             experience.repository_scope_iri,
             command_iri,
             recorded_at,
             statements
           ) do
      CommandEnvelope.new(
        %{
          command_type: command_type,
          command_version: @version,
          command_iri: command_iri,
          principal_iri: attributes[:principal_iri],
          actor_iri: attributes[:actor_iri],
          delegated_agent_iri: attributes[:delegated_agent_iri],
          delegation_iri: attributes[:delegation_iri],
          scope_iri: experience.repository_scope_iri,
          idempotency_key: command_iri,
          correlation_iri: attributes[:correlation_iri],
          causation_iri: attributes[:causation_iri],
          ontology_version: "1.2.0",
          shape_version: "1.2.0",
          expected_dataset_revision: attributes[:expected_dataset_revision],
          expected_graph_revisions: attributes[:expected_graph_revisions],
          reason: attributes[:reason],
          payload: %{
            changes: [target],
            guards: Keyword.fetch!(build_options, :guards),
            experience_case_iri: experience.iri,
            direct_side_effects: [],
            prompt_context: nil
          }
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:experience_command)
    end
  end

  defp command_iri(command_type, case_iri, statements) do
    {:ok, iri} =
      ResourceIdentity.deterministic(
        :command_request,
        :erlang.term_to_binary({command_type, case_iri, statements}, [:deterministic])
      )

    iri
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
