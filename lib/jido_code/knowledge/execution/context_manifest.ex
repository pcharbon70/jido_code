defmodule JidoCode.Knowledge.Execution.ContextManifest do
  @moduledoc """
  Immutable, digest-attributed context manifests for governed model calls.

  The first manifest (index 0) is created atomically with its execution
  attempt; later manifests are created atomically with the model-invocation
  start that changed context. A manifest records what JidoCode supplied, its
  reconstruction status, and - for delegated input - explicitly marks
  provider-internal context unavailable rather than inferred.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [:iri, :attempt_iri, :index, :digest, :kind, :reconstruction]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @kinds ~w[host_context delegated_input]a
  @reconstructions ~w[exact partial unavailable]a
  @digest64 ~r/^[a-f0-9]{64}$/

  @spec new(String.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attempt_iri, attributes) when is_binary(attempt_iri) and is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attempt_iri),
         index when is_integer(index) and index >= 0 <- attributes[:index],
         digest when is_binary(digest) <- attributes[:digest],
         true <- Regex.match?(@digest64, digest),
         kind when kind in @kinds <- attributes[:kind],
         reconstruction when reconstruction in @reconstructions <-
           attributes[:reconstruction],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :context_manifest,
             attempt_iri <> "\n" <> Integer.to_string(index)
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         attempt_iri: attempt_iri,
         index: index,
         digest: digest,
         kind: kind,
         reconstruction: reconstruction
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:context_manifest)
    end
  rescue
    _error -> invalid(:context_manifest)
  end

  def new(_attempt_iri, _attributes), do: invalid(:context_manifest)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = manifest) do
    [
      {manifest.iri, @rdf_type, RDF.iri(@jf <> "ContextManifest")},
      {manifest.iri, @jf <> "manifestOf", RDF.iri(manifest.attempt_iri)},
      {manifest.iri, @jf <> "manifestIndex", RDF.XSD.NonNegativeInteger.new(manifest.index)},
      {manifest.iri, @jf <> "manifestDigest", RDF.XSD.String.new(manifest.digest)},
      {manifest.iri, @jf <> "manifestKind",
       RDF.iri(@concept <> Macro.camelize(to_string(manifest.kind)))},
      {manifest.iri, @jf <> "reconstructionState",
       RDF.iri(@concept <> Macro.camelize(to_string(manifest.reconstruction)))}
    ]
  end

  @spec first_manifest_iri(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def first_manifest_iri(attempt_iri) when is_binary(attempt_iri),
    do: ResourceIdentity.deterministic(:context_manifest, attempt_iri <> "\n0")

  def first_manifest_iri(_attempt_iri), do: invalid(:context_manifest)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
