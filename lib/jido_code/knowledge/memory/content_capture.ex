defmodule JidoCode.Knowledge.Memory.ContentCapture do
  @moduledoc """
  Immutable per-body capture accounting with orthogonal state dimensions.

  A capture outcome never implies representation, storage, availability,
  retention, hold, reconstruction, or provider availability. Compatibility
  among those dimensions is checked explicitly and digest-only capture is
  never reported as replayable content.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.CaptureManifest
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Retention.Policy, as: RetentionPolicy
  alias JidoCode.Security.DataPolicy

  @enforce_keys [
    :iri,
    :manifest_iri,
    :body_iri,
    :event_iri,
    :event_role,
    :content_identity,
    :classification,
    :purpose,
    :policy_revision,
    :capture_outcome,
    :representation,
    :storage_location,
    :availability,
    :retention,
    :hold,
    :limitations,
    :allowed_uses,
    :retention_class,
    :reconstruction,
    :external_provider_availability
  ]
  defstruct @enforce_keys ++ [:redaction_receipt_iri, :representation_digest]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @outcomes ~w[captured omitted_by_policy unavailable_at_source capture_failed]a
  @representations ~w[exact deterministically_redacted normalized commitment_only absent]a
  @representation_policy %{
    exact: :exact_text,
    deterministically_redacted: :redacted_text,
    normalized: :normalized_text,
    commitment_only: :digest,
    absent: :none
  }
  @allowed_uses ~w[managed_continuity failure_recovery audit evidence_reference]a
  @reconstruction ~w[exact partial impossible externally_dependent]a
  @provider_availability ~w[not_external available unavailable unverified]a

  @spec outcomes() :: [atom()]
  def outcomes, do: @outcomes

  @spec representations() :: [atom()]
  def representations, do: @representations

  @spec new(CaptureManifest.t(), String.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(%CaptureManifest{} = manifest, body_iri, attributes) when is_map(attributes) do
    with {:ok, body} <- CaptureManifest.body(manifest, body_iri),
         true <- attributes[:event_iri] == body.event_iri,
         true <- attributes[:event_role] == body.role,
         true <- attributes[:content_identity] == body.content_identity,
         true <- attributes[:classification] in DataPolicy.classifications(),
         true <- attributes[:purpose] == manifest.purpose,
         true <- attributes[:policy_revision] == manifest.policy_revision,
         true <- attributes[:capture_outcome] in @outcomes,
         true <- attributes[:representation] in @representations,
         :ok <- state_dimension(:storage_location, attributes[:storage_location]),
         :ok <- state_dimension(:availability, attributes[:availability]),
         :ok <- state_dimension(:retention, attributes[:retention]),
         :ok <- state_dimension(:hold, attributes[:hold]),
         :ok <- outcome_representation(attributes),
         :ok <- representation_policy(manifest.profile, attributes),
         :ok <- optional_resource(attributes[:redaction_receipt_iri]),
         :ok <- digest(attributes[:representation_digest], attributes[:representation]),
         :ok <- texts(attributes[:limitations], 512),
         :ok <- allowed_uses(attributes[:allowed_uses]),
         true <- Map.has_key?(RetentionPolicy.classes(), attributes[:retention_class]),
         true <- attributes[:reconstruction] in @reconstruction,
         true <- attributes[:external_provider_availability] in @provider_availability,
         :ok <- reconstruction_consistency(attributes),
         {:ok, iri} <-
           ResourceIdentity.deterministic(:content_capture, manifest.iri <> "\n" <> body.iri) do
      {:ok,
       struct!(__MODULE__,
         iri: iri,
         manifest_iri: manifest.iri,
         body_iri: body.iri,
         event_iri: body.event_iri,
         event_role: body.role,
         content_identity: body.content_identity,
         classification: attributes.classification,
         purpose: manifest.purpose,
         policy_revision: manifest.policy_revision,
         capture_outcome: attributes.capture_outcome,
         representation: attributes.representation,
         storage_location: attributes.storage_location,
         availability: attributes.availability,
         retention: attributes.retention,
         hold: attributes.hold,
         redaction_receipt_iri: attributes[:redaction_receipt_iri],
         representation_digest: attributes[:representation_digest],
         limitations: Enum.sort(attributes.limitations),
         allowed_uses: Enum.sort(attributes.allowed_uses),
         retention_class: attributes.retention_class,
         reconstruction: attributes.reconstruction,
         external_provider_availability: attributes.external_provider_availability
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      :error -> invalid(:content_capture_body)
      _invalid -> invalid(:content_capture)
    end
  rescue
    _error -> invalid(:content_capture)
  end

  def new(_manifest, _body_iri, _attributes), do: invalid(:content_capture)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = capture) do
    [
      {capture.iri, @rdf_type, RDF.iri(@jf <> "ContentCapture")},
      {capture.iri, @jf <> "capturedBody", RDF.iri(capture.body_iri)},
      {capture.iri, @jf <> "sourceEvent", RDF.iri(capture.event_iri)},
      {capture.iri, @jf <> "bodyRole", RDF.XSD.String.new(to_string(capture.event_role))},
      {capture.iri, @jf <> "opaqueContentIdentity", RDF.XSD.String.new(capture.content_identity)},
      {capture.iri, @jf <> "contentClassification", concept(capture.classification)},
      {capture.iri, @jf <> "capturePurpose", RDF.XSD.String.new(to_string(capture.purpose))},
      {capture.iri, @jf <> "capturePolicyRevision", RDF.XSD.String.new(capture.policy_revision)},
      {capture.iri, @jf <> "captureOutcome", concept(outcome_term(capture.capture_outcome))},
      {capture.iri, @jf <> "contentRepresentation", concept(capture.representation)},
      {capture.iri, @jf <> "storageLocation", concept(capture.storage_location)},
      {capture.iri, @jf <> "availabilityState", concept(capture.availability)},
      {capture.iri, @jf <> "retentionState", concept(capture.retention)},
      {capture.iri, @jf <> "holdState", concept(capture.hold)},
      {capture.iri, @jf <> "retentionClass",
       RDF.XSD.String.new(to_string(capture.retention_class))},
      {capture.iri, @jf <> "reconstructionStatus", concept(capture.reconstruction)},
      {capture.iri, @jf <> "externalProviderAvailability",
       concept(capture.external_provider_availability)}
    ] ++
      optional_iri(capture.iri, @jf <> "redactionReceipt", capture.redaction_receipt_iri) ++
      optional_literal(
        capture.iri,
        @jf <> "representationDigest",
        capture.representation_digest
      ) ++
      Enum.map(capture.limitations, fn limitation ->
        {capture.iri, @jf <> "limitation", RDF.XSD.String.new(limitation)}
      end) ++
      Enum.map(capture.allowed_uses, fn use ->
        {capture.iri, @jf <> "allowedUse", RDF.XSD.String.new(to_string(use))}
      end)
  end

  @spec replayable?(t()) :: boolean()
  def replayable?(%__MODULE__{} = capture) do
    capture.capture_outcome == :captured and capture.representation == :exact and
      capture.availability == :available and capture.reconstruction == :exact
  end

  @doc """
  Binds capture shells to their owning event attributes. All captures must
  name that event and body role; duplicate body ownership is rejected.
  """
  @spec attach_to_event([t()], map()) :: {:ok, map()} | {:error, Error.t()}
  def attach_to_event(captures, event_attributes)
      when is_list(captures) and captures != [] and is_map(event_attributes) do
    body_iris = Enum.map(captures, & &1.body_iri)

    if Enum.all?(captures, fn
         %__MODULE__{} = capture ->
           capture.event_iri == event_attributes[:source_iri] and
             capture.event_role == event_attributes[:body_role]

         _invalid ->
           false
       end) and length(body_iris) == length(Enum.uniq(body_iris)) do
      {:ok,
       event_attributes
       |> Map.put(:content_capture_iris, Enum.map(captures, & &1.iri) |> Enum.sort())
       |> Map.put(:capture_statements, Enum.flat_map(captures, &statements/1))}
    else
      invalid(:capture_event_ownership)
    end
  end

  def attach_to_event(_captures, _event_attributes), do: invalid(:capture_event_ownership)

  defp outcome_representation(%{
         capture_outcome: :captured,
         representation: :deterministically_redacted,
         redaction_receipt_iri: receipt
       })
       when is_binary(receipt),
       do: :ok

  defp outcome_representation(%{capture_outcome: :captured, representation: representation})
       when representation not in [:absent, :deterministically_redacted],
       do: :ok

  defp outcome_representation(%{
         capture_outcome: outcome,
         representation: :absent,
         storage_location: :omitted,
         availability: availability
       })
       when outcome in [:omitted_by_policy, :unavailable_at_source, :capture_failed] and
              availability in [:unavailable, :failed],
       do: :ok

  defp outcome_representation(_attributes), do: invalid(:capture_outcome_representation)

  defp representation_policy(profile, attributes) do
    policy_representation = Map.fetch!(@representation_policy, attributes.representation)

    cond do
      attributes.classification == :secret_value ->
        unauthorized(:capture_secret_value)

      attributes.representation == :absent ->
        :ok

      DataPolicy.durable_allowed?(
        attributes.classification,
        :run_event_segment,
        policy_representation,
        profile
      ) ->
        :ok

      true ->
        unauthorized(:capture_representation)
    end
  end

  defp reconstruction_consistency(attributes) do
    cond do
      attributes.representation == :commitment_only and attributes.reconstruction == :exact ->
        invalid(:capture_reconstruction)

      attributes.representation == :absent and attributes.reconstruction != :impossible ->
        invalid(:capture_reconstruction)

      attributes.storage_location == :external_provider and
          attributes.external_provider_availability == :not_external ->
        invalid(:capture_provider_availability)

      attributes.storage_location != :external_provider and
          attributes.external_provider_availability != :not_external ->
        invalid(:capture_provider_availability)

      true ->
        :ok
    end
  end

  defp state_dimension(key, value) do
    if value in Map.fetch!(DataPolicy.dimensions(), key),
      do: :ok,
      else: invalid(:capture_state_dimension)
  end

  defp allowed_uses(values) when is_list(values) and values != [] do
    if length(values) == length(Enum.uniq(values)) and Enum.all?(values, &(&1 in @allowed_uses)),
      do: :ok,
      else: invalid(:capture_allowed_use)
  end

  defp allowed_uses(_values), do: invalid(:capture_allowed_use)

  defp texts(values, maximum) when is_list(values) and length(values) <= 20 do
    if Enum.all?(values, &(is_binary(&1) and byte_size(&1) in 1..maximum)),
      do: :ok,
      else: invalid(:capture_limitations)
  end

  defp texts(_values, _maximum), do: invalid(:capture_limitations)

  defp digest(nil, :absent), do: :ok

  defp digest(value, _representation) when is_binary(value) do
    if Regex.match?(~r/^[a-f0-9]{64}$/, value), do: :ok, else: invalid(:capture_digest)
  end

  defp digest(_value, _representation), do: invalid(:capture_digest)

  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: ResourceIdentity.validate(value)

  defp outcome_term(:omitted_by_policy), do: :omitted
  defp outcome_term(:unavailable_at_source), do: :unavailable
  defp outcome_term(:capture_failed), do: :capture_failed
  defp outcome_term(outcome), do: outcome

  defp concept(value), do: RDF.iri(@concept <> Macro.camelize(to_string(value)))
  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, value), do: [{subject, predicate, RDF.iri(value)}]
  defp optional_literal(_subject, _predicate, nil), do: []

  defp optional_literal(subject, predicate, value),
    do: [{subject, predicate, RDF.XSD.String.new(value)}]

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, Error.new(:unauthorized, operation)}
end
