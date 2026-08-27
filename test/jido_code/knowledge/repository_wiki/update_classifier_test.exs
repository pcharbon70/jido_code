defmodule JidoCode.Knowledge.RepositoryWiki.UpdateClassifierTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.UpdateClassifier
  alias JidoCode.Knowledge.ResourceIdentity

  setup do
    {:ok, repository_iri} = ResourceIdentity.conceptual_repository("classifier-repository")
    {:ok, tenant_iri} = ResourceIdentity.deterministic(:control_constraint, "classifier-tenant")
    {:ok, edition_iri} = ResourceIdentity.wiki_edition(repository_iri, digest("edition"))
    {:ok, page_iri} = ResourceIdentity.wiki_page(edition_iri, :user_guide, "guide")

    fence = %{
      enrollment_revision: 3,
      source_revision: digest("source-1"),
      compiler_digest: Protocol.compiler_digest(),
      policy_digest: digest("policy-1")
    }

    %{
      repository_iri: repository_iri,
      tenant_iri: tenant_iri,
      page_iri: page_iri,
      fence: fence,
      values: Map.new(UpdateClassifier.profile().inputs, &{&1, digest("#{&1}-1")})
    }
  end

  test "classifies no-op, stale-only, metadata, targeted, full, and unsupported changes",
       fixture do
    assert classify(fixture, %{}).action == :no_change

    stale =
      classify(fixture, %{}, %{
        causal_revisions: revisions("source-1", "source-2")
      })

    assert stale.action == :stale_only
    assert stale.current_stale?

    assert classify(fixture, %{metadata: digest("metadata-2")}).action == :metadata_refresh

    targeted =
      classify(fixture, %{guide: digest("guide-2")}, %{
        impact: impact([fixture.page_iri], true)
      })

    assert targeted.action == :targeted_rebuild
    assert targeted.reason == :guide_changed
    assert targeted.affected_page_iris == [fixture.page_iri]

    assert classify(fixture, %{lock: digest("lock-2")}).action == :full_rebuild
    assert classify(fixture, %{renderer: digest("renderer-2")}).action == :full_rebuild

    values = Map.put(fixture.values, :unregistered_input, digest("unknown-1"))
    fixture = %{fixture | values: values}
    assert classify(fixture, %{unregistered_input: digest("unknown-2")}).action == :unsupported
  end

  test "records immutable causality, priority, profile, coalescing identity, and zero usage",
       fixture do
    first =
      classify(fixture, %{source: digest("source-content-2")}, %{
        impact: impact([fixture.page_iri], true),
        priority: :high
      })

    second =
      classify(fixture, %{source: digest("source-content-2")}, %{
        impact: impact([fixture.page_iri], true),
        priority: :high
      })

    assert first == second
    assert first.change_trigger == "observed-default-branch"
    assert first.causal_revisions == revisions("source-1", "source-1")
    assert first.requested_profile == Protocol.compiler_profile()
    assert first.priority == :high
    assert Contract.digest?(first.coalescing_identity)
    assert first.model_calls == 0
    assert first.model_input_tokens == 0
    assert first.model_output_tokens == 0
    assert first.usage_cost_microunits == 0
  end

  test "forces reclassification after any enrollment, source, compiler, or policy fence drift",
       fixture do
    classification = classify(fixture, %{guide: digest("guide-2")})
    assert :ok = UpdateClassifier.validate_fence(classification, fixture.fence)

    for {key, value} <- [
          enrollment_revision: 4,
          source_revision: digest("source-2"),
          compiler_digest: digest("compiler-2"),
          policy_digest: digest("policy-2")
        ] do
      assert {:error, %{kind: :conflict}} =
               UpdateClassifier.validate_fence(classification, Map.put(fixture.fence, key, value))
    end

    assert {:error, %{kind: :conflict}} =
             classify_result(fixture, %{}, %{
               current_fence: %{fixture.fence | enrollment_revision: 4}
             })
  end

  test "marks authoritative drift stale while retaining the prior edition only by explicit policy",
       fixture do
    authoritative = %{fixture.fence | source_revision: digest("source-2")}

    assert {:ok, allowed} =
             UpdateClassifier.staleness(fixture.fence, authoritative, %{
               retained_read_policy: :allow
             })

    assert allowed.stale?
    assert allowed.reasons == [:source_revision]
    assert allowed.previous_edition_readable?
    assert allowed.requires_reclassification?

    assert {:ok, denied} =
             UpdateClassifier.staleness(fixture.fence, authoritative, %{
               retained_read_policy: :deny
             })

    refute denied.previous_edition_readable?
  end

  defp classify(fixture, changes, overrides \\ %{}) do
    assert {:ok, result} = classify_result(fixture, changes, overrides)
    result
  end

  defp classify_result(fixture, changes, overrides) do
    {:ok, before} = UpdateClassifier.manifest(fixture.values)
    {:ok, after_manifest} = UpdateClassifier.manifest(Map.merge(fixture.values, changes))

    attributes =
      %{
        repository_iri: fixture.repository_iri,
        tenant_iri: fixture.tenant_iri,
        change_trigger: "observed-default-branch",
        causal_revisions: revisions("source-1", "source-1"),
        requested_profile: Protocol.compiler_profile(),
        priority: :normal,
        retained_read_policy: :allow,
        classification_fence: fixture.fence,
        current_fence: fixture.fence,
        impact: impact([], false)
      }
      |> Map.merge(overrides)

    UpdateClassifier.classify(before, after_manifest, attributes)
  end

  defp impact(pages, proven?) do
    value = %{
      profile: "wiki-impact-manifest/1.0.0",
      proven?: proven?,
      affected_page_iris: Enum.sort(pages)
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  defp revisions(before, after_revision) do
    %{
      before_source_revision: digest(before),
      after_source_revision: digest(after_revision),
      trigger_revision: digest("trigger-1")
    }
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
