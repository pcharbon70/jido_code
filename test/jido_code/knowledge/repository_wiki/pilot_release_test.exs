defmodule JidoCode.Knowledge.RepositoryWiki.PilotReleaseTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Pilot
  alias JidoCode.Knowledge.RepositoryWiki.QualificationCorpus
  alias JidoCode.Knowledge.RepositoryWiki.QualityEvaluation
  alias JidoCode.Knowledge.RepositoryWiki.SecurityEvaluation
  alias JidoCode.Knowledge.RepositoryWiki.SignedEvidence
  alias JidoCode.RepositoryWikiRelease

  @secret "rw5-pilot-release-signing-key-for-tests"

  setup_all do
    {source_commit, 0} = System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true)
    source_commit = String.trim(source_commit)

    assert {:ok, corpus} = QualificationCorpus.sign(&sign/1)

    assert {:ok, security} =
             SecurityEvaluation.evaluate(corpus, security_observations(), [], &verify/2, &sign/1)

    assert {:ok, quality} =
             QualityEvaluation.evaluate(corpus, quality_evidence(), &verify/2, &sign/1)

    assert {:ok, pilot} = Pilot.run(File.cwd!(), source_commit, &sign/1)

    %{corpus: corpus, security: security, quality: quality, pilot: pilot}
  end

  test "self-hosted pilot covers project, dependencies, guides, documents, race, and opt-out",
       %{pilot: pilot} do
    assert :ok = Pilot.verify(pilot, &verify/2)
    assert Pilot.admitted?(pilot)

    compilation = pilot.payload.compilation
    assert compilation.repository.name == "jido_code"
    assert compilation.repository.external_identity == "github.com/pcharbon70/jido_code"
    assert compilation.overview.app == "jido_code"
    assert compilation.overview.version == "0.1.0"
    assert compilation.overview.elixir == "~> 1.19"
    assert compilation.overview.generation_mode == :deterministic_only
    assert compilation.inventory.file_count > 100
    assert compilation.inventory.module_count > 100
    assert Enum.all?(compilation.inventory.known_gaps, & &1.visible?)

    assert compilation.dependencies.complete?
    assert compilation.dependencies.missing_declared_lock_entries == []
    assert compilation.dependencies.unsupported_lock_entries == 0
    assert compilation.dependencies.declared_count == 26
    assert compilation.dependencies.locked_count >= compilation.dependencies.declared_count

    assert compilation.guides.configured_count == compilation.guides.rendered_count
    assert compilation.guides.blocking_count == 0
    assert compilation.guides.audience_counts.user > 0
    assert compilation.guides.audience_counts.developer > 0
    assert compilation.guides.audience_counts.operator > 0

    assert pilot.payload.review.accepted_document_coverage == %{
             adr: true,
             architecture: true,
             plan: true,
             research: true
           }

    assert Enum.all?(pilot.payload.review.checks, &elem(&1, 1))
    assert Enum.count(pilot.payload.race.outcomes, &(&1.outcome == :activated)) == 1
    assert Enum.count(pilot.payload.race.outcomes, &(&1.outcome == :competing)) == 1
    assert Enum.all?(pilot.payload.race.previews, &(not &1.current?))
    assert pilot.payload.lifecycle.final_state == :off
    assert pilot.payload.lifecycle.new_work_after_disable == 0
    assert pilot.payload.lifecycle.running_maintainers_after_disable == 0
    assert pilot.payload.lifecycle.model_cost_after_disable_microunits == 0
    assert pilot.payload.model_calls == 0
    assert pilot.payload.model_tokens == 0
  end

  test "publishes only the closed deterministic V1 catalog" do
    assert :ok = RepositoryWikiRelease.verify()
    release = RepositoryWikiRelease.manifest()

    assert release.versions == %{
             ontology: "1.5.0",
             graph_registry: "2.5.0",
             semantic_protocol: "2.10.0",
             wiki_protocol: "1.0.0"
           }

    assert release.default_enrollment == :off

    assert Enum.sort(Map.keys(release.offerings)) ==
             [:automatic_deterministic, :manual_deterministic]

    assert Enum.all?(release.offerings, fn {_name, offering} ->
             offering.selectable? and offering.explicit_repository_enrollment_required? and
               offering.generation_mode == :deterministic_only and offering.model_calls == 0 and
               offering.maximum_model_tokens == 0
           end)

    refute release.synthesis.enabled?
    assert release.synthesis.providers == []
    assert release.synthesis.models == []
    assert release.synthesis.prices == []
    assert release.synthesis.production_adapters == []
    assert release.synthesis.prompts == []
    assert Contract.digest?(release.digest)

    assert Enum.sort(Map.keys(release.component_digests)) ==
             Enum.sort(~w[compiler parser sandbox metadata lint renderer]a)

    assert Map.has_key?(release.rollback_profiles, :stop_new_work)
    assert Map.has_key?(release.rollback_profiles, :immediate_disable)
  end

  test "rejects a validly signed pilot with inconsistent race evidence", %{pilot: pilot} do
    forged_payload =
      put_in(
        pilot.payload,
        [:race, :outcomes],
        Enum.map(pilot.payload.race.outcomes, &%{&1 | outcome: :activated})
      )

    forged_payload = %{
      forged_payload
      | pilot_digest:
          Contract.digest(
            {forged_payload.compilation, forged_payload.review, forged_payload.race,
             forged_payload.lifecycle}
          )
    }

    assert {:ok, forged} =
             SignedEvidence.sign(:jido_code_wiki_pilot_report, forged_payload, &sign/1)

    assert {:error, %Error{kind: :unauthorized}} = Pilot.verify(forged, &verify/2)
    refute Pilot.admitted?(forged)
  end

  test "admits and verifies the exact signed corpus, reports, and pilot tuple", fixture do
    assert {:ok, decision} =
             RepositoryWikiRelease.publish(
               fixture.corpus,
               fixture.security,
               fixture.quality,
               fixture.pilot,
               &verify/2,
               &sign/1
             )

    assert decision.payload.status == :accepted
    assert decision.payload.rollout == :deterministic_v1
    assert decision.payload.default_enrollment == :off
    refute decision.payload.synthesis_enabled?
    assert decision.payload.hosted_provider_paths == 0

    assert decision.payload.enabled_offerings ==
             [:manual_deterministic, :automatic_deterministic]

    assert :ok =
             RepositoryWikiRelease.verify_decision(
               decision,
               fixture.corpus,
               fixture.security,
               fixture.quality,
               fixture.pilot,
               &verify/2
             )

    tampered = put_in(decision.payload.synthesis_enabled?, true)

    assert {:error, %Error{kind: :unauthorized}} =
             RepositoryWikiRelease.verify_decision(
               tampered,
               fixture.corpus,
               fixture.security,
               fixture.quality,
               fixture.pilot,
               &verify/2
             )
  end

  test "a signed rejected security report cannot publish", fixture do
    observations =
      security_observations()
      |> List.update_at(0, &%{&1 | severity: :critical})

    assert {:ok, rejected} =
             SecurityEvaluation.evaluate(fixture.corpus, observations, [], &verify/2, &sign/1)

    refute rejected.payload.admitted?

    assert {:error, %Error{kind: :incompatible, operation: :repository_wiki_release_admission}} =
             RepositoryWikiRelease.publish(
               fixture.corpus,
               rejected,
               fixture.quality,
               fixture.pilot,
               &verify/2,
               &sign/1
             )
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
