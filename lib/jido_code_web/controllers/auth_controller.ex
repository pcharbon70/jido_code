defmodule JidoCodeWeb.AuthController do
  use JidoCodeWeb, :controller

  alias JidoCode.Identity
  alias JidoCodeWeb.ProductAuth

  plug :secure_response

  def new(conn, params) do
    return_to = ProductAuth.safe_return_path(params["return_to"])

    render(conn, :new,
      page_title: "Sign in",
      capabilities: Identity.capabilities(),
      notice: session_notice(params["reason"]),
      form:
        Phoenix.Component.to_form(
          %{"login" => "", "credential" => "", "return_to" => return_to},
          as: :session
        ),
      error: nil
    )
  end

  def create(conn, %{"session" => params}) when is_map(params) do
    with :ok <- closed_params(params, ["login", "credential"], ["return_to"]),
         login when is_binary(login) and byte_size(login) <= 254 <- params["login"],
         credential when is_binary(credential) and byte_size(credential) <= 512 <-
           params["credential"],
         return_to <- ProductAuth.safe_return_path(params["return_to"]),
         {:ok, authentication} <- ProductAuth.authenticate_human(login, credential),
         {:ok, conn} <- ProductAuth.establish_session(conn, authentication) do
      redirect(conn, to: return_to)
    else
      _safe_failure ->
        authentication_failed(
          conn,
          bounded_login(params["login"]),
          ProductAuth.safe_return_path(params["return_to"])
        )
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

  def step_up_new(conn, params) do
    return_to = ProductAuth.safe_return_path(params["return_to"])

    render(conn, :step_up,
      page_title: "Verify assurance",
      capabilities: Identity.capabilities(),
      current_human: conn.assigns.authenticated_human,
      form:
        Phoenix.Component.to_form(
          %{"credential" => "", "return_to" => return_to},
          as: :step_up
        ),
      error: nil
    )
  end

  def step_up_create(conn, %{"step_up" => params}) when is_map(params) do
    human = conn.assigns.authenticated_human

    with :ok <- closed_params(params, ["credential"], ["return_to"]),
         credential when is_binary(credential) and byte_size(credential) <= 512 <-
           params["credential"],
         return_to <- ProductAuth.safe_return_path(params["return_to"]),
         {:ok, authentication} <-
           ProductAuth.authenticate_human(human.account.login, credential,
             minimum_assurance: :phishing_resistant
           ),
         {:ok, conn} <- ProductAuth.establish_session(conn, authentication) do
      redirect(conn, to: return_to)
    else
      _unavailable_or_invalid ->
        step_up_failed(conn, human, ProductAuth.safe_return_path(params["return_to"]))
    end
  end

  def step_up_create(conn, _params) do
    step_up_failed(conn, conn.assigns.authenticated_human, "/")
  end

  def recovery_new(conn, _params) do
    render_recovery(conn, 200, nil)
  end

  def recovery_create(conn, %{"recovery" => params}) when is_map(params) do
    _closed_and_bounded =
      with :ok <- closed_params(params, ["login"], []),
           login when is_binary(login) and byte_size(login) <= 254 <- params["login"] do
        :ok
      else
        _invalid -> :invalid
      end

    render_recovery(
      conn,
      202,
      "If recovery is available for the account, follow the independently verified operator instructions."
    )
  end

  def recovery_create(conn, _params), do: recovery_create(conn, %{"recovery" => %{"login" => ""}})

  defp authentication_failed(conn, login, return_to) do
    conn
    |> put_status(:unauthorized)
    |> render(:new,
      page_title: "Sign in",
      capabilities: Identity.capabilities(),
      notice: nil,
      form:
        Phoenix.Component.to_form(
          %{"login" => login, "credential" => "", "return_to" => return_to},
          as: :session
        ),
      error: "The session could not be established."
    )
  end

  defp step_up_failed(conn, human, return_to) do
    capabilities = Identity.capabilities()

    status =
      if(capabilities.step_up == :unavailable, do: :service_unavailable, else: :unauthorized)

    conn
    |> put_status(status)
    |> render(:step_up,
      page_title: "Verify assurance",
      capabilities: capabilities,
      current_human: human,
      form:
        Phoenix.Component.to_form(
          %{"credential" => "", "return_to" => return_to},
          as: :step_up
        ),
      error: "The requested assurance could not be established."
    )
  end

  defp render_recovery(conn, status, notice) do
    conn
    |> put_status(status)
    |> render(:recovery,
      page_title: "Account recovery",
      capabilities: Identity.capabilities(),
      notice: notice,
      form: Phoenix.Component.to_form(%{"login" => ""}, as: :recovery)
    )
  end

  defp session_notice("session-ended"),
    do: "Your prior browser session is no longer current. Sign in again to continue."

  defp session_notice(_reason), do: nil

  defp closed_params(params, required, optional) do
    keys = Map.keys(params) |> Enum.sort()

    if keys -- (required ++ optional) == [] and Enum.all?(required, &Map.has_key?(params, &1)),
      do: :ok,
      else: {:error, :invalid_parameters}
  end

  defp bounded_login(login) when is_binary(login) and byte_size(login) <= 254, do: login
  defp bounded_login(_login), do: ""

  defp secure_response(conn, _options) do
    conn
    |> put_resp_header("cache-control", "no-store, private")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("x-robots-tag", "noindex, nofollow")
  end
end
