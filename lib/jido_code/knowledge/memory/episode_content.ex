defmodule JidoCode.Knowledge.Memory.EpisodeContent do
  @moduledoc "Complete immutable graph-native encrypted content segment."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ContentChunk
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @enforce_keys [
    :iri,
    :revision,
    :repository_iri,
    :source_event_iri,
    :content_identity,
    :segment_index,
    :policy_revision,
    :classification,
    :media_type,
    :representation,
    :key_reference_iri,
    :key_generation,
    :encryption_algorithm,
    :nonce,
    :authentication_tag,
    :aad_digest,
    :chunks,
    :byte_count,
    :ciphertext_digest,
    :completeness_root,
    :closed_at,
    :encrypted_before_command?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @revision "1.0.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @allowed_classifications ~w[artifact_content encrypted_content]a

  def revision, do: @revision

  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes, ~w[repository_iri source_event_iri key_reference_iri]a),
         true <- opaque_identity?(attributes[:content_identity]),
         true <- non_negative_integer?(attributes[:segment_index]),
         true <- attributes[:policy_revision] == DataPolicy.revision(),
         true <- attributes[:classification] in @allowed_classifications,
         true <- media_type?(attributes[:media_type]),
         true <- attributes[:representation] == :ciphertext,
         true <- attributes[:encrypted_before_command?] == true,
         true <- positive_integer?(attributes[:key_generation]),
         true <- attributes[:encryption_algorithm] == :aes_256_gcm,
         true <- fixed_binary?(attributes[:nonce], 12),
         true <- fixed_binary?(attributes[:authentication_tag], 16),
         true <- digest?(attributes[:aad_digest]),
         %DateTime{} = closed_at <- attributes[:closed_at],
         {:ok, iri} <- identity(attributes),
         {:ok, chunks} <- build_chunks(iri, attributes[:ciphertext_chunks], attributes),
         ciphertext = chunks |> Enum.map_join(& &1.ciphertext),
         byte_count = byte_size(ciphertext),
         ciphertext_digest = digest(ciphertext),
         completeness_root = completeness_root(chunks, attributes),
         true <- attributes[:byte_count] in [nil, byte_count],
         true <- attributes[:ciphertext_digest] in [nil, ciphertext_digest],
         true <- attributes[:completeness_root] in [nil, completeness_root] do
      {:ok,
       %__MODULE__{
         iri: iri,
         revision: @revision,
         repository_iri: attributes.repository_iri,
         source_event_iri: attributes.source_event_iri,
         content_identity: attributes.content_identity,
         segment_index: attributes.segment_index,
         policy_revision: attributes.policy_revision,
         classification: attributes.classification,
         media_type: attributes.media_type,
         representation: :ciphertext,
         key_reference_iri: attributes.key_reference_iri,
         key_generation: attributes.key_generation,
         encryption_algorithm: attributes.encryption_algorithm,
         nonce: attributes.nonce,
         authentication_tag: attributes.authentication_tag,
         aad_digest: attributes.aad_digest,
         chunks: chunks,
         byte_count: byte_count,
         ciphertext_digest: ciphertext_digest,
         completeness_root: completeness_root,
         closed_at: closed_at,
         encrypted_before_command?: true
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :episode_content)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :episode_content)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :episode_content)}

  def statements(%__MODULE__{} = content) do
    [
      {content.iri, @rdf_type, RDF.iri(@jf <> "EpisodeContent")},
      {content.iri, @jf <> "about", RDF.iri(content.repository_iri)},
      {content.iri, @jf <> "sourceEvent", RDF.iri(content.source_event_iri)},
      {content.iri, @jf <> "opaqueContentIdentity", RDF.XSD.String.new(content.content_identity)},
      {content.iri, @jf <> "segmentIndex", RDF.XSD.NonNegativeInteger.new(content.segment_index)},
      {content.iri, @jf <> "capturePolicyRevision", RDF.XSD.String.new(content.policy_revision)},
      {content.iri, @jf <> "contentClassification",
       RDF.iri(@concept <> Macro.camelize(to_string(content.classification)))},
      {content.iri, @jf <> "mediaType", RDF.XSD.String.new(content.media_type)},
      {content.iri, @jf <> "representation", RDF.iri(@concept <> "Ciphertext")},
      {content.iri, @jf <> "keyReference", RDF.iri(content.key_reference_iri)},
      {content.iri, @jf <> "keyGeneration",
       RDF.XSD.NonNegativeInteger.new(content.key_generation)},
      {content.iri, @jf <> "encryptionAlgorithm", RDF.XSD.String.new("AES-256-GCM")},
      {content.iri, @jf <> "encryptionNonce", RDF.XSD.String.new(Base.encode64(content.nonce))},
      {content.iri, @jf <> "authenticationTag",
       RDF.XSD.String.new(Base.encode64(content.authentication_tag))},
      {content.iri, @jf <> "authenticatedContextDigest", RDF.XSD.String.new(content.aad_digest)},
      {content.iri, @jf <> "byteCount", RDF.XSD.NonNegativeInteger.new(content.byte_count)},
      {content.iri, @jf <> "ciphertextDigest", RDF.XSD.String.new(content.ciphertext_digest)},
      {content.iri, @jf <> "completenessRootDigest",
       RDF.XSD.String.new(content.completeness_root)},
      {content.iri, @jf <> "lifecycleState", RDF.iri(@concept <> "Closed")},
      {content.iri, @jf <> "completenessState", RDF.iri(@concept <> "Complete")},
      {content.iri, @jf <> "closedAt", RDF.XSD.DateTime.new(content.closed_at)}
    ] ++
      Enum.flat_map(content.chunks, fn chunk ->
        [{content.iri, @jf <> "hasChunk", RDF.iri(chunk.iri)} | ContentChunk.statements(chunk)]
      end)
  end

  def plaintext(content) when is_struct(content, __MODULE__), do: :unavailable

  defp build_chunks(content_iri, chunks, attributes) when is_list(chunks) do
    maximum = Guardrails.capacity_profile().content_chunks_per_command

    with true <- length(chunks) in 1..maximum,
         {:ok, specs} <- normalize_chunk_specs(chunks, attributes),
         true <- Enum.map(specs, & &1.index) == Enum.to_list(0..(length(specs) - 1)),
         built <- Enum.map(specs, &ContentChunk.new(content_iri, &1.index, &1.ciphertext)),
         true <- Enum.all?(built, &match?({:ok, %ContentChunk{}}, &1)) do
      {:ok, Enum.map(built, &elem(&1, 1))}
    else
      _invalid -> {:error, Error.new(:invalid_input, :content_chunks)}
    end
  end

  defp build_chunks(_content_iri, _chunks, _attributes),
    do: {:error, Error.new(:invalid_input, :content_chunks)}

  defp normalize_chunk_specs(chunks, attributes) do
    specs =
      Enum.with_index(chunks, fn
        ciphertext, index when is_binary(ciphertext) ->
          {:ok, %{index: index, ciphertext: ciphertext}}

        chunk, _index when is_map(chunk) ->
          with true <- chunk[:classification] in [nil, attributes[:classification]],
               true <- chunk[:policy_revision] in [nil, attributes[:policy_revision]],
               true <- chunk[:media_type] in [nil, attributes[:media_type]],
               true <- chunk[:key_reference_iri] in [nil, attributes[:key_reference_iri]],
               true <- is_integer(chunk[:index]),
               true <- is_binary(chunk[:ciphertext]) do
            {:ok, Map.take(chunk, [:index, :ciphertext])}
          else
            _invalid -> :error
          end

        _chunk, _index ->
          :error
      end)

    if Enum.all?(specs, &match?({:ok, _}, &1)),
      do: {:ok, Enum.map(specs, &elem(&1, 1))},
      else: {:error, Error.new(:invalid_input, :content_chunks)}
  end

  defp identity(attributes) do
    ResourceIdentity.deterministic(
      :episode_content,
      Enum.join(
        [
          attributes.repository_iri,
          attributes.source_event_iri,
          attributes.content_identity,
          Integer.to_string(attributes.segment_index)
        ],
        "\n"
      )
    )
  end

  defp completeness_root(chunks, attributes) do
    material =
      Enum.map(chunks, &{&1.index, &1.byte_count, &1.ciphertext_digest}) ++
        [
          attributes.policy_revision,
          attributes.classification,
          attributes.media_type,
          attributes.key_reference_iri,
          attributes.key_generation,
          attributes.encryption_algorithm,
          attributes.nonce,
          attributes.authentication_tag,
          attributes.aad_digest,
          attributes.source_event_iri
        ]

    digest(:erlang.term_to_binary(material, [:deterministic]))
  end

  defp resources(attributes, keys) do
    if Enum.all?(keys, &(ResourceIdentity.validate(attributes[&1]) == :ok)), do: :ok, else: :error
  end

  defp opaque_identity?(value),
    do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp media_type?(value),
    do: is_binary(value) and byte_size(value) in 3..128 and String.contains?(value, "/")

  defp non_negative_integer?(value), do: is_integer(value) and value >= 0
  defp positive_integer?(value), do: is_integer(value) and value > 0
  defp fixed_binary?(value, size), do: is_binary(value) and byte_size(value) == size
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
