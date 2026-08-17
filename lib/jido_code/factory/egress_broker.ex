defmodule JidoCode.Factory.EgressBroker do
  @moduledoc "Default-deny, authenticated, DNS-pinned egress broker."

  use GenServer
  import Bitwise

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Egress.Decision
  alias JidoCode.Factory.Egress.Destination
  alias JidoCode.Factory.Egress.Request

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, options, Keyword.take(options, [:name]))
  end

  @spec request(GenServer.server(), Request.t(), map(), binary()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def request(server, %Request{} = request, current, body)
      when is_map(current) and is_binary(body) do
    GenServer.call(server, {:request, request, current, body}, :infinity)
  end

  def request(_server, _request, _current, _body),
    do: {:error, AdapterError.new(:unauthorized, :egress_default_deny)}

  @impl true
  def init(options) do
    with {resolver_module, resolver} when is_atom(resolver_module) <-
           Keyword.get(options, :resolver),
         true <- port?(resolver_module, identity: 1, resolve: 2),
         {transport_module, transport} when is_atom(transport_module) <-
           Keyword.get(options, :transport),
         true <- port?(transport_module, request: 4),
         {audit_module, audit} when is_atom(audit_module) <- Keyword.get(options, :audit),
         true <- port?(audit_module, record: 2),
         clock when is_function(clock, 0) <- Keyword.get(options, :clock, &DateTime.utc_now/0) do
      {:ok,
       %{
         resolver_module: resolver_module,
         resolver: resolver,
         transport_module: transport_module,
         transport: transport,
         audit_module: audit_module,
         audit: audit,
         clock: clock,
         rate: %{}
       }}
    else
      _invalid -> {:stop, AdapterError.new(:invalid_input, :egress_broker)}
    end
  end

  @impl true
  def handle_call({:request, request, current, body}, _from, state) do
    now = state.clock.()

    if is_struct(now, DateTime) and byte_size(body) == request.request_bytes do
      {result, next_state} = dispatch(request, current, body, now, state, [])
      {:reply, result, next_state}
    else
      {result, next_state} = deny(request, :invalid_request_body, now, state)
      {:reply, result, next_state}
    end
  rescue
    _error -> {:reply, unavailable(:egress_broker), state}
  catch
    :exit, _reason -> {:reply, unavailable(:egress_broker), state}
  end

  defp dispatch(request, current, body, now, state, decisions) do
    with :ok <- current_authority(request, current, now),
         {:ok, uri} <- request_uri(request.uri),
         {:ok, destination} <- destination(request, uri),
         :ok <- policy_limits(request, destination),
         :ok <- resolver_identity(request, state),
         {:ok, next_state} <- consume_rate(request, now, state) do
      resolve_and_perform(request, current, body, uri, now, next_state, decisions)
    else
      {:deny, reason} -> deny(request, reason, now, state, decisions)
      {:error, %AdapterError{} = error} -> {{:error, error}, state}
      _invalid -> deny(request, :broker_boundary, now, state, decisions)
    end
  end

  defp resolve_and_perform(request, current, body, uri, now, state, decisions) do
    with {:ok, addresses} <- state.resolver_module.resolve(state.resolver, uri.host),
         {:ok, address} <- public_address(addresses) do
      perform(request, current, body, uri, address, now, state, decisions)
    else
      {:deny, reason} -> deny(request, reason, now, state, decisions)
      {:error, %AdapterError{} = error} -> {{:error, error}, state}
      _invalid -> deny(request, :uncontrolled_dns, now, state, decisions)
    end
  end

  defp perform(request, current, body, uri, address, now, state, decisions) do
    decision = Decision.issue(request, :allowed, :policy_match, now)

    with :ok <- record(state, decision),
         endpoint <- endpoint(uri, address, request),
         {:ok, response} <-
           state.transport_module.request(state.transport, request, endpoint, body),
         {:ok, response} <- response(response, request) do
      follow_response(response, request, current, body, now, state, [decision | decisions])
    else
      {:error, %AdapterError{} = error} -> {{:error, error}, state}
      _invalid -> {unavailable(:egress_transport), state}
    end
  end

  defp follow_response(%{location: location}, request, current, body, now, state, decisions)
       when is_binary(location) do
    if request.redirect_count < request.policy.maximum_redirects do
      redirected = %{request | uri: location, redirect_count: request.redirect_count + 1}
      dispatch(redirected, current, body, now, state, decisions)
    else
      deny(request, :redirect_limit, now, state, decisions)
    end
  end

  defp follow_response(response, _request, _current, _body, _now, state, decisions) do
    result = %{
      status: response.status,
      response_bytes: response.response_bytes,
      result: response.result,
      decisions: Enum.reverse(decisions)
    }

    {{:ok, result}, state}
  end

  defp deny(request, reason, now, state, decisions \\ [])

  defp deny(request, reason, %DateTime{} = now, state, _decisions) do
    decision = Decision.issue(request, :denied, reason, now)

    case record(state, decision) do
      :ok -> {{:error, blocked(request, reason)}, state}
      {:error, %AdapterError{} = error} -> {{:error, error}, state}
      _invalid -> {unavailable(:egress_audit), state}
    end
  end

  defp deny(_request, _reason, _now, state, _decisions), do: {unavailable(:egress_broker), state}

  defp current_authority(request, current, now) do
    policy = request.policy

    valid? =
      DateTime.compare(now, policy.expires_at) in [:lt, :eq] and current[:lease_state] == :active and
        current[:attempt_iri] == policy.attempt_iri and
        current[:invocation_iri] == policy.invocation_iri and
        current[:lease_iri] == policy.lease_iri and
        current[:fencing_token] == policy.fencing_token and
        current[:profile_revision] == policy.profile_revision and
        current[:egress_revision] == policy.egress_revision and
        current[:revocation_generation] == policy.revocation_generation

    if valid?, do: :ok, else: {:deny, :stale_authority}
  end

  defp request_uri(value) do
    case URI.parse(value) do
      %URI{scheme: "https", host: host, userinfo: nil, fragment: nil} = uri
      when is_binary(host) ->
        path = uri.path || "/"

        valid? =
          host == String.downcase(host) and byte_size(host) in 1..253 and
            (is_nil(uri.port) or uri.port in 1..65_535) and byte_size(path) in 1..1_024 and
            String.starts_with?(path, "/") and not String.contains?(path, ["\\", "%"]) and
            not Enum.any?(String.split(path, "/", trim: true), &(&1 in [".", ".."])) and
            (is_nil(uri.query) or byte_size(uri.query) <= 2_048)

        if valid?, do: {:ok, %{uri | path: path}}, else: {:deny, :unsafe_url}

      _invalid ->
        {:deny, :unsafe_url}
    end
  rescue
    _error -> {:deny, :unsafe_url}
  end

  defp destination(request, uri) do
    case Enum.find(request.policy.destinations, &Destination.matches?(&1, uri)) do
      %Destination{} = destination -> {:ok, destination}
      nil -> {:deny, :destination_not_approved}
    end
  end

  defp policy_limits(request, destination) do
    policy = request.policy

    allowed? =
      request.method in policy.methods and request.integrity in policy.allowed_integrity and
        request.confidentiality in policy.allowed_confidentiality and
        request.request_bytes <= policy.maximum_request_bytes and
        (request.traffic_class == :provider_api or destination.kind == :controlled_mirror)

    if allowed?, do: :ok, else: {:deny, :policy_restriction}
  end

  defp resolver_identity(request, state) do
    with {:ok, identity} <- state.resolver_module.identity(state.resolver),
         name when is_binary(name) <- identity[:name],
         digest when is_binary(digest) <- identity[:digest],
         true <- Regex.match?(~r/^sha256:[a-f0-9]{64}$/, digest),
         true <- identity[:controlled] == true,
         true <- request.policy.resolver_identity == name <> "@" <> digest do
      :ok
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:deny, :uncontrolled_dns}
    end
  end

  defp public_address(addresses) when is_list(addresses) and addresses != [] do
    normalized = Enum.map(addresses, &normalize_address/1)

    if Enum.all?(normalized, &public_address?/1) do
      {:ok, normalized |> Enum.sort() |> hd()}
    else
      {:deny, :non_public_address}
    end
  end

  defp public_address(_addresses), do: {:deny, :uncontrolled_dns}

  defp normalize_address(value) when is_binary(value) do
    case :inet.parse_strict_address(String.to_charlist(value)) do
      {:ok, address} -> address
      _invalid -> :invalid
    end
  end

  defp normalize_address(value) when is_tuple(value), do: value
  defp normalize_address(_value), do: :invalid

  defp public_address?({a, b, c, d})
       when a in 0..255 and b in 0..255 and c in 0..255 and d in 0..255 do
    cond do
      a == 0 -> false
      a == 10 -> false
      a == 100 and b in 64..127 -> false
      a == 127 -> false
      a == 169 and b == 254 -> false
      a == 172 and b in 16..31 -> false
      a == 192 and b == 168 -> false
      a == 192 and b == 0 and c in [0, 2] -> false
      a == 198 and b in [18, 19] -> false
      a == 198 and b == 51 and c == 100 -> false
      a == 203 and b == 0 and c == 113 -> false
      a >= 224 -> false
      true -> true
    end
  end

  defp public_address?({0, 0, 0, 0, 0, 65_535, high, low}),
    do: public_address?({high >>> 8, high &&& 255, low >>> 8, low &&& 255})

  defp public_address?({a, b, c, d, e, f, g, h})
       when a in 0..65_535 and b in 0..65_535 and c in 0..65_535 and d in 0..65_535 and
              e in 0..65_535 and f in 0..65_535 and g in 0..65_535 and h in 0..65_535 do
    cond do
      (a &&& 0xE000) != 0x2000 -> false
      a == 0x2001 and b == 0x0DB8 -> false
      true -> true
    end
  end

  defp public_address?(_address), do: false

  defp consume_rate(request, now, state) do
    policy = request.policy
    now_ms = DateTime.to_unix(now, :millisecond)
    cutoff = now_ms - policy.rate_limit.window_ms

    recent =
      state.rate
      |> Map.get(policy.policy_iri, [])
      |> Enum.filter(&(&1 > cutoff))

    if length(recent) < policy.rate_limit.requests do
      {:ok, put_in(state, [:rate, policy.policy_iri], [now_ms | recent])}
    else
      {:deny, :rate_limit}
    end
  end

  defp endpoint(uri, address, request) do
    %{
      uri: URI.to_string(uri),
      connect_address: address,
      tls_server_name: uri.host,
      port: uri.port || 443,
      maximum_response_bytes: request.policy.maximum_response_bytes,
      redirect_count: request.redirect_count
    }
  end

  defp response(response, request) when is_map(response) do
    with status when is_integer(status) and status in 100..599 <- response[:status],
         bytes
         when is_integer(bytes) and bytes in 0..request.policy.maximum_response_bytes//1 <-
           response[:response_bytes],
         location <- response[:location],
         true <- valid_location?(status, location),
         result when is_map(result) <- response[:result],
         true <- safe_result?(result) do
      {:ok, %{status: status, response_bytes: bytes, location: location, result: result}}
    else
      _invalid -> {:error, AdapterError.new(:corrupt, :egress_transport_response)}
    end
  end

  defp response(_response, _request),
    do: {:error, AdapterError.new(:corrupt, :egress_transport_response)}

  defp valid_location?(_status, nil), do: true

  defp valid_location?(status, location) when status in 300..399 and is_binary(location),
    do: byte_size(location) in 1..2_048

  defp valid_location?(_status, _location), do: false

  defp safe_result?(result) do
    byte_size(:erlang.term_to_binary(result, [:deterministic])) <= 32_768 and
      Enum.all?(result, fn {key, value} -> safe_key?(key) and safe_value?(value) end)
  end

  defp safe_key?(key) when is_atom(key), do: key not in [:body, :headers, :authorization, :cookie]

  defp safe_key?(key) when is_binary(key),
    do: String.downcase(key) not in ~w[body headers authorization cookie]

  defp safe_key?(_key), do: false
  defp safe_value?(value) when is_atom(value) or is_integer(value) or is_boolean(value), do: true
  defp safe_value?(value) when is_binary(value), do: byte_size(value) <= 1_024
  defp safe_value?(_value), do: false

  defp record(state, decision), do: state.audit_module.record(state.audit, decision)

  defp blocked(%Request{traffic_class: :package_registry}, _reason),
    do: AdapterError.new(:unauthorized, :egress_incompatible_build)

  defp blocked(_request, _reason), do: AdapterError.new(:unauthorized, :egress_policy)

  defp port?(module, functions) do
    Code.ensure_loaded?(module) and
      Enum.all?(functions, fn {function, arity} -> function_exported?(module, function, arity) end)
  end

  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
