defmodule JidoCode.Knowledge.Memory.ContentAccessOutcome do
  @moduledoc "Byte-free audit outcome for a consumed content-access permit."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :permit_iri,
    :content_iri,
    :selected_iris,
    :status,
    :byte_count,
    :ciphertext_commitment,
    :reason,
    :recorded_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @revision "1.0.0"
  @statuses ~w[released denied unavailable failed ambiguous]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  def revision, do: @revision
  def statuses, do: @statuses

  def new(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:permit_iri]),
         :ok <- ResourceIdentity.validate(attributes[:content_iri]),
         true <- attributes[:status] in @statuses,
         true <- is_integer(attributes[:byte_count]) and attributes.byte_count >= 0,
         true <- digest?(attributes[:ciphertext_commitment]),
         true <- text?(attributes[:reason], 512),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         true <- resources?(attributes[:selected_iris]),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :content_access_outcome,
             Enum.join([attributes.permit_iri, to_string(attributes.status)], "\n")
           ) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(Map.take(attributes, @enforce_keys), %{
           iri: iri,
           revision: @revision,
           recorded_at: recorded_at
         })
       )}
    else
      _invalid -> {:error, Error.new(:invalid_input, :content_access_outcome)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :content_access_outcome)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :content_access_outcome)}

  def statements(%__MODULE__{} = outcome) do
    [
      {outcome.iri, @rdf_type, RDF.iri(@jf <> "ContentAccessOutcome")},
      {outcome.iri, @jf <> "consumesPermit", RDF.iri(outcome.permit_iri)},
      {outcome.iri, @jf <> "selectedContent", RDF.iri(outcome.content_iri)},
      {outcome.iri, @jf <> "accessOutcome",
       RDF.iri(@concept <> Macro.camelize(to_string(outcome.status)))},
      {outcome.iri, @jf <> "releasedByteCount",
       RDF.XSD.NonNegativeInteger.new(outcome.byte_count)},
      {outcome.iri, @jf <> "ciphertextCommitment",
       RDF.XSD.String.new(outcome.ciphertext_commitment)},
      {outcome.iri, @jf <> "reason", RDF.XSD.String.new(outcome.reason)},
      {outcome.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(outcome.recorded_at)}
    ] ++
      Enum.map(outcome.selected_iris, fn iri ->
        {outcome.iri, @jf <> "selectedResource", RDF.iri(iri)}
      end)
  end

  defp resources?(values) when is_list(values) and values != [],
    do: Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok))

  defp resources?(_values), do: false
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp text?(value, max), do: is_binary(value) and byte_size(value) in 1..max
end
