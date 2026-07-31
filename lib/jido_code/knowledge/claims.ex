defmodule JidoCode.Knowledge.Claims do
  @moduledoc """
  Compiles first-class claim resources and selects direct-statement eligibility.

  Returned maps are transient command projections. The emitted RDF statements
  are the durable claim representation.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Temporal

  @jf "https://jido.run/ontology/factory#"
  @jfc "https://jido.run/ontology/concept/"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdf_subject "http://www.w3.org/1999/02/22-rdf-syntax-ns#subject"
  @rdf_predicate "http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate"
  @rdf_object "http://www.w3.org/1999/02/22-rdf-syntax-ns#object"
  @prov_generated_at "http://www.w3.org/ns/prov#generatedAtTime"
  @prov_invalidated_at "http://www.w3.org/ns/prov#invalidatedAtTime"
  @states %{
    observed: "Observed",
    asserted: "Asserted",
    inferred: "Inferred",
    proposed: "ClaimProposed",
    accepted: "Accepted",
    rejected: "Rejected",
    contradicted: "Contradicted",
    superseded: "ClaimSuperseded",
    invalidated: "Invalidated"
  }
  @confidence_bands %{low: "LowConfidence", medium: "MediumConfidence", high: "HighConfidence"}
  @claim_required_keys [
    :claim_iri,
    :graph_iri,
    :subject,
    :predicate,
    :object,
    :source_activity,
    :epistemic_state,
    :recorded_at
  ]
  @statement_level_keys [
    :consequential?,
    :disputable?,
    :epistemic_state,
    :source_activity,
    :confidence_value,
    :confidence_band,
    :valid_from,
    :valid_to,
    :source_observed_at,
    :invalidated_at,
    :supports,
    :contradicts,
    :supersedes
  ]

  @spec representation(map(), map()) :: {:ok, :direct | :claim} | {:error, Error.t()}
  def representation(graph_metadata, requirements)
      when is_map(graph_metadata) and is_map(requirements) do
    with {:ok, contract} <- GraphRegistry.fetch(Map.get(graph_metadata, :family)) do
      direct? =
        contract.mutability == :immutable and
          Map.get(graph_metadata, :lifecycle_state) == :closed and
          Map.get(graph_metadata, :completeness_state) == :complete and
          Enum.all?(@statement_level_keys, &empty_requirement?(Map.get(requirements, &1)))

      {:ok, if(direct?, do: :direct, else: :claim)}
    end
  end

  def representation(_metadata, _requirements),
    do: {:error, Error.new(:invalid_input, :claim_representation)}

  @spec build(map()) :: {:ok, map()} | {:error, Error.t()}
  def build(attributes) when is_map(attributes) do
    with true <- Enum.all?(@claim_required_keys, &Map.has_key?(attributes, &1)),
         :ok <- validate_identity(attributes),
         {:ok, statement} <- statement(attributes),
         {:ok, state_iri} <- state_iri(attributes.epistemic_state),
         :ok <- Temporal.validate(attributes),
         :ok <- validate_assessment(attributes),
         :ok <- validate_decision(attributes) do
      projection = projection(attributes, statement)

      {:ok,
       %{
         claim_iri: attributes.claim_iri,
         projection: projection,
         quads: claim_quads(attributes, statement, state_iri)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :claim_contract)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :claim_contract)}
  end

  def build(_attributes), do: {:error, Error.new(:invalid_input, :claim_contract)}

  @spec epistemic_states() :: [atom()]
  def epistemic_states, do: @states |> Map.keys() |> Enum.sort()

  defp validate_identity(attributes) do
    with :ok <- ResourceIdentity.validate(attributes.claim_iri),
         :ok <- ResourceIdentity.validate(attributes.source_activity),
         {:ok, _family} <- GraphRegistry.identify(attributes.graph_iri),
         true <- RDF.IRI.valid?(attributes.subject),
         true <- RDF.IRI.valid?(attributes.predicate),
         :ok <- validate_links(attributes) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :claim_identity)}
    end
  end

  defp validate_links(attributes) do
    links =
      [:supports, :contradicts, :supersedes]
      |> Enum.flat_map(fn key -> List.wrap(Map.get(attributes, key, [])) end)

    if Enum.all?(links, &(ResourceIdentity.validate(&1) == :ok)),
      do: :ok,
      else: {:error, Error.new(:invalid_input, :claim_relationship)}
  end

  defp statement(attributes) do
    triple = RDF.triple(attributes.subject, attributes.predicate, attributes.object)

    if RDF.Triple.valid?(triple) and not RDF.Triple.has_bnode?(triple),
      do: {:ok, triple},
      else: {:error, Error.new(:invalid_input, :claim_statement)}
  end

  defp validate_assessment(attributes) do
    with :ok <- validate_confidence(Map.get(attributes, :confidence_value)),
         :ok <- validate_confidence_band(Map.get(attributes, :confidence_band)) do
      :ok
    end
  end

  defp validate_confidence(nil), do: :ok
  defp validate_confidence(value) when is_number(value) and value >= 0 and value <= 1, do: :ok
  defp validate_confidence(_value), do: {:error, Error.new(:invalid_input, :claim_confidence)}

  defp validate_confidence_band(nil), do: :ok

  defp validate_confidence_band(value) when is_map_key(@confidence_bands, value), do: :ok

  defp validate_confidence_band(_value),
    do: {:error, Error.new(:invalid_input, :claim_confidence)}

  defp validate_decision(%{epistemic_state: state} = attributes)
       when state in [:accepted, :rejected] do
    with :ok <- ResourceIdentity.validate(Map.get(attributes, :decision)),
         :ok <- ResourceIdentity.validate(Map.get(attributes, :decision_authority)),
         %DateTime{} = decision_at <- Map.get(attributes, :decision_at),
         true <- DateTime.compare(decision_at, attributes.recorded_at) != :gt do
      :ok
    else
      _invalid -> {:error, Error.new(:invalid_input, :claim_decision)}
    end
  end

  defp validate_decision(_attributes), do: :ok

  defp claim_quads(attributes, {subject, predicate, object}, state_iri) do
    claim = attributes.claim_iri

    [
      triple(claim, @rdf_type, iri(@jf <> "Claim")),
      triple(claim, @rdf_subject, subject),
      triple(claim, @rdf_predicate, predicate),
      triple(claim, @rdf_object, object),
      triple(claim, @jf <> "sourceActivity", iri(attributes.source_activity)),
      triple(claim, @jf <> "graphScope", iri(attributes.graph_iri)),
      triple(claim, @jf <> "epistemicState", iri(state_iri)),
      triple(claim, @jf <> "recordedAt", RDF.literal(attributes.recorded_at))
    ]
    |> maybe_add_time(attributes, :generated_at, @prov_generated_at)
    |> maybe_add_time(attributes, :valid_from, @jf <> "validFrom")
    |> maybe_add_time(attributes, :valid_to, @jf <> "validTo")
    |> maybe_add_time(attributes, :source_observed_at, @jf <> "sourceObservedAt")
    |> maybe_add_time(attributes, :invalidated_at, @prov_invalidated_at)
    |> maybe_add_confidence(attributes)
    |> add_links(attributes, :supports, "supports")
    |> add_links(attributes, :contradicts, "contradicts")
    |> add_links(attributes, :supersedes, "supersedes")
    |> add_decision(attributes)
  end

  defp maybe_add_time(quads, attributes, key, predicate) do
    case Map.get(attributes, key) do
      %DateTime{} = value -> [triple(attributes.claim_iri, predicate, RDF.literal(value)) | quads]
      nil -> quads
    end
  end

  defp maybe_add_confidence(quads, attributes) do
    quads =
      case Map.get(attributes, :confidence_value) do
        nil -> quads
        value -> [triple(attributes.claim_iri, @jf <> "confidenceValue", decimal(value)) | quads]
      end

    case Map.get(attributes, :confidence_band) do
      nil ->
        quads

      band ->
        [
          triple(
            attributes.claim_iri,
            @jf <> "confidenceBand",
            iri(@jfc <> Map.fetch!(@confidence_bands, band))
          )
          | quads
        ]
    end
  end

  defp add_links(quads, attributes, key, predicate) do
    Enum.reduce(List.wrap(Map.get(attributes, key, [])), quads, fn target, acc ->
      [triple(attributes.claim_iri, @jf <> predicate, iri(target)) | acc]
    end)
  end

  defp add_decision(quads, %{epistemic_state: :accepted} = attributes) do
    decision_quads(attributes, "accepts") ++ quads
  end

  defp add_decision(quads, %{epistemic_state: :rejected} = attributes) do
    decision_quads(attributes, "rejects") ++ quads
  end

  defp add_decision(quads, _attributes), do: quads

  defp projection(attributes, statement) do
    attributes
    |> Map.take(
      @claim_required_keys ++
        @statement_level_keys ++ [:decision, :decision_authority, :decision_at, :generated_at]
    )
    |> Map.put(:statement, statement)
  end

  defp decision_quads(attributes, disposition) do
    [
      triple(attributes.decision, @rdf_type, iri(@jf <> "Decision")),
      triple(
        attributes.decision,
        @jf <> "decisionAuthority",
        iri(attributes.decision_authority)
      ),
      triple(attributes.decision, @prov_generated_at, RDF.literal(attributes.decision_at)),
      triple(attributes.decision, @jf <> disposition, iri(attributes.claim_iri))
    ]
  end

  defp state_iri(state) do
    case Map.fetch(@states, state) do
      {:ok, local} -> {:ok, @jfc <> local}
      :error -> {:error, Error.new(:invalid_input, :claim_epistemic_state)}
    end
  end

  defp decimal(value) when is_integer(value), do: RDF.XSD.Decimal.new(Integer.to_string(value))
  defp decimal(value) when is_float(value), do: RDF.XSD.Decimal.new(Float.to_string(value))
  defp triple(subject, predicate, object), do: RDF.triple(subject, predicate, object)
  defp iri(value), do: RDF.iri(value)
  defp empty_requirement?(nil), do: true
  defp empty_requirement?(false), do: true
  defp empty_requirement?([]), do: true
  defp empty_requirement?(_value), do: false
end
