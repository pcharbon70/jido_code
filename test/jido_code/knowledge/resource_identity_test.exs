defmodule JidoCode.Knowledge.ResourceIdentityTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  test "canonicalizes natural provider, locator, Git, and content identities" do
    assert {:ok, "https://jido.run/id/provider/github.com"} =
             ResourceIdentity.provider_host("HTTPS://GitHub.COM/")

    assert {:ok, locator} =
             ResourceIdentity.repository_locator("github.com:443", "Agent Jido", "jido_code.git")

    assert locator.canonical == "github.com/Agent Jido/jido_code"

    assert locator.iri ==
             "https://jido.run/id/repository-locator/github.com/Agent%20Jido/jido_code"

    assert {:ok, repository_a} = ResourceIdentity.repository("github-node-id:R_123")
    assert {:ok, repository_b} = ResourceIdentity.repository("github-node-id:R_123")
    assert repository_a == repository_b
    refute repository_a == locator.iri

    sha1 = String.duplicate("A", 40)
    assert {:ok, git} = ResourceIdentity.git_object(:sha1, sha1)
    assert String.ends_with?(git, "/sha1/#{String.downcase(sha1)}")

    sha256 = String.duplicate("b", 64)
    assert {:ok, content} = ResourceIdentity.content_digest("sha256", sha256)
    assert String.ends_with?(content, "/sha256/#{sha256}")
  end

  test "constructs opaque time-sortable local IRIs through deterministic ports" do
    entropy = <<0, 1, 2, 3, 4, 5, 6, 7, 8, 9>>

    assert {:ok, first} = ResourceIdentity.local(:claim, 1_000, entropy)
    assert {:ok, second} = ResourceIdentity.local(:claim, 1_001, entropy)
    assert first < second

    assert {:ok, generated} =
             ResourceIdentity.generate_local(:claim,
               clock: fn -> 1_000 end,
               random: fn 10 -> entropy end
             )

    assert generated == first
    assert :ok = ResourceIdentity.validate(first)
  end

  test "rejects ambiguous, oversized, non-normalized, and literal relationship identities" do
    assert {:error, %Error{operation: :provider_identity}} =
             ResourceIdentity.provider_host("https://user@example.com/path")

    assert {:error, %Error{operation: :identity_segment}} =
             ResourceIdentity.scope(:path, "../escape")

    assert {:error, %Error{operation: :digest_value}} =
             ResourceIdentity.git_object(:sha1, "abc")

    assert {:error, %Error{operation: :resource_identity}} =
             ResourceIdentity.validate("https://jido.run/id/claim/e\u0301")

    assert {:error, %Error{operation: :resource_relationship}} =
             ResourceIdentity.validate_relationship({
               "https://jido.run/id/claim/0000000003e800010203040506070809",
               "https://jido.run/ontology/factory#supports",
               "display-id"
             })
  end
end
