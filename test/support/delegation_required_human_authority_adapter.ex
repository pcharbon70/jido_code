defmodule JidoCode.TestSupport.DelegationRequiredHumanAuthorityAdapter do
  @behaviour JidoCode.Identity.AuthorityAdapter

  @impl true
  def resolve(identity, memberships, delegations, resource, request) do
    membership_matches =
      Enum.filter(memberships, fn membership ->
        request.area in membership.route_groups and
          membership.tenant_ref == resource.tenant_ref and
          membership.project_ref == resource.project_ref
      end)

    delegation_matches =
      Enum.filter(delegations, fn delegation ->
        delegation.delegate_subject_ref == identity.subject_ref and
          resource.resource_ref in delegation.resource_refs and
          request.action in delegation.actions and
          delegation.environment == resource.environment
      end)

    case {membership_matches, delegation_matches} do
      {[_membership], [delegation]} ->
        {:ok,
         %{
           grant_ref:
             "https://jido.run/id/grant/test/delegated/#{identity.subject_ref}/#{request.operation}",
           delegation_ref: delegation.delegation_ref,
           obligations: delegation.obligations,
           graph_revisions: %{"https://jido.run/graph/factory/policy" => 1}
         }}

      {[], _delegations} ->
        {:error, :concealed_not_found}

      {_memberships, _delegations} ->
        {:error, :denied}
    end
  end
end
