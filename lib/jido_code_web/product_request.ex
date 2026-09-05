defmodule JidoCodeWeb.ProductRequest do
  @moduledoc """
  Closed request boundary for authenticated controller-rendered product pages.

  Route controllers supply operations, areas, actions, and resource parameter
  names as code-owned values. Browser parameters can identify only bounded
  opaque registry references and closed lens/filter values.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias JidoCode.Identity.AuthorityBuilder
  alias JidoCode.Identity.AuthorizationResult
  alias JidoCode.Identity.Store
  alias JidoCodeWeb.ProductAuth

  @maximum_ref_bytes 64
  @maximum_query_bytes 128
  @maximum_page 100
  @ref ~r/\A[A-Za-z0-9][A-Za-z0-9_-]*\z/
  @lenses ~w[source dependencies history architecture security quality]
  @states ~w(all active waiting blocked verifying complete)

  @type resource_spec ::
          :factory
          | :session
          | {:resource, String.t(), atom()}
          | {:nested, String.t(), atom(), String.t(), atom()}

  @spec authorize(Plug.Conn.t(), map(), map()) ::
          {:ok, Plug.Conn.t(), map()} | {:error, Plug.Conn.t()}
  def authorize(conn, spec, params) when is_map(spec) and is_map(params) do
    conn = secure(conn)

    with {:ok, route_params} <- normalize_route_params(spec, params),
         {:ok, query, query_errors} <- normalize_query(Map.get(spec, :query, []), params),
         {:ok, authorization} <- authorize_resource(conn, spec, route_params),
         :ok <- verify_resource(spec.resource, route_params, authorization) do
      page = %{
        key: Map.fetch!(spec, :key),
        title: Map.fetch!(spec, :title),
        summary: Map.fetch!(spec, :summary),
        area: Map.fetch!(spec, :area),
        route_params: route_params,
        query: query,
        query_fields: Map.get(spec, :query, []),
        query_errors: query_errors,
        authorization: authorization,
        canonical_url: canonical_url(conn.request_path, query)
      }

      {:ok, assign_authorization(conn, authorization), page}
    else
      {:error, :invalid_route_parameter} -> {:error, not_found(conn)}
      {:error, :concealed_not_found} -> {:error, not_found(conn)}
      {:error, :denied} -> {:error, forbidden(conn)}
      {:error, :step_up_required} -> {:error, step_up(conn)}
      {:error, :revoked} -> {:error, expired(conn)}
      {:error, _unavailable} -> {:error, unavailable(conn)}
    end
  end

  @spec closed_lenses() :: [String.t()]
  def closed_lenses, do: @lenses

  defp normalize_route_params(%{resource: :factory}, _params), do: {:ok, %{}}
  defp normalize_route_params(%{resource: :session}, _params), do: {:ok, %{}}

  defp normalize_route_params(%{resource: {:resource, name, kind}} = spec, params) do
    with {:ok, ref} <- bounded_ref(params[name]),
         :ok <- validate_lens(spec, params) do
      {:ok, %{resource_ref: ref, resource_kind: kind, lens: params["lens"]}}
    end
  end

  defp normalize_route_params(
         %{resource: {:nested, parent_name, parent_kind, child_name, child_kind}} = spec,
         params
       ) do
    with {:ok, parent_ref} <- bounded_ref(params[parent_name]),
         {:ok, child_ref} <- bounded_ref(params[child_name]),
         :ok <- validate_lens(spec, params) do
      {:ok,
       %{
         parent_ref: parent_ref,
         parent_kind: parent_kind,
         resource_ref: child_ref,
         resource_kind: child_kind,
         lens: params["lens"]
       }}
    end
  end

  defp validate_lens(%{lens: true}, %{"lens" => lens}) when lens in @lenses, do: :ok
  defp validate_lens(%{lens: true}, _params), do: {:error, :invalid_route_parameter}
  defp validate_lens(_spec, _params), do: :ok

  defp bounded_ref(value)
       when is_binary(value) and byte_size(value) in 1..@maximum_ref_bytes do
    if Regex.match?(@ref, value), do: {:ok, value}, else: {:error, :invalid_route_parameter}
  end

  defp bounded_ref(_value), do: {:error, :invalid_route_parameter}

  defp normalize_query(allowed, params) do
    allowed = MapSet.new(allowed)

    {query, errors} =
      params
      |> Map.take(["q", "state", "page"])
      |> Enum.reduce({%{}, []}, fn {key, value}, {acc, errors} ->
        if MapSet.member?(allowed, key) do
          case normalize_query_value(key, value) do
            {:ok, nil} -> {acc, errors}
            {:ok, normalized} -> {Map.put(acc, key, normalized), errors}
            {:error, :invalid_route_parameter} -> {acc, [query_error(key) | errors]}
          end
        else
          {acc, errors}
        end
      end)

    {:ok, query, Enum.reverse(errors)}
  end

  defp query_error("q"),
    do: %{
      key: "query",
      label: "Search must be at most 128 bytes.",
      target_id: "product-filter-search-query"
    }

  defp query_error("state"),
    do: %{
      key: "state",
      label: "Choose one of the available states.",
      target_id: "product-filter-search-filter-state"
    }

  defp query_error("page"),
    do: %{key: "page", label: "Page must be between 1 and 100.", target_id: "product-pagination"}

  defp normalize_query_value("q", value)
       when is_binary(value) and byte_size(value) <= @maximum_query_bytes do
    case String.trim(value) do
      "" -> {:ok, nil}
      query -> {:ok, query}
    end
  end

  defp normalize_query_value("state", value) when value in @states do
    if value == "all", do: {:ok, nil}, else: {:ok, value}
  end

  defp normalize_query_value("page", value) do
    case Integer.parse(to_string(value)) do
      {page, ""} when page in 1..@maximum_page -> {:ok, if(page == 1, do: nil, else: page)}
      _invalid -> {:error, :invalid_route_parameter}
    end
  end

  defp normalize_query_value(_key, _value), do: {:error, :invalid_route_parameter}

  defp authorize_resource(conn, %{resource: :session}, _params) do
    case conn.assigns[:authenticated_human] do
      %{session_ref: session_ref} -> {:ok, %{decision: :allowed, session_ref: session_ref}}
      _missing -> {:error, :revoked}
    end
  end

  defp authorize_resource(conn, spec, route_params) do
    with %{session_ref: session_ref} <- conn.assigns[:authenticated_human],
         {:ok, _parent} <- authorize_parent(session_ref, spec, route_params, conn),
         {:ok, request} <-
           AuthorityBuilder.request(
             Map.fetch!(spec, :operation),
             Map.fetch!(spec, :area),
             :page,
             resource_ref(spec.resource, route_params),
             reauthorization_point: :before_response_start,
             correlation_ref: conn.assigns[:request_id] || route_correlation(conn)
           ),
         {:ok, authorization} <- AuthorityBuilder.build(session_ref, request),
         :allowed <- authorization.decision do
      {:ok, authorization}
    else
      {:ok, %AuthorizationResult{decision: decision}} -> {:error, decision}
      decision when is_atom(decision) -> {:error, decision}
      {:error, reason} -> {:error, reason}
      _invalid -> {:error, :unavailable}
    end
  end

  defp authorize_parent(session_ref, %{resource: {:nested, _, _, _, _}} = spec, params, conn) do
    with {:ok, request} <-
           AuthorityBuilder.request(
             :project_page,
             :developer,
             :page,
             params.parent_ref,
             reauthorization_point: :before_response_start,
             correlation_ref: (conn.assigns[:request_id] || route_correlation(conn)) <> "-parent"
           ),
         {:ok, authorization} <- AuthorityBuilder.build(session_ref, request),
         :allowed <- authorization.decision,
         true <- authorization.current_scope.resource_kind == elem(spec.resource, 2) do
      {:ok, authorization}
    else
      false -> {:error, :concealed_not_found}
      decision when is_atom(decision) -> {:error, decision}
      {:error, reason} -> {:error, reason}
    end
  end

  defp authorize_parent(_session_ref, _spec, _params, _conn), do: {:ok, nil}

  defp verify_resource(:factory, _params, %AuthorizationResult{current_scope: scope}),
    do: if(scope.resource_kind == :factory, do: :ok, else: {:error, :concealed_not_found})

  defp verify_resource(:session, _params, _authorization), do: :ok

  defp verify_resource({:resource, _name, kind}, _params, %AuthorizationResult{
         current_scope: scope
       }),
       do: if(scope.resource_kind == kind, do: :ok, else: {:error, :concealed_not_found})

  defp verify_resource({:nested, _, _, _, kind}, params, %AuthorizationResult{
         current_scope: scope
       }) do
    with true <- scope.resource_kind == kind,
         {:ok, parent} <- Store.resolve_resource(params.parent_ref),
         {:ok, child} <- Store.resolve_resource(params.resource_ref),
         true <- child.parent_ref == parent.resource_ref,
         true <- child.tenant_ref == parent.tenant_ref,
         true <- child.project_ref == parent.project_ref do
      :ok
    else
      _mismatch -> {:error, :concealed_not_found}
    end
  end

  defp resource_ref(:factory, _params), do: :factory
  defp resource_ref({:resource, _, _}, params), do: params.resource_ref
  defp resource_ref({:nested, _, _, _, _}, params), do: params.resource_ref

  defp assign_authorization(conn, %AuthorizationResult{} = authorization) do
    conn
    |> assign(:current_scope, authorization.current_scope)
    |> assign(:product_identity, authorization.product_identity)
    |> assign(:authority, authorization.authority_context)
    |> assign(:authorization, authorization)
  end

  defp assign_authorization(conn, _session_authorization), do: conn

  defp canonical_url(path, query) when map_size(query) == 0,
    do: JidoCodeWeb.Endpoint.url() <> path

  defp canonical_url(path, query),
    do: JidoCodeWeb.Endpoint.url() <> path <> "?" <> URI.encode_query(query)

  defp secure(conn) do
    conn
    |> put_resp_header("cache-control", "no-store, private")
    |> put_resp_header("referrer-policy", "origin")
    |> put_resp_header("x-robots-tag", "noindex, nofollow")
  end

  defp not_found(conn), do: send_resp(conn, :not_found, "Not found.")
  defp forbidden(conn), do: send_resp(conn, :forbidden, "This area is not available.")

  defp unavailable(conn),
    do: send_resp(conn, :service_unavailable, "The product authority is unavailable.")

  defp expired(conn) do
    conn
    |> ProductAuth.delete_session()
    |> redirect(to: "/sign-in?" <> URI.encode_query(%{"reason" => "expired"}))
  end

  defp step_up(conn) do
    return_to = ProductAuth.safe_return_path(request_path_with_query(conn))
    redirect(conn, to: "/step-up?" <> URI.encode_query(%{"return_to" => return_to}))
  end

  defp request_path_with_query(conn) do
    if conn.query_string == "",
      do: conn.request_path,
      else: conn.request_path <> "?" <> conn.query_string
  end

  defp route_correlation(conn),
    do: "route-" <> Integer.to_string(:erlang.phash2({conn.method, conn.request_path}))
end
