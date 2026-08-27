defmodule JidoCode.Factory.RepositoryWiki.HexMetadataTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.RepositoryWiki.HexMetadata
  alias JidoCode.Factory.RepositoryWiki.MetadataCache
  alias JidoCode.Knowledge.ResourceIdentity

  @retrieved_at ~U[2026-08-27 12:00:00.000000Z]

  test "replays immutable fixtures, normalizes bounded observed facts, and caches positive entries" do
    cache = start_supervised!({MetadataCache, []})
    context = context(cache, "fixture")

    assert {:ok, first} = HexMetadata.fetch("demo_pkg", "1.2.3", context, fixture: fixture())
    assert first.profile == "hex-req/1.0.0"
    assert HexMetadata.profile().cache_profile == "wiki-metadata-cache/1.0.0"
    assert HexMetadata.profile().cache_profile_digest == MetadataCache.profile().digest
    assert first.state == :available
    assert first.authority == :observed
    assert first.cache_state == :miss
    assert first.fixture_digest
    assert first.facts.summary == "A bounded package summary."
    assert first.facts.licenses == ["Apache-2.0", "MIT"]
    assert first.facts.maintainers == ["maintainer", "owner"]
    assert first.facts.release_date == "2026-08-01T00:00:00Z"
    assert first.facts.checksum == String.duplicate("a", 64)

    assert first.facts.requirements == [
             %{name: "dep", requirement: "~> 2.0", optional: true, app: true}
           ]

    assert first.model_calls == 0
    assert first.model_input_tokens == 0
    assert first.model_output_tokens == 0
    assert first.usage_cost_microunits == 0
    assert MetadataCache.size(cache) == 1

    assert {:ok, cached} = HexMetadata.fetch("demo_pkg", "1.2.3", context, fixture: %{})
    assert cached.cache_state == :fresh
    assert cached.facts == first.facts
  end

  test "uses Req against only the exact package and release routes" do
    test_name = __MODULE__.Success

    Req.Test.stub(test_name, fn conn ->
      assert conn.method == "GET"
      assert List.first(Plug.Conn.get_req_header(conn, "accept")) == "application/json"

      case conn.request_path do
        "/api/packages/demo_pkg" ->
          conn
          |> Plug.Conn.put_resp_header("etag", "package-v1")
          |> Req.Test.json(fixture().package.body)

        "/api/packages/demo_pkg/releases/1.2.3" ->
          conn
          |> Plug.Conn.put_resp_header("etag", "release-v1")
          |> Req.Test.json(fixture().release.body)

        unexpected ->
          flunk("unexpected Hex route: #{unexpected}")
      end
    end)

    assert {:ok, result} =
             HexMetadata.fetch("demo_pkg", "1.2.3", context(nil, "req"), req_test: test_name)

    assert result.state == :available

    assert Enum.map(result.endpoints, & &1.endpoint) == [
             "https://hex.pm/api/packages/demo_pkg",
             "https://hex.pm/api/packages/demo_pkg/releases/1.2.3"
           ]

    assert Enum.map(result.endpoints, & &1.validators.etag) == ["package-v1", "release-v1"]
    refute inspect(result) =~ "A bounded package summary.\"}"
  end

  test "denies redirects and preserves rate limits, malformed JSON, and oversized bodies as gaps" do
    redirect_name = __MODULE__.Redirect

    Req.Test.stub(redirect_name, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("location", "https://example.invalid/redirect")
      |> Plug.Conn.send_resp(302, "redirect denied")
    end)

    assert {:ok, redirected} =
             HexMetadata.fetch("demo_pkg", "1.2.3", context(nil, "redirect"),
               req_test: redirect_name
             )

    assert redirected.state == :unavailable
    assert redirected.reason == :redirect_rejected

    rate_fixture = %{
      package: %{status: 429, headers: %{"retry-after" => "60"}, body: "rate limited"},
      release: %{status: 429, headers: %{"retry-after" => "60"}, body: "rate limited"}
    }

    assert {:ok, rate_limited} =
             HexMetadata.fetch("demo_pkg", "1.2.3", context(nil, "rate"), fixture: rate_fixture)

    assert rate_limited.reason == :rate_limited
    assert Enum.all?(rate_limited.endpoints, &(&1.retry_after == "60"))

    malformed = %{
      package: %{status: 200, body: "{"},
      release: %{status: 200, body: String.duplicate("x", 262_145)}
    }

    assert {:ok, invalid} =
             HexMetadata.fetch("demo_pkg", "1.2.3", context(nil, "invalid"), fixture: malformed)

    assert invalid.state == :unavailable
    assert Enum.map(invalid.endpoints, & &1.reason) == [:malformed_json, :response_too_large]
  end

  test "caches bounded negative observations under the same repository fence" do
    cache = start_supervised!({MetadataCache, []})
    metadata_context = context(cache, "negative")

    not_found = %{
      package: %{status: 404, body: "not found"},
      release: %{status: 404, body: "not found"}
    }

    assert {:ok, first} =
             HexMetadata.fetch("missing_pkg", "1.0.0", metadata_context, fixture: not_found)

    assert first.state == :unavailable
    assert first.cache_state == :miss

    assert {:ok, cached} =
             HexMetadata.fetch("missing_pkg", "1.0.0", metadata_context, fixture: fixture())

    assert cached.state == :unavailable
    assert cached.cache_state == :fresh
    assert cached.reason == :not_found
    assert MetadataCache.size(cache) == 1
  end

  test "serves stale positive metadata after a transport failure and fences cache keys by repository" do
    cache = start_supervised!({MetadataCache, []})
    first_context = context(cache, "first")

    assert {:ok, original} =
             HexMetadata.fetch("demo_pkg", "1.2.3", first_context, fixture: fixture())

    unavailable_name = __MODULE__.Unavailable
    Req.Test.stub(unavailable_name, &Req.Test.transport_error(&1, :timeout))
    stale_context = %{first_context | retrieved_at: DateTime.add(@retrieved_at, 86_401, :second)}

    assert {:ok, stale} =
             HexMetadata.fetch("demo_pkg", "1.2.3", stale_context, req_test: unavailable_name)

    assert stale.cache_state == :stale
    assert stale.refresh_failure == :transport_unavailable
    assert stale.facts == original.facts

    second_context = context(cache, "second")

    assert {:ok, second} =
             HexMetadata.fetch("demo_pkg", "1.2.3", second_context, fixture: fixture())

    assert second.cache_state == :miss
    assert MetadataCache.size(cache) == 2
  end

  defp context(cache, suffix) do
    {:ok, repository_iri} = ResourceIdentity.conceptual_repository("hex-metadata-#{suffix}")
    {:ok, tenant_iri} = ResourceIdentity.deterministic(:control_constraint, "hex-tenant")

    %{
      repository_iri: repository_iri,
      tenant_iri: tenant_iri,
      authorization_class: :public_anonymous,
      retrieved_at: @retrieved_at,
      cache: cache
    }
  end

  defp fixture do
    %{
      package: %{
        status: 200,
        headers: %{"etag" => "package-fixture"},
        body: %{
          "name" => "demo_pkg",
          "meta" => %{
            "description" => "A bounded package summary.",
            "licenses" => ["MIT", "Apache-2.0"],
            "maintainers" => ["maintainer"],
            "links" => %{
              "GitHub" => "https://github.com/example/demo",
              "Home" => "https://example.org/demo"
            }
          },
          "owners" => [%{"username" => "owner", "email" => "not-retained@example.org"}]
        }
      },
      release: %{
        status: 200,
        headers: %{"etag" => "release-fixture"},
        body: %{
          "version" => "1.2.3",
          "checksum" => String.duplicate("a", 64),
          "inserted_at" => "2026-08-01T00:00:00Z",
          "retirement" => nil,
          "requirements" => %{
            "dep" => %{"requirement" => "~> 2.0", "optional" => true, "app" => true}
          }
        }
      }
    }
  end
end
