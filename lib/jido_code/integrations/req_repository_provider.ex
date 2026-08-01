defmodule JidoCode.Integrations.ReqRepositoryProvider do
  @moduledoc """
  Bounded HTTP repository-provider adapter implemented with `Req`.

  Raw bodies and credentials remain inside one adapter call. Returned values
  contain normalized provider facts, source IDs, revision headers, response
  digests, completeness, and redacted limitations only.
  """

  @behaviour JidoCode.Factory.Ports.RepositoryProvider

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Observations.ProviderObservation
  alias JidoCode.Factory.RepositoryLocator

  @derive {Inspect,
           only: [
             :provider,
             :receive_timeout_ms,
             :max_retries,
             :max_pages,
             :page_size,
             :max_body_bytes
           ]}
  @enforce_keys [
    :provider,
    :base_url,
    :receive_timeout_ms,
    :max_retries,
    :max_pages,
    :page_size,
    :max_body_bytes,
    :request_fun
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @collection_paths %{
    issues: "issues",
    pull_requests: "pulls",
    branches: "branches",
    checks: "commits/HEAD/check-runs"
  }

  @spec new(keyword()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(options) when is_list(options) do
    base_url = Keyword.get(options, :base_url, "https://api.github.com/")
    uri = URI.parse(base_url)
    timeout = Keyword.get(options, :receive_timeout_ms, 5_000)
    retries = Keyword.get(options, :max_retries, 2)
    pages = Keyword.get(options, :max_pages, 5)
    page_size = Keyword.get(options, :page_size, 50)
    max_body = Keyword.get(options, :max_body_bytes, 1_000_000)
    request_fun = Keyword.get(options, :request_fun, &Req.request/1)

    with true <- valid_base_uri?(uri),
         true <- is_integer(timeout) and timeout in 100..30_000,
         true <- is_integer(retries) and retries in 0..3,
         true <- is_integer(pages) and pages in 1..10,
         true <- is_integer(page_size) and page_size in 1..100,
         true <- is_integer(max_body) and max_body in 1_024..5_000_000,
         true <- is_function(request_fun, 1) do
      {:ok,
       %__MODULE__{
         provider: :github,
         base_url: normalized_base_url(uri),
         receive_timeout_ms: timeout,
         max_retries: retries,
         max_pages: pages,
         page_size: page_size,
         max_body_bytes: max_body,
         request_fun: request_fun
       }}
    else
      _invalid -> invalid(:provider_adapter_config)
    end
  rescue
    _error -> invalid(:provider_adapter_config)
  end

  @impl true
  def observe_repository(
        %__MODULE__{} = adapter,
        %RepositoryLocator{} = locator,
        %CredentialReference{} = credential,
        options
      )
      when is_list(options) do
    with {:ok, retrieved_at} <- trusted_time(options),
         {:ok, token} <- fetch_secret(credential, options),
         {:ok, response} <-
           request(adapter, "repositories/#{URI.encode(locator.external_id)}", token, []),
         result <- repository_response(response, locator, retrieved_at, adapter.max_body_bytes) do
      result
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:observe_repository)
    end
  rescue
    _error -> invalid(:observe_repository)
  end

  def observe_repository(_adapter, _locator, _credential, _options),
    do: invalid(:observe_repository)

  @impl true
  def observe_collection(
        %__MODULE__{} = adapter,
        :capabilities,
        %RepositoryLocator{} = locator,
        %CredentialReference{} = credential,
        _cursor,
        options
      ) do
    case observe_repository(adapter, locator, credential, options) do
      {:ok, %{observations: [%ProviderObservation{} = repository]}} ->
        capability = %{
          repository
          | kind: :capability,
            external_id: repository.external_id <> ":capabilities",
            data: %{
              permissions: repository.data.permissions,
              visibility: repository.data.visibility
            },
            completeness: %{
              status: repository.completeness.status,
              covered: ["permissions", "visibility"],
              missing: repository.completeness.missing
            }
        }

        {:ok, %{observations: [capability], next_cursor: nil}}

      {:error, %AdapterError{} = error} ->
        {:error, error}

      _invalid ->
        invalid(:observe_provider_capabilities)
    end
  end

  def observe_collection(
        %__MODULE__{} = adapter,
        kind,
        %RepositoryLocator{} = locator,
        %CredentialReference{} = credential,
        cursor,
        options
      )
      when kind in [:issues, :pull_requests, :branches, :checks] and is_list(options) do
    with {:ok, retrieved_at} <- trusted_time(options),
         {:ok, page} <- page(cursor),
         {:ok, token} <- fetch_secret(credential, options),
         {:ok, observations, next_cursor} <-
           collect_pages(adapter, kind, locator, token, page, retrieved_at, 0, []) do
      {:ok, %{observations: observations, next_cursor: next_cursor}}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:observe_provider_collection)
    end
  rescue
    _error -> invalid(:observe_provider_collection)
  end

  def observe_collection(_adapter, _kind, _locator, _credential, _cursor, _options),
    do: invalid(:observe_provider_collection)

  defp collect_pages(adapter, kind, locator, token, page, retrieved_at, count, observations) do
    with {:ok, owner, name} <- locator_address(locator),
         path <-
           "repos/#{URI.encode(owner)}/#{URI.encode(name)}/#{Map.fetch!(@collection_paths, kind)}",
         {:ok, response} <-
           request(adapter, path, token, page: page, per_page: adapter.page_size),
         {:ok, body, digest} <- bounded_json(response, adapter.max_body_bytes),
         {:ok, items} <- collection_items(kind, body),
         {:ok, normalized} <-
           normalize_collection(kind, items, response, digest, retrieved_at) do
      accumulated = observations ++ normalized
      next_count = count + 1

      cond do
        length(items) < adapter.page_size ->
          {:ok, accumulated, nil}

        next_count >= adapter.max_pages ->
          {:ok, mark_partial(accumulated, "pagination_limit_reached"),
           Integer.to_string(page + 1)}

        true ->
          collect_pages(
            adapter,
            kind,
            locator,
            token,
            page + 1,
            retrieved_at,
            next_count,
            accumulated
          )
      end
    end
  end

  defp request(adapter, path, token, params) do
    url = URI.merge(adapter.base_url, path) |> URI.to_string()
    started = System.monotonic_time()

    result =
      adapter.request_fun.(
        method: :get,
        url: url,
        params: params,
        headers: [
          {"accept", "application/vnd.github+json"},
          {"authorization", "Bearer " <> token},
          {"x-github-api-version", "2022-11-28"},
          {"user-agent", "jido-code/phase-06"}
        ],
        receive_timeout: adapter.receive_timeout_ms,
        retry: :transient,
        max_retries: adapter.max_retries,
        redirect: false,
        decode_body: false
      )

    duration = System.monotonic_time() - started
    status = response_status(result)

    :telemetry.execute(
      [:jido_code, :integration, :provider, :request],
      %{duration: duration},
      %{provider: adapter.provider, status_class: status_class(status)}
    )

    case result do
      {:ok, %Req.Response{} = response} -> {:ok, response}
      {:error, _reason} -> {:error, AdapterError.new(:unavailable, :provider_http_request)}
      _invalid -> invalid(:provider_http_response)
    end
  end

  defp repository_response(%Req.Response{status: 200} = response, locator, retrieved_at, limit) do
    with {:ok, body, digest} <- bounded_json(response, limit),
         true <- is_map(body),
         {:ok, observation} <-
           ProviderObservation.new(%{
             kind: :repository,
             external_id: to_string(Map.get(body, "id", locator.external_id)),
             source_time: source_time(body),
             retrieved_at: retrieved_at,
             etag: header(response, "etag"),
             source_revision: header(response, "x-github-api-version"),
             response_digest: digest,
             data: normalize_repository(body),
             completeness: %{
               status: :complete,
               covered: ["identity", "default_branch", "visibility", "repository_state"],
               missing: []
             },
             limitations: ["provider_observation_not_accepted_knowledge"],
             warnings: unknown_field_warning(body)
           }) do
      {:ok, %{observations: [observation], next_cursor: nil}}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:provider_repository_payload)
    end
  end

  defp repository_response(
         %Req.Response{status: status} = response,
         locator,
         retrieved_at,
         _limit
       )
       when status in [301, 302, 307, 308, 404] do
    state = if status == 404, do: "not_found", else: "redirected"
    digest = digest_body(response.body)

    with {:ok, observation} <-
           ProviderObservation.new(%{
             kind: :repository,
             external_id: locator.external_id,
             source_time: nil,
             retrieved_at: retrieved_at,
             etag: header(response, "etag"),
             source_revision: nil,
             response_digest: digest,
             data: %{availability: state},
             completeness: %{
               status: :partial,
               covered: ["availability"],
               missing: ["repository_metadata"]
             },
             limitations: ["response_body_not_retained"],
             warnings: [state]
           }) do
      {:ok, %{observations: [observation], next_cursor: nil}}
    end
  end

  defp repository_response(%Req.Response{status: 401}, _locator, _time, _limit),
    do: {:error, AdapterError.new(:unauthorized, :provider_credentials)}

  defp repository_response(%Req.Response{status: 403} = response, _locator, _time, _limit) do
    if header(response, "x-ratelimit-remaining") == "0",
      do: {:error, AdapterError.new(:unavailable, :provider_rate_limit)},
      else: {:error, AdapterError.new(:unauthorized, :provider_permissions)}
  end

  defp repository_response(%Req.Response{status: status}, _locator, _time, _limit)
       when status == 429 or status >= 500,
       do: {:error, AdapterError.new(:unavailable, :provider_http_status)}

  defp repository_response(_response, _locator, _time, _limit),
    do: invalid(:provider_http_status)

  defp normalize_collection(kind, items, response, digest, retrieved_at) do
    item_kind = collection_kind(kind)

    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
      attributes = %{
        kind: item_kind,
        external_id: external_id(item),
        source_time: source_time(item),
        retrieved_at: retrieved_at,
        etag: header(response, "etag"),
        source_revision: header(response, "x-github-api-version"),
        response_digest: digest,
        data: normalize_item(kind, item),
        completeness: %{status: :complete, covered: [Atom.to_string(kind)], missing: []},
        limitations: ["collection_page_digest_shared"],
        warnings: []
      }

      case ProviderObservation.new(attributes) do
        {:ok, observation} -> {:cont, {:ok, [observation | acc]}}
        {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp bounded_json(%Req.Response{status: 200, body: body}, limit) when is_binary(body) do
    if byte_size(body) <= limit do
      case Jason.decode(body) do
        {:ok, decoded} -> {:ok, decoded, digest_body(body)}
        {:error, _reason} -> {:error, AdapterError.new(:corrupt, :provider_json)}
      end
    else
      {:error, AdapterError.new(:invalid_input, :provider_response_size)}
    end
  end

  defp bounded_json(%Req.Response{status: status}, _limit) when status in [401, 403],
    do: {:error, AdapterError.new(:unauthorized, :provider_collection)}

  defp bounded_json(%Req.Response{status: status}, _limit) when status == 429 or status >= 500,
    do: {:error, AdapterError.new(:unavailable, :provider_collection)}

  defp bounded_json(_response, _limit), do: invalid(:provider_collection_response)

  defp collection_items(:checks, %{"check_runs" => items}) when is_list(items), do: {:ok, items}
  defp collection_items(kind, items) when kind != :checks and is_list(items), do: {:ok, items}
  defp collection_items(_kind, _body), do: invalid(:provider_collection_payload)

  defp normalize_repository(body) do
    %{
      provider_id: Map.get(body, "id"),
      node_id: Map.get(body, "node_id"),
      name: Map.get(body, "name"),
      full_name: Map.get(body, "full_name"),
      owner: get_in(body, ["owner", "login"]),
      default_branch: Map.get(body, "default_branch"),
      visibility: visibility(body),
      archived: Map.get(body, "archived", false),
      disabled: Map.get(body, "disabled", false),
      fork: Map.get(body, "fork", false),
      permissions: normalize_permissions(Map.get(body, "permissions", %{}))
    }
  end

  defp normalize_item(:issues, item),
    do: select(item, ~w[id node_id number state locked created_at updated_at closed_at])

  defp normalize_item(:pull_requests, item),
    do: select(item, ~w[id node_id number state draft merged created_at updated_at closed_at])

  defp normalize_item(:branches, item) do
    %{
      name: Map.get(item, "name"),
      protected: Map.get(item, "protected", false),
      commit_sha: get_in(item, ["commit", "sha"])
    }
  end

  defp normalize_item(:checks, item),
    do: select(item, ~w[id node_id name status conclusion started_at completed_at])

  defp select(map, keys), do: Map.take(map, keys)

  defp normalize_permissions(value) when is_map(value) do
    value
    |> Map.take(~w[admin maintain push triage pull])
    |> Map.new(fn {key, allowed} -> {key, allowed == true} end)
  end

  defp normalize_permissions(_value), do: %{}

  defp source_time(body) when is_map(body) do
    body
    |> then(&(Map.get(&1, "updated_at") || Map.get(&1, "pushed_at") || Map.get(&1, "created_at")))
    |> parse_datetime()
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, time, _offset} -> time
      _invalid -> nil
    end
  end

  defp parse_datetime(_value), do: nil

  defp external_id(item) do
    case Map.get(item, "id") || Map.get(item, "node_id") || Map.get(item, "name") do
      nil -> "unknown:" <> digest_body(Jason.encode!(normalize_item_guess(item)))
      value -> to_string(value)
    end
  end

  defp normalize_item_guess(item), do: Map.take(item, ~w[id node_id name number state])
  defp collection_kind(:issues), do: :issue
  defp collection_kind(:pull_requests), do: :pull_request
  defp collection_kind(:branches), do: :branch
  defp collection_kind(:checks), do: :ci

  defp mark_partial(observations, warning) do
    Enum.map(observations, fn observation ->
      %{
        observation
        | completeness: %{observation.completeness | status: :partial},
          warnings: Enum.uniq(observation.warnings ++ [warning])
      }
    end)
  end

  defp visibility(body) do
    Map.get(body, "visibility") || if(Map.get(body, "private"), do: "private", else: "public")
  end

  defp unknown_field_warning(body) do
    known = MapSet.new(~w[
      id node_id name full_name owner default_branch visibility private archived disabled fork
      permissions updated_at pushed_at created_at
    ])

    if Enum.any?(Map.keys(body), &(not MapSet.member?(known, &1))),
      do: ["unknown_fields_ignored"],
      else: []
  end

  defp locator_address(%RepositoryLocator{observed_address: address}) do
    case String.split(address, "/", parts: 3) do
      [_host, owner, name] when owner != "" and name != "" -> {:ok, owner, name}
      _invalid -> invalid(:provider_locator_address)
    end
  end

  defp fetch_secret(credential, options) do
    case Keyword.get(options, :secret_provider) do
      fun when is_function(fun, 1) ->
        normalize_secret(fun.(credential))

      {module, provider} when is_atom(module) ->
        normalize_secret(module.fetch(provider, credential))

      _invalid ->
        invalid(:provider_secret_port)
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :provider_secret_port)}
  end

  defp normalize_secret({:ok, value}) when is_binary(value) and byte_size(value) in 1..8_192,
    do: {:ok, value}

  defp normalize_secret({:error, %AdapterError{} = error}), do: {:error, error}
  defp normalize_secret(_value), do: invalid(:provider_secret_value)

  defp trusted_time(options) do
    case Keyword.get(options, :clock) do
      fun when is_function(fun, 0) ->
        case fun.() do
          %DateTime{} = time -> {:ok, DateTime.truncate(time, :microsecond)}
          _invalid -> invalid(:provider_clock)
        end

      _invalid ->
        invalid(:provider_clock)
    end
  end

  defp page(nil), do: {:ok, 1}

  defp page(value) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} when page in 1..10_000 -> {:ok, page}
      _invalid -> invalid(:provider_cursor)
    end
  end

  defp page(_value), do: invalid(:provider_cursor)

  defp header(%Req.Response{headers: headers}, name) when is_map(headers) do
    case Map.get(headers, name) || Map.get(headers, String.downcase(name)) do
      [value | _] -> value
      value when is_binary(value) -> value
      _missing -> nil
    end
  end

  defp header(%Req.Response{headers: headers}, name) when is_list(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == String.downcase(name), do: to_string(value)
    end)
  end

  defp header(_response, _name), do: nil

  defp digest_body(body) when is_binary(body) do
    body |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end

  defp digest_body(body), do: body |> :erlang.term_to_binary([:deterministic]) |> digest_body()

  defp valid_base_uri?(uri) do
    uri.scheme == "https" and is_binary(uri.host) and is_nil(uri.userinfo) and
      is_nil(uri.query) and is_nil(uri.fragment) and not String.contains?(uri.path || "", "..")
  end

  defp normalized_base_url(uri) do
    path = uri.path || "/"
    path = if String.ends_with?(path, "/"), do: path, else: path <> "/"
    URI.to_string(%{uri | path: path})
  end

  defp response_status({:ok, %Req.Response{status: status}}), do: status
  defp response_status(_result), do: nil
  defp status_class(status) when is_integer(status), do: div(status, 100)
  defp status_class(_status), do: :network_error

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
