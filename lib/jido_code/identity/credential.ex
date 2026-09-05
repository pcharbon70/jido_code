defmodule JidoCode.Identity.Credential do
  @moduledoc false

  @minimum_bytes 12
  @maximum_bytes 512
  @digest_bytes 32

  @spec build(String.t(), pos_integer()) :: {:ok, map()} | {:error, :invalid_credential}
  def build(credential, iterations)
      when is_binary(credential) and byte_size(credential) in @minimum_bytes..@maximum_bytes and
             is_integer(iterations) do
    salt = :crypto.strong_rand_bytes(16)

    {:ok,
     %{
       algorithm: :pbkdf2_sha256,
       iterations: iterations,
       salt: salt,
       verifier: derive(credential, salt, iterations)
     }}
  end

  def build(_credential, _iterations), do: {:error, :invalid_credential}

  @spec verify(String.t(), map()) :: boolean()
  def verify(credential, %{algorithm: :pbkdf2_sha256} = material)
      when is_binary(credential) and byte_size(credential) <= @maximum_bytes do
    candidate = derive(credential, material.salt, material.iterations)
    Plug.Crypto.secure_compare(candidate, material.verifier)
  rescue
    _error -> false
  end

  def verify(_credential, _material), do: false

  @spec dummy_verify(String.t(), pos_integer()) :: false
  def dummy_verify(credential, iterations) do
    candidate = if is_binary(credential), do: credential, else: ""
    verifier = derive(candidate, <<0::128>>, iterations)
    Plug.Crypto.secure_compare(verifier, <<0::size(@digest_bytes * 8)>>)
    false
  end

  defp derive(credential, salt, iterations) do
    :crypto.pbkdf2_hmac(:sha256, credential, salt, iterations, @digest_bytes)
  end
end
