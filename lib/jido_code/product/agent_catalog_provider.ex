defmodule JidoCode.Product.AgentCatalogProvider do
  @moduledoc "Reviewed-query boundary for scope-filtered coding-agent offerings."

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.AgentOffering

  @callback list(AuthorityContext.t(), map(), map()) ::
              {:ok, [AgentOffering.t()]} | {:error, term()}
end
