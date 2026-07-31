defmodule JidoCode.Knowledge.CommandProvenance do
  @moduledoc false

  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.ChangeSet
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.ResourceIdentity

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_activity "http://www.w3.org/ns/prov#Activity"
  @prov_entity "http://www.w3.org/ns/prov#Entity"
  @prov_associated "http://www.w3.org/ns/prov#wasAssociatedWith"
  @prov_generated "http://www.w3.org/ns/prov#generated"
  @prov_generated_at "http://www.w3.org/ns/prov#generatedAtTime"
  @prov_used "http://www.w3.org/ns/prov#used"

  @spec identities(CommandEnvelope.t()) :: {:ok, map()}
  def identities(%CommandEnvelope{} = envelope) do
    material =
      Enum.join(
        [
          envelope.actor_iri,
          envelope.scope_iri,
          envelope.command_type,
          envelope.command_version,
          envelope.idempotency_key
        ],
        "\n"
      )

    {:ok, request_iri} = ResourceIdentity.deterministic(:command_request, material)
    digest = sha256(request_iri)

    {:ok,
     %{
       request_iri: request_iri,
       commit_id: "urn:jido-code:commit:command_#{binary_part(digest, 0, 40)}",
       audit_iri: envelope.command_iri <> "/audit",
       receipt_iri: envelope.command_iri <> "/receipt"
     }}
  end

  @spec quads(CommandEnvelope.t(), ChangeSet.t(), map(), map(), String.t()) :: [RDF.Quad.t()]
  def quads(envelope, change_set, authority, identities, audit_graph) do
    command = envelope.command_iri
    change = change_set.change_set_iri
    audit = identities.audit_iri
    request = identities.request_iri
    receipt = identities.receipt_iri
    issued = RDF.XSD.DateTime.new(envelope.issued_at)
    capability = Authorization.capability_iri(authority.capability)

    base = [
      quad(command, @rdf_type, RDF.iri(@prov_activity), audit_graph),
      quad(command, @jf <> "commandClass", command_class(envelope.command_type), audit_graph),
      quad(command, @jf <> "commandVersion", envelope.command_version, audit_graph),
      quad(command, @prov_associated, RDF.iri(envelope.actor_iri), audit_graph),
      quad(command, @jf <> "principal", RDF.iri(envelope.principal_iri), audit_graph),
      quad(command, @jf <> "inScope", RDF.iri(envelope.scope_iri), audit_graph),
      quad(command, @jf <> "correlation", RDF.iri(envelope.correlation_iri), audit_graph),
      quad(command, @jf <> "cause", RDF.iri(envelope.causation_iri), audit_graph),
      quad(command, @prov_generated_at, issued, audit_graph),
      quad(command, @prov_generated, RDF.iri(change), audit_graph),
      quad(command, @prov_generated, RDF.iri(receipt), audit_graph),
      quad(command, @prov_used, RDF.iri(request), audit_graph),
      quad(request, @rdf_type, RDF.iri(@prov_entity), audit_graph),
      quad(request, @jf <> "requestFingerprint", change_set.request_fingerprint, audit_graph),
      quad(change, @rdf_type, RDF.iri(@prov_entity), audit_graph),
      quad(change, @jf <> "command", RDF.iri(command), audit_graph),
      quad(change, @jf <> "ontologyVersion", ontology(envelope.ontology_version), audit_graph),
      quad(change, @jf <> "shapeVersion", envelope.shape_version, audit_graph),
      quad(change, @jf <> "validatorVersion", "1.0.0", audit_graph),
      quad(change, @jf <> "assertionCount", change_set.assertion_count, audit_graph),
      quad(change, @jf <> "supersessionCount", change_set.supersession_count, audit_graph),
      quad(receipt, @rdf_type, RDF.iri(@prov_entity), audit_graph),
      quad(receipt, @jf <> "commitIdentity", RDF.iri(identities.commit_id), audit_graph),
      quad(audit, @rdf_type, RDF.iri(@prov_activity), audit_graph),
      quad(audit, @prov_associated, RDF.iri(envelope.actor_iri), audit_graph),
      quad(audit, @jf <> "auditsCommand", RDF.iri(command), audit_graph),
      quad(audit, @jf <> "authorizationGrant", RDF.iri(authority.grant_iri), audit_graph),
      quad(audit, @jf <> "capability", RDF.iri(capability), audit_graph),
      quad(audit, @jf <> "outcome", outcome(:committed), audit_graph),
      quad(audit, @jf <> "recordedAt", issued, audit_graph)
    ]

    targets =
      Enum.flat_map(change_set.targets, fn target ->
        [
          quad(change, @jf <> "targetGraph", RDF.iri(target.graph_iri), audit_graph),
          quad(
            audit,
            @jf <> "affectedGraphFamily",
            graph_family(target.family),
            audit_graph
          )
        ]
      end)

    delegation =
      if is_binary(envelope.delegation_iri) do
        [quad(command, @jf <> "delegation", RDF.iri(envelope.delegation_iri), audit_graph)]
      else
        []
      end

    Enum.uniq(base ++ targets ++ delegation)
  end

  defp command_class(name), do: RDF.iri(Authorization.command_class_iri(name))

  defp graph_family(family),
    do: RDF.iri("https://jido.run/ontology/graph-family/#{Atom.to_string(family)}")

  defp ontology(version), do: RDF.iri("https://jido.run/ontology/release/#{version}")
  defp outcome(value), do: RDF.iri("https://jido.run/ontology/outcome/#{value}")
  defp quad(subject, predicate, object, graph), do: RDF.quad(subject, predicate, object, graph)

  defp sha256(value) do
    value
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
