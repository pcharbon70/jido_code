defmodule JidoCode.Knowledge.QuerySource do
  @moduledoc false

  alias JidoCode.Knowledge.Vocabulary

  @jf "https://jido.run/ontology/factory#"
  @prov "http://www.w3.org/ns/prov#"

  @spec fetch(atom()) :: String.t()
  def fetch(:dataset_revision) do
    """
    SELECT ?revision WHERE {
      GRAPH <#{Vocabulary.system_graph()}> {
        <#{Vocabulary.dataset()}> <#{Vocabulary.predicate(:dataset_revision)}> ?revision .
      }
    }
    ORDER BY DESC(?revision)
    LIMIT 1
    """
  end

  def fetch(:graph_metadata) do
    """
    SELECT ?predicate ?value WHERE {
      GRAPH {{graph}} {
        {{graph}} ?predicate ?value .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:ontology_compatibility) do
    """
    SELECT ?predicate ?object WHERE {
      GRAPH {{graph}} {
        <https://jido.run/ontology/release/1.0.0> ?predicate ?object .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:command_receipt) do
    """
    SELECT ?receipt WHERE {
      GRAPH {{graph}} {
        {{resource}} <#{@prov}generated> ?receipt .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:audit_reference) do
    """
    SELECT ?audit WHERE {
      GRAPH {{graph}} {
        ?audit <#{@jf}auditsCommand> {{resource}} .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:graph_health) do
    """
    ASK {
      GRAPH {{graph}} {
        {{graph}} a <#{@jf}NamedGraph> .
      }
    }
    """
  end

  def fetch(:resource_description) do
    """
    CONSTRUCT { {{resource}} ?predicate ?value }
    WHERE {
      GRAPH {{graph}} { {{resource}} ?predicate ?value }
    }
    LIMIT {{triple_limit}}
    """
  end

  def fetch(:semantic_neighborhood) do
    """
    CONSTRUCT {
      {{resource}} ?outPredicate ?outValue .
      ?inSubject ?inPredicate {{resource}} .
    }
    WHERE {
      GRAPH {{graph}} {
        { {{resource}} ?outPredicate ?outValue }
        UNION
        { ?inSubject ?inPredicate {{resource}} }
      }
    }
    LIMIT {{triple_limit}}
    """
  end

  def fetch(:provenance_chain) do
    """
    CONSTRUCT { {{resource}} <#{@prov}wasDerivedFrom> ?source }
    WHERE {
      GRAPH {{graph}} {
        {{resource}} <#{@prov}wasDerivedFrom> ?source .
      }
    }
    LIMIT {{triple_limit}}
    """
  end

  def fetch(:supporting_claims) do
    claim_query("supports")
  end

  def fetch(:contradicting_claims) do
    claim_query("contradicts")
  end

  def fetch(:supersession) do
    """
    SELECT ?resource ?superseder WHERE {
      GRAPH {{graph}} {
        { {{resource}} <#{@jf}supersededBy> ?superseder }
        UNION
        { ?superseder <#{@jf}supersedes> {{resource}} }
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:transition_endpoint) do
    transition_query(true)
  end

  def fetch(:transition_history) do
    transition_query(false)
  end

  def fetch(:temporal_as_of) do
    """
    SELECT ?assertion ?recorded WHERE {
      GRAPH {{graph}} {
        ?assertion <#{@jf}about> {{resource}} .
        ?assertion <#{@jf}recordedAt> ?recorded .
        FILTER(?recorded <= {{instant}})
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:graph_completeness) do
    """
    SELECT ?assertion ?predicate ?value WHERE {
      GRAPH {{graph}} {
        ?assertion a <#{@jf}CompletenessAssertion> ;
                   <#{@jf}about> {{resource}} ;
                   ?predicate ?value .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:derived_graph_freshness) do
    """
    SELECT ?predicate ?value WHERE {
      GRAPH {{graph}} {
        {{graph}} ?predicate ?value .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:repository_description), do: fetch(:resource_description)

  def fetch(:locator_resolution) do
    """
    SELECT ?repository WHERE {
      GRAPH {{graph}} {
        ?repository <#{@jf}locatedBy> {{resource}} .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:active_enrollment) do
    """
    SELECT ?enrollment ?policy ?locator ?validFrom ?validTo WHERE {
      GRAPH {{graph}} {
        ?enrollment <#{@jf}manages> {{resource}} .
        OPTIONAL { ?enrollment <#{@jf}governedBy> ?policy }
        OPTIONAL { ?enrollment <#{@jf}locatedBy> ?locator }
        OPTIONAL { ?enrollment <#{@jf}validFrom> ?validFrom }
        OPTIONAL { ?enrollment <#{@jf}validTo> ?validTo }
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:enrollment_history) do
    """
    SELECT ?enrollment ?transition ?state ?revision ?predecessor ?actor ?cause ?policy ?locator WHERE {
      GRAPH {{graph}} {
        ?transition <#{@jf}transitionSubject> ?enrollment ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}subjectRevision> ?revision ;
                    <#{@prov}wasAssociatedWith> ?actor ;
                    <#{@jf}cause> ?cause .
        ?decision <#{@jf}accepts> ?transition .
        OPTIONAL { ?transition <#{@jf}expectedPredecessor> ?predecessor }
        OPTIONAL { ?transition <#{@jf}governedBy> ?policy }
        OPTIONAL { ?transition <#{@jf}locatedBy> ?locator }
        FILTER(?enrollment = {{resource}})
      }
    }
    ORDER BY ?revision
    LIMIT {{row_limit}}
    """
  end

  def fetch(:factory_repository_cohort) do
    """
    SELECT ?enrollment ?repository WHERE {
      GRAPH {{graph}} {
        {{resource}} <#{@jf}enrolls> ?enrollment .
        ?enrollment <#{@jf}manages> ?repository .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:latest_complete_observation) do
    """
    SELECT ?batch ?recorded ?observed WHERE {
      GRAPH {{graph}} {
        ?batch a <#{@jf}ObservationBatch> ;
               <#{@jf}validFor> {{resource}} ;
               <#{@jf}recordedAt> ?recorded ;
               <#{@jf}completenessState> <https://jido.run/ontology/concept/Complete> .
        OPTIONAL { ?batch <#{@jf}sourceObservedAt> ?observed }
      }
    }
    ORDER BY DESC(?recorded)
    LIMIT 1
    """
  end

  def fetch(:observation_claim_history) do
    """
    SELECT ?claim ?predicate ?object ?state ?recorded ?observed WHERE {
      GRAPH {{graph}} {
        ?claim a <#{@jf}Claim> ;
               <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> {{resource}} ;
               <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> ?predicate ;
               <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> ?object ;
               <#{@jf}epistemicState> ?state ;
               <#{@jf}recordedAt> ?recorded .
        OPTIONAL { ?claim <#{@jf}sourceObservedAt> ?observed }
      }
    }
    ORDER BY ?recorded
    LIMIT {{row_limit}}
    """
  end

  def fetch(:observation_contradictions) do
    """
    SELECT ?claim ?contradiction WHERE {
      GRAPH {{graph}} {
        { {{resource}} <#{@jf}contradicts> ?contradiction }
        UNION
        { ?claim <#{@jf}contradicts> {{resource}} }
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:provider_freshness) do
    """
    SELECT ?batch ?recorded ?observed ?state WHERE {
      GRAPH {{graph}} {
        ?batch a <#{@jf}ObservationBatch> ;
               <#{@jf}validFor> {{resource}} ;
               <#{@jf}recordedAt> ?recorded ;
               <#{@jf}completenessState> ?state .
        OPTIONAL { ?batch <#{@jf}sourceObservedAt> ?observed }
      }
    }
    ORDER BY DESC(?recorded)
    LIMIT {{row_limit}}
    """
  end

  def fetch(:repository_snapshot_description), do: fetch(:resource_description)

  def fetch(:snapshot_readiness_freshness) do
    """
    SELECT ?readiness ?observed ?batch ?recorded WHERE {
      GRAPH {{graph}} {
        {{snapshot}} a <#{@jf}RepositorySnapshot> ;
                     <#{@jf}analyzerReadiness> ?readiness ;
                     <#{@jf}sourceObservedAt> ?observed .
        ?batch <#{@prov}generated> {{snapshot}} ;
               <#{@jf}recordedAt> ?recorded .
      }
    }
    ORDER BY DESC(?recorded)
    LIMIT {{row_limit}}
    """
  end

  def fetch(:source_modules) do
    """
    SELECT ?entity ?name ?analyzer ?configuration ?tree ?coverage ?analysisWarning WHERE {
      GRAPH {{graph}} {
        {{graph}} <#{@jf}sourceSnapshot> {{snapshot}} ;
                  <#{@jf}analyzerVersion> ?analyzer ;
                  <#{@jf}configurationDigest> ?configuration ;
                  <#{@jf}inputTreeDigest> ?tree ;
                  <#{@jf}coverageStatus> ?coverage .
        OPTIONAL { {{graph}} <#{@jf}analysisWarning> ?analysisWarning }
        OPTIONAL {
          ?entity a <#{@jf}CodeSymbol> ;
                  <#{@jf}sourceSnapshot> {{snapshot}} ;
                  <#{@jf}symbolKind> <https://jido.run/ontology/concept/Module> ;
                  <#{@jf}displayName> ?name .
        }
      }
    }
    ORDER BY ?name
    LIMIT {{row_limit}}
    """
  end

  def fetch(:source_functions) do
    """
    SELECT ?entity ?name ?arity ?visibility ?analyzer ?configuration ?tree ?coverage ?analysisWarning WHERE {
      GRAPH {{graph}} {
        {{graph}} <#{@jf}sourceSnapshot> {{snapshot}} ;
                  <#{@jf}analyzerVersion> ?analyzer ;
                  <#{@jf}configurationDigest> ?configuration ;
                  <#{@jf}inputTreeDigest> ?tree ;
                  <#{@jf}coverageStatus> ?coverage .
        OPTIONAL { {{graph}} <#{@jf}analysisWarning> ?analysisWarning }
        OPTIONAL {
          ?entity a <#{@jf}CodeSymbol> ;
                  <#{@jf}sourceSnapshot> {{snapshot}} ;
                  <#{@jf}symbolKind> <https://jido.run/ontology/concept/Function> ;
                  <#{@jf}displayName> ?name ;
                  <#{@jf}arity> ?arity ;
                  <#{@jf}visibility> ?visibility .
        }
      }
    }
    ORDER BY ?name
    LIMIT {{row_limit}}
    """
  end

  def fetch(:source_otp_patterns) do
    """
    SELECT ?entity ?name ?pattern ?analyzer ?configuration ?tree ?coverage ?analysisWarning WHERE {
      GRAPH {{graph}} {
        {{graph}} <#{@jf}sourceSnapshot> {{snapshot}} ;
                  <#{@jf}analyzerVersion> ?analyzer ;
                  <#{@jf}configurationDigest> ?configuration ;
                  <#{@jf}inputTreeDigest> ?tree ;
                  <#{@jf}coverageStatus> ?coverage .
        OPTIONAL { {{graph}} <#{@jf}analysisWarning> ?analysisWarning }
        OPTIONAL {
          ?entity <#{@jf}sourceSnapshot> {{snapshot}} ;
                  <#{@jf}displayName> ?name ;
                  <#{@jf}otpPattern> ?pattern .
        }
      }
    }
    ORDER BY ?name ?pattern
    LIMIT {{row_limit}}
    """
  end

  def fetch(:source_dependencies) do
    """
    SELECT ?entity ?name ?dependency ?dependencyName ?analyzer ?configuration ?tree ?coverage ?analysisWarning WHERE {
      GRAPH {{graph}} {
        {{graph}} <#{@jf}sourceSnapshot> {{snapshot}} ;
                  <#{@jf}analyzerVersion> ?analyzer ;
                  <#{@jf}configurationDigest> ?configuration ;
                  <#{@jf}inputTreeDigest> ?tree ;
                  <#{@jf}coverageStatus> ?coverage .
        OPTIONAL { {{graph}} <#{@jf}analysisWarning> ?analysisWarning }
        OPTIONAL {
          ?entity <#{@jf}sourceSnapshot> {{snapshot}} ;
                  <#{@jf}displayName> ?name ;
                  <#{@jf}dependsOn> ?dependency .
          ?dependency <#{@jf}sourceSnapshot> {{snapshot}} ;
                      <#{@jf}displayName> ?dependencyName .
        }
      }
    }
    ORDER BY ?name ?dependencyName
    LIMIT {{row_limit}}
    """
  end

  def fetch(:source_entity_neighborhood) do
    source_relation_query(false)
  end

  def fetch(:source_impact) do
    source_relation_query(true)
  end

  def fetch(:desired_outcome_description) do
    """
    SELECT ?predicate ?object ?constraint ?constraintPredicate ?constraintValue WHERE {
      GRAPH {{graph}} {
        {{resource}} ?predicate ?object .
        OPTIONAL {
          {{resource}} <#{@jf}constrainedBy> ?constraint .
          ?constraint ?constraintPredicate ?constraintValue .
        }
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:goal_neighborhood) do
    """
    SELECT ?predicate ?object ?incoming ?incomingPredicate WHERE {
      GRAPH {{graph}} {
        { {{resource}} ?predicate ?object }
        UNION
        { ?incoming ?incomingPredicate {{resource}} }
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:task_dag) do
    """
    SELECT ?task ?kind ?dependency ?blocker ?alternative ?capability ?artifact WHERE {
      GRAPH {{graph}} {
        {{resource}} <#{@jf}includesTask> ?task .
        OPTIONAL { ?task <#{@jf}taskKind> ?kind }
        OPTIONAL { ?task <#{@jf}dependsOn> ?dependency }
        OPTIONAL { ?task <#{@jf}blocks> ?blocker }
        OPTIONAL { ?task <#{@jf}alternativeTo> ?alternative }
        OPTIONAL { ?task <#{@jf}requiresCapability> ?capability }
        OPTIONAL { ?task <#{@jf}requiresArtifact> ?artifact }
      }
    }
    ORDER BY ?task ?dependency
    LIMIT {{row_limit}}
    """
  end

  def fetch(:work_blockers) do
    """
    SELECT ?dependency ?dependencyTransition ?dependencyState ?blocker WHERE {
      GRAPH {{graph}} {
        OPTIONAL { {{resource}} <#{@jf}dependsOn> ?dependency }
        OPTIONAL { ?blocker <#{@jf}blocks> {{resource}} }
        OPTIONAL {
          ?dependencyTransition <#{@jf}transitionSubject> ?dependency ;
                                <#{@jf}nextState> ?dependencyState .
          ?decision <#{@jf}accepts> ?dependencyTransition .
          FILTER NOT EXISTS {
            ?successor <#{@jf}expectedPredecessor> ?dependencyTransition .
            ?successorDecision <#{@jf}accepts> ?successor .
          }
        }
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:work_transition_history) do
    """
    SELECT ?transition ?state ?revision ?predecessor ?actor ?cause ?reason ?recorded WHERE {
      GRAPH {{graph}} {
        ?transition <#{@jf}transitionSubject> {{resource}} ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}subjectRevision> ?revision ;
                    <#{@prov}wasAssociatedWith> ?actor ;
                    <#{@jf}cause> ?cause ;
                    <#{@jf}reason> ?reason ;
                    <#{@jf}recordedAt> ?recorded .
        ?decision <#{@jf}accepts> ?transition .
        OPTIONAL { ?transition <#{@jf}expectedPredecessor> ?predecessor }
      }
    }
    ORDER BY ?revision
    LIMIT {{row_limit}}
    """
  end

  def fetch(:work_lens) do
    """
    SELECT ?work ?transition ?revision ?successor WHERE {
      GRAPH {{graph}} {
        ?transition <#{@jf}transitionSubject> ?work ;
                    <#{@jf}nextState> {{state}} ;
                    <#{@jf}subjectRevision> ?revision .
        ?decision <#{@jf}accepts> ?transition .
        OPTIONAL {
          ?successor <#{@jf}expectedPredecessor> ?transition .
          ?successorDecision <#{@jf}accepts> ?successor .
        }
      }
    }
    ORDER BY ?work
    LIMIT {{row_limit}}
    """
  end

  def fetch(:plan_context) do
    """
    SELECT ?sourceGraphIri ?sourceRevision ?snapshot ?planner ?plannerVersion ?assumption ?effect ?strategy ?revisionReference ?inputGraphIri ?inputRevision WHERE {
      GRAPH {{graph}} {
        {{resource}} <#{@jf}sourceGraph> ?sourceGraphIri ;
                     <#{@jf}sourceRevisionNumber> ?sourceRevision ;
                     <#{@jf}sourceSnapshot> ?snapshot ;
                     <#{@jf}planner> ?planner ;
                     <#{@jf}displayId> ?plannerVersion ;
                     <#{@jf}verificationStrategy> ?strategy .
        OPTIONAL { {{resource}} <#{@jf}derivedFrom> ?assumption }
        OPTIONAL { {{resource}} <#{@jf}expectedEffect> ?effect }
        OPTIONAL {
          {{resource}} <#{@jf}sourceGraphRevision> ?revisionReference .
          ?revisionReference <#{@jf}sourceGraph> ?inputGraphIri ;
                             <#{@jf}sourceRevisionNumber> ?inputRevision .
        }
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:policy_description) do
    """
    SELECT ?predicate ?object WHERE {
      GRAPH {{graph}} {
        {{resource}} ?predicate ?object .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:governance_transition_history), do: fetch(:work_transition_history)

  def fetch(:cohort_definition) do
    """
    SELECT ?predicate ?object WHERE {
      GRAPH {{graph}} {
        {{resource}} ?predicate ?object .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:cohort_membership) do
    """
    SELECT ?membership ?repository ?path ?completeness ?evaluator ?sourceGraphIri ?sourceRevision WHERE {
      GRAPH {{graph}} {
        ?membership a <#{@jf}CohortMembership> ;
                    <#{@jf}inCohort> {{resource}} ;
                    <#{@jf}member> ?repository ;
                    <#{@jf}completenessState> ?completeness ;
                    <#{@jf}applicabilityEvaluator> ?evaluator .
        OPTIONAL { ?membership <#{@jf}membershipPath> ?path }
        OPTIONAL {
          {{graph}} <#{@jf}sourceGraphRevision> ?sourceReference .
          ?sourceReference <#{@jf}sourceGraph> ?sourceGraphIri ;
                           <#{@jf}sourceRevisionNumber> ?sourceRevision .
        }
      }
    }
    ORDER BY ?repository ?membership
    LIMIT {{row_limit}}
    """
  end

  def fetch(:policy_applicability) do
    """
    SELECT ?membership ?repository ?cohort ?path ?completeness ?evaluator ?sourceGraphIri ?sourceRevision WHERE {
      GRAPH {{graph}} {
        ?membership <#{@jf}inCohort> ?cohort ;
                    <#{@jf}member> ?repository ;
                    <#{@jf}completenessState> ?completeness ;
                    <#{@jf}applicabilityEvaluator> ?evaluator .
        OPTIONAL { ?membership <#{@jf}membershipPath> ?path }
        OPTIONAL {
          {{graph}} <#{@jf}sourceGraphRevision> ?sourceReference .
          ?sourceReference <#{@jf}sourceGraph> ?sourceGraphIri ;
                           <#{@jf}sourceRevisionNumber> ?sourceRevision .
        }
        FILTER(?cohort = {{resource}} || ?membership = {{resource}})
      }
    }
    ORDER BY ?repository ?membership
    LIMIT {{row_limit}}
    """
  end

  def fetch(:obligation_description) do
    """
    SELECT ?predicate ?object ?revisionReference ?sourceGraphIri ?sourceRevision WHERE {
      GRAPH {{graph}} {
        {{resource}} ?predicate ?object .
        OPTIONAL {
          {{resource}} <#{@jf}sourceGraphRevision> ?revisionReference .
          ?revisionReference <#{@jf}sourceGraph> ?sourceGraphIri ;
                             <#{@jf}sourceRevisionNumber> ?sourceRevision .
        }
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:capability_strict_view) do
    """
    SELECT ?predicate ?object ?transition ?state ?revision ?successor WHERE {
      GRAPH {{graph}} {
        {{resource}} ?predicate ?object .
        OPTIONAL {
          ?transition <#{@jf}transitionSubject> {{resource}} ;
                      <#{@jf}nextState> ?state ;
                      <#{@jf}subjectRevision> ?revision .
          ?decision <#{@jf}accepts> ?transition .
          OPTIONAL {
            ?successor <#{@jf}expectedPredecessor> ?transition .
            ?successorDecision <#{@jf}accepts> ?successor .
          }
        }
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:capability_hierarchy) do
    """
    SELECT ?classification ?capability ?broader ?version ?sourceGraphIri ?sourceRevision WHERE {
      GRAPH {{graph}} {
        ?classification a <#{@jf}CapabilityClassification> ;
                        <#{@jf}member> ?capability ;
                        <#{@jf}broaderCapability> ?broader ;
                        <#{@jf}version> ?version .
        OPTIONAL {
          {{graph}} <#{@jf}sourceGraphRevision> ?sourceReference .
          ?sourceReference <#{@jf}sourceGraph> ?sourceGraphIri ;
                           <#{@jf}sourceRevisionNumber> ?sourceRevision .
        }
        FILTER(?capability = {{resource}} || ?broader = {{resource}})
      }
    }
    ORDER BY ?capability ?broader
    LIMIT {{row_limit}}
    """
  end

  defp claim_query(predicate) do
    """
    SELECT ?claim WHERE {
      GRAPH {{graph}} {
        ?claim <#{@jf}#{predicate}> {{resource}} .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  defp transition_query(endpoint?) do
    order =
      if endpoint?,
        do: "ORDER BY DESC(?revision)\nLIMIT 1",
        else: "ORDER BY ?revision\nLIMIT {{row_limit}}"

    """
    SELECT ?transition ?state ?revision ?predecessor ?actor ?cause WHERE {
      GRAPH {{graph}} {
        ?transition a <#{@jf}StateTransition> ;
                    <#{@jf}transitionSubject> {{resource}} ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}subjectRevision> ?revision ;
                    <#{@prov}wasAssociatedWith> ?actor ;
                    <#{@jf}cause> ?cause .
        OPTIONAL { ?transition <#{@jf}expectedPredecessor> ?predecessor }
        ?decision <#{@jf}accepts> ?transition .
      }
    }
    #{order}
    """
  end

  defp source_relation_query(impact_only?) do
    if impact_only? do
      """
      SELECT ?outCall ?outDependency ?inCaller ?inDependent ?definer ?analyzer ?configuration ?tree ?coverage ?analysisWarning WHERE {
        GRAPH {{graph}} {
          {{graph}} <#{@jf}sourceSnapshot> {{snapshot}} ;
                    <#{@jf}analyzerVersion> ?analyzer ;
                    <#{@jf}configurationDigest> ?configuration ;
                    <#{@jf}inputTreeDigest> ?tree ;
                    <#{@jf}coverageStatus> ?coverage .
          OPTIONAL { {{graph}} <#{@jf}analysisWarning> ?analysisWarning }
          {{resource}} <#{@jf}sourceSnapshot> {{snapshot}} .
          { {{resource}} <#{@jf}calls> ?outCall }
          UNION
          { {{resource}} <#{@jf}dependsOn> ?outDependency }
          UNION
          { ?inCaller <#{@jf}calls> {{resource}} }
          UNION
          { ?inDependent <#{@jf}dependsOn> {{resource}} }
          UNION
          { ?definer <#{@jf}defines> {{resource}} }
        }
      }
      LIMIT {{row_limit}}
      """
    else
      """
      SELECT ?outPredicate ?outValue ?inSubject ?inPredicate ?analyzer ?configuration ?tree ?coverage ?analysisWarning WHERE {
        GRAPH {{graph}} {
          {{graph}} <#{@jf}sourceSnapshot> {{snapshot}} ;
                    <#{@jf}analyzerVersion> ?analyzer ;
                    <#{@jf}configurationDigest> ?configuration ;
                    <#{@jf}inputTreeDigest> ?tree ;
                    <#{@jf}coverageStatus> ?coverage .
          OPTIONAL { {{graph}} <#{@jf}analysisWarning> ?analysisWarning }
          {{resource}} <#{@jf}sourceSnapshot> {{snapshot}} .
          { {{resource}} ?outPredicate ?outValue }
          UNION
          { ?inSubject ?inPredicate {{resource}} }
        }
      }
      LIMIT {{row_limit}}
      """
    end
  end
end
