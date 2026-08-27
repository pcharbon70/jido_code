defmodule JidoCode.Product.GraphAgentCatalogProvider do
  @moduledoc "Loads offerings through the configured reviewed graph-query adapter."

  @behaviour JidoCode.Product.AgentCatalogProvider

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.AgentOffering

  @impl true
  def list(%AuthorityContext{} = authority, identity, scope)
      when is_map(identity) and is_map(scope) do
    loader = Application.get_env(:jido_code, :agent_catalog_graph_loader)

    with loader when is_function(loader, 3) <- loader,
         {:ok, offerings} when is_list(offerings) <- loader.(authority, identity, scope),
         true <- Enum.all?(offerings, &match?(%AgentOffering{}, &1)) do
      {:ok, offerings}
    else
      _unavailable -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  end

  def list(_authority, _identity, _scope), do: {:error, :unauthorized}
end
