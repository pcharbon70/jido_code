defmodule JidoCode.Product.ReadProjectionProvider do
  @moduledoc """
  Product-owned boundary for native-shell read projections.

  Implementations reauthorize at query and field-shaping boundaries and return
  only `ReadProjection` values. They never execute semantic commands.
  """

  alias JidoCode.Product.ReadProjection

  @callback load(map(), keyword()) :: {:ok, ReadProjection.t()} | {:error, term()}
end
