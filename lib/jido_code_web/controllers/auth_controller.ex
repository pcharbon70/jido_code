defmodule JidoCodeWeb.AuthController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductAuth

  def new(conn, _params) do
    render(conn, :new,
      page_title: "Operator sign in",
      form: Phoenix.Component.to_form(%{"credential" => ""}, as: :operator),
      error: nil
    )
  end

  def create(conn, %{"operator" => %{"credential" => credential}}) do
    case ProductAuth.authenticate(credential) do
      :ok ->
        conn
        |> ProductAuth.establish_session()
        |> redirect(to: ~p"/")

      :error ->
        conn
        |> put_status(:unauthorized)
        |> render(:new,
          page_title: "Operator sign in",
          form: Phoenix.Component.to_form(%{"credential" => ""}, as: :operator),
          error: "The operator session could not be established."
        )
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> render(:new,
      page_title: "Operator sign in",
      form: Phoenix.Component.to_form(%{"credential" => ""}, as: :operator),
      error: "The operator session could not be established."
    )
  end

  def delete(conn, _params) do
    conn
    |> ProductAuth.delete_session()
    |> redirect(to: ~p"/sign-in")
  end
end
