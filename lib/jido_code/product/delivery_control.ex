defmodule JidoCode.Product.DeliveryControl do
  @moduledoc "Trusted local rollback switch; never changes graph truth, identity or native routes."

  def enabled?, do: Application.get_env(:jido_code, :hypermedia_delivery_enabled, true) == true

  def disable do
    Application.put_env(:jido_code, :hypermedia_delivery_enabled, false)
    JidoCode.Product.StreamCoordinator.drain()
  end
end
