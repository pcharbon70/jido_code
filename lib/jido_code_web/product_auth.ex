defmodule JidoCodeWeb.ProductAuth do
  @moduledoc """
  Browser authentication and transient actor-scope construction.

  The operator credential remains external configuration. The signed browser
  session contains only authentication time, a random nonce, and a revocation
  generation; it contains no credential or durable authorization decision.
  """

  use JidoCodeWeb, :verified_routes

  import Phoenix.Controller
  import Plug.Conn

  alias JidoCode.Product
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @authenticated_at_key "jido_code_authenticated_at"
  @generation_key "jido_code_session_generation"
  @nonce_key "jido_code_session_nonce"
  @maximum_token_bytes 512

  def init(action)
      when action in [
             :fetch_current_scope,
             :require_authenticated_operator,
             :fetch_api_scope,
             :require_authenticated_api
           ],
      do: action

  def call(conn, :fetch_current_scope), do: fetch_current_scope(conn, [])
  def call(conn, :require_authenticated_operator), do: require_authenticated_operator(conn, [])
  def call(conn, :fetch_api_scope), do: fetch_api_scope(conn, [])
  def call(conn, :require_authenticated_api), do: require_authenticated_api(conn, [])

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

  @spec establish_session(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def establish_session(conn, options \\ []) do
    authenticated_at = Keyword.get(options, :authenticated_at, System.system_time(:second))

    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_session(@authenticated_at_key, authenticated_at)
    |> put_session(@generation_key, generation())
    |> put_session(@nonce_key, Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false))
  end

  @spec delete_session(Plug.Conn.t()) :: Plug.Conn.t()
  def delete_session(conn) do
    conn
    |> configure_session(drop: true)
    |> clear_session()
  end

  def fetch_current_scope(conn, _options) do
    scope =
      conn
      |> session_values()
      |> build_scope()
      |> case do
        {:ok, scope} -> scope
        :error -> nil
      end

    Plug.Conn.assign(conn, :current_scope, scope)
  end

  def require_authenticated_operator(conn, _options) do
    if conn.assigns[:current_scope] do
      conn
    else
      conn
      |> redirect(to: ~p"/sign-in")
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
        identity: identity
      }

      {:ok, scope, authority}
    else
      _invalid -> :error
    end
  rescue
    _error -> :error
  end

  def on_mount(:require_authenticated, _params, session, %Socket{} = socket) do
    with {:ok, scope} <- build_scope(session),
         {:ok, authority} <- Product.authority(scope.identity) do
      {:cont,
       socket
       |> Phoenix.Component.assign(:current_scope, scope)
       |> Phoenix.Component.assign(:product_identity, scope.identity)
       |> Phoenix.Component.assign(:authority, authority)
       |> LiveView.attach_hook(
         :product_session_authority,
         :handle_event,
         &authorize_event/3
       )}
    else
      :error -> {:halt, LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  @spec current_scope_valid?(map()) :: boolean()
  def current_scope_valid?(scope) when is_map(scope) do
    now = System.system_time(:second)

    is_integer(scope.authenticated_at) and is_integer(scope.expires_at) and
      now >= scope.authenticated_at and now < scope.expires_at and
      scope.session_generation == generation()
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

  defp build_scope(session) when is_map(session) do
    authenticated_at = session[@authenticated_at_key]
    session_generation = session[@generation_key]
    nonce = session[@nonce_key]
    identity = product_identity()

    scope = %{
      iri: identity.factory_scope_iri,
      actor_iri: identity.actor_iri,
      principal_iri: identity.principal_iri,
      authenticated_at: authenticated_at,
      expires_at: expires_at(authenticated_at),
      session_generation: session_generation,
      nonce: nonce,
      identity: identity
    }

    if valid_nonce?(nonce) and current_scope_valid?(scope), do: {:ok, scope}, else: :error
  rescue
    _error -> :error
  end

  defp build_scope(_session), do: :error

  defp session_values(conn) do
    %{
      @authenticated_at_key => get_session(conn, @authenticated_at_key),
      @generation_key => get_session(conn, @generation_key),
      @nonce_key => get_session(conn, @nonce_key)
    }
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) in 1..@maximum_token_bytes -> {:ok, token}
      _missing_or_ambiguous -> :error
    end
  end

  defp expires_at(authenticated_at) when is_integer(authenticated_at),
    do: authenticated_at + ttl_seconds()

  defp expires_at(_authenticated_at), do: nil

  defp valid_nonce?(nonce),
    do:
      is_binary(nonce) and byte_size(nonce) in 20..96 and
        Regex.match?(~r/^[A-Za-z0-9_-]+$/, nonce)

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
