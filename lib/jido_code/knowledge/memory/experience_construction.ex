defmodule JidoCode.Knowledge.Memory.ExperienceConstruction do
  @moduledoc "Deterministic extraction of a case skeleton from one closed run and bounded evidence."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ExperienceCase
  alias JidoCode.Knowledge.Memory.ExperienceSourceManifest

  @revision "1.0.0"

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec build(map(), [map()], map()) ::
          {:ok, %{case: ExperienceCase.t(), manifest: ExperienceSourceManifest.t()}}
          | {:error, Error.t()}
  def build(run, later_evidence, attributes)
      when is_map(run) and is_list(later_evidence) and is_map(attributes) do
    effective_at = attributes[:effective_at]

    with true <- run[:closed?] == true and run[:finalization_state] in [:complete, :incomplete],
         true <- run[:source_event_iris] != [] and run[:semantic_event_digests] != [],
         %DateTime{} <- effective_at,
         true <- evidence_bounded?(later_evidence, effective_at),
         evidence_iris <- Enum.map(later_evidence, & &1.iri),
         revisions <- Map.merge(run.source_graph_revisions, evidence_revisions(later_evidence)),
         {:ok, manifest} <-
           ExperienceSourceManifest.new(%{
             repository_iri: run.repository_iri,
             repository_scope_iri: run.repository_scope_iri,
             attempt_iri: run.attempt_iri,
             effective_at: effective_at,
             source_event_iris: run.source_event_iris,
             source_artifact_iris: run.source_artifact_iris,
             source_evidence_iris: evidence_iris,
             source_graph_revisions: revisions
           }),
         signature <- failure_signature(run, later_evidence),
         {:ok, experience} <-
           ExperienceCase.new(
             attributes
             |> Map.merge(Map.take(run, case_run_fields()))
             |> Map.put(:problem_signature, signature)
             |> Map.put(:source_event_iris, manifest.source_event_iris)
             |> Map.put(:source_artifact_iris, manifest.source_artifact_iris)
             |> Map.put(:source_evidence_iris, manifest.source_evidence_iris)
           ) do
      {:ok, %{case: experience, manifest: manifest}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def build(_run, _later_evidence, _attributes), do: invalid()

  @spec failure_signature(map(), [map()]) :: String.t()
  def failure_signature(run, later_evidence) do
    {
      @revision,
      run[:task_class],
      run[:environment],
      run[:dependencies],
      Enum.sort(run[:symptoms] || []),
      Enum.sort(run[:semantic_event_digests] || []),
      Enum.sort(Enum.map(later_evidence, &{&1[:outcome], &1[:semantic_digest]}))
    }
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp evidence_bounded?(evidence, effective_at) do
    evidence != [] and
      Enum.all?(evidence, fn item ->
        is_map(item) and is_struct(item[:observed_at], DateTime) and
          DateTime.compare(item.observed_at, effective_at) in [:lt, :eq] and
          is_binary(item[:iri]) and is_binary(item[:graph_iri]) and
          is_integer(item[:graph_revision]) and item.graph_revision >= 0 and
          is_binary(item[:semantic_digest])
      end)
  end

  defp evidence_revisions(evidence),
    do: Map.new(evidence, &{&1.graph_iri, &1.graph_revision})

  defp case_run_fields do
    [
      :repository_iri,
      :repository_scope_iri,
      :experience_graph_iri,
      :repository_version,
      :task_class,
      :plan_phase,
      :environment,
      :dependencies,
      :symptoms,
      :reproduction,
      :inspected_files,
      :inspected_symbols,
      :interventions,
      :disproved_assumptions,
      :terminal_intervention,
      :verification_iris,
      :delayed_outcome,
      :exceptions,
      :limitations,
      :case_class,
      :recorded_at,
      :actor_iri,
      :cause_iri
    ]
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :experience_construction)}
end
