defmodule JidoCodeWeb.Api.V1.ProductResponse do
  @moduledoc "Stable bounded JSON outcomes for coding-agent product endpoints."

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Product.WorkflowOutcome

  @spec ok(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def ok(conn, payload), do: json(conn, Map.put(payload, :outcome, "admitted"))

  @spec workflow(Plug.Conn.t(), WorkflowOutcome.t()) :: Plug.Conn.t()
  def workflow(conn, %WorkflowOutcome{} = outcome) do
    conn
    |> put_status(status(outcome.code))
    |> json(WorkflowOutcome.safe_map(outcome))
  end

  @spec error(Plug.Conn.t(), AdapterError.t() | term()) :: Plug.Conn.t()
  def error(conn, %AdapterError{} = error) do
    code = code(error.kind)

    conn
    |> put_status(status(code))
    |> json(%{outcome: code, retry: error.retry})
  end

  def error(conn, _error) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{outcome: "unavailable", retry: "retry"})
  end

  defp code(:unauthorized), do: :unauthorized
  defp code(:conflict), do: :conflict
  defp code(:unavailable), do: :unavailable
  defp code(:timeout), do: :unavailable
  defp code(:invalid_input), do: :rejected
  defp code(:corrupt), do: :rejected

  defp status(:admitted), do: :accepted
  defp status(:duplicate), do: :ok
  defp status(:stale), do: :conflict
  defp status(:unauthorized), do: :forbidden
  defp status(:incompatible), do: :unprocessable_entity
  defp status(:unavailable), do: :service_unavailable
  defp status(:rejected), do: :unprocessable_entity
  defp status(:conflict), do: :conflict
end
