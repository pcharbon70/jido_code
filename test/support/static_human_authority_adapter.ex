defmodule JidoCode.TestSupport.StaticHumanAuthorityAdapter do
  @behaviour JidoCode.Identity.AuthorityAdapter

  @impl true
  def resolve(identity, memberships, delegations, resource, request) do
    matching =
      Enum.filter(memberships, fn membership ->
        request.area in membership.route_groups and
          membership.tenant_ref == resource.tenant_ref and
          membership.project_ref == resource.project_ref
      end)

    case matching do
      [membership] ->
        with {:ok, delegation_ref} <-
               exact_delegation(delegations, identity.subject_ref, resource, request) do
          {:ok,
           %{
             grant_ref:
               "https://jido.run/id/grant/test/#{identity.subject_ref}/#{request.operation}",
             delegation_ref: delegation_ref,
             obligations: [],
             graph_revisions: %{"https://jido.run/graph/factory/policy" => membership.revision}
           }}
        end

      [] ->
        {:error, :concealed_not_found}

      _ambiguous ->
        {:error, :denied}
    end
  end

  defp exact_delegation(delegations, subject_ref, resource, request) do
    matches =
      Enum.filter(delegations, fn delegation ->
        delegation.delegate_subject_ref == subject_ref and
          resource.resource_ref in delegation.resource_refs and
          request.action in delegation.actions
      end)

    case matches do
      [] -> {:ok, nil}
      [delegation] -> {:ok, delegation.delegation_ref}
      _ambiguous -> {:error, :denied}
    end
  end
end
