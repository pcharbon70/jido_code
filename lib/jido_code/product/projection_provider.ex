defmodule JidoCode.Product.ProjectionProvider do
  @moduledoc """
  Product-owned boundary for rebuilding workbench projections from the graph.
  """

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.Projection

  @callback load(AuthorityContext.t(), map(), keyword()) ::
              {:ok, Projection.t()} | {:error, term()}
end
