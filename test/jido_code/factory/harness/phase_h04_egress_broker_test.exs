defmodule JidoCode.Factory.Harness.PhaseH04EgressBrokerTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Egress.Destination
  alias JidoCode.Factory.Egress.Policy
  alias JidoCode.Factory.Egress.Request
  alias JidoCode.Factory.EgressBroker
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeEgressAudit
  alias JidoCode.TestSupport.FakeEgressResolver
  alias JidoCode.TestSupport.FakeEgressTransport

  @resolver_name "JidoCode.TestSupport.FakeEgressResolver"
  @resolver_digest "sha256:" <> String.duplicate("e", 64)

  test "approved HTTPS egress is audited before a DNS-pinned transport call" do
    {broker, request, current} = broker_fixture()

    assert {:ok, result} = EgressBroker.request(broker, request, current, "hello")
    assert result.status == 200
    assert result.response_bytes == 17
    assert [%{outcome: :allowed, reason: :policy_match}] = result.decisions

    assert_received {:egress_resolve, "api.github.com"}
    assert_received {:egress_audit, decision}
    assert decision.outcome == :allowed
    refute inspect(decision) =~ "token=not-a-secret"

    assert_received {:egress_transport, ^request, endpoint, "hello"}
    assert endpoint.connect_address == {93, 184, 216, 34}
    assert endpoint.tls_server_name == "api.github.com"
    assert endpoint.uri == "https://api.github.com/repos/example?token=not-a-secret"
  end

  test "destination, method, both classification axes, and byte limits deny before transport" do
    {broker, request, current} = broker_fixture()

    mutations = [
      %{request | uri: "https://evil.example/repos/example"},
      %{request | method: :delete},
      %{request | integrity: :untrusted},
      %{request | confidentiality: :restricted},
      %{request | request_bytes: request.policy.maximum_request_bytes + 1}
    ]

    for denied <- mutations do
      body = :binary.copy("x", denied.request_bytes)

      assert {:error, %AdapterError{operation: :egress_policy}} =
               EgressBroker.request(broker, denied, current, body)

      assert_received {:egress_audit, %{outcome: :denied}}
      refute_received {:egress_transport, _request, _endpoint, _body}
    end

    assert {:error, %AdapterError{operation: :egress_default_deny}} =
             EgressBroker.request(broker, nil, current, "")
  end

  test "unsafe schemes, URL authority tricks, and private or metadata addresses fail closed" do
    for {uri, addresses, expected_reason} <- [
          {"http://api.github.com/repos/example", [{93, 184, 216, 34}], :unsafe_url},
          {"https://user@api.github.com/repos/example", [{93, 184, 216, 34}], :unsafe_url},
          {"https://api.github.com/repos/%2e%2e/admin", [{93, 184, 216, 34}], :unsafe_url},
          {"https://api.github.com/repos/example", [{127, 0, 0, 1}], :non_public_address},
          {"https://api.github.com/repos/example", [{10, 0, 0, 1}], :non_public_address},
          {"https://api.github.com/repos/example", [{172, 16, 1, 1}], :non_public_address},
          {"https://api.github.com/repos/example", [{192, 168, 1, 1}], :non_public_address},
          {"https://api.github.com/repos/example", [{169, 254, 169, 254}], :non_public_address},
          {"https://api.github.com/repos/example", [{0, 0, 0, 0, 0, 0, 0, 1}],
           :non_public_address},
          {"https://api.github.com/repos/example", [{0xFE80, 0, 0, 0, 0, 0, 0, 1}],
           :non_public_address}
        ] do
      {broker, request, current} =
        broker_fixture(uri: uri, resolve: fn _host -> {:ok, addresses} end)

      assert {:error, %AdapterError{operation: :egress_policy}} =
               EgressBroker.request(broker, request, current, "hello")

      assert_received {:egress_audit, %{outcome: :denied, reason: ^expected_reason}}
      refute_received {:egress_transport, _request, _endpoint, _body}
    end
  end

  test "uncontrolled DNS identity denies without resolution" do
    identity = resolver_identity() |> Map.put(:digest, "sha256:" <> String.duplicate("f", 64))
    {broker, request, current} = broker_fixture(resolver_identity: identity)

    assert {:error, %AdapterError{operation: :egress_policy}} =
             EgressBroker.request(broker, request, current, "hello")

    assert_received {:egress_audit, %{outcome: :denied, reason: :uncontrolled_dns}}
    refute_received {:egress_resolve, _host}
    refute_received {:egress_transport, _request, _endpoint, _body}
  end

  test "audit failure is fail-closed and consumes the rate slot before any transport" do
    policy = policy!(rate_limit: %{requests: 1, window_ms: 60_000})
    request = request!(policy)

    broker =
      start_broker(audit_result: {:error, AdapterError.new(:unavailable, :egress_audit_write)})

    assert {:error, %AdapterError{operation: :egress_audit_write}} =
             EgressBroker.request(broker, request, current(policy), "hello")

    refute_received {:egress_transport, _request, _endpoint, _body}

    assert {:error, %AdapterError{operation: :egress_audit_write}} =
             EgressBroker.request(broker, request, current(policy), "hello")

    refute_received {:egress_transport, _request, _endpoint, _body}
  end

  test "package traffic requires an explicitly controlled mirror and fails visibly otherwise" do
    {broker, request, current} = broker_fixture()
    package_request = %{request | traffic_class: :package_registry}

    assert {:error, %AdapterError{operation: :egress_incompatible_build}} =
             EgressBroker.request(broker, package_request, current, "hello")

    refute_received {:egress_transport, _request, _endpoint, _body}

    mirror = destination!("hex.internal.example", "/packages", :controlled_mirror)
    policy = policy!(destinations: [mirror])

    package_request =
      request!(policy,
        uri: "https://hex.internal.example/packages/registry.ets.gz",
        traffic_class: :package_registry
      )

    broker = start_broker(resolve: fn _host -> {:ok, [{93, 184, 216, 35}]} end)

    assert {:ok, %{status: 200}} =
             EgressBroker.request(broker, package_request, current(policy), "hello")
  end

  test "redirects are reauthorized and DNS rebinding to a private destination is blocked" do
    redirect = destination!("uploads.github.com", "/objects", :approved_api)
    policy = policy!(destinations: [default_destination(), redirect], maximum_redirects: 1)
    request = request!(policy)

    resolve = fn
      "api.github.com" -> {:ok, [{93, 184, 216, 34}]}
      "uploads.github.com" -> {:ok, [{169, 254, 169, 254}]}
    end

    transport = fn sent_request, _endpoint, _body ->
      if sent_request.redirect_count == 0 do
        response(status: 302, location: "https://uploads.github.com/objects/candidate")
      else
        response()
      end
    end

    broker = start_broker(resolve: resolve, transport: transport)

    assert {:error, %AdapterError{operation: :egress_policy}} =
             EgressBroker.request(broker, request, current(policy), "hello")

    assert_received {:egress_transport, %{redirect_count: 0}, _endpoint, "hello"}
    refute_received {:egress_transport, %{redirect_count: 1}, _endpoint, _body}
    assert_received {:egress_audit, %{outcome: :denied, reason: :non_public_address}}

    unapproved = fn _request, _endpoint, _body ->
      response(status: 302, location: "https://evil.example/collect")
    end

    broker = start_broker(transport: unapproved)

    assert {:error, %AdapterError{operation: :egress_policy}} =
             EgressBroker.request(broker, request!(policy), current(policy), "hello")

    assert_received {:egress_audit, %{outcome: :denied, reason: :destination_not_approved}}
    refute_received {:egress_resolve, "evil.example"}
  end

  test "redirect limits and per-policy request rates are hard ceilings" do
    policy = policy!(maximum_redirects: 0, rate_limit: %{requests: 2, window_ms: 60_000})
    request = request!(policy)

    redirecting = fn _request, _endpoint, _body ->
      response(status: 302, location: "https://api.github.com/repos/other")
    end

    redirect_broker = start_broker(transport: redirecting)

    assert {:error, %AdapterError{operation: :egress_policy}} =
             EgressBroker.request(redirect_broker, request, current(policy), "hello")

    assert_received {:egress_audit, %{outcome: :denied, reason: :redirect_limit}}

    rate_broker = start_broker()
    assert {:ok, _result} = EgressBroker.request(rate_broker, request, current(policy), "hello")
    assert {:ok, _result} = EgressBroker.request(rate_broker, request, current(policy), "hello")

    assert {:error, %AdapterError{operation: :egress_policy}} =
             EgressBroker.request(rate_broker, request, current(policy), "hello")

    assert_received {:egress_audit, %{outcome: :denied, reason: :rate_limit}}
  end

  test "expired, revoked, stale revision, lease, invocation, and fence authority never resolve" do
    {_broker, request, current} = broker_fixture()

    mutations = [
      &Map.put(&1, :lease_state, :revoked),
      &Map.put(&1, :attempt_iri, resource!(:execution_attempt, "other-attempt")),
      &Map.put(&1, :invocation_iri, resource!(:tool_invocation, "other-invocation")),
      &Map.put(&1, :lease_iri, resource!(:execution_lease, "other-lease")),
      &Map.update!(&1, :fencing_token, fn value -> value + 1 end),
      &Map.update!(&1, :profile_revision, fn value -> value + 1 end),
      &Map.update!(&1, :egress_revision, fn value -> value + 1 end),
      &Map.update!(&1, :revocation_generation, fn value -> value + 1 end)
    ]

    for mutate <- mutations do
      broker = start_broker()

      assert {:error, %AdapterError{operation: :egress_policy}} =
               EgressBroker.request(broker, request, mutate.(current), "hello")

      refute_received {:egress_resolve, _host}
    end

    expired_at = DateTime.add(request.policy.expires_at, 1, :second)
    broker = start_broker(clock: fn -> expired_at end)

    assert {:error, %AdapterError{operation: :egress_policy}} =
             EgressBroker.request(broker, request, current, "hello")

    refute_received {:egress_resolve, _host}
  end

  test "invalid or duplicate policy destinations and non-HTTPS destinations are rejected" do
    assert {:error, %AdapterError{operation: :egress_destination}} =
             Destination.new(%{
               scheme: "http",
               host: "registry.example",
               port: 443,
               path_prefix: "/",
               kind: :controlled_mirror
             })

    destination = default_destination()

    assert {:error, %AdapterError{operation: :egress_policy}} =
             Policy.new(Map.put(policy_attributes(), :destinations, [destination, destination]))
  end

  defp broker_fixture(options \\ []) do
    policy = policy!()
    request = request!(policy, uri: Keyword.get(options, :uri, default_uri()))
    {start_broker(options), request, current(policy)}
  end

  defp start_broker(options \\ []) do
    resolver = %{
      owner: self(),
      identity: Keyword.get(options, :resolver_identity, resolver_identity()),
      resolve: Keyword.get(options, :resolve, fn _host -> {:ok, [{93, 184, 216, 34}]} end)
    }

    transport = %{
      owner: self(),
      request: Keyword.get(options, :transport, fn _request, _endpoint, _body -> response() end)
    }

    audit = %{owner: self(), result: Keyword.get(options, :audit_result, :ok)}

    start_supervised!(
      {EgressBroker,
       [
         resolver: {FakeEgressResolver, resolver},
         transport: {FakeEgressTransport, transport},
         audit: {FakeEgressAudit, audit},
         clock: Keyword.get(options, :clock, fn -> DateTime.utc_now() end)
       ]},
      id: {:egress_broker, System.unique_integer([:positive, :monotonic])}
    )
  end

  defp policy!(overrides \\ []) do
    attributes = Enum.into(overrides, policy_attributes())
    assert {:ok, policy} = Policy.new(attributes)
    policy
  end

  defp policy_attributes do
    %{
      policy_iri: resource!("policy"),
      attempt_iri: resource!(:execution_attempt, "attempt"),
      invocation_iri: resource!(:tool_invocation, "invocation"),
      lease_iri: resource!(:execution_lease, "lease"),
      fencing_token: 404,
      profile_revision: 7,
      egress_revision: 5,
      revocation_generation: 2,
      destinations: [default_destination()],
      methods: [:get, :post],
      allowed_integrity: [:verified, :trusted],
      allowed_confidentiality: [:public, :internal],
      maximum_request_bytes: 32,
      maximum_response_bytes: 1_024,
      maximum_redirects: 2,
      rate_limit: %{requests: 10, window_ms: 60_000},
      resolver_identity: @resolver_name <> "@" <> @resolver_digest,
      expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
    }
  end

  defp request!(policy, overrides \\ []) do
    attributes =
      Enum.into(overrides, %{
        uri: default_uri(),
        method: :post,
        traffic_class: :provider_api,
        integrity: :verified,
        confidentiality: :internal,
        request_bytes: 5,
        redirect_count: 0
      })

    assert {:ok, request} = Request.new(policy, attributes)
    request
  end

  defp default_destination, do: destination!("api.github.com", "/repos", :approved_api)

  defp destination!(host, path, kind) do
    assert {:ok, destination} =
             Destination.new(%{
               scheme: "https",
               host: host,
               port: 443,
               path_prefix: path,
               kind: kind
             })

    destination
  end

  defp default_uri, do: "https://api.github.com/repos/example?token=not-a-secret"

  defp response(overrides \\ []) do
    {:ok,
     Enum.into(overrides, %{
       status: 200,
       response_bytes: 17,
       location: nil,
       result: %{outcome: :accepted, provider_ref: "provider-operation-1"}
     })}
  end

  defp resolver_identity do
    %{name: @resolver_name, digest: @resolver_digest, controlled: true}
  end

  defp current(policy) do
    %{
      lease_state: :active,
      attempt_iri: policy.attempt_iri,
      invocation_iri: policy.invocation_iri,
      lease_iri: policy.lease_iri,
      fencing_token: policy.fencing_token,
      profile_revision: policy.profile_revision,
      egress_revision: policy.egress_revision,
      revocation_generation: policy.revocation_generation
    }
  end

  defp resource!(seed), do: resource!(:knowledge_assertion, seed)

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h04-egress-#{seed}")
    iri
  end
end
