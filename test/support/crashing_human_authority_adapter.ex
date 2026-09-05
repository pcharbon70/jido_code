defmodule JidoCode.TestSupport.CrashingHumanAuthorityAdapter do
  @behaviour JidoCode.Identity.AuthorityAdapter

  @impl true
  def resolve(_identity, _memberships, _delegations, _resource, _request) do
    raise "fixture adapter failure"
  end
end
