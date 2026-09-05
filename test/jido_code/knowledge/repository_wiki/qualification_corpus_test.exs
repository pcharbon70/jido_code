defmodule JidoCode.Knowledge.RepositoryWiki.QualificationCorpusTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.QualificationCorpus
  alias JidoCode.Knowledge.RepositoryWiki.QualityEvaluation
  alias JidoCode.Knowledge.RepositoryWiki.SecurityEvaluation
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventory

  @secret "rw5-qualification-signing-key-for-tests"

  test "signs every immutable corpus member and rejects substitution" do
    corpus = signed_corpus()

    assert corpus.revision == "repository-wiki-qualification-corpus/1.1.0"
    assert :ok = QualificationCorpus.verify(corpus, &verify/2)
    assert Contract.digest?(QualificationCorpus.digest(corpus))

    assert Enum.sort(Map.keys(corpus.artifacts)) ==
             Enum.sort(
               ~w[corpus expected_outputs component_profiles clock evaluator release_thresholds]a
             )

    fixtures = QualificationCorpus.member(corpus, :corpus)

    assert fixture_ids(fixtures.repository) ==
             Enum.sort(~w[
               simple umbrella dynamic_mix complete_lock incomplete_lock hex_dependency
               git_dependency path_dependency private_dependency optional_dependency cyclic_dependency
               malformed_repository oversized_repository unicode_repository hostile_repository
             ]a)

    assert fixture_ids(fixtures.guides) ==
             Enum.sort(~w[
               user_guide developer_guide operator_guide renamed_guide broken_link raw_html
               script_content unsafe_scheme secret_like_value huge_document anchor_collision
             ]a)

    assert fixture_ids(fixtures.concurrency) ==
             Enum.sort(~w[
               many_repositories competing_same_repository_sessions parallel_previews source_churn
               activation_race maintainer_takeover opt_out_during_work bounded_retries late_result
             ]a)

    assert fixture_ids(fixtures.accounting) ==
             Enum.sort(~w[
               zero_token_attempt live_reservation exact_usage partial_usage missing_usage price_change
               currency_rounding duplicate_callback crash_recovery unknown_liability
             ]a)

    expected = QualificationCorpus.member(corpus, :expected_outputs)
    assert map_size(expected.graph) == length(fixtures.repository) + length(fixtures.concurrency)
    assert map_size(expected.page) == length(fixtures.repository) + length(fixtures.guides)
    assert map_size(expected.usage) == length(fixtures.accounting)
    assert Enum.all?(expected.graph, fn {_id, digest} -> Contract.digest?(digest) end)

    profiles = QualificationCorpus.member(corpus, :component_profiles)
    thresholds = QualificationCorpus.member(corpus, :release_thresholds)
    clock = QualificationCorpus.member(corpus, :clock)
    assert clock.evaluated_at == ~U[2026-09-05 16:00:00.000000Z]
    assert profiles.inventory.profile == SourceInventory.profile()
    assert profiles.inventory.digest == Contract.digest(SourceInventory.profile())
    assert thresholds.resources.inventory_files == 2_000
    assert thresholds.resources.inventory_bytes == 16_777_216

    substituted = put_in(corpus.artifacts.clock.payload.mode, :wall_clock)

    assert {:error, %Error{kind: :unauthorized}} =
             QualificationCorpus.verify(substituted, &verify/2)

    stale_profile =
      put_in(
        corpus.artifacts.component_profiles.payload.inventory.profile.revision,
        "wiki-source-inventory/1.0.0"
      )

    assert {:error, %Error{kind: :unauthorized}} =
             QualificationCorpus.verify(stale_profile, &verify/2)

    wider_threshold =
      put_in(corpus.artifacts.release_thresholds.payload.resources.inventory_bytes, 16_777_217)

    assert {:error, %Error{kind: :unauthorized}} =
             QualificationCorpus.verify(wider_threshold, &verify/2)
  end

  test "security evaluation admits complete contained evidence with no high findings" do
    corpus = signed_corpus()
    observations = security_observations()

    residuals = [
      %{
        id: "bounded-parser-complexity",
        severity: :low,
        bounded?: true,
        mitigation: "The signed parser and inventory ceilings reject oversized input.",
        evidence_digest: digest(:bounded_parser_complexity)
      }
    ]

    assert {:ok, report} =
             SecurityEvaluation.evaluate(corpus, observations, residuals, &verify/2, &sign/1)

    assert report.payload.admitted?
    assert report.payload.blocking_reasons == []
    assert report.payload.finding_counts.critical == 0
    assert report.payload.finding_counts.high == 0
    assert report.payload.missing_scenarios == []
    assert report.payload.missing_invariants == []
    assert report.payload.model_tokens == 0
    assert :ok = SecurityEvaluation.verify_report(report, corpus, &verify/2)

    tampered = put_in(report.payload.admitted?, false)

    assert {:error, %Error{kind: :unauthorized}} =
             SecurityEvaluation.verify_report(tampered, corpus, &verify/2)
  end

  test "security evidence cannot override a high finding or missing invariant" do
    corpus = signed_corpus()

    high_finding =
      security_observations()
      |> List.update_at(0, &%{&1 | severity: :high})

    assert {:ok, report} =
             SecurityEvaluation.evaluate(corpus, high_finding, [], &verify/2, &sign/1)

    refute report.payload.admitted?
    assert :high_findings in report.payload.blocking_reasons

    incomplete_invariants =
      security_observations()
      |> Enum.map(&%{&1 | invariants: [:no_execution]})

    assert {:ok, incomplete} =
             SecurityEvaluation.evaluate(corpus, incomplete_invariants, [], &verify/2, &sign/1)

    refute incomplete.payload.admitted?
    assert :missing_security_invariants in incomplete.payload.blocking_reasons
    assert :ok = SecurityEvaluation.verify_report(incomplete, corpus, &verify/2)
  end

  test "quality evaluation pins complete coverage, replay, usefulness, isolation, and ceilings" do
    corpus = signed_corpus()
    evidence = quality_evidence()

    assert {:ok, report} =
             QualityEvaluation.evaluate(corpus, evidence, &verify/2, &sign/1)

    assert report.payload.admitted?
    assert report.payload.blocking_reasons == []
    assert report.payload.canonical_graph_digest == digest(:canonical_graph)
    assert report.payload.canonical_page_digest == digest(:canonical_page)
    assert report.payload.resource_failures == []
    assert report.payload.model_calls == 0
    assert :ok = QualityEvaluation.verify_report(report, corpus, &verify/2)
  end

  test "quality evaluation blocks replay drift, failed source fencing, and resource excess" do
    corpus = signed_corpus()

    evidence =
      quality_evidence()
      |> put_in([:isolation, :source_churn, :passed?], false)
      |> put_in([:resources, :graph_statements, :value], 250_001)
      |> update_in([:replays], fn replays ->
        List.update_at(replays, 0, &%{&1 | graph_digest: digest(:drifted_graph)})
      end)

    assert {:ok, report} =
             QualityEvaluation.evaluate(corpus, evidence, &verify/2, &sign/1)

    refute report.payload.admitted?
    assert :nondeterministic_replay in report.payload.blocking_reasons
    assert :edition_or_scope_mixing in report.payload.blocking_reasons
    assert :resource_ceiling_exceeded in report.payload.blocking_reasons
    assert report.payload.replay_failures == [:graph_digest_mismatch]
    assert report.payload.resource_failures == [:graph_statements]
    assert :ok = QualityEvaluation.verify_report(report, corpus, &verify/2)
  end

  defp signed_corpus do
    assert {:ok, corpus} = QualificationCorpus.sign(&sign/1)
    corpus
  end

  defp security_observations do
    all_invariants = QualificationCorpus.security_invariants()

    QualificationCorpus.security_scenarios()
    |> Enum.with_index()
    |> Enum.map(fn {id, index} ->
      %{
        id: id,
        outcome: :blocked,
        severity: :none,
        invariants: if(index == 0, do: all_invariants, else: [:no_execution]),
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

  defp assertions(keys, kind) do
    Map.new(keys, fn key ->
      {key, %{passed?: true, evidence_digest: digest({kind, key})}}
    end)
  end

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

  defp fixture_ids(fixtures), do: fixtures |> Enum.map(& &1.id) |> Enum.sort()
  defp digest(value), do: Contract.digest(value)
  defp sign(material), do: :crypto.mac(:hmac, :sha256, @secret, material)
  defp verify(material, signature), do: Plug.Crypto.secure_compare(sign(material), signature)
end
