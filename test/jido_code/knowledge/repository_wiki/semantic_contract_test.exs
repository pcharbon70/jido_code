defmodule JidoCode.Knowledge.RepositoryWiki.SemanticContractTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.SemanticContract
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-26 12:00:00Z]
  @digest String.duplicate("a", 64)

  setup do
    {:ok, repository} = ResourceIdentity.repository("wiki-shape-repository")
    {:ok, other_repository} = ResourceIdentity.repository("wiki-shape-other")
    {:ok, tenant} = ResourceIdentity.scope(:organization, "wiki-shape-tenant")
    {:ok, wiki} = ResourceIdentity.repository_wiki(repository)
    {:ok, profile} = ResourceIdentity.deterministic(:wiki_generation_profile, "manual")
    {:ok, enrollment} = ResourceIdentity.deterministic(:repository_wiki_enrollment, repository)
    {:ok, source} = ResourceIdentity.deterministic(:repository_snapshot, "wiki-shape-source")
    {:ok, attempt} = ResourceIdentity.deterministic(:wiki_compilation_attempt, "attempt")

    %{
      repository: repository,
      other_repository: other_repository,
      tenant: tenant,
      wiki: wiki,
      profile: profile,
      enrollment: enrollment,
      source: source,
      attempt: attempt
    }
  end

  test "accepts only closed deterministic generation profiles", ids do
    attributes = profile(ids)
    assert :ok = SemanticContract.validate(:generation_profile, attributes)

    assert {:error, %Error{operation: :wiki_closed_shape}} =
             SemanticContract.validate(:generation_profile, Map.put(attributes, :model, "other"))

    assert {:error, %Error{operation: :wiki_generation_profile_shape}} =
             SemanticContract.validate(
               :generation_profile,
               %{attributes | profile_key: :caller_selected, generation_mode: :synthesis_allowed}
             )
  end

  test "requires profiles for enabled enrollment and forbids them when off", ids do
    manual = enrollment(ids, :manual, ids.profile)
    assert :ok = SemanticContract.validate(:enrollment, manual)

    assert {:error, %Error{operation: :wiki_missing_profile}} =
             SemanticContract.validate(
               :enrollment,
               Map.delete(manual, :generation_profile_iri)
             )

    assert {:error, %Error{operation: :wiki_off_profile}} =
             SemanticContract.validate(:enrollment, %{manual | state: :off})

    assert :ok =
             SemanticContract.validate(
               :enrollment,
               manual |> Map.put(:state, :off) |> Map.delete(:generation_profile_iri)
             )
  end

  test "rejects cross-repository resources and multiple current editions", ids do
    first = edition(ids, @digest, true)
    second = edition(ids, String.duplicate("b", 64), true)

    assert {:error, %Error{operation: :wiki_multiple_current_editions}} =
             SemanticContract.validate_dataset(edition: first, edition: second)

    other_ids =
      ids
      |> Map.put(:repository, ids.other_repository)
      |> Map.put(:wiki, ResourceIdentity.repository_wiki(ids.other_repository) |> elem(1))

    other = edition(other_ids, String.duplicate("c", 64), false)

    assert {:error, %Error{operation: :wiki_cross_repository}} =
             SemanticContract.validate_dataset(edition: first, edition: other)
  end

  test "requires page source provenance and makes finalized editions append-immutable", ids do
    edition = edition(ids, @digest, false)
    {:ok, page_iri} = ResourceIdentity.wiki_page(edition.edition_iri, :home, "home")

    page = %{
      page_iri: page_iri,
      repository_iri: ids.repository,
      tenant_iri: ids.tenant,
      edition_iri: edition.edition_iri,
      kind: :home,
      stable_key: "home",
      title: "Repository home",
      slug: "home",
      content_digest: @digest,
      source_iris: [ids.source]
    }

    assert :ok = SemanticContract.validate(:page, page)

    assert {:error, %Error{operation: :wiki_page_shape}} =
             SemanticContract.validate(:page, %{page | source_iris: []})

    assert SemanticContract.write_allowed?(:building, :append)
    assert SemanticContract.write_allowed?(:building, :finalize)
    refute SemanticContract.write_allowed?(:finalized, :append)
    refute SemanticContract.write_allowed?(:closed, :append)
    refute SemanticContract.write_allowed?(:invalidated, :close)
  end

  test "requires terminal complete zero-token accounting for deterministic attempts", ids do
    {:ok, usage} = ResourceIdentity.deterministic(:wiki_usage_record, "usage")

    attributes = %{
      usage_iri: usage,
      repository_iri: ids.repository,
      tenant_iri: ids.tenant,
      attempt_iri: ids.attempt,
      generation_mode: :deterministic_only,
      accounting_state: :success,
      input_tokens: 0,
      output_tokens: 0,
      cached_tokens: 0,
      reasoning_tokens: 0,
      cost_microunits: 0,
      currency: "USD",
      recorded_at: @now
    }

    assert :ok = SemanticContract.validate(:usage_record, attributes)

    assert {:error, %Error{operation: :wiki_usage_shape}} =
             SemanticContract.validate(:usage_record, %{attributes | input_tokens: 1})

    assert {:error, %Error{operation: :wiki_usage_shape}} =
             SemanticContract.validate(:usage_record, %{
               attributes
               | accounting_state: :reserved
             })
  end

  defp profile(ids) do
    %{
      profile_iri: ids.profile,
      profile_key: :manual_deterministic,
      revision: 1,
      digest: @digest,
      generation_mode: :deterministic_only,
      compiler_profile: "wiki-deterministic-elixir/1.0.0",
      compiler_digest: @digest,
      enabled?: true,
      approved_at: @now
    }
  end

  defp enrollment(ids, state, profile) do
    %{
      enrollment_iri: ids.enrollment,
      repository_iri: ids.repository,
      tenant_iri: ids.tenant,
      wiki_iri: ids.wiki,
      revision: 1,
      state: state,
      generation_mode: :deterministic_only,
      preview_mode: :disabled,
      retention_class: :current,
      generation_profile_iri: profile,
      recorded_at: @now
    }
  end

  defp edition(ids, root, current?) do
    {:ok, edition_iri} = ResourceIdentity.wiki_edition(ids.repository, root)

    {:ok, graph_iri} =
      GraphRegistry.graph_iri(:repository_wiki, %{
        repository: ids.repository,
        edition: edition_iri
      })

    %{
      edition_iri: edition_iri,
      repository_iri: ids.repository,
      tenant_iri: ids.tenant,
      wiki_iri: ids.wiki,
      graph_iri: graph_iri,
      source_snapshot_iri: ids.source,
      source_fence: "source-fence-1",
      compiler_profile: "wiki-deterministic-elixir/1.0.0",
      compiler_digest: @digest,
      input_manifest_digest: @digest,
      edition_root: root,
      purpose: :current,
      state: :building,
      completeness: :building,
      freshness: :current,
      retention_class: :current,
      current?: current?,
      page_count: 0,
      segment_count: 0,
      statement_count: 0,
      content_bytes: 0,
      created_at: @now
    }
  end
end
