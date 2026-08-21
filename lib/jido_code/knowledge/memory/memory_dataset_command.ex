defmodule JidoCode.Knowledge.Memory.MemoryDatasetCommand do
  @moduledoc "Semantic commands for governed dataset manifests, rows, export, lifecycle, and evaluation."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.DatasetExportPermit
  alias JidoCode.Knowledge.Memory.MemoryDatasetArtifact
  alias JidoCode.Knowledge.Memory.MemoryDatasetGraph
  alias JidoCode.Knowledge.Memory.MemoryDatasetManifest
  alias JidoCode.Knowledge.Memory.MemoryDatasetRow
  alias JidoCode.Knowledge.Memory.MemoryEvaluationProgram
  alias JidoCode.Knowledge.ResourceIdentity

  @jf "https://jido.run/ontology/factory#"

  def store_manifest(
        %MemoryDatasetManifest{} = manifest,
        graph,
        revision,
        attributes,
        options \\ []
      ) do
    build(
      "StoreMemoryDatasetManifest",
      CommandRegistry.dataset_version(),
      manifest.iri,
      MemoryDatasetManifest.statements(manifest),
      [{:subject_absent, graph, manifest.iri}],
      graph,
      revision,
      manifest.cohort_iri,
      attributes,
      options
    )
  end

  def record_rows(
        %MemoryDatasetManifest{} = manifest,
        rows,
        graph,
        revision,
        attributes,
        options \\ []
      )
      when is_list(rows) and rows != [] do
    with true <-
           Enum.all?(
             rows,
             &match?(%MemoryDatasetRow{manifest_iri: iri} when iri == manifest.iri, &1)
           ) do
      build(
        "RecordMemoryDatasetRows",
        CommandRegistry.dataset_version(),
        manifest.iri,
        Enum.flat_map(rows, &MemoryDatasetRow.statements/1),
        [{:subject_present, graph, manifest.iri}] ++
          Enum.map(rows, &{:subject_absent, graph, &1.iri}),
        graph,
        revision,
        manifest.cohort_iri,
        attributes,
        options
      )
    else
      _invalid -> invalid()
    end
  end

  def authorize_export(
        %MemoryDatasetManifest{} = manifest,
        %DatasetExportPermit{} = permit,
        graph,
        revision,
        attributes,
        options \\ []
      ) do
    build(
      "AuthorizeMemoryDatasetExport",
      CommandRegistry.dataset_export_version(),
      permit.iri,
      DatasetExportPermit.statements(permit),
      [{:subject_present, graph, manifest.iri}, {:subject_absent, graph, permit.iri}],
      graph,
      revision,
      manifest.cohort_iri,
      attributes,
      options
    )
  end

  def record_export(
        %MemoryDatasetManifest{} = manifest,
        %MemoryDatasetArtifact{} = artifact,
        graph,
        revision,
        attributes,
        options \\ []
      ) do
    build(
      "RecordMemoryDatasetExport",
      CommandRegistry.dataset_export_version(),
      artifact.iri,
      MemoryDatasetArtifact.statements(artifact),
      [
        {:subject_present, graph, manifest.iri},
        {:subject_present, graph, artifact.permit_iri},
        {:subject_absent, graph, artifact.iri}
      ],
      graph,
      revision,
      manifest.cohort_iri,
      attributes,
      options
    )
  end

  def record_evaluation(
        %MemoryDatasetManifest{} = manifest,
        report,
        graph,
        revision,
        attributes,
        options \\ []
      )
      when is_map(report) do
    build(
      "RecordMemoryEvaluation",
      CommandRegistry.memory_evaluation_version(),
      report.iri,
      MemoryEvaluationProgram.statements(report),
      [{:subject_present, graph, manifest.iri}, {:subject_absent, graph, report.iri}],
      graph,
      revision,
      manifest.cohort_iri,
      attributes,
      options
    )
  end

  def transition_lifecycle(
        %MemoryDatasetManifest{} = manifest,
        transition,
        graph,
        revision,
        attributes,
        options \\ []
      )
      when is_map(transition) do
    statements = [
      {transition.transition_iri, @jf <> "datasetArtifact", RDF.iri(transition.artifact_iri)},
      {transition.transition_iri, @jf <> "priorState", concept(transition.prior_state)},
      {transition.transition_iri, @jf <> "nextState", concept(transition.next_state)},
      {transition.transition_iri, @jf <> "lifecycleEvent", concept(transition.event)},
      {transition.transition_iri, @jf <> "evidence", RDF.iri(transition.evidence_iri)},
      {transition.transition_iri, @jf <> "recordedAt",
       RDF.XSD.DateTime.new(transition.recorded_at)}
    ]

    build(
      "TransitionMemoryDatasetLifecycle",
      CommandRegistry.dataset_export_version(),
      transition.transition_iri,
      statements,
      [
        {:subject_present, graph, transition.artifact_iri},
        {:subject_absent, graph, transition.transition_iri}
      ],
      graph,
      revision,
      manifest.cohort_iri,
      attributes,
      options
    )
  end

  defp build(
         type,
         version,
         identity,
         statements,
         guards,
         graph,
         revision,
         owner_scope,
         attributes,
         options
       ) do
    with true <- attributes[:expected_graph_revisions] == %{graph => revision},
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, Enum.join([type, identity], "\n")),
         {:ok, target} <-
           MemoryDatasetGraph.target(
             graph,
             revision,
             owner_scope,
             command_iri,
             attributes[:recorded_at],
             statements
           ) do
      CommandEnvelope.new(
        %{
          command_type: type,
          command_version: version,
          command_iri: command_iri,
          principal_iri: attributes[:principal_iri],
          actor_iri: attributes[:actor_iri],
          delegated_agent_iri: attributes[:delegated_agent_iri],
          delegation_iri: attributes[:delegation_iri],
          scope_iri: attributes[:scope_iri],
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
            guards: guards,
            dataset_resource_iri: identity,
            direct_side_effects: [],
            prompt_context: nil
          }
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  end

  defp concept(value),
    do: RDF.iri("https://jido.run/ontology/concept/" <> Macro.camelize(to_string(value)))

  defp invalid, do: {:error, Error.new(:invalid_input, :memory_dataset_command)}
end
