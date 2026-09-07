defmodule JidoCodeWeb.StreamAdmission do
  @moduledoc false
  alias JidoCode.Product.StreamCoordinator
  alias JidoCodeWeb.{ReadSecurity, StreamContext}

  def acquire(conn, page) do
    if conn.private[:stream_intent] do
      with {:ok, binding} <- JidoCode.Product.StreamProjectionRegistry.build(page),
           {:ok, context} <- StreamContext.build(conn, page),
           {:ok, lease} <- StreamCoordinator.admit(context) do
        {:ok,
         conn
         |> Plug.Conn.put_private(:stream_binding, binding)
         |> Plug.Conn.put_private(:stream_context, context)
         |> Plug.Conn.put_private(:stream_lease, lease)}
      else
        {:error, :rate_limited} -> {:error, ReadSecurity.reject(conn, 429)}
        {:error, :duplicate} -> {:error, ReadSecurity.reject(conn, 409)}
        {:error, :invalid_cursor} -> {:error, ReadSecurity.reject(conn, 422)}
        {:error, :expired} -> {:error, ReadSecurity.reject(conn, 401)}
        _ -> {:error, ReadSecurity.reject(conn, 503)}
      end
    else
      {:ok, conn}
    end
  end
end
