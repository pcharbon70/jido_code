defmodule JidoCodeWeb.AshTypescriptRpcController do
  use JidoCodeWeb, :controller

  def run(conn, params) do
    result = AshTypescript.Rpc.run_action(:jido_code, conn, params)
    json(conn, result)
  end

  def validate(conn, params) do
    result = AshTypescript.Rpc.validate_action(:jido_code, conn, params)
    json(conn, result)
  end
end
