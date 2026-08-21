defmodule JidoCode.Knowledge.Memory.ContentChunk do
  @moduledoc "Bounded ordered ciphertext chunk for an immutable episode-content segment."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [:iri, :content_iri, :index, :ciphertext, :byte_count, :ciphertext_digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @revision "1.0.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"

  def revision, do: @revision

  def new(content_iri, index, ciphertext)
      when is_integer(index) and index >= 0 and is_binary(ciphertext) do
    maximum = Guardrails.capacity_profile().ciphertext_chunk_bytes

    with :ok <- ResourceIdentity.validate(content_iri),
         true <- byte_size(ciphertext) in 1..maximum,
         digest = digest(ciphertext),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :content_chunk,
             Enum.join([content_iri, Integer.to_string(index), digest], "\n")
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         content_iri: content_iri,
         index: index,
         ciphertext: ciphertext,
         byte_count: byte_size(ciphertext),
         ciphertext_digest: digest
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :content_chunk)}
    end
  end

  def new(_content_iri, _index, _ciphertext),
    do: {:error, Error.new(:invalid_input, :content_chunk)}

  def statements(%__MODULE__{} = chunk) do
    [
      {chunk.iri, @rdf_type, RDF.iri(@jf <> "ContentChunk")},
      {chunk.iri, @jf <> "partOf", RDF.iri(chunk.content_iri)},
      {chunk.iri, @jf <> "chunkIndex", RDF.XSD.NonNegativeInteger.new(chunk.index)},
      {chunk.iri, @jf <> "ciphertext", RDF.XSD.String.new(Base.encode64(chunk.ciphertext))},
      {chunk.iri, @jf <> "byteCount", RDF.XSD.NonNegativeInteger.new(chunk.byte_count)},
      {chunk.iri, @jf <> "ciphertextDigest", RDF.XSD.String.new(chunk.ciphertext_digest)}
    ]
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
