defmodule JidoCode.Identity.AuthorityAdapter do
  @moduledoc "Trusted current graph-grant adapter used by the human authority builder."

  alias JidoCode.Identity.AuthorityRequest
  alias JidoCode.Identity.Resource

  @callback resolve(map(), [struct()], [struct()], Resource.t(), AuthorityRequest.t()) ::
              {:ok,
               %{
                 required(:grant_ref) => String.t(),
                 optional(:delegation_ref) => String.t() | nil,
                 optional(:obligations) => [atom()],
                 optional(:graph_revisions) => map()
               }}
              | {:error,
                 :concealed_not_found
                 | :redacted
                 | :denied
                 | :unavailable
                 | :revoked
                 | :step_up_required}
end
