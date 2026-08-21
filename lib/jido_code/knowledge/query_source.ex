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
        {{graph}} ?predicate ?object .
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

  def fetch(:active_reconciliation_scopes) do
    """
    SELECT ?enrollment ?repository ?scope ?transition ?revision WHERE {
      GRAPH {{graph}} {
        ?enrollment <#{@jf}manages> ?repository ;
                    <#{@jf}inScope> ?scope .
      }
    }
    ORDER BY ?repository
    LIMIT {{row_limit}}
    """
  end

  def fetch(:incomplete_reconciliations) do
    """
    SELECT ?activity ?scope ?transition ?state ?revision WHERE {
      GRAPH {{graph}} {
        ?activity a <#{@jf}ReconciliationActivity> ;
                  <#{@jf}validFor> ?scope .
        ?transition <#{@jf}transitionSubject> ?activity ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}subjectRevision> ?revision .
        ?decision <#{@jf}accepts> ?transition .
        FILTER(?state = <https://jido.run/ontology/concept/ReconciliationProposed> ||
               ?state = <https://jido.run/ontology/concept/ReconciliationRunning>)
        FILTER NOT EXISTS {
          ?successor <#{@jf}expectedPredecessor> ?transition .
          ?successorDecision <#{@jf}accepts> ?successor .
        }
      }
    }
    ORDER BY ?activity
    LIMIT {{row_limit}}
    """
  end

  def fetch(:reconciliation_input) do
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

  def fetch(:reconciliation_explanation) do
    """
    SELECT ?subject ?desired ?result WHERE {
      GRAPH {{graph}} {
        ?subject <#{@jf}inputPackage> {{resource}} .
        ?subject <#{@jf}about> ?desired .
        ?subject <#{@jf}epistemicState> ?result .
      }
    }
    ORDER BY ?subject
    LIMIT {{row_limit}}
    """
  end

  def fetch(:eligible_work_candidates) do
    """
    SELECT ?task ?transition ?revision WHERE {
      GRAPH {{graph}} {
        ?task a <#{@jf}Task> .
        ?transition <#{@jf}transitionSubject> ?task ;
                    <#{@jf}nextState> <https://jido.run/ontology/concept/TaskEligible> ;
                    <#{@jf}subjectRevision> ?revision .
        ?decision <#{@jf}accepts> ?transition .
        FILTER NOT EXISTS {
          ?successor <#{@jf}expectedPredecessor> ?transition .
          ?successorDecision <#{@jf}accepts> ?successor .
        }
      }
    }
    ORDER BY ?task
    LIMIT {{row_limit}}
    """
  end

  def fetch(:eligibility_context) do
    """
    SELECT ?predicate ?object WHERE {
      GRAPH {{graph}} {
        {{resource}} ?predicate ?object .
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:lease_description), do: fetch(:eligibility_context)

  def fetch(:lease_transition_history) do
    """
    SELECT ?transition ?state ?revision WHERE {
      GRAPH {{graph}} {
        ?transition <#{@jf}transitionSubject> {{resource}} ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}subjectRevision> ?revision .
        ?decision <#{@jf}accepts> ?transition .
      }
    }
    ORDER BY ?revision
    LIMIT {{row_limit}}
    """
  end

  def fetch(:execution_context_subject) do
    """
    SELECT ?predicate ?object WHERE {
      GRAPH {{graph}} {
        {{resource}} ?predicate ?object .
      }
    }
    ORDER BY ?predicate ?object
    LIMIT {{row_limit}}
    """
  end

  def fetch(:interaction_session), do: fetch(:execution_context_subject)

  def fetch(:interaction_timeline) do
    """
    SELECT ?message ?sequence ?sender ?audience ?reply ?classification ?intent ?content ?recorded ?command WHERE {
      GRAPH {{graph}} {
        ?message a <#{@jf}Message> ;
                 <#{@jf}validFor> {{resource}} ;
                 <#{@jf}sequence> ?sequence ;
                 <#{@prov}wasAssociatedWith> ?sender ;
                 <#{@jf}contentClassification> ?classification ;
                 <#{@jf}messageIntent> ?intent ;
                 <#{@jf}content> ?content ;
                 <#{@jf}recordedAt> ?recorded .
        OPTIONAL { ?message <#{@jf}audience> ?audience }
        OPTIONAL { ?message <#{@jf}replyTo> ?reply }
        OPTIONAL { ?message <#{@jf}resultingCommand> ?command }
      }
    }
    ORDER BY ?sequence ?message
    LIMIT {{row_limit}}
    """
  end

  def fetch(:active_attempts) do
    """
    SELECT ?attempt ?lease ?task ?fence ?validTo ?state ?transition ?successor ?successorState WHERE {
      GRAPH {{graph}} {
        ?lease a <#{@jf}Lease> ;
               <#{@jf}leasesTask> ?task ;
               <#{@jf}fencingToken> ?fence .
        ?transition <#{@jf}transitionSubject> ?lease ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}executes> ?attempt .
        ?decision <#{@jf}accepts> ?transition .
        OPTIONAL { ?transition <#{@jf}validTo> ?validTo }
        OPTIONAL {
          ?successor <#{@jf}expectedPredecessor> ?transition .
          ?successorDecision <#{@jf}accepts> ?successor .
          ?successor <#{@jf}nextState> ?successorState .
        }
      }
    }
    ORDER BY ?task ?attempt
    LIMIT {{row_limit}}
    """
  end

  def fetch(:attempt_by_task) do
    """
    SELECT ?attempt ?lease ?fence ?validTo ?state ?transition WHERE {
      GRAPH {{graph}} {
        ?lease a <#{@jf}Lease> ;
               <#{@jf}leasesTask> {{resource}} ;
               <#{@jf}fencingToken> ?fence .
        ?transition <#{@jf}transitionSubject> ?lease ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}executes> ?attempt .
        ?decision <#{@jf}accepts> ?transition .
        OPTIONAL { ?transition <#{@jf}validTo> ?validTo }
      }
    }
    ORDER BY DESC(?fence) ?attempt
    LIMIT {{row_limit}}
    """
  end

  def fetch(:attempt_status) do
    """
    SELECT ?predicate ?object WHERE {
      GRAPH {{graph}} {
        {{resource}} ?predicate ?object .
      }
    }
    ORDER BY ?predicate ?object
    LIMIT {{row_limit}}
    """
  end

  def fetch(:attempt_timeline) do
    """
    SELECT ?transition ?prior ?state ?revision ?recorded ?runtimeSequence ?outcome ?diagnostic WHERE {
      GRAPH {{graph}} {
        ?transition <#{@jf}transitionSubject> {{resource}} ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}subjectRevision> ?revision ;
                    <#{@jf}recordedAt> ?recorded .
        ?decision <#{@jf}accepts> ?transition .
        OPTIONAL { ?transition <#{@jf}priorState> ?prior }
        OPTIONAL { ?transition <#{@jf}runtimeSequence> ?runtimeSequence }
        OPTIONAL { ?transition <#{@jf}outcomeClass> ?outcome }
        OPTIONAL { ?transition <#{@jf}diagnostic> ?diagnostic }
      }
    }
    ORDER BY DESC(?revision)
    LIMIT {{row_limit}}
    """
  end

  def fetch(:tool_invocations) do
    """
    SELECT ?invocation ?tool ?version ?sequence ?effect ?started ?deadline ?result ?status ?ended
           ?exitStatus ?stdoutDigest ?stderrDigest ?usageDigest ?redaction ?artifact WHERE {
      GRAPH {{graph}} {
        ?invocation a <#{@jf}ToolInvocation> ;
                    <#{@jf}attempts> {{resource}} ;
                    <#{@jf}executes> ?tool ;
                    <#{@jf}toolVersion> ?version ;
                    <#{@jf}invocationSequence> ?sequence ;
                    <#{@jf}expectedEffect> ?effect ;
                    <#{@prov}startedAtTime> ?started ;
                    <#{@jf}deadline> ?deadline .
        OPTIONAL {
          ?invocation <#{@jf}result> ?result .
          ?result <#{@jf}outcomeClass> ?status ;
                  <#{@prov}endedAtTime> ?ended ;
                  <#{@jf}stdoutDigest> ?stdoutDigest ;
                  <#{@jf}stderrDigest> ?stderrDigest ;
                  <#{@jf}usageDigest> ?usageDigest ;
                  <#{@jf}redactionResult> ?redaction .
          OPTIONAL { ?result <#{@jf}exitStatus> ?exitStatus }
          OPTIONAL { ?result <#{@prov}generated> ?artifact }
        }
      }
    }
    ORDER BY ?sequence ?invocation
    LIMIT {{row_limit}}
    """
  end

  def fetch(:attempt_artifacts) do
    """
    SELECT ?artifact ?kind ?snapshot ?generator ?digest ?mediaType ?byteCount ?storage
           ?external ?path ?symbol ?commit ?tree WHERE {
      GRAPH {{graph}} {
        {{resource}} <#{@prov}generated> ?artifact .
        ?artifact a <#{@jf}Artifact> ;
                  <#{@jf}artifactKind> ?kind ;
                  <#{@jf}sourceSnapshot> ?snapshot ;
                  <#{@prov}wasGeneratedBy> ?generator ;
                  <#{@jf}contentDigest> ?digest ;
                  <#{@jf}mediaType> ?mediaType ;
                  <#{@jf}byteCount> ?byteCount ;
                  <#{@jf}storageClass> ?storage .
        OPTIONAL { ?artifact <#{@jf}externalOutput> ?external }
        OPTIONAL { ?artifact <#{@jf}affectedPath> ?path }
        OPTIONAL { ?artifact <#{@jf}affects> ?symbol }
        OPTIONAL { ?artifact <#{@jf}proposedCommit> ?commit }
        OPTIONAL { ?artifact <#{@jf}proposedTree> ?tree }
      }
    }
    ORDER BY ?artifact ?path ?symbol
    LIMIT {{row_limit}}
    """
  end

  def fetch(:cancellation_retry_lineage) do
    """
    SELECT ?retryOf ?retry ?cancellation ?outcome WHERE {
      GRAPH {{graph}} {
        OPTIONAL { {{resource}} <#{@jf}retryOf> ?retryOf }
        OPTIONAL { ?retry <#{@jf}retryOf> {{resource}} }
        OPTIONAL { {{resource}} <#{@jf}cancellationRequest> ?cancellation }
        OPTIONAL { {{resource}} <#{@jf}outcomeClass> ?outcome }
      }
    }
    LIMIT {{row_limit}}
    """
  end

  def fetch(:run_completeness) do
    """
    SELECT ?lifecycle ?state ?closed ?assertion ?runtimeCompletion ?missing ?limitation ?usageDigest WHERE {
      GRAPH {{graph}} {
        {{graph}} <#{@jf}lifecycleState> ?lifecycle ;
                  <#{@jf}completenessState> ?state .
        OPTIONAL { {{graph}} <#{@jf}closedAt> ?closed }
        OPTIONAL {
          {{resource}} <#{@jf}provenanceCompleteness> ?assertion .
          ?assertion <#{@jf}usageDigest> ?usageDigest .
          OPTIONAL { ?assertion <#{@jf}missingOutput> ?missing }
          OPTIONAL { ?assertion <#{@jf}limitation> ?limitation }
        }
        OPTIONAL { {{resource}} <#{@jf}runtimeCompletion> ?runtimeCompletion }
      }
    }
    ORDER BY ?missing ?limitation
    LIMIT {{row_limit}}
    """
  end

  def fetch(:attempt_capture_completeness) do
    """
    SELECT ?segment ?expectedBody ?event ?eventKind ?sourceEvent ?bodyRole ?capture
           ?outcome ?representation ?location ?availability ?retention ?hold ?classification
           ?purpose ?reconstruction ?providerAvailability ?allowedUse ?limitation ?digest
           WHERE {
      GRAPH {{graph}} {
        ?segment <#{@jf}segmentOf> {{resource}} .
        ?event <#{@jf}segmentOf> ?segment ;
               <#{@jf}eventKind> ?eventKind ;
               <#{@jf}hasCapture> ?capture .
        ?capture <#{@jf}capturedBody> ?expectedBody ;
                 <#{@jf}sourceEvent> ?sourceEvent ;
                 <#{@jf}bodyRole> ?bodyRole ;
                 <#{@jf}captureOutcome> ?outcome ;
                 <#{@jf}contentRepresentation> ?representation ;
                 <#{@jf}storageLocation> ?location ;
                 <#{@jf}availabilityState> ?availability ;
                 <#{@jf}retentionState> ?retention ;
                 <#{@jf}holdState> ?hold ;
                 <#{@jf}contentClassification> ?classification ;
                 <#{@jf}capturePurpose> ?purpose ;
                 <#{@jf}reconstructionStatus> ?reconstruction ;
                 <#{@jf}externalProviderAvailability> ?providerAvailability .
        OPTIONAL { ?capture <#{@jf}allowedUse> ?allowedUse }
        OPTIONAL { ?capture <#{@jf}limitation> ?limitation }
        OPTIONAL { ?capture <#{@jf}representationDigest> ?digest }
      }
    }
    ORDER BY ?expectedBody ?allowedUse ?limitation
    LIMIT {{row_limit}}
    """
  end

  def fetch(:task_attempt_lineage) do
    """
    SELECT ?attempt ?lease ?fence ?transition ?state ?validFrom ?validTo ?retryOf
           ?cancellation ?outcome WHERE {
      GRAPH {{graph}} {
        ?lease a <#{@jf}Lease> ;
               <#{@jf}leasesTask> {{resource}} ;
               <#{@jf}fencingToken> ?fence .
        ?transition <#{@jf}transitionSubject> ?lease ;
                    <#{@jf}executes> ?attempt ;
                    <#{@jf}nextState> ?state .
        ?decision <#{@jf}accepts> ?transition .
        OPTIONAL { ?transition <#{@jf}validFrom> ?validFrom }
        OPTIONAL { ?transition <#{@jf}validTo> ?validTo }
        OPTIONAL { ?attempt <#{@jf}retryOf> ?retryOf }
        OPTIONAL { ?attempt <#{@jf}cancellationRequest> ?cancellation }
        OPTIONAL { ?attempt <#{@jf}outcomeClass> ?outcome }
      }
    }
    ORDER BY ?fence ?attempt ?transition
    LIMIT {{row_limit}}
    """
  end

  def fetch(:attempt_event_range), do: event_range_query(false)
  def fetch(:segment_event_range), do: event_range_query(true)

  def fetch(:exact_failure_occurrences) do
    """
    SELECT ?segment ?event ?sequence ?eventKind ?role ?occurred ?resource WHERE {
      GRAPH {{graph}} {
        ?segment <#{@jf}segmentOf> ?attempt .
        ?event <#{@jf}segmentOf> ?segment ;
               <#{@jf}eventSequence> ?sequence ;
               <#{@jf}eventKind> ?eventKind ;
               <#{@jf}eventRole> ?role ;
               <#{@jf}accountsResource> ?resource .
        ?resource <#{@jf}semanticDigest> {{signature}} ;
                  <#{@prov}generatedAtTime> ?occurred .
        FILTER(?occurred <= {{instant}})
      }
    }
    ORDER BY ?occurred ?sequence ?event
    LIMIT {{row_limit}}
    """
  end

  def fetch(:issue_change_test_lineage) do
    lineage_query("?relation", "")
  end

  def fetch(:incident_linkage) do
    relation = "<#{@jf}incidentLink>"
    lineage_query("?relation", "FILTER(?relation = #{relation})")
  end

  def fetch(:why_does_this_exist) do
    """
    SELECT ?relation ?source ?resourceRecorded ?recorded ?classification WHERE {
      GRAPH {{graph}} {
        {
          {{resource}} ?relation ?source .
        } UNION {
          ?source ?relation {{resource}} .
        }
        {{resource}} <#{@jf}recordedAt> ?resourceRecorded .
        OPTIONAL { ?source <#{@jf}recordedAt> ?recorded }
        OPTIONAL { ?source <#{@prov}generatedAtTime> ?recorded }
        OPTIONAL { ?source <#{@jf}contentClassification> ?classification }
        FILTER(?resourceRecorded <= {{instant}})
      }
    }
    ORDER BY ?recorded ?relation ?source
    LIMIT {{row_limit}}
    """
  end

  def fetch(:similar_resolved_cases), do: experience_case_query(false)
  def fetch(:failed_interventions), do: experience_case_query(true)

  def fetch(:experience_case_source_trace) do
    """
    SELECT ?manifest ?manifestDigest ?event ?artifact ?evidence ?recorded WHERE {
      GRAPH {{graph}} {
        {{resource}} <#{@jf}recordedAt> ?recorded .
        FILTER(?recorded <= {{instant}})
        OPTIONAL {
          ?summary <#{@jf}about> {{resource}} ; <#{@jf}sourceManifest> ?manifest .
          ?manifest <#{@jf}manifestDigest> ?manifestDigest .
        }
        OPTIONAL { {{resource}} <#{@jf}sourceEvent> ?event }
        OPTIONAL { {{resource}} <#{@jf}sourceArtifact> ?artifact }
        OPTIONAL { {{resource}} <#{@jf}evidenceSource> ?evidence }
      }
    }
    ORDER BY ?event ?artifact ?evidence
    LIMIT {{row_limit}}
    """
  end

  def fetch(:experience_case_contradictions) do
    """
    SELECT ?contradiction ?evidence ?recorded WHERE {
      GRAPH {{graph}} {
        {{resource}} <#{@jf}recordedAt> ?caseRecorded .
        FILTER(?caseRecorded <= {{instant}})
        {
          ?contradiction <#{@jf}contradicts> {{resource}} .
        } UNION {
          {{resource}} <#{@jf}evidenceSource> ?evidence .
          ?evidence <#{@jf}contradicts> ?contradiction .
        }
        OPTIONAL { ?contradiction <#{@jf}recordedAt> ?recorded }
      }
    }
    ORDER BY ?recorded ?contradiction ?evidence
    LIMIT {{row_limit}}
    """
  end

  def fetch(:experience_case_lifecycle) do
    """
    SELECT ?transition ?prior ?state ?revision ?predecessor ?actor ?cause ?reason ?recorded WHERE {
      GRAPH {{graph}} {
        ?transition <#{@jf}transitionSubject> {{resource}} ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}subjectRevision> ?revision ;
                    <#{@prov}wasAssociatedWith> ?actor ;
                    <#{@jf}cause> ?cause ;
                    <#{@jf}reason> ?reason ;
                    <#{@jf}recordedAt> ?recorded .
        FILTER(?recorded <= {{instant}})
        OPTIONAL { ?transition <#{@jf}priorState> ?prior }
        OPTIONAL { ?transition <#{@jf}expectedPredecessor> ?predecessor }
      }
    }
    ORDER BY ?revision ?transition
    LIMIT {{row_limit}}
    """
  end

  def fetch(:memory_use_outcomes) do
    """
    SELECT ?assessment ?packet ?packetDigest ?attempt ?attemptOutcome ?evaluator ?policy
           ?policyVersion ?outcome ?controlAttempt ?controlOutcome ?triggerConcentration
           ?poisoningSuccess ?recorded WHERE {
      GRAPH {{graph}} {
        ?assessment a <#{@jf}MemoryUseAssessment> ;
                    <#{@jf}about> {{resource}} ;
                    <#{@jf}retrievalPacket> ?packet ;
                    <#{@jf}retrievalPacketDigest> ?packetDigest ;
                    <#{@jf}evaluatedAttempt> ?attempt ;
                    <#{@jf}attemptOutcome> ?attemptOutcome ;
                    <#{@prov}wasAssociatedWith> ?evaluator ;
                    <#{@jf}governedBy> ?policy ;
                    <#{@jf}policyVersion> ?policyVersion ;
                    <#{@jf}memoryUseOutcome> ?outcome ;
                    <#{@jf}withheldControlAttempt> ?controlAttempt ;
                    <#{@jf}withheldControlOutcome> ?controlOutcome ;
                    <#{@jf}suspiciousTriggerConcentration> ?triggerConcentration ;
                    <#{@jf}poisoningSuccess> ?poisoningSuccess ;
                    <#{@jf}recordedAt> ?recorded .
        FILTER(?recorded <= {{instant}})
      }
    }
    ORDER BY ?recorded ?assessment
    LIMIT {{row_limit}}
    """
  end

  def fetch(:negative_transfer_cases) do
    """
    SELECT ?assessment ?outcome ?triggerConcentration ?poisoningSuccess ?recorded WHERE {
      GRAPH {{graph}} {
        ?assessment a <#{@jf}MemoryUseAssessment> ;
                    <#{@jf}about> {{resource}} ;
                    <#{@jf}memoryUseOutcome> ?outcome ;
                    <#{@jf}suspiciousTriggerConcentration> ?triggerConcentration ;
                    <#{@jf}poisoningSuccess> ?poisoningSuccess ;
                    <#{@jf}recordedAt> ?recorded .
        FILTER(?recorded <= {{instant}})
        FILTER(
          ?outcome = <https://jido.run/ontology/concept/Misleading> ||
          ?outcome = <https://jido.run/ontology/concept/Stale> ||
          ?outcome = <https://jido.run/ontology/concept/Unauthorized> ||
          ?poisoningSuccess = true || ?triggerConcentration >= 0.8
        )
      }
    }
    ORDER BY DESC(?triggerConcentration) ?recorded ?assessment
    LIMIT {{row_limit}}
    """
  end

  def fetch(:artifact_claims) do
    """
    SELECT ?claim ?snapshot ?artifact ?path ?symbol ?selector ?digest ?value ?command
           ?environment ?evidence ?strength ?state ?revision ?checked WHERE {
      GRAPH {{graph}} {
        ?claim a <#{@jf}ArtifactClaim> ;
               <#{@jf}about> {{resource}} ;
               <#{@jf}sourceSnapshot> ?snapshot ;
               <#{@jf}evaluatesArtifact> ?artifact ;
               <#{@jf}path> ?path ;
               <#{@jf}contentDigest> ?digest ;
               <#{@jf}value> ?value ;
               <#{@jf}verificationCommand> ?command ;
               <#{@jf}verificationEnvironment> ?environment ;
               <#{@jf}evidenceSource> ?evidence ;
               <#{@jf}evidenceStrength> ?strength ;
               <#{@jf}checkedAt> ?checked .
        ?transition <#{@jf}transitionSubject> ?claim ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}subjectRevision> ?revision ;
                    <#{@jf}recordedAt> ?transitionAt .
        FILTER(?checked <= {{instant}} && ?transitionAt <= {{instant}})
        OPTIONAL { ?claim <#{@jf}symbol> ?symbol }
        OPTIONAL { ?claim <#{@jf}selector> ?selector }
      }
    }
    ORDER BY ?claim DESC(?revision)
    LIMIT {{row_limit}}
    """
  end

  def fetch(:historical_test_risk) do
    """
    SELECT ?claim ?artifact ?path ?value ?strength ?state ?revision ?checked WHERE {
      GRAPH {{graph}} {
        ?claim a <#{@jf}ArtifactClaim> ; <#{@jf}about> {{resource}} ;
               <#{@jf}evaluatesArtifact> ?artifact ; <#{@jf}path> ?path ;
               <#{@jf}value> ?value ; <#{@jf}evidenceStrength> ?strength ;
               <#{@jf}checkedAt> ?checked .
        ?transition <#{@jf}transitionSubject> ?claim ; <#{@jf}nextState> ?state ;
                    <#{@jf}subjectRevision> ?revision ; <#{@jf}recordedAt> ?recorded .
        FILTER(?checked <= {{instant}} && ?recorded <= {{instant}})
      }
    }
    ORDER BY DESC(?revision) ?claim
    LIMIT {{row_limit}}
    """
  end

  def fetch(:evidence_by_goal),
    do: evidence_bundle_query("?activity <#{@jf}evaluatedGoal> {{resource}} .")

  def fetch(:evidence_by_claim) do
    evidence_bundle_query("""
    {
      ?bundle <#{@jf}generatedClaim> {{resource}} .
    } UNION {
      ?bundle <#{@jf}supports> {{resource}} .
    } UNION {
      ?bundle <#{@jf}contradicts> {{resource}} .
    }
    """)
  end

  def fetch(:evidence_by_attempt) do
    """
    SELECT ?bundle ?activity ?method ?methodVersion ?kind ?evaluator ?strength ?classification
           ?coverageTotal ?coveragePassed ?coverageFailed ?coverageSkipped ?coverageUnknown
           ?completeness ?support ?contradiction ?claim ?limitation ?validFrom ?validTo
           ?sourceGraphIri ?sourceRevision WHERE {
      GRAPH {{graph}} {
        ?activity <#{@jf}evaluatedAttempt> {{resource}} .
        ?bundle a <#{@jf}EvidenceBundle> ;
                <#{@jf}verificationActivity> ?activity ;
                <#{@jf}evidenceStrength> ?strength ;
                <#{@jf}evidenceClassification> ?classification ;
                <#{@jf}coverageTotal> ?coverageTotal ;
                <#{@jf}coveragePassed> ?coveragePassed ;
                <#{@jf}coverageFailed> ?coverageFailed ;
                <#{@jf}coverageSkipped> ?coverageSkipped ;
                <#{@jf}coverageUnknown> ?coverageUnknown ;
                <#{@jf}completenessState> ?completeness ;
                <#{@jf}validFrom> ?validFrom ;
                <#{@jf}validTo> ?validTo .
        ?activity <#{@jf}usesVerificationMethod> ?method ;
                  <#{@prov}wasAssociatedWith> ?evaluator .
        ?method <#{@jf}version> ?methodVersion ; <#{@jf}verificationKind> ?kind .
        OPTIONAL { ?bundle <#{@jf}supports> ?support }
        OPTIONAL { ?bundle <#{@jf}contradicts> ?contradiction }
        OPTIONAL { ?bundle <#{@jf}generatedClaim> ?claim }
        OPTIONAL { ?bundle <#{@jf}limitation> ?limitation }
        OPTIONAL {
          ?bundle <#{@jf}sourceGraphRevision> ?sourceRef .
          ?sourceRef <#{@jf}sourceGraph> ?sourceGraphIri ;
                     <#{@jf}sourceRevisionNumber> ?sourceRevision .
        }
      }
    }
    ORDER BY ?bundle ?sourceGraphIri
    LIMIT {{row_limit}}
    """
  end

  def fetch(:evidence_by_artifact) do
    """
    SELECT ?bundle ?activity ?method ?methodVersion ?kind ?evaluator ?strength ?classification
           ?coverageTotal ?coveragePassed ?coverageFailed ?coverageSkipped ?coverageUnknown
           ?completeness ?support ?contradiction ?claim ?limitation ?validFrom ?validTo
           ?sourceGraphIri ?sourceRevision WHERE {
      GRAPH {{graph}} {
        ?activity <#{@jf}evaluatesArtifact> {{resource}} .
        ?bundle a <#{@jf}EvidenceBundle> ;
                <#{@jf}verificationActivity> ?activity ;
                <#{@jf}evidenceStrength> ?strength ;
                <#{@jf}evidenceClassification> ?classification ;
                <#{@jf}coverageTotal> ?coverageTotal ;
                <#{@jf}coveragePassed> ?coveragePassed ;
                <#{@jf}coverageFailed> ?coverageFailed ;
                <#{@jf}coverageSkipped> ?coverageSkipped ;
                <#{@jf}coverageUnknown> ?coverageUnknown ;
                <#{@jf}completenessState> ?completeness ;
                <#{@jf}validFrom> ?validFrom ;
                <#{@jf}validTo> ?validTo .
        ?activity <#{@jf}usesVerificationMethod> ?method ;
                  <#{@prov}wasAssociatedWith> ?evaluator .
        ?method <#{@jf}version> ?methodVersion ; <#{@jf}verificationKind> ?kind .
        OPTIONAL { ?bundle <#{@jf}supports> ?support }
        OPTIONAL { ?bundle <#{@jf}contradicts> ?contradiction }
        OPTIONAL { ?bundle <#{@jf}generatedClaim> ?claim }
        OPTIONAL { ?bundle <#{@jf}limitation> ?limitation }
        OPTIONAL {
          ?bundle <#{@jf}sourceGraphRevision> ?sourceRef .
          ?sourceRef <#{@jf}sourceGraph> ?sourceGraphIri ;
                     <#{@jf}sourceRevisionNumber> ?sourceRevision .
        }
      }
    }
    ORDER BY ?bundle ?sourceGraphIri
    LIMIT {{row_limit}}
    """
  end

  def fetch(:verification_timeline) do
    """
    SELECT ?activity ?method ?methodVersion ?kind ?evaluator ?started ?ended ?completeness
           ?snapshot ?artifact ?check ?checkId ?checkStatus ?mandatory ?rawRef WHERE {
      GRAPH {{graph}} {
        ?activity a <#{@jf}VerificationActivity> ;
                  <#{@jf}evaluatedGoal> {{resource}} ;
                  <#{@jf}usesVerificationMethod> ?method ;
                  <#{@jf}evaluatedSnapshot> ?snapshot ;
                  <#{@prov}wasAssociatedWith> ?evaluator ;
                  <#{@prov}startedAtTime> ?started ;
                  <#{@prov}endedAtTime> ?ended ;
                  <#{@jf}completenessState> ?completeness .
        ?method <#{@jf}version> ?methodVersion ; <#{@jf}verificationKind> ?kind .
        OPTIONAL { ?activity <#{@jf}evaluatesArtifact> ?artifact }
        OPTIONAL {
          ?activity <#{@jf}hasCheck> ?check .
          ?check <#{@jf}displayId> ?checkId ;
                 <#{@jf}checkStatus> ?checkStatus ;
                 <#{@jf}mandatory> ?mandatory .
          OPTIONAL { ?check <#{@jf}rawOutcome> ?rawRef }
        }
      }
    }
    ORDER BY ?started ?activity ?checkId
    LIMIT {{row_limit}}
    """
  end

  def fetch(:evidence_support), do: fetch(:evidence_by_claim)

  def fetch(:evidence_sufficiency),
    do: evidence_bundle_query("?activity <#{@jf}evaluatedGoal> {{resource}} .")

  def fetch(:missing_evidence_requirements),
    do: evidence_bundle_query("?activity <#{@jf}evaluatedGoal> {{resource}} .")

  def fetch(:stale_evidence) do
    """
    SELECT ?bundle ?validTo ?superseder ?activity ?method ?methodVersion ?kind ?evaluator
           ?support ?contradiction WHERE {
      GRAPH {{graph}} {
        ?bundle a <#{@jf}EvidenceBundle> ;
                <#{@jf}verificationActivity> ?activity ;
                <#{@jf}validTo> ?validTo .
        ?activity <#{@jf}usesVerificationMethod> ?method ;
                  <#{@prov}wasAssociatedWith> ?evaluator .
        ?method <#{@jf}version> ?methodVersion ; <#{@jf}verificationKind> ?kind .
        OPTIONAL { ?bundle <#{@jf}supports> ?support }
        OPTIONAL { ?bundle <#{@jf}contradicts> ?contradiction }
        OPTIONAL { ?superseder <#{@jf}supersedes> ?bundle }
        FILTER(?validTo < {{instant}} || BOUND(?superseder))
      }
    }
    ORDER BY ?validTo ?bundle
    LIMIT {{row_limit}}
    """
  end

  def fetch(:decision_by_goal),
    do: decision_query("?decision <#{@jf}addresses> {{resource}} .")

  def fetch(:decision_by_claim) do
    decision_query("""
    {
      ?decision ?claimDispositionPredicate {{resource}} .
      FILTER(?claimDispositionPredicate IN (<#{@jf}accepts>, <#{@jf}rejects>, <#{@jf}waives>, <#{@jf}defers>, <#{@jf}supersedes>))
    } UNION {
      ?dispositionClaim <#{@jf}supersedes> {{resource}} .
      ?decision ?claimDispositionPredicate ?dispositionClaim .
      FILTER(?claimDispositionPredicate IN (<#{@jf}accepts>, <#{@jf}rejects>, <#{@jf}waives>))
    }
    """)
  end

  def fetch(:decision_by_evidence) do
    decision_query("""
    ?assessment <#{@jf}consideredEvidence> {{resource}} .
    ?decision <#{@jf}evaluates> ?assessment .
    """)
  end

  def fetch(:decision_by_actor),
    do: decision_query("?decision <#{@jf}decisionAuthority> {{resource}} .")

  def fetch(:decision_waivers),
    do: decision_query("?decision <#{@jf}addresses> {{resource}} ; <#{@jf}waives> ?waived .")

  def fetch(:decision_rejections),
    do: decision_query("?decision <#{@jf}addresses> {{resource}} ; <#{@jf}rejects> ?rejected .")

  def fetch(:deferred_actions) do
    decision_query("""
    ?decision <#{@jf}addresses> {{resource}} .
    { ?decision <#{@jf}defers> ?deferred }
    UNION
    { ?decision <#{@jf}requestsMoreEvidence> ?requested }
    """)
  end

  def fetch(:decision_supersession) do
    """
    SELECT ?decision ?superseded ?superseder ?actor ?recorded ?disposition ?stage WHERE {
      GRAPH {{graph}} {
        {
          {{resource}} <#{@jf}supersedes> ?superseded .
          BIND({{resource}} AS ?decision)
        } UNION {
          ?superseder <#{@jf}supersedes> {{resource}} .
          BIND({{resource}} AS ?decision)
        }
        ?decision <#{@jf}decisionAuthority> ?actor ;
                  <#{@jf}recordedAt> ?recorded ;
                  <#{@jf}decisionDisposition> ?disposition ;
                  <#{@jf}outcomeStage> ?stage .
      }
    }
    ORDER BY ?recorded ?decision
    LIMIT {{row_limit}}
    """
  end

  def fetch(:satisfaction_path) do
    """
    SELECT ?transition ?state ?revision ?decision ?stage ?disposition ?cause ?recorded WHERE {
      GRAPH {{graph}} {
        ?transition <#{@jf}transitionSubject> {{resource}} ;
                    <#{@jf}nextState> ?state ;
                    <#{@jf}subjectRevision> ?revision ;
                    <#{@jf}cause> ?cause ;
                    <#{@jf}recordedAt> ?recorded .
        ?decision <#{@jf}accepts> ?transition .
        OPTIONAL { ?cause <#{@jf}outcomeStage> ?stage }
        OPTIONAL { ?cause <#{@jf}decisionDisposition> ?disposition }
      }
    }
    ORDER BY ?revision
    LIMIT {{row_limit}}
    """
  end

  def fetch(:decision_follow_up) do
    """
    SELECT ?followUp ?decision ?goal ?task ?kind ?requiresLease ?target ?superseder WHERE {
      GRAPH {{graph}} {
        ?followUp a <#{@jf}DecisionFollowUp> ;
                  <#{@jf}causedBy> ?decision ;
                  <#{@jf}about> ?target ;
                  <#{@jf}followUpGoal> ?goal ;
                  <#{@jf}followUpTask> ?task ;
                  <#{@jf}followUpKind> ?kind ;
                  <#{@jf}requiresLease> ?requiresLease .
        OPTIONAL { ?superseder <#{@jf}supersedes> ?followUp }
        FILTER(?decision = {{resource}} || ?target = {{resource}} || ?goal = {{resource}} || ?task = {{resource}})
      }
    }
    ORDER BY ?followUp
    LIMIT {{row_limit}}
    """
  end

  def fetch(:knowledge_by_scope),
    do: knowledge_query("?assertion <#{@jf}validFor> {{resource}} .")

  def fetch(:knowledge_by_goal),
    do: knowledge_query("?assertion <#{@jf}addresses> {{resource}} .")

  def fetch(:knowledge_by_task),
    do: knowledge_query("?assertion <#{@jf}addresses> {{resource}} .")

  def fetch(:knowledge_by_source),
    do:
      knowledge_query(
        "?assertion <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> {{resource}} ."
      )

  def fetch(:knowledge_by_policy),
    do: knowledge_query("?assertion <#{@jf}governedBy> {{resource}} .")

  def fetch(:knowledge_by_classification),
    do: knowledge_query("?assertion <#{@jf}knowledgeClassification> {{resource}} .")

  def fetch(:knowledge_by_validity),
    do: knowledge_query("?assertion <#{@jf}validFor> {{resource}} .")

  def fetch(:knowledge_neighborhood) do
    knowledge_query("""
    {
      ?assertion ?neighborhoodPredicate {{resource}} .
      FILTER(?neighborhoodPredicate IN (<#{@jf}supports>, <#{@jf}contradicts>, <#{@jf}supersedes>))
    } UNION {
      {{resource}} ?neighborhoodPredicate ?assertion .
      FILTER(?neighborhoodPredicate IN (<#{@jf}supports>, <#{@jf}contradicts>, <#{@jf}supersedes>))
    }
    """)
  end

  def fetch(:shared_dependencies), do: insight_query("dependsOn")
  def fetch(:repeated_findings), do: insight_query("hasFinding")
  def fetch(:repeated_failures), do: insight_query("hasFailure")
  def fetch(:policy_outcome_patterns), do: insight_query("policyOutcome")
  def fetch(:reusable_evidence_methods), do: insight_query("usesVerificationMethod")
  def fetch(:related_source_symbols), do: insight_query("relatedSymbol")
  def fetch(:applicable_lessons), do: insight_query("applicableLesson")

  defp event_range_query(include_manifest?) do
    manifest =
      if include_manifest? do
        """
        ?segment <#{@jf}segmentIndex> ?segmentIndex ;
                 <#{@jf}sequenceStart> ?segmentStart .
        OPTIONAL { ?segment <#{@jf}sequenceEnd> ?segmentEnd }
        OPTIONAL { ?segment <#{@jf}segmentRootDigest> ?segmentRoot }
        OPTIONAL { ?segment <#{@jf}completenessState> ?completeness }
        """
      else
        ""
      end

    """
    SELECT ?segment ?segmentIndex ?segmentStart ?segmentEnd ?segmentRoot ?completeness
           ?event ?sequence ?eventKind ?role ?predecessor ?sourceEvent ?sourceOrder
           ?resource ?capture ?occurred WHERE {
      GRAPH {{graph}} {
        ?segment <#{@jf}segmentOf> {{resource}} .
        #{manifest}
        ?event <#{@jf}segmentOf> ?segment ;
               <#{@jf}eventSequence> ?sequence ;
               <#{@jf}eventKind> ?eventKind ;
               <#{@jf}eventRole> ?role .
        FILTER(?sequence >= {{sequence_start}} && ?sequence <= {{sequence_end}})
        OPTIONAL { ?event <#{@jf}eventPredecessor> ?predecessor }
        OPTIONAL { ?event <#{@jf}sourceEvent> ?sourceEvent }
        OPTIONAL { ?event <#{@jf}sourceOrder> ?sourceOrder }
        OPTIONAL { ?event <#{@jf}accountsResource> ?resource }
        OPTIONAL { ?event <#{@jf}hasCapture> ?capture }
        OPTIONAL { ?resource <#{@prov}generatedAtTime> ?occurred }
      }
    }
    ORDER BY ?sequence ?event ?resource ?capture
    LIMIT {{row_limit}}
    """
  end

  defp experience_case_query(failures_only?) do
    class_filter =
      if failures_only? do
        "FILTER(?caseClass != <https://jido.run/ontology/concept/Success>)"
      else
        ""
      end

    """
    SELECT ?case ?caseClass ?signature ?framework ?frameworkVersion ?environment ?dependency
           ?taskClass ?planPhase ?terminalIntervention ?recorded ?validatedAt ?transition WHERE {
      GRAPH {{graph}} {
        ?case a <#{@jf}ExperienceCase> ;
              <#{@jf}about> {{resource}} ;
              <#{@jf}caseClass> ?caseClass ;
              <#{@jf}problemSignature> ?signature ;
              <#{@jf}environmentFramework> ?framework ;
              <#{@jf}environmentVersion> ?frameworkVersion ;
              <#{@jf}environmentRuntime> ?environment ;
              <#{@jf}dependency> ?dependency ;
              <#{@jf}taskClass> ?taskClass ;
              <#{@jf}planPhase> ?planPhase ;
              <#{@jf}terminalIntervention> ?terminalIntervention ;
              <#{@jf}recordedAt> ?recorded .
        ?transition <#{@jf}transitionSubject> ?case ;
                    <#{@jf}nextState> <https://jido.run/ontology/concept/ExperienceValidated> ;
                    <#{@jf}recordedAt> ?validatedAt .
        FILTER(?signature = {{signature}})
        FILTER(?framework = {{framework}})
        FILTER(?frameworkVersion = {{framework_version}})
        FILTER(?environment = {{environment}})
        FILTER(?dependency = {{dependency}})
        FILTER(?taskClass = {{task_class}})
        FILTER(?planPhase = {{plan_phase}})
        FILTER(?recorded <= {{instant}} && ?validatedAt <= {{instant}})
        #{class_filter}
      }
    }
    ORDER BY DESC(?validatedAt) ?caseClass ?case
    LIMIT {{case_limit}}
    """
  end

  defp lineage_query(relation_pattern, relation_binding) do
    """
    SELECT ?resource ?relation ?related ?resourceRecorded ?recorded ?classification WHERE {
      GRAPH {{graph}} {
        {
          {{resource}} #{relation_pattern} ?related .
          #{relation_binding}
        } UNION {
          ?related #{relation_pattern} {{resource}} .
          #{relation_binding}
        }
        {{resource}} <#{@jf}recordedAt> ?resourceRecorded .
        OPTIONAL { ?related <#{@jf}recordedAt> ?recorded }
        OPTIONAL { ?related <#{@prov}generatedAtTime> ?recorded }
        OPTIONAL { ?related <#{@jf}contentClassification> ?classification }
        FILTER(?resourceRecorded <= {{instant}})
      }
    }
    ORDER BY ?recorded ?relation ?related
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

  defp evidence_bundle_query(match) do
    """
    SELECT ?bundle ?activity ?attempt ?goal ?artifact ?method ?methodVersion ?kind ?evaluator
           ?strength ?classification ?coverageTotal ?coveragePassed ?coverageFailed
           ?coverageSkipped ?coverageUnknown ?completeness ?support ?contradiction ?claim
           ?limitation ?validFrom ?validTo ?sourceGraphIri ?sourceRevision WHERE {
      GRAPH {{graph}} {
        #{match}
        ?bundle a <#{@jf}EvidenceBundle> ;
                <#{@jf}verificationActivity> ?activity ;
                <#{@jf}evidenceStrength> ?strength ;
                <#{@jf}evidenceClassification> ?classification ;
                <#{@jf}coverageTotal> ?coverageTotal ;
                <#{@jf}coveragePassed> ?coveragePassed ;
                <#{@jf}coverageFailed> ?coverageFailed ;
                <#{@jf}coverageSkipped> ?coverageSkipped ;
                <#{@jf}coverageUnknown> ?coverageUnknown ;
                <#{@jf}completenessState> ?completeness ;
                <#{@jf}validFrom> ?validFrom ;
                <#{@jf}validTo> ?validTo .
        ?activity <#{@jf}usesVerificationMethod> ?method ;
                  <#{@jf}evaluatedAttempt> ?attempt ;
                  <#{@jf}evaluatedGoal> ?goal ;
                  <#{@prov}wasAssociatedWith> ?evaluator .
        ?method <#{@jf}version> ?methodVersion ; <#{@jf}verificationKind> ?kind .
        OPTIONAL { ?activity <#{@jf}evaluatesArtifact> ?artifact }
        OPTIONAL { ?bundle <#{@jf}supports> ?support }
        OPTIONAL { ?bundle <#{@jf}contradicts> ?contradiction }
        OPTIONAL { ?bundle <#{@jf}generatedClaim> ?claim }
        OPTIONAL { ?bundle <#{@jf}limitation> ?limitation }
        OPTIONAL {
          ?bundle <#{@jf}sourceGraphRevision> ?sourceRef .
          ?sourceRef <#{@jf}sourceGraph> ?sourceGraphIri ;
                     <#{@jf}sourceRevisionNumber> ?sourceRevision .
        }
      }
    }
    ORDER BY ?bundle ?sourceGraphIri
    LIMIT {{row_limit}}
    """
  end

  defp decision_query(match) do
    """
    SELECT ?decision ?goal ?actor ?policy ?assessment ?mode ?stage ?disposition ?validFrom ?validTo
           ?recorded ?accepted ?rejected ?waived ?deferred ?requested ?superseded ?rationale
           ?evidence ?claimState ?sourceSnapshot ?sourceGraphIri ?sourceRevision
           ?policyGraphRevision ?planGraphRevision WHERE {
      GRAPH {{graph}} {
        #{match}
        ?decision a <#{@jf}Decision> ;
                  <#{@jf}addresses> ?goal ;
                  <#{@jf}decisionAuthority> ?actor ;
                  <#{@jf}governedBy> ?policy ;
                  <#{@jf}evaluates> ?assessment ;
                  <#{@jf}decisionMode> ?mode ;
                  <#{@jf}outcomeStage> ?stage ;
                  <#{@jf}decisionDisposition> ?disposition ;
                  <#{@jf}validFrom> ?validFrom ;
                  <#{@jf}validTo> ?validTo ;
                  <#{@jf}recordedAt> ?recorded .
        OPTIONAL { ?decision <#{@jf}accepts> ?accepted }
        OPTIONAL { ?decision <#{@jf}rejects> ?rejected }
        OPTIONAL { ?decision <#{@jf}waives> ?waived }
        OPTIONAL { ?decision <#{@jf}defers> ?deferred }
        OPTIONAL { ?decision <#{@jf}requestsMoreEvidence> ?requested }
        OPTIONAL { ?decision <#{@jf}supersedes> ?superseded }
        OPTIONAL { ?decision <#{@jf}rationaleReference> ?rationale }
        OPTIONAL { ?assessment <#{@jf}consideredEvidence> ?evidence }
        OPTIONAL { ?assessment <#{@jf}policyGraphRevision> ?policyGraphRevision }
        OPTIONAL { ?assessment <#{@jf}planGraphRevision> ?planGraphRevision }
        OPTIONAL {
          ?assessment <#{@jf}sourceGraphRevision> ?sourceReference .
          ?sourceReference <#{@jf}sourceGraph> ?sourceGraphIri ;
                           <#{@jf}sourceRevisionNumber> ?sourceRevision .
        }
        OPTIONAL {
          ?accepted <#{@jf}epistemicState> ?claimState .
          OPTIONAL { ?accepted <#{@jf}sourceSnapshot> ?sourceSnapshot }
        }
      }
    }
    ORDER BY ?recorded ?decision
    LIMIT {{row_limit}}
    """
  end

  defp knowledge_query(match) do
    """
    SELECT ?assertion ?subject ?predicate ?object ?classification ?scope ?state ?stateRevision
           ?stateTransition ?adoption ?actor ?policy ?policyVersion ?confidence ?validFrom ?validTo
           ?recorded ?decision ?claim ?evidence ?snapshot ?related ?support ?contradiction
           ?superseded ?limitation ?sourceGraphIri ?sourceRevision WHERE {
      GRAPH {{graph}} {
        #{match}
        ?assertion a <#{@jf}KnowledgeAssertion> ;
                   <http://www.w3.org/1999/02/22-rdf-syntax-ns#subject> ?subject ;
                   <http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate> ?predicate ;
                   <http://www.w3.org/1999/02/22-rdf-syntax-ns#object> ?object ;
                   <#{@jf}knowledgeClassification> ?classification ;
                   <#{@jf}validFor> ?scope ;
                   <#{@jf}sourceActivity> ?adoption ;
                   <#{@jf}governedBy> ?policy ;
                   <#{@jf}version> ?policyVersion ;
                   <#{@jf}confidenceScore> ?confidence ;
                   <#{@jf}validFrom> ?validFrom ;
                   <#{@jf}validTo> ?validTo ;
                   <#{@jf}recordedAt> ?recorded .
        ?adoption <#{@prov}wasAssociatedWith> ?actor .
        ?stateTransition a <#{@jf}KnowledgeStateTransition> ;
                         <#{@jf}transitionSubject> ?assertion ;
                         <#{@jf}nextState> ?state ;
                         <#{@jf}subjectRevision> ?stateRevision .
        ?stateActivity <#{@jf}accepts> ?stateTransition .
        OPTIONAL { ?assertion <#{@prov}wasDerivedFrom> ?decision }
        OPTIONAL { ?assertion <#{@jf}sourceClaim> ?claim }
        OPTIONAL { ?assertion <#{@jf}evidenceSource> ?evidence }
        OPTIONAL { ?assertion <#{@jf}sourceSnapshot> ?snapshot }
        OPTIONAL { ?assertion <#{@jf}addresses> ?related }
        OPTIONAL { ?assertion <#{@jf}supports> ?support }
        OPTIONAL { ?assertion <#{@jf}contradicts> ?contradiction }
        OPTIONAL { ?superseded <#{@jf}supersedes> ?assertion }
        OPTIONAL { ?assertion <#{@jf}limitation> ?limitation }
        OPTIONAL {
          ?assertion <#{@jf}sourceGraphRevision> ?sourceReference .
          ?sourceReference <#{@jf}sourceGraph> ?sourceGraphIri ;
                           <#{@jf}sourceRevisionNumber> ?sourceRevision .
        }
      }
    }
    ORDER BY DESC(?recorded) ?assertion
    LIMIT {{row_limit}}
    """
  end

  defp insight_query(predicate) do
    """
    SELECT ?repository ?candidate ?evidence ?classification ?confidence ?limitation WHERE {
      GRAPH {{graph}} {
        {{resource}} <#{@jf}#{predicate}> ?candidate .
        ?repository <#{@jf}#{predicate}> ?candidate .
        FILTER(?repository != {{resource}})
        OPTIONAL { ?candidate <#{@jf}evidenceSource> ?evidence }
        OPTIONAL { ?candidate <#{@jf}knowledgeClassification> ?classification }
        OPTIONAL { ?candidate <#{@jf}confidenceScore> ?confidence }
        OPTIONAL { ?candidate <#{@jf}limitation> ?limitation }
      }
    }
    ORDER BY ?candidate ?repository
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
