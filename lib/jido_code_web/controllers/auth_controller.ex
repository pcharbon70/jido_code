defmodule JidoCodeWeb.AuthController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductAuth

  def new(conn, params) do
    return_to = ProductAuth.safe_return_path(params["return_to"])

    render(conn, :new,
      page_title: "Sign in",
      form:
        Phoenix.Component.to_form(
          %{"login" => "", "credential" => "", "return_to" => return_to},
          as: :session
        ),
      error: nil
    )
  end

  def create(conn, %{
        "session" => %{"login" => login, "credential" => credential} = params
      }) do
    return_to = ProductAuth.safe_return_path(params["return_to"])

    with {:ok, authentication} <- ProductAuth.authenticate_human(login, credential),
         {:ok, conn} <- ProductAuth.establish_session(conn, authentication) do
      redirect(conn, to: return_to)
    else
      _safe_failure -> authentication_failed(conn, login, return_to)
    end
  end

  def create(conn, _params) do
    authentication_failed(conn, "", "/")
  end

  def delete(conn, _params) do
    conn
    |> ProductAuth.delete_session()
    |> redirect(to: ~p"/sign-in")
  end

  def delete_all(conn, _params) do
    case ProductAuth.logout_all(conn) do
      :ok ->
        conn
        |> ProductAuth.delete_session()
        |> redirect(to: ~p"/sign-in")

      {:error, _reason} ->
        conn
        |> ProductAuth.delete_session()
        |> redirect(to: ~p"/sign-in")
    end
  end

  defp authentication_failed(conn, login, return_to) do
    conn
    |> put_status(:unauthorized)
    |> render(:new,
      page_title: "Sign in",
      form:
        Phoenix.Component.to_form(
          %{"login" => login, "credential" => "", "return_to" => return_to},
          as: :session
        ),
      error: "The session could not be established."
    )
  end
end
