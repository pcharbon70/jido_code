defmodule JidoCodeWeb.ProductAuth do
  @moduledoc """
  Browser named-human authentication and transient scope construction.

  Browser cookies contain only an encrypted opaque session reference. Every
  protected request resolves current account and session state from the
  server-owned identity authority. The legacy operator token remains isolated
  to the compatibility API and cannot establish a browser session.
  """

  use JidoCodeWeb, :verified_routes

  import Phoenix.Controller
  import Plug.Conn

  alias JidoCode.Identity
  alias JidoCode.Identity.AuthorityBuilder
  alias JidoCode.Identity.Sessions
  alias JidoCode.Product
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @session_ref_key "jido_code_human_session_ref"
  @maximum_token_bytes 512
  @maximum_return_path_bytes 1_024

  def init(action)
      when action in [
             :fetch_current_scope,
             :require_authenticated_human,
             :fetch_authenticated_session,
             :require_authenticated_session,
             :fetch_api_scope,
             :require_authenticated_api
           ],
      do: action

  def call(conn, :fetch_current_scope), do: fetch_current_scope(conn, [])
  def call(conn, :require_authenticated_human), do: require_authenticated_human(conn, [])
  def call(conn, :fetch_authenticated_session), do: fetch_authenticated_session(conn, [])
  def call(conn, :require_authenticated_session), do: require_authenticated_session(conn, [])
  def call(conn, :fetch_api_scope), do: fetch_api_scope(conn, [])
  def call(conn, :require_authenticated_api), do: require_authenticated_api(conn, [])

  @doc "Authenticates a named human through the configured server-side adapter."
  @spec authenticate_human(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def authenticate_human(login, credential, options \\ []) do
    Identity.authenticate(login, credential, options)
  end

  @doc "Authenticates only the isolated compatibility API operator."
  @spec authenticate(String.t()) :: :ok | :error
  def authenticate(token) when is_binary(token) and byte_size(token) <= @maximum_token_bytes do
    case auth_config()[:credential_digest] do
      digest when is_binary(digest) and byte_size(digest) == 32 ->
        candidate = :crypto.hash(:sha256, token)
        if Plug.Crypto.secure_compare(candidate, digest), do: :ok, else: :error

      _missing ->
        :error
    end
  end

  def authenticate(_token), do: :error

  @spec establish_session(Plug.Conn.t(), map(), keyword()) ::
          {:ok, Plug.Conn.t()} | {:error, atom()}
  def establish_session(conn, authentication, options \\ []) do
    prior_session_ref = get_session(conn, @session_ref_key)

    with {:ok, session} <-
           Sessions.issue(
             authentication,
             Keyword.put(options, :replace_session_ref, prior_session_ref)
           ) do
      renewed =
        conn
        |> configure_session(renew: true)
        |> clear_session()
        |> put_session(@session_ref_key, session.session_ref)

      {:ok, renewed}
    end
  end

  @spec delete_session(Plug.Conn.t()) :: Plug.Conn.t()
  def delete_session(conn) do
    session_ref = get_session(conn, @session_ref_key)

    if is_binary(session_ref) do
      with {:ok, %{account: account}} <- Sessions.validate(session_ref, touch: false) do
        Sessions.revoke(%{actor_ref: account.subject_ref}, session_ref)
      end
    end

    conn
    |> configure_session(drop: true)
    |> clear_session()
  end

  @spec logout_all(Plug.Conn.t()) :: :ok | {:error, atom()}
  def logout_all(conn) do
    with session_ref when is_binary(session_ref) <- get_session(conn, @session_ref_key),
         {:ok, %{account: account}} <- Sessions.validate(session_ref, touch: false),
         {:ok, _account} <-
           Identity.logout_all(%{actor_ref: account.subject_ref}, account.subject_ref) do
      :ok
    else
      _invalid -> {:error, :invalid_session}
    end
  end

  def fetch_current_scope(conn, _options) do
    case current_human(get_session(conn, @session_ref_key)) do
      {:ok, scope, identity, authority, authorization} ->
        conn
        |> assign(:current_scope, scope)
        |> assign(:product_identity, identity)
        |> assign(:authority, authority)
        |> assign(:authorization, authorization)
        |> assign(:authorization_outcome, :allowed)

      {:error, reason} ->
        conn
        |> assign(:current_scope, nil)
        |> assign(:product_identity, nil)
        |> assign(:authority, nil)
        |> assign(:authorization, nil)
        |> assign(:authorization_outcome, reason)
    end
  end

  @doc "Resolves only the current named-human session for route admission."
  @spec fetch_authenticated_session(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def fetch_authenticated_session(conn, _options) do
    case get_session(conn, @session_ref_key) do
      session_ref when is_binary(session_ref) ->
        case Sessions.validate(session_ref) do
          {:ok, %{session: session, account: account}} ->
            assign(conn, :authenticated_human, %{
              account: account,
              identity: named_product_identity(account),
              session: session,
              session_ref: session_ref
            })

          {:error, reason} ->
            conn
            |> assign(:authenticated_human, nil)
            |> assign(:authentication_outcome, reason)
        end

      _missing ->
        conn
        |> assign(:authenticated_human, nil)
        |> assign(:authentication_outcome, :invalid_session)
    end
  rescue
    _error ->
      conn
      |> assign(:authenticated_human, nil)
      |> assign(:authentication_outcome, :unavailable)
  end

  @doc "Requires the server-resolved named-human session without selecting a product grant."
  @spec require_authenticated_session(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def require_authenticated_session(conn, _options) do
    if conn.assigns[:authenticated_human] do
      conn
    else
      return_to = request_path_with_query(conn)

      conn
      |> redirect(to: ~p"/sign-in?#{%{return_to: return_to}}")
      |> halt()
    end
  end

  def require_authenticated_human(conn, _options) do
    case {conn.assigns[:current_scope], conn.assigns[:authorization_outcome]} do
      {%{}, :allowed} ->
        conn

      {nil, :concealed_not_found} ->
        conn |> send_resp(:not_found, "Not found.") |> halt()

      {nil, outcome} when outcome in [:unavailable, :denied, :step_up_required] ->
        conn |> send_resp(:service_unavailable, "The product authority is unavailable.") |> halt()

      _unauthenticated_or_revoked ->
        return_to = request_path_with_query(conn)

        conn
        |> redirect(to: ~p"/sign-in?#{%{return_to: return_to}}")
        |> halt()
    end
  end

  @spec fetch_api_scope(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def fetch_api_scope(conn, _options) do
    case bearer_token(conn) do
      {:ok, token} ->
        case api_scope(token) do
          {:ok, scope, authority} ->
            conn
            |> assign(:current_scope, scope)
            |> assign(:product_identity, scope.identity)
            |> assign(:authority, authority)

          :error ->
            assign(conn, :current_scope, nil)
        end

      :error ->
        assign(conn, :current_scope, nil)
    end
  end

  @spec require_authenticated_api(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def require_authenticated_api(conn, _options) do
    if conn.assigns[:current_scope] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{outcome: "unauthorized", retry: "never"})
      |> halt()
    end
  end

  @spec api_scope(String.t()) :: {:ok, map(), term()} | :error
  def api_scope(token) do
    with :ok <- authenticate(token),
         identity <- product_identity(),
         {:ok, authority} <- Product.authority(identity) do
      now = System.system_time(:second)

      scope = %{
        iri: identity.factory_scope_iri,
        actor_iri: identity.actor_iri,
        principal_iri: identity.principal_iri,
        authenticated_at: now,
        expires_at: now + ttl_seconds(),
        session_generation: generation(),
        nonce: "api",
        identity: identity,
        principal_class: :compatibility_operator
      }

      {:ok, scope, authority}
    else
      _invalid -> :error
    end
  rescue
    _error -> :error
  end

  def on_mount(:require_authenticated, _params, session, %Socket{} = socket) do
    with session_ref when is_binary(session_ref) <- session[@session_ref_key],
         {:ok, scope, identity, authority, authorization} <- current_human(session_ref) do
      {:cont,
       socket
       |> Phoenix.Component.assign(:current_scope, scope)
       |> Phoenix.Component.assign(:product_identity, identity)
       |> Phoenix.Component.assign(:authority, authority)
       |> Phoenix.Component.assign(:authorization, authorization)
       |> LiveView.attach_hook(
         :product_session_authority,
         :handle_event,
         &authorize_event/3
       )}
    else
      _invalid -> {:halt, LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  @spec current_scope_valid?(map()) :: boolean()
  def current_scope_valid?(scope) when is_map(scope) do
    with session_ref when is_binary(session_ref) <- scope[:session_ref],
         {:ok, request} <-
           AuthorityBuilder.request(:compatibility_product, :developer, :page, :factory),
         {:ok, authorization} <- AuthorityBuilder.build(session_ref, request, touch: false) do
      authorization.decision == :allowed and
        authorization.current_scope.subject_ref == scope[:subject_ref] and
        authorization.current_scope.account_generation == scope[:account_generation] and
        authorization.current_scope.revocation_generations == scope[:revocation_generations]
    else
      _invalid -> false
    end
  end

  def current_scope_valid?(_scope), do: false

  @spec product_identity() :: map()
  def product_identity do
    config = Application.fetch_env!(:jido_code, :product_surface)

    %{
      factory_iri: Keyword.fetch!(config, :factory_iri),
      factory_scope_iri: Keyword.fetch!(config, :factory_scope_iri),
      policy_boundary_iri: Keyword.fetch!(config, :policy_boundary_iri),
      policy_iris: Keyword.fetch!(config, :policy_iris),
      principal_iri: Keyword.fetch!(config, :principal_iri),
      actor_iri: Keyword.fetch!(config, :actor_iri)
    }
  end

  @doc false
  def named_product_identity(account), do: human_product_identity(account)

  @spec safe_return_path(term()) :: String.t()
  def safe_return_path(path)
      when is_binary(path) and byte_size(path) in 1..@maximum_return_path_bytes do
    uri = URI.parse(path)

    if uri.scheme == nil and uri.host == nil and String.starts_with?(uri.path || "", "/") and
         not String.starts_with?(path, "//") and uri.path not in ["/sign-in", "/sign-out"] do
      path
    else
      "/"
    end
  end

  def safe_return_path(_path), do: "/"

  defp current_human(session_ref) when is_binary(session_ref) do
    with {:ok, request} <-
           AuthorityBuilder.request(:compatibility_product, :developer, :page, :factory),
         {:ok, authorization} <- AuthorityBuilder.build(session_ref, request),
         :allowed <- authorization.decision do
      {:ok, authorization.current_scope, authorization.product_identity,
       authorization.authority_context, authorization}
    else
      {:error, reason} ->
        {:error, reason}

      reason
      when reason in [
             :concealed_not_found,
             :redacted,
             :unavailable,
             :revoked,
             :denied,
             :step_up_required
           ] ->
        {:error, reason}
    end
  rescue
    _error -> {:error, :invalid_session}
  end

  defp current_human(_session_ref), do: {:error, :invalid_session}

  defp human_product_identity(account) do
    base = product_identity()
    human_iri = "https://jido.run/id/human/#{account.subject_ref}"

    base
    |> Map.put(:subject_ref, account.subject_ref)
    |> Map.put(:display_name, account.display_name)
    |> Map.put(:principal_iri, human_iri)
    |> Map.put(:actor_iri, human_iri)
  end

  defp authorize_event(_event, _params, socket) do
    if current_scope_valid?(socket.assigns.current_scope) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.Component.assign(:authority, nil)
       |> Phoenix.Component.assign(:product_identity, nil)
       |> LiveView.push_navigate(to: ~p"/sign-in")}
    end
  end

  defp request_path_with_query(conn) do
    case conn.query_string do
      "" -> conn.request_path
      query -> conn.request_path <> "?" <> query
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) in 1..@maximum_token_bytes -> {:ok, token}
      _missing_or_ambiguous -> :error
    end
  end

  defp ttl_seconds do
    case auth_config()[:session_ttl_seconds] do
      value when is_integer(value) and value in 300..86_400 -> value
      _invalid -> 28_800
    end
  end

  defp generation do
    case auth_config()[:session_generation] do
      value when is_binary(value) and byte_size(value) in 1..64 -> value
      _invalid -> "invalid"
    end
  end

  defp auth_config, do: Application.get_env(:jido_code, :product_auth, [])
end
