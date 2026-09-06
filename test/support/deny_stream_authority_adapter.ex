defmodule JidoCode.TestSupport.DenyStreamAuthorityAdapter do
  @behaviour JidoCode.Identity.AuthorityAdapter

  @impl true
  def resolve(_identity, _memberships, _delegations, _resource, %{action: :stream}),
    do: {:error, :denied}

  def resolve(identity, memberships, delegations, resource, request),
    do:
      JidoCode.TestSupport.StaticHumanAuthorityAdapter.resolve(
        identity,
        memberships,
        delegations,
        resource,
        request
      )
end
