defmodule JidoCode.Knowledge.RepositoryWiki.DependencyLinksTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.RepositoryWiki.HexMetadata
  alias JidoCode.Knowledge.RepositoryWiki.DependencyLinks
  alias JidoCode.Knowledge.ResourceIdentity

  @retrieved_at ~U[2026-08-27 12:00:00.000000Z]

  test "generates verified Hex destinations and renders unsafe remote values as text only" do
    {node, attributes, metadata_context} = fixture_context()

    fixture = %{
      package: %{
        status: 200,
        body: %{
          "meta" => %{
            "description" => "Demo",
            "links" => %{
              "GitHub" => "https://github.com/example/demo",
              "Credentials" => "https://token@example.org/private",
              "Encoded Credentials" => "https://token%40example.org/private",
              "Internal" => "https://service.internal/admin",
              "Application" => "https://admin.jido.run/privileged",
              "FTP" => "ftp://example.org/archive",
              "Unicode" => "https://exämple.org/lookalike"
            }
          }
        }
      },
      release: %{status: 200, body: %{"version" => "1.2.3"}}
    }

    assert {:ok, metadata} =
             HexMetadata.fetch("demo_pkg", "1.2.3", metadata_context, fixture: fixture)

    assert {:ok, first} = DependencyLinks.build(node, metadata, attributes)
    assert {:ok, second} = DependencyLinks.build(node, metadata, attributes)
    assert first == second
    assert first.clickable_count == 4
    assert first.text_only_count == 6

    assert Enum.any?(first.links, fn link ->
             link.kind == :package and link.destination == "https://hex.pm/packages/demo_pkg" and
               link.verification == :verified
           end)

    assert Enum.any?(first.links, fn link ->
             link.kind == :documentation and
               link.destination == "https://hexdocs.pm/demo_pkg/1.2.3"
           end)

    unsafe = Enum.filter(first.links, &(&1.verification == :text_only))
    assert Enum.all?(unsafe, &is_nil(&1.destination))
    assert Enum.all?(unsafe, &(&1.navigation == :none))

    assert Enum.map(unsafe, & &1.reason) |> Enum.sort() ==
             [
               :credentials,
               :credentials,
               :private_or_ambiguous_host,
               :private_or_ambiguous_host,
               :unsafe_characters,
               :unsafe_scheme
             ]

    tampered = put_in(metadata.facts.summary, "changed after acquisition")

    assert {:error, %{kind: :invalid_input}} =
             DependencyLinks.build(node, tampered, attributes)
  end

  test "links only immutable classified git sources and rejects metadata for another package" do
    {hex_node, attributes, metadata_context} = fixture_context()
    {:ok, git_iri} = ResourceIdentity.deterministic(:wiki_dependency_use, "git-link")

    git_node = %{
      iri: git_iri,
      name: "source_dep",
      scm: "git",
      selected_version: nil,
      lock: nil,
      source: %{
        state: :verified,
        external_link_eligible: true,
        canonical_url: "https://github.com/example/source.git"
      }
    }

    assert {:ok, links} = DependencyLinks.build(git_node, nil, attributes)
    assert [%{kind: :source, verification: :verified, destination: destination}] = links.links
    assert destination == "https://github.com/example/source.git"

    other_fixture = %{
      package: %{status: 200, body: %{"meta" => %{}}},
      release: %{status: 200, body: %{}}
    }

    assert {:ok, other} =
             HexMetadata.fetch("other_pkg", "1.2.3", metadata_context, fixture: other_fixture)

    assert {:error, %{kind: :invalid_input}} =
             DependencyLinks.build(hex_node, other, attributes)
  end

  defp fixture_context do
    {:ok, dependency_iri} = ResourceIdentity.deterministic(:wiki_dependency_use, "hex-link")
    {:ok, edition_iri} = ResourceIdentity.deterministic(:wiki_edition, "links-edition")
    {:ok, repository_iri} = ResourceIdentity.conceptual_repository("links-repository")
    {:ok, tenant_iri} = ResourceIdentity.deterministic(:control_constraint, "links-tenant")

    node = %{
      iri: dependency_iri,
      name: "demo_pkg",
      scm: "hex",
      selected_version: "1.2.3",
      lock: %{package: "demo_pkg", repository: "hexpm"},
      source: %{state: :verified_lock, external_link_eligible: true}
    }

    attributes = %{edition_iri: edition_iri}

    metadata_context = %{
      repository_iri: repository_iri,
      tenant_iri: tenant_iri,
      authorization_class: :public_anonymous,
      retrieved_at: @retrieved_at,
      cache: nil
    }

    {node, attributes, metadata_context}
  end
end
