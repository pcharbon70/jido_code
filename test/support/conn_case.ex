defmodule JidoCodeWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use JidoCodeWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint JidoCodeWeb.Endpoint

      use JidoCodeWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import JidoCodeWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def sign_in_named_human(conn) do
    {:ok, authentication} =
      JidoCode.Identity.authenticate(
        "operator@example.test",
        "test-named-human-credential"
      )

    {:ok, conn} =
      conn
      |> Plug.Conn.fetch_session()
      |> JidoCodeWeb.ProductAuth.establish_session(authentication)

    conn
  end

  def with_same_origin(conn) do
    default_port? =
      (conn.scheme == :http and conn.port == 80) or
        (conn.scheme == :https and conn.port == 443)

    port = if default_port?, do: "", else: ":#{conn.port}"
    Plug.Conn.put_req_header(conn, "origin", "#{conn.scheme}://#{conn.host}#{port}")
  end
end
