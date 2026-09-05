defmodule JidoCode.TestSupport.MalformedHumanAuthorityAdapter do
  @behaviour JidoCode.Identity.AuthorityAdapter

  @impl true
  def resolve(_identity, _memberships, _delegations, _resource, _request) do
    {:ok,
     %{
       grant_ref: "not an iri",
       obligations: ["browser supplied"],
       graph_revisions: %{unknown: -1},
       injected_authority: true
     }}
  end
end
