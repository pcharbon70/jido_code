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
end
