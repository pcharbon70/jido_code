defmodule JidoCode.Knowledge.RepositoryWiki.SignedEvidence do
  @moduledoc """
  Closed signed-artifact envelope for repository-wiki qualification evidence.

  Signing and verification are injected so private key material never enters
  repository data, graph state, diagnostics, or this module. The signature
  covers an artifact kind and the canonical digest of its immutable payload.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract

  @revision "repository-wiki-signed-evidence/1.0.0"
  @keys ~w[revision kind digest payload signed_material signature]a

  @spec sign(atom(), term(), (String.t() -> binary())) ::
          {:ok, map()} | {:error, Error.t()}
  def sign(kind, payload, signer) when is_atom(kind) and is_function(signer, 1) do
    digest = Contract.digest(payload)
    material = Enum.join([@revision, Atom.to_string(kind), digest], "\n")

    with signature when is_binary(signature) and byte_size(signature) >= 32 <- signer.(material) do
      {:ok,
       %{
         revision: @revision,
         kind: kind,
         digest: digest,
         payload: payload,
         signed_material: material,
         signature: Base.encode64(signature)
       }}
    else
      _invalid -> invalid(:repository_wiki_evidence_sign)
    end
  rescue
    _error -> invalid(:repository_wiki_evidence_sign)
  end

  def sign(_kind, _payload, _signer), do: invalid(:repository_wiki_evidence_sign)

  @spec verify(map(), atom(), (String.t(), binary() -> boolean())) ::
          :ok | {:error, Error.t()}
  def verify(artifact, expected_kind, verifier)
      when is_map(artifact) and is_atom(expected_kind) and is_function(verifier, 2) do
    expected_digest = Contract.digest(artifact[:payload])

    expected_material =
      Enum.join([@revision, Atom.to_string(expected_kind), expected_digest], "\n")

    with true <- Enum.sort(Map.keys(artifact)) == Enum.sort(@keys),
         true <- artifact[:revision] == @revision,
         true <- artifact[:kind] == expected_kind,
         true <- artifact[:digest] == expected_digest,
         true <- artifact[:signed_material] == expected_material,
         {:ok, signature} <- Base.decode64(artifact[:signature]),
         true <- byte_size(signature) >= 32,
         true <- verifier.(expected_material, signature) do
      :ok
    else
      _invalid -> unauthorized()
    end
  rescue
    _error -> unauthorized()
  end

  def verify(_artifact, _expected_kind, _verifier), do: unauthorized()

  @spec revision() :: String.t()
  def revision, do: @revision

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp unauthorized, do: {:error, Error.new(:unauthorized, :repository_wiki_evidence_signature)}
end
