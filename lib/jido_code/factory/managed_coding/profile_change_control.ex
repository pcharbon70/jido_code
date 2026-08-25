defmodule JidoCode.Factory.ManagedCoding.ProfileChangeControl do
  @moduledoc "Material profile changes require a signed new digest and complete reevaluation."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.ProductionProfile

  @spec propose(ProductionProfile.t(), ProductionProfile.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def propose(%ProductionProfile{} = current, %ProductionProfile{} = proposed, actor_iri, reason)
      when is_binary(reason) and byte_size(reason) in 1..512 do
    with :ok <- Identity.validate_resource(actor_iri),
         true <- proposed.revision > current.revision,
         true <- proposed.profile_iri == current.profile_iri,
         true <- proposed.profile_digest != current.profile_digest do
      {:ok,
       %{
         actor_iri: actor_iri,
         reason: reason,
         from_digest: current.profile_digest,
         to_digest: proposed.profile_digest,
         signed_digest: proposed.signed_digest,
         requires_reevaluation: true,
         prior_qualification_valid: false,
         publication_authority: false
       }}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_profile_change)}
    end
  end

  def propose(_current, _proposed, _actor_iri, _reason),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_profile_change)}
end
