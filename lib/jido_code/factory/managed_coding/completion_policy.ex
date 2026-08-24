defmodule JidoCode.Factory.ManagedCoding.CompletionPolicy do
  @moduledoc "Converts bounded model completion text into an unverified candidate proposal."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest

  @authority_claim ~r/\b(tests? (pass|passed|succeed)|verified|verification complete|evidence (is )?sufficient|accepted|approved|published|merged|ready to merge)\b/i

  @spec proposal(map(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def proposal(decision, correlation) when is_map(decision) and is_map(correlation) do
    summary = decision[:summary]
    claims = decision[:claims]

    with true <- is_binary(summary) and byte_size(summary) in 1..4_096,
         true <- is_list(claims) and length(claims) <= 32,
         false <- authority_claim?(summary, claims),
         attempt when is_binary(attempt) <- correlation[:attempt_iri],
         fence when is_integer(fence) and fence > 0 <- correlation[:fencing_token],
         digest <- WorkspaceDigest.digest({summary, claims, attempt, fence}),
         {:ok, iri} <- Identity.deterministic(:patch_artifact, digest) do
      {:ok,
       %{
         candidate_iri: iri,
         candidate_digest: digest,
         summary: summary,
         claims: claims,
         authority: :proposal_only,
         verification_status: :not_started,
         publication_authority: false
       }}
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :managed_coding_completion_claim)}
    end
  rescue
    _error -> {:error, AdapterError.new(:invalid_input, :managed_coding_completion_proposal)}
  end

  def proposal(_decision, _correlation),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_completion_proposal)}

  defp authority_claim?(summary, claims) do
    Enum.any?([summary | claims], fn value ->
      not is_binary(value) or byte_size(value) > 1_024 or Regex.match?(@authority_claim, value)
    end)
  end
end
