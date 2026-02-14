defmodule JidoCodeWeb.AshTypescriptRpcController do
  use JidoCodeWeb, :controller

  require Logger

  alias AshAuthentication.{Info, Strategy}
  alias JidoCode.Accounts.User

  @api_key_audit_event [:jido_code, :rpc, :api_key, :used]
  @api_key_prefix "agentjido_"

  def run(conn, params) do
    execute_rpc(conn, params, &AshTypescript.Rpc.run_action(:jido_code, &1, &2))
  end

  def validate(conn, params) do
    execute_rpc(conn, params, &AshTypescript.Rpc.validate_action(:jido_code, &1, &2))
  end

  defp execute_rpc(conn, params, rpc_callback) do
    case resolve_rpc_auth(conn) do
      {:error, auth_mode} ->
        json(conn, auth_failure_response(auth_mode))

      {:ok, conn, auth_mode, actor} ->
        maybe_record_api_key_audit(conn, actor, auth_mode)

        result =
          rpc_callback.(conn, params)
          |> attach_actor_auth_mode(auth_mode)

        json(conn, result)
    end
  end

  defp resolve_rpc_auth(conn) do
    case rpc_auth_credential(conn) do
      {:bearer, _token} ->
        resolve_bearer_auth(conn)

      {:api_key, api_key} ->
        resolve_api_key_auth(conn, api_key)

      :none ->
        {:ok, conn, resolved_non_bearer_auth_mode(conn), Ash.PlugHelpers.get_actor(conn)}
    end
  end

  defp resolve_bearer_auth(conn) do
    case bearer_actor(conn) do
      nil ->
        {:error, "bearer"}

      actor ->
        {:ok, assign_actor(conn, actor), "bearer", actor}
    end
  end

  defp resolve_api_key_auth(conn, api_key) do
    strategy = Info.strategy!(User, :api_key)

    opts = [
      tenant: Ash.PlugHelpers.get_tenant(conn),
      context: Ash.PlugHelpers.get_context(conn) || %{}
    ]

    case Strategy.action(strategy, :sign_in, %{"api_key" => api_key}, opts) do
      {:ok, actor} ->
        {:ok, assign_actor(conn, actor), "api_key", actor}

      {:error, _error} ->
        {:error, "api_key"}
    end
  end

  defp assign_actor(conn, actor) do
    conn
    |> Plug.Conn.assign(:current_user, actor)
    |> AshAuthentication.Plug.Helpers.set_actor(:user)
  end

  defp rpc_auth_credential(conn) do
    case authorization_header_credential(conn) do
      {:ok, credential} -> credential
      :error -> x_api_key_credential(conn)
    end
  end

  defp authorization_header_credential(conn) do
    conn
    |> Plug.Conn.get_req_header("authorization")
    |> Enum.reduce_while(:error, fn header, _acc ->
      case parse_authorization_header(header) do
        :error -> {:cont, :error}
        credential -> {:halt, {:ok, credential}}
      end
    end)
  end

  defp parse_authorization_header(header) when is_binary(header) do
    case String.split(header, " ", parts: 2) do
      [scheme, token] ->
        token = String.trim(token)

        if token == "" do
          :error
        else
          parse_authorization_token(String.downcase(scheme), token)
        end

      _ ->
        :error
    end
  end

  defp parse_authorization_token("bearer", token) do
    if api_key_token?(token), do: {:api_key, token}, else: {:bearer, token}
  end

  defp parse_authorization_token("apikey", token), do: {:api_key, token}
  defp parse_authorization_token("api-key", token), do: {:api_key, token}
  defp parse_authorization_token(_scheme, _token), do: :error

  defp x_api_key_credential(conn) do
    conn
    |> Plug.Conn.get_req_header("x-api-key")
    |> Enum.find_value(:none, fn api_key ->
      normalized_api_key = String.trim(api_key)
      if normalized_api_key == "", do: false, else: {:api_key, normalized_api_key}
    end)
  end

  defp api_key_token?(token), do: String.starts_with?(token, @api_key_prefix)

  defp bearer_actor(conn) do
    conn
    |> with_cleared_assigns()
    |> AshAuthentication.Plug.Helpers.retrieve_from_bearer(:jido_code)
    |> Map.get(:assigns, %{})
    |> Map.get(:current_user)
  end

  defp with_cleared_assigns(%Plug.Conn{} = conn) do
    %Plug.Conn{conn | assigns: %{}}
  end

  defp resolved_non_bearer_auth_mode(conn) do
    actor = Ash.PlugHelpers.get_actor(conn)

    cond do
      api_key_actor?(actor) -> "api_key"
      is_nil(actor) -> "anonymous"
      true -> "session"
    end
  end

  defp api_key_actor?(actor) when is_map(actor) do
    actor
    |> Map.get(:__metadata__, %{})
    |> Map.get(:using_api_key?, false)
  end

  defp api_key_actor?(_actor), do: false

  defp maybe_record_api_key_audit(conn, actor, "api_key") when is_map(actor) do
    measurements = %{count: 1, usage_timestamp: System.system_time(:millisecond)}

    metadata = %{
      endpoint: conn.request_path,
      method: conn.method,
      actor_id: Map.get(actor, :id),
      api_key_id: actor_api_key_id(actor)
    }

    :telemetry.execute(@api_key_audit_event, measurements, metadata)

    Logger.info("api_key_rpc_audit=#{inspect(Map.merge(metadata, %{usage_timestamp: measurements.usage_timestamp}))}")
  end

  defp maybe_record_api_key_audit(_conn, _actor, _auth_mode), do: :ok

  defp actor_api_key_id(actor) when is_map(actor) do
    actor
    |> Map.get(:__metadata__, %{})
    |> Map.get(:api_key)
    |> case do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp actor_api_key_id(_actor), do: nil

  defp auth_failure_response("api_key"), do: api_key_auth_failure_response()
  defp auth_failure_response(auth_mode), do: bearer_auth_failure_response(auth_mode)

  defp api_key_auth_failure_response do
    %{
      success: false,
      errors: [
        %{
          type: "authorization_failed",
          short_message: "Authorization failed",
          message: "API key is invalid, expired, or revoked.",
          vars: %{},
          fields: [],
          path: [],
          details: %{reason: "invalid_expired_or_revoked_api_key"}
        }
      ]
    }
    |> attach_actor_auth_mode("api_key")
  end

  defp bearer_auth_failure_response(auth_mode) do
    %{
      success: false,
      errors: [
        %{
          type: "authorization_failed",
          short_message: "Authorization failed",
          message: "Bearer token is invalid, expired, or revoked.",
          vars: %{},
          fields: [],
          path: [],
          details: %{reason: "invalid_expired_or_revoked_bearer_token"}
        }
      ]
    }
    |> attach_actor_auth_mode(auth_mode)
  end

  defp attach_actor_auth_mode(result, auth_mode) when is_map(result) do
    Map.update(result, :meta, %{actor_auth_mode: auth_mode}, fn meta ->
      if is_map(meta), do: Map.put(meta, :actor_auth_mode, auth_mode), else: %{actor_auth_mode: auth_mode}
    end)
  end
end
