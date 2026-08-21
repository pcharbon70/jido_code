defmodule JidoCode.Knowledge.Memory.ArtifactClaim do
  @moduledoc "Exact source, verification, evidence-strength, and freshness claim contract."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ArtifactClaimTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :repository_iri,
    :repository_revision_iri,
    :artifact_iri,
    :path,
    :symbol,
    :selector,
    :content_digest,
    :claim,
    :verification_command,
    :verification_environment,
    :evidence_iri,
    :evidence_strength,
    :valid_at,
    :checked_at,
    :transition,
    :runtime_success_only?
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
  @revision "1.0.0"
  @strengths ~w[weak moderate strong]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  def revision, do: @revision
  def evidence_strengths, do: @strengths

  def new(attributes) when is_map(attributes) do
    with :ok <-
           resources(
             attributes,
             ~w[repository_iri repository_revision_iri artifact_iri evidence_iri actor_iri cause_iri]a
           ),
         true <-
           text?(attributes[:path], 512) and optional_text?(attributes[:symbol], 256) and
             optional_text?(attributes[:selector], 256),
         true <- digest?(attributes[:content_digest]) and text?(attributes[:claim], 2_048),
         true <- text?(attributes[:verification_command], 1_024),
         true <- environment?(attributes[:verification_environment]),
         true <- attributes[:evidence_strength] in @strengths,
         false <- attributes[:runtime_success_only?],
         %DateTime{} = valid_at <- attributes[:valid_at],
         %DateTime{} = checked_at <- attributes[:checked_at],
         true <- DateTime.compare(valid_at, checked_at) in [:lt, :eq],
         {:ok, iri} <- identity(attributes),
         {:ok, transition} <-
           ArtifactClaimTransition.new(%{
             claim_iri: iri,
             prior_state: nil,
             next_state: :fresh,
             revision: 0,
             expected_predecessor: nil,
             actor_iri: attributes.actor_iri,
             cause_iri: attributes.cause_iri,
             reason: "record independently evidenced artifact claim",
             recorded_at: checked_at
           }) do
      fields =
        attributes
        |> Map.take(@enforce_keys)
        |> Map.merge(%{
          iri: iri,
          revision: @revision,
          valid_at: valid_at,
          checked_at: checked_at,
          transition: transition
        })

      {:ok, struct!(__MODULE__, fields)}
    else
      _invalid -> {:error, Error.new(:invalid_input, :artifact_claim)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :artifact_claim)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :artifact_claim)}

  def statements(claim) do
    [
      {claim.iri, @rdf_type, RDF.iri(@jf <> "ArtifactClaim")},
      {claim.iri, @jf <> "about", RDF.iri(claim.repository_iri)},
      {claim.iri, @jf <> "sourceSnapshot", RDF.iri(claim.repository_revision_iri)},
      {claim.iri, @jf <> "evaluatesArtifact", RDF.iri(claim.artifact_iri)},
      {claim.iri, @jf <> "path", RDF.XSD.String.new(claim.path)},
      {claim.iri, @jf <> "contentDigest", RDF.XSD.String.new(claim.content_digest)},
      {claim.iri, @jf <> "value", RDF.XSD.String.new(claim.claim)},
      {claim.iri, @jf <> "verificationCommand", RDF.XSD.String.new(claim.verification_command)},
      {claim.iri, @jf <> "verificationEnvironment",
       RDF.XSD.String.new(claim.verification_environment)},
      {claim.iri, @jf <> "evidenceSource", RDF.iri(claim.evidence_iri)},
      {claim.iri, @jf <> "evidenceStrength",
       RDF.iri(@concept <> Macro.camelize(to_string(claim.evidence_strength)))},
      {claim.iri, @jf <> "validAt", RDF.XSD.DateTime.new(claim.valid_at)},
      {claim.iri, @jf <> "checkedAt", RDF.XSD.DateTime.new(claim.checked_at)}
    ] ++ optional_literals(claim) ++ ArtifactClaimTransition.statements(claim.transition)
  end

  def current?(claim, current, transitions \\ nil) do
    state = if transitions, do: lifecycle_state(transitions), else: claim.transition.next_state

    state == :fresh and current[:repository_revision_iri] == claim.repository_revision_iri and
      current[:artifact_iri] == claim.artifact_iri and
      current[:content_digest] == claim.content_digest and
      current[:symbol] == claim.symbol and
      current[:verification_environment] == claim.verification_environment and
      current[:verification_command] == claim.verification_command and
      current[:evidence_iri] == claim.evidence_iri
  end

  def drift_transition(claim, current, transition, attributes) do
    state =
      cond do
        current[:contradicted?] -> :contradicted
        current[:invalidated?] -> :invalidated
        current[:superseded_by] -> :superseded
        current?(claim, current, [claim.transition, transition]) -> :fresh
        true -> :stale
      end

    ArtifactClaimTransition.new(%{
      claim_iri: claim.iri,
      prior_state: transition.next_state,
      next_state: state,
      revision: transition.revision + 1,
      expected_predecessor: transition.iri,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:cause_iri],
      reason: "artifact claim freshness reevaluation",
      recorded_at: attributes[:recorded_at]
    })
  end

  defp lifecycle_state(transitions) do
    case ArtifactClaimTransition.resolve(transitions) do
      {:ok, endpoint} -> endpoint.state
      _error -> :invalidated
    end
  end

  defp identity(attributes),
    do:
      ResourceIdentity.deterministic(
        :artifact_claim,
        :erlang.term_to_binary(Map.drop(attributes, [:actor_iri, :cause_iri]), [:deterministic])
      )

  defp resources(attributes, keys),
    do:
      if(Enum.all?(keys, &(ResourceIdentity.validate(attributes[&1]) == :ok)),
        do: :ok,
        else: :error
      )

  defp text?(value, max), do: is_binary(value) and byte_size(value) in 1..max
  defp optional_text?(nil, _max), do: true
  defp optional_text?(value, max), do: text?(value, max)
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp environment?(value), do: is_binary(value) and byte_size(value) in 1..512

  defp optional_literals(claim),
    do:
      Enum.flat_map([symbol: "symbol", selector: "selector"], fn {field, predicate} ->
        case Map.fetch!(claim, field) do
          nil -> []
          value -> [{claim.iri, @jf <> predicate, RDF.XSD.String.new(value)}]
        end
      end)
end
