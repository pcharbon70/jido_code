defmodule JidoCode.Knowledge.Memory.ContentGateway do
  @moduledoc "Consumes one permit before decrypting and releasing its exact bounded range."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ContentAccessOutcome
  alias JidoCode.Knowledge.Memory.ContentAccessPermit
  alias JidoCode.Knowledge.Memory.ContentCipher

  def consume(%ContentAccessPermit{} = permit, encrypted, context, options)
      when is_map(encrypted) and is_map(context) and is_list(options) do
    consume_permit = Keyword.fetch!(options, :consume_permit)
    provider = Keyword.fetch!(options, :key_provider)
    key_server = Keyword.fetch!(options, :key_server)
    cipher_attributes = Keyword.fetch!(options, :cipher_attributes)
    release = Keyword.get(options, :release, fn _bytes -> :ok end)

    with :ok <- ContentAccessPermit.recheck(permit, context),
         true <- encrypted[:object_iri] == permit.content_iri,
         :ok <- consume_permit.(permit) do
      if Keyword.get(options, :crash_after_consumption, false) do
        outcome(permit, encrypted, :ambiguous, 0, context.now, "crash after permit consumption")
        |> error_result(:persistence_failure)
      else
        release_content(
          permit,
          encrypted,
          context,
          provider,
          key_server,
          cipher_attributes,
          release
        )
      end
    else
      {:error, %Error{} = error} ->
        outcome(
          permit,
          encrypted,
          :denied,
          0,
          context[:now],
          "authorization or consumption denied"
        )
        |> error_result(error)

      _invalid ->
        error = Error.new(:unauthorized, :content_access)

        outcome(permit, encrypted, :denied, 0, context[:now], "content identity mismatch")
        |> error_result(error)
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :content_gateway)}
  end

  def consume(_permit, _encrypted, _context, _options),
    do: {:error, Error.new(:invalid_input, :content_gateway)}

  defp release_content(permit, encrypted, context, provider, server, cipher_attributes, release) do
    with {:ok, plaintext} <- ContentCipher.decrypt(provider, server, encrypted, cipher_attributes),
         {:ok, selected} <- select_range(plaintext, permit.byte_range),
         :ok <- normalize_release(release.(selected)),
         {:ok, audit} <-
           outcome(
             permit,
             encrypted,
             :released,
             byte_size(selected),
             context.now,
             "committed representation and range released"
           ) do
      {:ok, selected, audit}
    else
      {:error, %Error{kind: :unavailable} = error} ->
        outcome(permit, encrypted, :unavailable, 0, context.now, "content key unavailable")
        |> error_result(error)

      {:error, %Error{} = error} ->
        outcome(permit, encrypted, :failed, 0, context.now, "content release failed")
        |> error_result(error)
    end
  end

  defp outcome(permit, encrypted, status, byte_count, recorded_at, reason) do
    commitment =
      :crypto.hash(
        :sha256,
        Enum.join(
          [
            encrypted[:ciphertext_digest] || "unavailable",
            Integer.to_string(permit.byte_range.offset),
            Integer.to_string(permit.byte_range.length)
          ],
          "\n"
        )
      )
      |> Base.encode16(case: :lower)

    ContentAccessOutcome.new(%{
      permit_iri: permit.iri,
      content_iri: permit.content_iri,
      selected_iris: [permit.content_iri],
      status: status,
      byte_count: byte_count,
      ciphertext_commitment: commitment,
      reason: reason,
      recorded_at: recorded_at
    })
  end

  defp error_result({:ok, outcome}, %Error{} = error), do: {:error, error, outcome}
  defp error_result({:ok, outcome}, kind), do: {:error, Error.new(kind, :content_access), outcome}
  defp error_result({:error, %Error{} = error}, _reason), do: {:error, error}

  defp select_range(plaintext, %{offset: offset, length: length})
       when offset + length <= byte_size(plaintext),
       do: {:ok, binary_part(plaintext, offset, length)}

  defp select_range(_plaintext, _range), do: {:error, Error.new(:unavailable, :content_range)}

  defp normalize_release(:ok), do: :ok
  defp normalize_release({:ok, _receipt}), do: :ok
  defp normalize_release({:error, %Error{} = error}), do: {:error, error}
  defp normalize_release(_result), do: {:error, Error.new(:persistence_failure, :content_release)}
end
