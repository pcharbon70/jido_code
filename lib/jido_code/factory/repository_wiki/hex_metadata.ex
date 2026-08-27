defmodule JidoCode.Factory.RepositoryWiki.HexMetadata do
  @moduledoc "Bounded Req acquisition of non-authoritative public Hex package metadata."

  alias JidoCode.Factory.RepositoryWiki.MetadataCache
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @profile "hex-req/1.0.0"
  @origin "https://hex.pm"
  @headers [{"accept", "application/json"}, {"user-agent", "jido-code-repository-wiki/1.0"}]
  @limits %{
    response_bytes: 262_144,
    summary_bytes: 2_048,
    text_bytes: 512,
    url_bytes: 2_048,
    links: 32,
    licenses: 32,
    maintainers: 32,
    requirements: 256,
    concurrent_requests: 4,
    packages: 128
  }
  @cache_policy %{
    positive_ttl_seconds: 86_400,
    negative_ttl_seconds: 900,
    stale_if_error_seconds: 604_800
  }
  @package ~r/^[a-z][a-z0-9_]{0,127}$/
  @version ~r/^[0-9A-Za-z][0-9A-Za-z.+_-]{0,127}$/

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      origin: @origin,
      routes: ["/api/packages/:package", "/api/packages/:package/releases/:version"],
      method: :get,
      headers: @headers,
      redirect: :deny,
      tls: :system_trust_https_only,
      receive_timeout_ms: 3_000,
      connect_timeout_ms: 2_000,
      retry: :deny,
      limits: @limits,
      cache: @cache_policy,
      cache_profile: MetadataCache.profile().revision,
      cache_profile_digest: MetadataCache.profile().digest,
      authority: :observed_only,
      html_interpretation: :forbidden,
      model_calls: 0
    }

    Map.put(value, :digest, Knowledge.repository_wiki_digest(value))
  end

  @spec fetch(String.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def fetch(package, version, context, options \\ [])

  def fetch(package, version, context, options)
      when is_binary(package) and is_binary(version) and is_map(context) and is_list(options) do
    with :ok <- validate(package, version, context, options),
         key <- cache_key(package, version, context),
         cached <- cache_lookup(context[:cache], key, context.retrieved_at),
         {:ok, result} <- acquire_with_cache(cached, package, version, context, options, key) do
      {:ok, result}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  rescue
    _error -> invalid()
  end

  def fetch(_package, _version, _context, _options), do: invalid()

  @spec fetch_many([{String.t(), String.t()}], map(), keyword()) ::
          {:ok, [map()]} | {:error, Error.t()}
  def fetch_many(requests, context, options \\ [])

  def fetch_many(requests, context, options)
      when is_list(requests) and is_map(context) and is_list(options) and
             length(requests) <= @limits.packages do
    results =
      Task.async_stream(
        requests,
        fn
          {package, version} -> fetch(package, version, context, options)
          _invalid -> invalid()
        end,
        ordered: true,
        max_concurrency: @limits.concurrent_requests,
        timeout: :infinity
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, _reason} -> invalid()
      end)

    case Enum.find(results, &match?({:error, %Error{}}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, value} -> value end)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  def fetch_many(_requests, _context, _options), do: invalid()

  defp validate(package, version, context, options) do
    allowed_options = [:fixture, :req_test]

    cond do
      not Regex.match?(@package, package) or not Regex.match?(@version, version) ->
        invalid()

      Knowledge.validate_resource_identity(context[:repository_iri]) != :ok or
          Knowledge.validate_resource_identity(context[:tenant_iri]) != :ok ->
        invalid()

      context[:authorization_class] != :public_anonymous or
          not match?(%DateTime{}, context[:retrieved_at]) ->
        invalid()

      Keyword.keys(options) -- allowed_options != [] ->
        invalid()

      options[:req_test] && not is_atom(options[:req_test]) ->
        invalid()

      options[:fixture] && not is_map(options[:fixture]) ->
        invalid()

      true ->
        :ok
    end
  end

  defp cache_key(package, version, context) do
    {
      context.tenant_iri,
      context.repository_iri,
      context.authorization_class,
      package,
      version,
      profile().digest
    }
  end

  defp cache_lookup(nil, _key, _now), do: :miss
  defp cache_lookup(cache, key, now), do: MetadataCache.lookup(cache, key, now)

  defp acquire_with_cache({:fresh, entry}, _package, _version, context, _options, _key) do
    {:ok, cached_result(entry.value, :fresh, context.retrieved_at, nil)}
  end

  defp acquire_with_cache(cached, package, version, context, options, key) do
    result = acquire(package, version, context.retrieved_at, options)

    cond do
      result.state in [:available, :partial] ->
        put_cache(context[:cache], key, result, :positive, context.retrieved_at)
        {:ok, result}

      match?({:stale, _entry}, cached) ->
        {:stale, entry} = cached
        {:ok, cached_result(entry.value, :stale, context.retrieved_at, result.reason)}

      true ->
        put_cache(context[:cache], key, result, :negative, context.retrieved_at)
        {:ok, result}
    end
  end

  defp put_cache(nil, _key, _result, _outcome, _now), do: :ok

  defp put_cache(cache, key, result, outcome, now),
    do: MetadataCache.put(cache, key, result, outcome, now, @cache_policy)

  defp cached_result(value, cache_state, checked_at, refresh_failure) do
    value
    |> Map.put(:cache_state, cache_state)
    |> Map.put(:cache_checked_at, checked_at)
    |> Map.put(:refresh_failure, refresh_failure)
    |> put_digest()
  end

  defp acquire(package, version, retrieved_at, options) do
    fixture = options[:fixture]
    package_result = endpoint(:package, package, version, retrieved_at, fixture, options)
    release_result = endpoint(:release, package, version, retrieved_at, fixture, options)
    successful = Enum.flat_map([package_result, release_result], &successful_endpoint/1)
    failures = Enum.flat_map([package_result, release_result], &failed_endpoint/1)

    state =
      case {length(successful), length(failures)} do
        {2, 0} -> :available
        {count, _failures} when count > 0 -> :partial
        _none -> :unavailable
      end

    facts = normalize_facts(package, version, successful)
    reason = failures |> List.first() |> then(&if(&1, do: &1.reason, else: nil))

    %{
      profile: @profile,
      profile_digest: profile().digest,
      package: package,
      version: version,
      state: state,
      reason: reason,
      authority: :observed,
      source_kind: :hex_remote_metadata,
      retrieved_at: retrieved_at,
      cache_state: :miss,
      fixture_digest: if(fixture, do: Knowledge.repository_wiki_digest(fixture), else: nil),
      endpoints: Enum.map(successful, &Map.drop(&1, [:body])) ++ failures,
      facts: facts,
      diagnostics: diagnostics(failures, facts),
      limitations: [
        :remote_metadata_non_authoritative,
        :remote_html_not_interpreted,
        :response_body_not_retained
      ],
      model_calls: 0,
      model_input_tokens: 0,
      model_output_tokens: 0,
      usage_cost_microunits: 0
    }
    |> put_digest()
  end

  defp endpoint(kind, package, version, retrieved_at, fixture, options) do
    route = route(kind, package, version)

    response =
      if fixture do
        fixture_response(fixture[kind])
      else
        request(route, options[:req_test])
      end

    normalize_response(kind, route, response, retrieved_at)
  end

  defp route(:package, package, _version), do: "/api/packages/" <> package

  defp route(:release, package, version),
    do: "/api/packages/" <> package <> "/releases/" <> version

  defp fixture_response(%{status: status} = fixture) when is_integer(status) do
    body = fixture[:body] || ""
    encoded = if is_binary(body), do: body, else: Jason.encode!(body)
    {:ok, %Req.Response{status: status, headers: fixture[:headers] || %{}, body: encoded}}
  rescue
    _error -> {:error, :invalid_fixture}
  end

  defp fixture_response(_fixture), do: {:error, :invalid_fixture}

  defp request(route, req_test) do
    request_options = [
      method: :get,
      url: @origin <> route,
      headers: @headers,
      receive_timeout: 3_000,
      connect_options: [timeout: 2_000],
      retry: false,
      redirect: false,
      decode_body: false
    ]

    request_options =
      if req_test,
        do: Keyword.put(request_options, :plug, {Req.Test, req_test}),
        else: request_options

    Req.request(request_options)
  rescue
    _error -> {:error, :request_failure}
  catch
    :exit, _reason -> {:error, :request_failure}
  end

  defp normalize_response(kind, route, {:ok, %Req.Response{status: 200} = response}, retrieved_at) do
    with {:ok, body, body_digest} <- bounded_json(response.body) do
      {:ok,
       %{
         kind: kind,
         endpoint: @origin <> route,
         endpoint_id: Atom.to_string(kind),
         status: 200,
         validators: %{
           etag: header(response, "etag"),
           last_modified: header(response, "last-modified")
         },
         retrieved_at: retrieved_at,
         body_digest: body_digest,
         body: body,
         parse_diagnostics: []
       }}
    else
      {:error, reason} ->
        endpoint_error(kind, route, response.status, reason, response, retrieved_at)
    end
  end

  defp normalize_response(kind, route, {:ok, %Req.Response{} = response}, retrieved_at) do
    reason =
      cond do
        response.status in [301, 302, 303, 307, 308] -> :redirect_rejected
        response.status == 404 -> :not_found
        response.status == 429 -> :rate_limited
        response.status >= 500 -> :remote_unavailable
        true -> :http_status
      end

    endpoint_error(kind, route, response.status, reason, response, retrieved_at)
  end

  defp normalize_response(kind, route, {:error, _reason}, retrieved_at) do
    {:error,
     %{
       kind: kind,
       endpoint: @origin <> route,
       endpoint_id: Atom.to_string(kind),
       status: nil,
       validators: %{},
       retrieved_at: retrieved_at,
       body_digest: nil,
       reason: :transport_unavailable,
       retry_after: nil
     }}
  end

  defp endpoint_error(kind, route, status, reason, response, retrieved_at) do
    {:error,
     %{
       kind: kind,
       endpoint: @origin <> route,
       endpoint_id: Atom.to_string(kind),
       status: status,
       validators: %{
         etag: header(response, "etag"),
         last_modified: header(response, "last-modified")
       },
       retrieved_at: retrieved_at,
       body_digest: digest_body(response.body),
       reason: reason,
       retry_after: header(response, "retry-after")
     }}
  end

  defp bounded_json(body) when is_binary(body) and byte_size(body) <= @limits.response_bytes do
    case Jason.decode(body) do
      {:ok, value} when is_map(value) -> {:ok, value, digest_body(body)}
      _invalid -> {:error, :malformed_json}
    end
  end

  defp bounded_json(body) when is_binary(body), do: {:error, :response_too_large}
  defp bounded_json(_body), do: {:error, :invalid_body}

  defp successful_endpoint({:ok, endpoint}), do: [endpoint]
  defp successful_endpoint(_failed), do: []
  defp failed_endpoint({:error, endpoint}), do: [endpoint]
  defp failed_endpoint(_successful), do: []

  defp normalize_facts(package, version, endpoints) do
    package_body = endpoint_body(endpoints, :package)
    release_body = endpoint_body(endpoints, :release)
    meta = if is_map(package_body["meta"]), do: package_body["meta"], else: %{}

    %{
      package: package,
      version: version,
      summary:
        bounded_text(meta["description"] || package_body["description"], @limits.summary_bytes),
      licenses: bounded_text_list(meta["licenses"], @limits.licenses),
      maintainers: maintainers(meta, package_body),
      links: bounded_links(meta["links"]),
      retirement: bounded_retirement(release_body["retirement"]),
      release_date: bounded_text(release_body["inserted_at"], @limits.text_bytes),
      requirements: bounded_requirements(release_body["requirements"]),
      checksum: bounded_checksum(release_body["checksum"])
    }
  end

  defp endpoint_body(endpoints, kind) do
    case Enum.find(endpoints, &(&1.kind == kind)) do
      %{body: body} when is_map(body) -> body
      _missing -> %{}
    end
  end

  defp bounded_text(value, maximum) when is_binary(value) and byte_size(value) <= maximum do
    if String.valid?(value) and String.normalize(value, :nfc) == value and
         not String.contains?(value, [<<0>>, "\r"]) do
      value
    end
  end

  defp bounded_text(_value, _maximum), do: nil

  defp bounded_text_list(values, maximum) when is_list(values) do
    values
    |> Enum.take(maximum)
    |> Enum.map(&bounded_text(&1, @limits.text_bytes))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp bounded_text_list(_values, _maximum), do: []

  defp maintainers(meta, package_body) do
    explicit = bounded_text_list(meta["maintainers"], @limits.maintainers)

    owners =
      (package_body["owners"] || [])
      |> Enum.take(@limits.maintainers)
      |> Enum.map(fn
        owner when is_map(owner) -> bounded_text(owner["username"], @limits.text_bytes)
        owner -> bounded_text(owner, @limits.text_bytes)
      end)
      |> Enum.reject(&is_nil/1)

    (explicit ++ owners) |> Enum.uniq() |> Enum.sort()
  end

  defp bounded_links(links) when is_map(links) and map_size(links) <= @limits.links do
    links
    |> Enum.flat_map(fn {kind, target} ->
      with display when is_binary(display) <- bounded_text(to_string(kind), @limits.text_bytes),
           value when is_binary(value) <- bounded_text(target, @limits.url_bytes) do
        [%{label: display, value: value}]
      else
        _invalid -> []
      end
    end)
    |> Enum.sort_by(&{&1.label, &1.value})
  end

  defp bounded_links(_links), do: []

  defp bounded_retirement(value) when is_map(value) do
    %{
      reason: bounded_text(value["reason"], @limits.text_bytes),
      message: bounded_text(value["message"], @limits.summary_bytes)
    }
  end

  defp bounded_retirement(_value), do: nil

  defp bounded_requirements(values)
       when is_map(values) and map_size(values) <= @limits.requirements do
    values
    |> Enum.flat_map(fn {name, requirement} ->
      if Regex.match?(@package, to_string(name)) and is_map(requirement) do
        [
          %{
            name: to_string(name),
            requirement: bounded_text(requirement["requirement"], @limits.text_bytes),
            optional: requirement["optional"] == true,
            app: requirement["app"] != false
          }
        ]
      else
        []
      end
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp bounded_requirements(_values), do: []

  defp bounded_checksum(value) when is_binary(value) do
    if Regex.match?(~r/^[a-fA-F0-9]{64}$/, value), do: String.downcase(value)
  end

  defp bounded_checksum(_value), do: nil

  defp diagnostics(failures, facts) do
    endpoint_diagnostics = Enum.map(failures, &%{endpoint: &1.endpoint_id, reason: &1.reason})

    missing_summary =
      if facts.summary, do: [], else: [%{endpoint: "package", reason: :missing_summary}]

    Enum.sort_by(endpoint_diagnostics ++ missing_summary, &{&1.endpoint, to_string(&1.reason)})
  end

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

  defp digest_body(body) when is_binary(body),
    do: body |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  defp digest_body(_body), do: nil

  defp put_digest(value),
    do: Map.put(value, :digest, Knowledge.repository_wiki_digest(Map.delete(value, :digest)))

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_hex_metadata)}
end
