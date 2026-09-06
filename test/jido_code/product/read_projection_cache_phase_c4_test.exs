defmodule JidoCode.Product.ReadProjectionCachePhaseC4Test do
  use ExUnit.Case, async: true

  alias JidoCode.Identity.AuthorizationResult
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Health
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Product.GraphReadProjectionProvider
  alias JidoCode.Product.ReadProjection
  alias JidoCode.Product.ReadProjectionCache
  alias JidoCode.Product.ReadProjectionTelemetry
  alias JidoCode.TestSupport.HypermediaUIPhaseC4Fixture

  test "normalizes every documented source outcome across every read surface" do
    surfaces = [
      :factory,
      :fleet,
      :projects,
      :project,
      :project_attempts,
      :project_wiki,
      :project_dependencies,
      :attempt
    ]

    outcomes = %{
      ready: :ready,
      empty: :empty,
      stale: :stale,
      partial: :incomplete,
      truncated: :truncated,
      contradiction: :contradicted,
      denied: :unauthorized,
      concealed: :unauthorized,
      unavailable: :unavailable,
      unconfigured: :unavailable,
      loading: :unavailable,
      error: :unavailable,
      maintenance: :maintenance,
      recovery: :recovery
    }

    for surface <- surfaces, {outcome, expected_state} <- outcomes do
      projection = ReadProjection.unavailable(surface, outcome)
      assert projection.state == expected_state

      if expected_state in [:unauthorized, :unavailable, :maintenance, :recovery] do
        assert projection.attention == []
        assert projection.fleet == []
        assert projection.projects == []
        assert projection.project == nil
        assert projection.attempts == []
        assert projection.attempt == nil
        assert projection.summaries == %{}
      end
    end
  end

  test "keys exact principal, session generations, scope, grants, revisions, and closed intent" do
    base = context()
    assert {:ok, key} = ReadProjectionCache.key(base)
    assert byte_size(key) == 64

    variants = [
      put_in(base, [:current_scope, :principal_iri], "https://jido.run/id/human/other"),
      %{base | session_ref: "session-other"},
      update_in(base, [:current_scope, :session_generation], &(&1 + 1)),
      update_in(base, [:current_scope, :account_generation], &(&1 + 1)),
      put_in(base, [:current_scope, :resource_ref], "resource-other"),
      put_in(base, [:authorization, Access.key!(:exact_grant_ref)], "grant-other"),
      put_in(base, [:authorization, Access.key!(:delegation_ref)], "delegation-other"),
      put_in(base, [:authorization, Access.key!(:graph_revisions)], %{"graph" => 9}),
      put_in(base, [:page, :query], %{"state" => "blocked"})
    ]

    variant_keys =
      Enum.map(variants, fn variant ->
        {:ok, variant_key} = ReadProjectionCache.key(variant)
        variant_key
      end)

    assert Enum.uniq([key | variant_keys]) |> length() == length(variants) + 1
    refute key =~ "session"
    assert {:error, :invalid_cache_context} = ReadProjectionCache.key(%{page: %{key: :factory}})
  end

  test "bounds freshness, stale retention, capacity, and protected-state insertion" do
    cache =
      start_supervised!(
        {ReadProjectionCache, name: nil, fresh_ttl_ms: 10, retention_ms: 20, max_entries: 2}
      )

    projection = HypermediaUIPhaseC4Fixture.projection(:factory)

    :ok = ReadProjectionCache.put(cache, "first", projection, 100)
    assert {:fresh, ^projection} = ReadProjectionCache.fetch(cache, "first", 110)
    assert {:stale, ^projection} = ReadProjectionCache.fetch(cache, "first", 111)
    assert :miss = ReadProjectionCache.fetch(cache, "first", 121)

    :ok = ReadProjectionCache.put(cache, "first", projection, 200)
    :ok = ReadProjectionCache.put(cache, "second", projection, 200)
    :ok = ReadProjectionCache.put(cache, "third", projection, 200)
    assert ReadProjectionCache.size(cache) == 2
    assert :miss = ReadProjectionCache.fetch(cache, "first", 200)

    denied = ReadProjection.unavailable(:factory, :denied)
    :ok = ReadProjectionCache.put(cache, "denied", denied, 200)
    assert :miss = ReadProjectionCache.fetch(cache, "denied", 200)
  end

  test "reauthorizes cache hits, refreshes stale entries, and clears on revocation or errors" do
    test_pid = self()

    cache =
      start_supervised!(
        {ReadProjectionCache, name: nil, fresh_ttl_ms: 10, retention_ms: 50, max_entries: 10}
      )

    control = start_supervised!({Agent, fn -> %{authorization: :allowed, query: :ok} end})

    authorize = fn _context, _operation, _area, _action, point, _resource_ref ->
      send(test_pid, {:authorization_check, point})

      case Agent.get(control, & &1.authorization) do
        :allowed -> {:ok, authorization_view()}
        outcome -> {:error, outcome}
      end
    end

    query = fn name, _version, parameters, _authority, _scope, _options ->
      send(test_pid, {:query, name})

      case Agent.get(control, & &1.query) do
        :ok -> {:ok, result(name, [], parameters)}
        :error -> {:error, Error.new(:unavailable, :hui_c4_cache_refresh)}
      end
    end

    options = [
      authorize: authorize,
      resources: fn :project, 100 -> {:ok, []} end,
      query: query,
      health: ready_health(),
      cache_server: cache
    ]

    assert {:ok, first} =
             GraphReadProjectionProvider.load(
               context(),
               Keyword.put(options, :cache_clock, fn -> 100 end)
             )

    assert first.state == :empty
    assert first.cache.status == :miss
    assert_receive {:query, :factory_repository_cohort}

    assert {:ok, hit} =
             GraphReadProjectionProvider.load(
               context(),
               Keyword.put(options, :cache_clock, fn -> 105 end)
             )

    assert hit.cache.status == :hit
    assert_receive {:authorization_check, :before_field_shaping}
    refute_receive {:query, :factory_repository_cohort}

    assert {:ok, refreshed} =
             GraphReadProjectionProvider.load(
               context(),
               Keyword.put(options, :cache_clock, fn -> 111 end)
             )

    assert refreshed.cache.status == :refresh
    assert_receive {:query, :factory_repository_cohort}

    Agent.update(control, &%{&1 | authorization: :revoked})

    assert {:ok, revoked} =
             GraphReadProjectionProvider.load(
               context(),
               Keyword.put(options, :cache_clock, fn -> 115 end)
             )

    assert revoked.state == :unauthorized
    assert revoked.fleet == []
    assert revoked.summaries == %{}
    assert revoked.cache.status == :invalidated

    Agent.update(control, &%{&1 | authorization: :allowed, query: :error})

    assert {:ok, unavailable} =
             GraphReadProjectionProvider.load(
               context(),
               Keyword.put(options, :cache_clock, fn -> 116 end)
             )

    assert unavailable.state == :unavailable
    assert unavailable.fleet == []
    assert unavailable.cache.status == :invalidated
    assert_receive {:query, :factory_repository_cohort}
  end

  test "emits only bounded projection measurements and closed metadata" do
    handler = "phase-c4-read-telemetry-#{System.unique_integer([:positive])}"
    test_pid = self()

    :ok =
      :telemetry.attach(
        handler,
        ReadProjectionTelemetry.event(),
        fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)

    projection =
      HypermediaUIPhaseC4Fixture.projection(:factory, %{
        fleet: [HypermediaUIPhaseC4Fixture.fleet_row("alpha", "/projects/alpha")],
        truncated?: true,
        cache: %{status: :hit}
      })

    assert :ok = ReadProjectionTelemetry.emit(12, :factory, {:ok, projection})

    assert_receive {:telemetry, [:jido_code, :product, :read_projection], measurements, metadata}

    assert measurements == %{
             duration_ms: 12,
             row_count: 1,
             truncated_count: 1,
             cache_hit_count: 1
           }

    assert metadata == %{
             surface: :factory,
             outcome: :ok,
             state: :ready,
             cache_status: :hit,
             query_version: "2.11.0"
           }

    refute Map.has_key?(metadata, :principal)
    refute Map.has_key?(metadata, :scope)
    refute Map.has_key?(metadata, :query)
  end

  defp context do
    scope = %{
      iri: "https://jido.run/id/scope/factory/default",
      principal_iri: "https://jido.run/id/human/phase-c4",
      subject_ref: "human_phase_c4",
      tenant_ref: "tenant_phase_c4",
      project_ref: nil,
      resource_ref: "factory_phase_c4",
      resource_kind: :factory,
      resource_revision: 3,
      session_generation: 4,
      account_generation: 5,
      revocation_generations: %{account: 5, session: 4}
    }

    authorization = %AuthorizationResult{
      decision: :allowed,
      safe_reason: :authorized,
      current_scope: scope,
      product_identity: product_identity(),
      authority_context: authority(),
      membership_explanations: [],
      exact_grant_ref: "grant-phase-c4",
      delegation_ref: nil,
      obligations: [:named_human],
      policy_revision: "policy-phase-c4",
      graph_revisions: %{"factory" => 3},
      audit_correlation_ref: "audit-phase-c4",
      concealment: :reveal,
      redaction: :none
    }

    %{
      session_ref: "session-phase-c4",
      current_scope: scope,
      authorization: authorization,
      page: %{
        key: :factory,
        route_params: %{},
        query: %{},
        canonical_url: "https://example.test/factory"
      }
    }
  end

  defp authorization_view do
    %{
      decision: :allowed,
      product_identity: product_identity(),
      authority_context: authority()
    }
  end

  defp product_identity do
    %{
      factory_iri: "https://jido.run/id/repository-factory/default",
      factory_scope_iri: "https://jido.run/id/scope/factory/default"
    }
  end

  defp authority do
    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: "https://jido.run/id/human/phase-c4",
        actor_iri: "https://jido.run/id/human/phase-c4",
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    authority
  end

  defp result(name, data, parameters) do
    %QueryResult{
      query_name: name,
      query_version: "2.11.0",
      scope_iri: "https://jido.run/id/scope/factory/default",
      dataset_revision: 77,
      graph_revisions: %{parameters.graph => 3},
      ontology_version: "1.5.0",
      completeness: %{complete?: true},
      freshness: :current,
      truncated?: false,
      cursor: nil,
      warnings: [],
      execution_class: :product,
      consistency: %{status: :current},
      evaluated_at: ~U[2026-09-06 12:00:00Z],
      data: data
    }
  end

  defp ready_health do
    %Health{state: :ready, store_verified?: true, ontology_verified?: true}
  end
end
