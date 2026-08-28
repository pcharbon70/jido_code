defmodule JidoCode.Knowledge.RepositoryWiki.Phase05IntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.RepositoryWiki.FleetOperations
  alias JidoCode.Knowledge.RepositoryWiki.ContextProfile
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.GenerationCatalog
  alias JidoCode.Knowledge.RepositoryWiki.QualificationCorpus
  alias JidoCode.Knowledge.RepositoryWiki.QualityEvaluation
  alias JidoCode.Knowledge.RepositoryWiki.SecurityEvaluation
  alias JidoCode.Product.RepositoryWikiOperationsProjection
  alias JidoCode.RepositoryWikiRelease

  @secret "rw5-integration-signing-key-for-tests"

  test "pins one advisory context, signed qualification, and closed release tuple" do
    context = ContextProfile.profile()
    assert context.authority? == false
    assert context.preview_context? == false

    assert context.eligible_page_classes ==
             ~w[architecture dependencies guides known_gaps overview project source]a

    assert {:ok, corpus} = QualificationCorpus.sign(&sign/1)

    assert {:ok, security} =
             SecurityEvaluation.evaluate(corpus, security_observations(), [], &verify/2, &sign/1)

    assert {:ok, quality} =
             QualityEvaluation.evaluate(corpus, quality_evidence(), &verify/2, &sign/1)

    assert security.payload.admitted?
    assert quality.payload.admitted?
    assert security.payload.corpus_digest == quality.payload.corpus_digest
    assert security.payload.model_tokens == 0
    assert quality.payload.model_tokens == 0

    qualified_components = QualificationCorpus.member(corpus, :component_profiles)
    released_components = RepositoryWikiRelease.manifest().component_digests

    for name <- ~w[compiler parser sandbox metadata lint renderer]a do
      assert qualified_components[name].digest == released_components[name]
    end
  end

  test "keeps every repository Off and every hosted synthesis path unavailable by default" do
    release = RepositoryWikiRelease.manifest()
    operations = RepositoryWikiOperationsProjection.empty(nil, :empty)

    assert release.default_enrollment == :off
    assert release.synthesis.enabled? == false
    assert release.synthesis.providers == []
    assert release.synthesis.models == []
    assert release.synthesis.prices == []
    assert release.synthesis.production_adapters == []
    assert GenerationCatalog.provider_adapters() == []
    assert GenerationCatalog.price_profiles() == []

    assert operations.totals.attempts == 0
    assert operations.totals.input_tokens == 0
    assert operations.totals.output_tokens == 0
    assert operations.totals.cached_tokens == 0
    assert operations.totals.reasoning_tokens == 0
    assert operations.totals.measured_cost_microunits == 0
    refute operations.profile.synthesis_available?
  end

  test "preserves fleet alerts, rollback history, and every reopening condition" do
    release = RepositoryWikiRelease.manifest()

    assert Enum.sort(FleetOperations.alert_types()) ==
             Enum.sort(~w[
               stale_current_edition repeated_deterministic_failure abandoned_edition
               expired_lease queue_pressure stuck_reservation usage_pending usage_unknown
               restore_drift cross_scope_invariant
             ]a)

    for {_name, rollback} <- release.rollback_profiles do
      assert rollback.new_compilation == :denied
      assert rollback.current_editions == :unchanged
      assert rollback.retained_reads == :policy_preserved
      assert rollback.usage_and_accounting == :retained
      assert rollback.audit_history == :retained
    end

    assert :default_enrollment_not_off in release.gate_reopening_conditions
    assert :disabled_repository_creates_work_or_cost in release.gate_reopening_conditions
    assert :hosted_synthesis_path_enabled in release.gate_reopening_conditions
    assert :cross_tenant_repository_or_session_disclosure in release.gate_reopening_conditions
    assert :deterministic_replay_digest_differs in release.gate_reopening_conditions
    assert :clean_checkout_gate_failure in release.gate_reopening_conditions
  end

  defp security_observations do
    invariants = QualificationCorpus.security_invariants()

    QualificationCorpus.security_scenarios()
    |> Enum.with_index()
    |> Enum.map(fn {id, index} ->
      %{
        id: id,
        outcome: :blocked,
        severity: :none,
        invariants: if(index == 0, do: invariants, else: [:no_execution]),
        evidence_digest: digest({:security, id})
      }
    end)
  end

  defp quality_evidence do
    %{
      completeness: assertions(QualificationCorpus.quality_dimensions(), :completeness),
      usefulness: assertions(QualificationCorpus.usefulness_tasks(), :usefulness),
      isolation: assertions(QualificationCorpus.isolation_scenarios(), :isolation),
      replays:
        for axis <- QualificationCorpus.replay_axes(), run <- 1..2 do
          %{
            axis: axis,
            run: run,
            graph_digest: digest(:canonical_graph),
            page_digest: digest(:canonical_page),
            evidence_digest: digest({:replay, axis, run})
          }
        end,
      resources:
        Map.new(resource_units(), fn {key, unit} ->
          {key, %{value: 1, unit: unit, evidence_digest: digest({:resource, key})}}
        end)
    }
  end

  defp assertions(keys, kind),
    do: Map.new(keys, &{&1, %{passed?: true, evidence_digest: digest({kind, &1})}})

  defp resource_units do
    %{
      inventory_files: :count,
      inventory_bytes: :bytes,
      parsing_ast_nodes: :count,
      graph_statements: :count,
      rendered_bytes: :bytes,
      search_entries: :count,
      maintainer_concurrency: :count,
      storage_bytes: :bytes,
      recovery_milliseconds: :milliseconds
    }
  end

  defp digest(value), do: Contract.digest(value)
  defp sign(material), do: :crypto.mac(:hmac, :sha256, @secret, material)
  defp verify(material, signature), do: Plug.Crypto.secure_compare(sign(material), signature)
end
