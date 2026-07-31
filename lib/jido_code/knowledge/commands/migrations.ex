defmodule JidoCode.Knowledge.Commands.Migrations do
  @moduledoc """
  Creates an attributed target graph for a transform-required ontology change.

  Source graphs are never rewritten. The target graph and completed migration
  activity are admitted together through the graph creation command.
  """

  alias JidoCode.Knowledge.Commands.Graphs
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Ontology.Evolution
  alias JidoCode.Knowledge.ResourceIdentity

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_used "http://www.w3.org/ns/prov#used"
  @prov_generated "http://www.w3.org/ns/prov#generated"
  @prov_associated "http://www.w3.org/ns/prov#wasAssociatedWith"
  @prov_started "http://www.w3.org/ns/prov#startedAtTime"
  @prov_ended "http://www.w3.org/ns/prov#endedAtTime"

  @spec create(atom(), map(), [RDF.Statement.coercible()], map(), keyword()) :: term()
  def create(target_family, target_scopes, transformed_payload, attributes, options \\ [])

  def create(target_family, target_scopes, transformed_payload, attributes, options)
      when is_atom(target_family) and is_map(target_scopes) and is_list(transformed_payload) and
             is_map(attributes) and is_list(options) do
    with {:ok, normalized} <- validate_attributes(attributes),
         {:ok, target_graph} <- GraphRegistry.graph_iri(target_family, target_scopes),
         :ok <- validate_graphs(normalized.source_graph, target_graph),
         {:ok, _plan} <-
           Evolution.plan(
             normalized.source_version,
             normalized.target_version,
             :transform_required,
             %{
               transformer_version: normalized.transformer_version,
               rollback_posture: normalized.rollback_posture
             }
           ) do
      migration_payload = migration_quads(normalized, target_graph, length(transformed_payload))

      graph_attributes = %{
        owner_scope: normalized.owner_scope,
        ontology_version: "https://jido.run/ontology/release/#{normalized.target_version}",
        creation_activity: normalized.activity,
        created_at: normalized.completed_at,
        closed_at: normalized.completed_at,
        parent_graph: normalized.source_graph,
        source_revision: normalized.source_revision
      }

      Graphs.create(
        target_family,
        target_scopes,
        transformed_payload ++ migration_payload,
        graph_attributes,
        options
      )
    end
  end

  def create(_target_family, _target_scopes, _payload, _attributes, _options),
    do: {:error, Error.new(:invalid_input, :graph_migration)}

  defp validate_attributes(attributes) do
    required = [
      :source_graph,
      :source_version,
      :target_version,
      :transformer_version,
      :actor,
      :activity,
      :owner_scope,
      :validation_report,
      :rollback_posture,
      :started_at,
      :completed_at,
      :source_count
    ]

    with true <- Enum.all?(required, &Map.has_key?(attributes, &1)),
         {:ok, _source_family} <- GraphRegistry.identify(attributes.source_graph),
         :ok <- ResourceIdentity.validate(attributes.activity),
         :ok <- ResourceIdentity.validate(attributes.actor),
         :ok <- ResourceIdentity.validate(attributes.owner_scope),
         :ok <- ResourceIdentity.validate(attributes.validation_report),
         true <- match?(%DateTime{}, attributes.started_at),
         true <- match?(%DateTime{}, attributes.completed_at),
         true <- DateTime.compare(attributes.started_at, attributes.completed_at) in [:lt, :eq],
         true <- is_integer(attributes.source_count) and attributes.source_count >= 0,
         true <- attributes.rollback_posture in [:retain_source, :revert_selector, :manual] do
      {:ok,
       Map.take(attributes, required ++ [:source_revision])
       |> Map.put_new(:source_revision, nil)}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :graph_migration)}
    end
  end

  defp validate_graphs(source_graph, target_graph) do
    if source_graph != target_graph,
      do: :ok,
      else: {:error, Error.new(:invalid_input, :graph_migration)}
  end

  defp migration_quads(attributes, target_graph, target_count) do
    activity = attributes.activity

    [
      triple(activity, @rdf_type, iri(@jf <> "MigrationActivity")),
      triple(activity, @prov_used, iri(attributes.source_graph)),
      triple(activity, @prov_generated, iri(target_graph)),
      triple(activity, @prov_associated, iri(attributes.actor)),
      triple(activity, @prov_started, RDF.literal(attributes.started_at)),
      triple(activity, @prov_ended, RDF.literal(attributes.completed_at)),
      triple(activity, @jf <> "sourceGraph", iri(attributes.source_graph)),
      triple(activity, @jf <> "targetGraph", iri(target_graph)),
      triple(
        activity,
        @jf <> "sourceOntologyVersion",
        iri("https://jido.run/ontology/release/#{attributes.source_version}")
      ),
      triple(
        activity,
        @jf <> "targetOntologyVersion",
        iri("https://jido.run/ontology/release/#{attributes.target_version}")
      ),
      triple(activity, @jf <> "transformerVersion", RDF.literal(attributes.transformer_version)),
      triple(activity, @jf <> "validationReport", iri(attributes.validation_report)),
      triple(
        activity,
        @jf <> "rollbackPosture",
        RDF.literal(Atom.to_string(attributes.rollback_posture))
      ),
      triple(
        activity,
        @jf <> "sourceCount",
        RDF.XSD.NonNegativeInteger.new(attributes.source_count)
      ),
      triple(activity, @jf <> "targetCount", RDF.XSD.NonNegativeInteger.new(target_count))
    ]
  end

  defp triple(subject, predicate, object), do: RDF.triple(subject, predicate, object)
  defp iri(value), do: RDF.iri(value)
end
