defmodule JidoCode.Identity.Authority.Unconfigured do
  @moduledoc "Fail-closed human graph-authority adapter used until production composition."

  @behaviour JidoCode.Identity.AuthorityAdapter

  @impl true
  def resolve(_identity, _memberships, _delegations, _resource, _request),
    do: {:error, :unavailable}
end
