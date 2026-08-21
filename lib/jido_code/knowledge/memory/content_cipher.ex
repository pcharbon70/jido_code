defmodule JidoCode.Knowledge.Memory.ContentCipher do
  @moduledoc "AES-256-GCM envelope cipher that obtains per-object keys through a provider port."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.Memory.ContentHygiene
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @revision "1.0.0"
  @algorithm :aes_256_gcm

  def revision, do: @revision
  def algorithm, do: @algorithm

  def encrypt(provider, server, tenant_iri, object_iri, plaintext, attributes, options \\ [])

  def encrypt(provider, server, tenant_iri, object_iri, plaintext, attributes, options)
      when is_atom(provider) and is_binary(plaintext) and is_map(attributes) do
    random_bytes = Keyword.get(options, :random_bytes, &:crypto.strong_rand_bytes/1)
    key_operation = Keyword.get(options, :key_operation, :create)

    with :ok <- ResourceIdentity.validate(tenant_iri),
         :ok <- ResourceIdentity.validate(object_iri),
         :ok <- ContentHygiene.inspect(plaintext, attributes),
         true <- attributes[:policy_revision] == DataPolicy.revision(),
         {:ok, key} <- key(provider, server, tenant_iri, object_iri, key_operation),
         nonce when is_binary(nonce) and byte_size(nonce) == 12 <- random_bytes.(12),
         aad = aad(tenant_iri, object_iri, attributes, key.generation),
         {ciphertext, tag} <-
           :crypto.crypto_one_time_aead(@algorithm, key.key, nonce, plaintext, aad, 16, true),
         {:ok, chunks} <- chunks(ciphertext) do
      {:ok,
       %{
         revision: @revision,
         algorithm: @algorithm,
         tenant_iri: tenant_iri,
         object_iri: object_iri,
         key_reference_iri: key.reference_iri,
         key_generation: key.generation,
         nonce: nonce,
         authentication_tag: tag,
         aad_digest: digest(aad),
         ciphertext_digest: digest(ciphertext),
         ciphertext_chunks: chunks,
         encrypted_before_command?: true
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :content_encrypt)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :content_encrypt)}
  end

  def encrypt(_provider, _server, _tenant, _object, _plaintext, _attributes, _options),
    do: {:error, Error.new(:invalid_input, :content_encrypt)}

  def decrypt(provider, server, encrypted, attributes)
      when is_atom(provider) and is_map(encrypted) and is_map(attributes) do
    with true <- encrypted[:revision] == @revision,
         true <- encrypted[:algorithm] == @algorithm,
         {:ok, key} <- provider.fetch_key(server, encrypted[:key_reference_iri]),
         true <- key.generation == encrypted[:key_generation],
         ciphertext when is_binary(ciphertext) <- Enum.join(encrypted[:ciphertext_chunks]),
         true <- digest(ciphertext) == encrypted[:ciphertext_digest],
         aad = aad(encrypted[:tenant_iri], encrypted[:object_iri], attributes, key.generation),
         true <- digest(aad) == encrypted[:aad_digest],
         plaintext when is_binary(plaintext) <-
           :crypto.crypto_one_time_aead(
             @algorithm,
             key.key,
             encrypted[:nonce],
             ciphertext,
             aad,
             encrypted[:authentication_tag],
             false
           ) do
      {:ok, plaintext}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:corrupt, :content_decrypt)}
    end
  rescue
    _error -> {:error, Error.new(:corrupt, :content_decrypt)}
  end

  def decrypt(_provider, _server, _encrypted, _attributes),
    do: {:error, Error.new(:invalid_input, :content_decrypt)}

  defp chunks(ciphertext) do
    size = Guardrails.capacity_profile().ciphertext_chunk_bytes
    chunks = for <<chunk::binary-size(size) <- ciphertext>>, do: chunk
    consumed = Enum.reduce(chunks, 0, &(byte_size(&1) + &2))
    remainder = binary_part(ciphertext, consumed, byte_size(ciphertext) - consumed)
    chunks = if remainder == "", do: chunks, else: chunks ++ [remainder]

    if length(chunks) in 1..Guardrails.capacity_profile().content_chunks_per_command,
      do: {:ok, chunks},
      else: {:error, Error.new(:invalid_input, :content_ciphertext_capacity)}
  end

  defp aad(tenant, object, attributes, generation) do
    :erlang.term_to_binary(
      {
        @revision,
        tenant,
        object,
        generation,
        attributes[:classification],
        attributes[:media_type],
        attributes[:policy_revision]
      },
      [:deterministic]
    )
  end

  defp key(provider, server, tenant, object, :create),
    do: provider.create_key(server, tenant, object)

  defp key(provider, server, tenant, object, :rotate),
    do: provider.rotate_key(server, tenant, object)

  defp key(_provider, _server, _tenant, _object, _operation),
    do: {:error, Error.new(:invalid_input, :content_key_operation)}

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
