defmodule JidoCodeWeb.QualificationRawBodyReader do
  @moduledoc """
  Retains request bytes only for the isolated HUI-B3 qualification namespace.

  Exact bytes let the closed signal decoder reject duplicate JSON keys. Other
  application requests are delegated without retaining their bodies.
  """

  @qualification_prefix "/__qualification/hypermedia/"

  @spec read_body(Plug.Conn.t(), keyword()) ::
          {:ok | :more, binary(), Plug.Conn.t()} | {:error, term()}
  def read_body(conn, options) do
    case Plug.Conn.read_body(conn, options) do
      {status, body, conn} when status in [:ok, :more] ->
        conn =
          if String.starts_with?(conn.request_path, @qualification_prefix) do
            %{conn | private: Map.update(conn.private, :hui_b3_raw_body, [body], &[body | &1])}
          else
            conn
          end

        {status, body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec body(Plug.Conn.t()) :: binary()
  def body(conn) do
    conn.private
    |> Map.get(:hui_b3_raw_body, [])
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end
end
