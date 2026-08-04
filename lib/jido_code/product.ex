defmodule JidoCode.Product do
  @moduledoc """
  Product application boundary over graph projections and semantic commands.

  Web modules consume this boundary and never call the knowledge substrate
  directly.
  """

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.AuthorityContext

  @spec subscribe_changes(String.t()) :: :ok | {:error, term()}
  def subscribe_changes(scope_iri), do: Knowledge.subscribe_changes(scope_iri)

  @spec authority(map()) :: {:ok, AuthorityContext.t()} | {:error, term()}
  def authority(identity) when is_map(identity) do
    AuthorityContext.new(%{
      principal_iri: identity.principal_iri,
      actor_iri: identity.actor_iri,
      delegated_agent_iri: nil,
      delegation_iri: nil
    })
  end

  def authority(_identity), do: {:error, :invalid_identity}
end
