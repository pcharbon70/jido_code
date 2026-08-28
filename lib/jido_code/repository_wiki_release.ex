defmodule JidoCode.RepositoryWikiRelease do
  @moduledoc """
  Closed deterministic V1 repository-wiki release and admission contract.

  The catalog exposes only explicit manual and automatic deterministic
  offerings. Every repository remains Off until separately enrolled, and no
  provider, model, price, prompt, or synthesis adapter is selectable.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Ontology.Release, as: OntologyRelease
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.DependencyLint
  alias JidoCode.Knowledge.RepositoryWiki.FullCompiler
  alias JidoCode.Knowledge.RepositoryWiki.GuideRenderer
  alias JidoCode.Knowledge.RepositoryWiki.LockParser
  alias JidoCode.Knowledge.RepositoryWiki.MixStatic
  alias JidoCode.Knowledge.RepositoryWiki.Pilot
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.QualificationCorpus
  alias JidoCode.Knowledge.RepositoryWiki.QualityEvaluation
  alias JidoCode.Knowledge.RepositoryWiki.SecurityEvaluation
  alias JidoCode.Knowledge.RepositoryWiki.SignedEvidence
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventory

  @contract_version "1.0.0"
  @required_components ~w[compiler parser sandbox metadata lint renderer]a

  @spec manifest() :: map()
  def manifest do
    material = %{
      contract_version: @contract_version,
      versions: %{
        ontology: "1.5.0",
        graph_registry: "2.5.0",
        semantic_protocol: "2.10.0",
        wiki_protocol: "1.0.0"
      },
      durable_authority: :triple_store,
      default_enrollment: :off,
      offerings: %{
        manual_deterministic: %{
          selectable?: true,
          explicit_repository_enrollment_required?: true,
          maintenance_mode: :manual,
          generation_mode: :deterministic_only,
          preview_mode: :allowed,
          model_calls: 0,
          maximum_model_tokens: 0
        },
        automatic_deterministic: %{
          selectable?: true,
          explicit_repository_enrollment_required?: true,
          maintenance_mode: :automatic,
          generation_mode: :deterministic_only,
          preview_mode: :allowed,
          model_calls: 0,
          maximum_model_tokens: 0
        }
      },
      component_profiles: component_profiles(),
      component_digests: component_digests(),
      synthesis: %{
        enabled?: false,
        providers: [],
        models: [],
        prices: [],
        production_adapters: [],
        prompts: [],
        required_future_evidence: [
          :separate_adr_and_release_gate,
          :signed_provider_profile,
          :signed_model_and_prompt_profile,
          :current_price_and_budget_profile,
          :security_and_privacy_qualification,
          :token_and_cost_accounting_reconciliation,
          :controlled_pilot
        ]
      },
      supported_repository_envelope: supported_envelope(),
      cost_semantics: %{
        deterministic_model_calls: 0,
        deterministic_model_tokens: 0,
        deterministic_model_cost_microunits: 0,
        infrastructure_cost_claim: :not_measured,
        unknown_synthesis_liability: :unavailable_by_construction
      },
      privacy: %{
        repository_partition_before_retrieval?: true,
        preview_session_isolation?: true,
        repository_text_is_untrusted?: true,
        source_bodies_in_release_evidence?: false,
        credentials_in_release_evidence?: false,
        telemetry_content_free?: true
      },
      retention: %{
        current_editions: :retained_by_repository_policy,
        release_editions: :retained,
        usage_and_accounting: :retained,
        audit_history: :retained,
        previews: :bounded,
        disposable_indexes: :rebuildable
      },
      rollback_profiles: rollback_profiles(),
      documentation: [
        "docs/guides/repository-wiki-v1-user-guide.md",
        "docs/guides/repository-wiki-v1-developer-guide.md",
        "docs/operations/repository-wiki-v1-runbook.md"
      ],
      gate_reopening_conditions: gate_reopening_conditions()
    }

    Map.put(material, :digest, Contract.digest(material))
  end

  @spec digest() :: String.t()
  def digest, do: manifest().digest

  @spec verify() :: :ok | {:error, Error.t()}
  def verify do
    release = manifest()

    with true <- release.versions.ontology == OntologyRelease.current_version(),
         true <- release.versions.graph_registry == GraphRegistry.revision(),
         true <- release.versions.semantic_protocol == Protocol.semantic_version(),
         true <- release.versions.wiki_protocol == @contract_version,
         true <- release.default_enrollment == :off,
         true <-
           Enum.sort(Map.keys(release.offerings)) ==
             [:automatic_deterministic, :manual_deterministic],
         true <- Enum.all?(release.offerings, &deterministic_offering?/1),
         true <- release.synthesis.enabled? == false,
         true <-
           Enum.all?(
             ~w[providers models prices production_adapters prompts]a,
             &(release.synthesis[&1] == [])
           ),
         true <- Enum.sort(Map.keys(release.component_digests)) == Enum.sort(@required_components),
         true <-
           Enum.all?(release.component_digests, fn {_name, value} -> Contract.digest?(value) end),
         true <- release.digest == Contract.digest(Map.delete(release, :digest)) do
      :ok
    else
      _invalid -> incompatible(:repository_wiki_release)
    end
  rescue
    _error -> incompatible(:repository_wiki_release)
  end

  @spec publish(map(), map(), map(), map(), function(), function()) ::
          {:ok, map()} | {:error, Error.t()}
  def publish(corpus, security, quality, pilot, verifier, signer)
      when is_map(corpus) and is_map(security) and is_map(quality) and is_map(pilot) and
             is_function(verifier, 2) and is_function(signer, 1) do
    with :ok <- verify(),
         :ok <- QualificationCorpus.verify(corpus, verifier),
         :ok <- SecurityEvaluation.verify_report(security, corpus, verifier),
         :ok <- QualityEvaluation.verify_report(quality, corpus, verifier),
         :ok <- Pilot.verify(pilot, verifier),
         true <- security.payload.admitted?,
         true <- quality.payload.admitted?,
         true <- Pilot.admitted?(pilot),
         true <- qualified_components?(corpus),
         payload <- decision_payload(corpus, security, quality, pilot),
         {:ok, decision} <- SignedEvidence.sign(:repository_wiki_v1_release, payload, signer) do
      {:ok, decision}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> incompatible(:repository_wiki_release_admission)
    end
  rescue
    _error -> incompatible(:repository_wiki_release_admission)
  end

  def publish(_corpus, _security, _quality, _pilot, _verifier, _signer),
    do: invalid(:repository_wiki_release_admission)

  @spec verify_decision(map(), map(), map(), map(), map(), function()) ::
          :ok | {:error, Error.t()}
  def verify_decision(decision, corpus, security, quality, pilot, verifier)
      when is_map(decision) and is_map(corpus) and is_map(security) and is_map(quality) and
             is_map(pilot) and is_function(verifier, 2) do
    with :ok <- verify(),
         :ok <- QualificationCorpus.verify(corpus, verifier),
         :ok <- SecurityEvaluation.verify_report(security, corpus, verifier),
         :ok <- QualityEvaluation.verify_report(quality, corpus, verifier),
         :ok <- Pilot.verify(pilot, verifier),
         true <-
           security.payload.admitted? and quality.payload.admitted? and Pilot.admitted?(pilot),
         true <- qualified_components?(corpus),
         :ok <- SignedEvidence.verify(decision, :repository_wiki_v1_release, verifier),
         true <- decision.payload == decision_payload(corpus, security, quality, pilot) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> incompatible(:repository_wiki_release_decision)
    end
  rescue
    _error -> incompatible(:repository_wiki_release_decision)
  end

  def verify_decision(_decision, _corpus, _security, _quality, _pilot, _verifier),
    do: invalid(:repository_wiki_release_decision)

  defp decision_payload(corpus, security, quality, pilot) do
    release = manifest()

    %{
      contract_version: @contract_version,
      status: :accepted,
      rollout: :deterministic_v1,
      release_catalog_digest: release.digest,
      corpus_digest: QualificationCorpus.digest(corpus),
      security_report_digest: security.digest,
      quality_report_digest: quality.digest,
      pilot_report_digest: pilot.digest,
      component_digests: release.component_digests,
      enabled_offerings: [:manual_deterministic, :automatic_deterministic],
      default_enrollment: :off,
      synthesis_enabled?: false,
      hosted_provider_paths: 0,
      rollback_profiles: release.rollback_profiles |> Map.keys() |> Enum.sort(),
      admitted_at: QualificationCorpus.member(corpus, :clock).evaluated_at,
      model_calls: 0,
      model_tokens: 0,
      model_cost_microunits: 0
    }
  end

  defp component_profiles do
    %{
      compiler: FullCompiler.profile(),
      parser: MixStatic.profile(),
      inventory: SourceInventory.profile(),
      lock_parser: LockParser.profile(),
      lint: DependencyLint.profile(),
      renderer: GuideRenderer.profile(),
      sandbox: sandbox_profile(),
      metadata: metadata_profile()
    }
  end

  defp component_digests do
    profiles = component_profiles()

    Map.new(@required_components, fn name ->
      profile = Map.fetch!(profiles, name)
      {name, profile[:digest] || Contract.digest(profile)}
    end)
  end

  defp sandbox_profile do
    %{
      revision: "wiki-observation-sandbox/1.0.0",
      execution: :isolated_allowlisted,
      hooks: :forbidden,
      credentials: :forbidden,
      network: :forbidden
    }
  end

  defp metadata_profile do
    %{
      revision: "hex-metadata/1.0.0",
      transport: :injected_req,
      authority: :observed_only
    }
  end

  defp supported_envelope do
    %{
      language: :elixir,
      project_shape: [:single_application, :umbrella],
      source_inventory: SourceInventory.profile().limits,
      compiler: FullCompiler.profile().limits,
      renderer: GuideRenderer.profile().limits,
      dynamic_mix: :visible_gap_without_authorized_sandbox_observation,
      dependencies: [:hex, :git, :path, :private, :optional, :transitive],
      generated_page_storage: :triple_store,
      source_body_storage: :provider_owned
    }
  end

  defp rollback_profiles do
    %{
      stop_new_work: %{
        new_compilation: :denied,
        maintainers: :drain_then_stop,
        current_editions: :unchanged,
        retained_reads: :policy_preserved,
        usage_and_accounting: :retained,
        audit_history: :retained
      },
      immediate_disable: %{
        new_compilation: :denied,
        maintainers: :fenced_and_stopped,
        current_editions: :unchanged,
        retained_reads: :policy_preserved,
        in_flight_usage: :terminal_or_unknown_liability,
        usage_and_accounting: :retained,
        audit_history: :retained
      }
    }
  end

  defp gate_reopening_conditions do
    [
      :default_enrollment_not_off,
      :disabled_repository_creates_work_or_cost,
      :hosted_synthesis_path_enabled,
      :cross_tenant_repository_or_session_disclosure,
      :wiki_context_gains_authority,
      :deterministic_replay_digest_differs,
      :required_dependency_or_guide_knowledge_missing_without_visible_gap,
      :multiple_current_editions,
      :source_or_activation_fence_bypass,
      :token_or_cost_accounting_not_terminal,
      :rollback_loses_current_read_usage_or_audit_history,
      :signed_profile_or_evidence_digest_changes,
      :clean_checkout_gate_failure
    ]
  end

  defp qualified_components?(corpus) do
    qualified = QualificationCorpus.member(corpus, :component_profiles)
    release = component_digests()

    Enum.all?(@required_components, fn name ->
      get_in(qualified, [name, :digest]) == Map.fetch!(release, name)
    end)
  end

  defp deterministic_offering?({_name, offering}) do
    offering.selectable? and offering.explicit_repository_enrollment_required? and
      offering.generation_mode == :deterministic_only and offering.model_calls == 0 and
      offering.maximum_model_tokens == 0
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp incompatible(operation), do: {:error, Error.new(:incompatible, operation)}
end
