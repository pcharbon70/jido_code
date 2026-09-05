defmodule JidoCode.Knowledge.RepositoryWiki.QualificationCorpus do
  @moduledoc """
  Immutable representative and adversarial RW5 qualification corpus.

  Fixture entries are manifests and deterministic oracles, never executable
  repository content. Each member and the enclosing manifest are signed so a
  runner cannot substitute cases, clocks, profiles, outputs, or thresholds.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.DependencyLint
  alias JidoCode.Knowledge.RepositoryWiki.FullCompiler
  alias JidoCode.Knowledge.RepositoryWiki.GuideRenderer
  alias JidoCode.Knowledge.RepositoryWiki.MixStatic
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.SignedEvidence
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventory

  @revision "repository-wiki-qualification-corpus/1.1.0"
  @member_kinds ~w[corpus expected_outputs component_profiles clock evaluator release_thresholds]a
  @clock ~U[2026-09-05 16:00:00.000000Z]

  @repository_fixtures [
    {:simple, :accepted},
    {:umbrella, :accepted},
    {:dynamic_mix, :visible_gap},
    {:complete_lock, :accepted},
    {:incomplete_lock, :visible_gap},
    {:hex_dependency, :accepted},
    {:git_dependency, :accepted},
    {:path_dependency, :accepted},
    {:private_dependency, :redacted},
    {:optional_dependency, :accepted},
    {:cyclic_dependency, :visible_gap},
    {:malformed_repository, :rejected},
    {:oversized_repository, :bounded_rejection},
    {:unicode_repository, :accepted},
    {:hostile_repository, :contained}
  ]

  @guide_fixtures [
    {:user_guide, :rendered},
    {:developer_guide, :rendered},
    {:operator_guide, :rendered},
    {:renamed_guide, :redirect_reviewed},
    {:broken_link, :blocking_finding},
    {:raw_html, :escaped_text},
    {:script_content, :escaped_text},
    {:unsafe_scheme, :blocking_finding},
    {:secret_like_value, :redacted_and_blocked},
    {:huge_document, :bounded_rejection},
    {:anchor_collision, :stable_disambiguation}
  ]

  @concurrency_fixtures [
    {:many_repositories, :scope_isolated},
    {:competing_same_repository_sessions, :one_current},
    {:parallel_previews, :not_current},
    {:source_churn, :stale_retry},
    {:activation_race, :one_current},
    {:maintainer_takeover, :fenced_takeover},
    {:opt_out_during_work, :cancelled_no_new_work},
    {:bounded_retries, :terminal_or_requeued},
    {:late_result, :retained_not_activated}
  ]

  @accounting_fixtures [
    {:zero_token_attempt, :exact_zero},
    {:live_reservation, :reserved_liability},
    {:exact_usage, :measured},
    {:partial_usage, :pending},
    {:missing_usage, :unknown_liability},
    {:price_change, :invocation_price_pinned},
    {:currency_rounding, :integer_microunits},
    {:duplicate_callback, :charged_once},
    {:crash_recovery, :reconciled},
    {:unknown_liability, :budget_conservative}
  ]

  @security_scenarios ~w[
    path_traversal symlink_escape parser_bomb atom_exhaustion code_execution mix_hook_execution
    credential_access network_escape endpoint_injection unsafe_redirect content_injection
    graph_iri_injection raw_query_bypass cross_tenant_join cross_repository_join preview_disclosure
    cache_collision stale_reference forged_source_fence multiple_current budget_bypass
    reservation_race profile_substitution price_substitution usage_suppression duplicate_charge
    arithmetic_overflow late_provider_result disable_after_invocation wiki_prompt_injection
    authority_confusion
  ]a

  @security_invariants ~w[
    no_execution no_network no_credentials bounded_parsing safe_links escaped_content graph_scope
    reviewed_queries tenant_isolation repository_isolation preview_isolation opaque_reference_freshness
    source_fence_integrity single_current budget_integrity reservation_integrity profile_integrity
    price_integrity usage_terminal_integrity charge_idempotency arithmetic_integrity late_result_fencing
    disable_fencing quoted_context attributable_context no_command_authority no_tool_authority
    no_policy_authority no_credential_authority no_runtime_authority no_merge_authority
  ]a

  @quality_dimensions ~w[
    dependency_node_coverage dependency_edge_coverage project_fields_or_gaps guide_provenance
    source_provenance safe_links page_reachability lint_success render_success
  ]a
  @replay_axes ~w[clean_checkout randomized_enumeration process_restart supported_runtime]a
  @usefulness_tasks ~w[
    page_discoverability navigation source_tracing dependency_explanation known_gap_visibility
    bounded_search
  ]a
  @isolation_scenarios ~w[
    activation_race source_churn parallel_preview competing_session cross_repository
  ]a
  @resource_keys ~w[
    inventory_files inventory_bytes parsing_ast_nodes graph_statements rendered_bytes search_entries
    maintainer_concurrency storage_bytes recovery_milliseconds
  ]a

  @spec sign((String.t() -> binary())) :: {:ok, map()} | {:error, Error.t()}
  def sign(signer) when is_function(signer, 1) do
    members = members()

    with {:ok, artifacts} <- sign_members(members, signer),
         manifest <- manifest_payload(artifacts),
         {:ok, envelope} <- SignedEvidence.sign(:qualification_manifest, manifest, signer) do
      {:ok, %{revision: @revision, artifacts: artifacts, envelope: envelope}}
    end
  end

  def sign(_signer), do: invalid(:repository_wiki_qualification_corpus)

  @spec verify(map(), (String.t(), binary() -> boolean())) :: :ok | {:error, Error.t()}
  def verify(signed, verifier) when is_map(signed) and is_function(verifier, 2) do
    expected = members()

    with true <- Enum.sort(Map.keys(signed)) == [:artifacts, :envelope, :revision],
         true <- signed.revision == @revision,
         true <- Enum.sort(Map.keys(signed.artifacts)) == Enum.sort(@member_kinds),
         :ok <- verify_members(signed.artifacts, expected, verifier),
         true <- signed.envelope.payload == manifest_payload(signed.artifacts),
         :ok <- SignedEvidence.verify(signed.envelope, :qualification_manifest, verifier) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> unauthorized()
    end
  rescue
    _error -> unauthorized()
  end

  def verify(_signed, _verifier), do: unauthorized()

  @spec digest(map()) :: String.t() | nil
  def digest(%{envelope: %{digest: digest}}) when is_binary(digest), do: digest
  def digest(_signed), do: nil

  @spec member(map(), atom()) :: term() | nil
  def member(%{artifacts: artifacts}, kind) when kind in @member_kinds,
    do: get_in(artifacts, [kind, :payload])

  def member(_signed, _kind), do: nil

  @spec security_scenarios() :: [atom()]
  def security_scenarios, do: @security_scenarios

  @spec security_invariants() :: [atom()]
  def security_invariants, do: @security_invariants

  @spec quality_dimensions() :: [atom()]
  def quality_dimensions, do: @quality_dimensions

  @spec replay_axes() :: [atom()]
  def replay_axes, do: @replay_axes

  @spec usefulness_tasks() :: [atom()]
  def usefulness_tasks, do: @usefulness_tasks

  @spec isolation_scenarios() :: [atom()]
  def isolation_scenarios, do: @isolation_scenarios

  @spec resource_keys() :: [atom()]
  def resource_keys, do: @resource_keys

  defp members do
    corpus = %{
      revision: @revision,
      repository: fixtures(@repository_fixtures),
      guides: fixtures(@guide_fixtures),
      concurrency: fixtures(@concurrency_fixtures),
      accounting: fixtures(@accounting_fixtures)
    }

    %{
      corpus: corpus,
      expected_outputs: expected_outputs(corpus),
      component_profiles: component_profiles(),
      clock: %{evaluated_at: @clock, timezone: "Etc/UTC", mode: :frozen},
      evaluator: evaluator_contract(),
      release_thresholds: release_thresholds()
    }
  end

  defp fixtures(values) do
    Enum.map(values, fn {id, expected} ->
      %{id: id, expected: expected, fixture_digest: Contract.digest({id, expected, @revision})}
    end)
  end

  defp expected_outputs(corpus) do
    %{
      graph: output_oracles(corpus.repository ++ corpus.concurrency, :canonical_graph),
      page: output_oracles(corpus.repository ++ corpus.guides, :canonical_page),
      usage: output_oracles(corpus.accounting, :canonical_usage)
    }
  end

  defp output_oracles(fixtures, output_kind) do
    Map.new(fixtures, fn fixture ->
      {fixture.id,
       Contract.digest({output_kind, fixture.id, fixture.expected, fixture.fixture_digest})}
    end)
  end

  defp component_profiles do
    profiles = %{
      compiler: FullCompiler.profile(),
      parser: MixStatic.profile(),
      inventory: SourceInventory.profile(),
      lint: DependencyLint.profile(),
      renderer: GuideRenderer.profile(),
      sandbox: %{
        revision: "wiki-observation-sandbox/1.0.0",
        execution: :isolated_allowlisted,
        hooks: :forbidden,
        credentials: :forbidden,
        network: :forbidden
      },
      metadata: %{
        revision: "hex-metadata/1.0.0",
        transport: :injected_req,
        authority: :observed_only
      }
    }

    Map.new(profiles, fn {name, profile} ->
      {name, %{profile: profile, digest: profile[:digest] || Contract.digest(profile)}}
    end)
  end

  defp evaluator_contract do
    %{
      revision: "repository-wiki-qualification-evaluator/1.0.0",
      security_scenarios: @security_scenarios,
      security_invariants: @security_invariants,
      quality_dimensions: @quality_dimensions,
      replay_axes: @replay_axes,
      usefulness_tasks: @usefulness_tasks,
      isolation_scenarios: @isolation_scenarios,
      resource_keys: @resource_keys,
      enumeration: :stable_id,
      failure_policy: :fail_closed,
      model_calls: 0
    }
  end

  defp release_thresholds do
    inventory_limits = SourceInventory.profile().limits

    %{
      maximum_findings: %{critical: 0, high: 0},
      maximum_residual_severity: :medium,
      require_all_security_scenarios: true,
      require_all_security_invariants: true,
      require_all_quality_dimensions: true,
      require_identical_replay_digests: true,
      require_all_usefulness_tasks: true,
      require_all_isolation_scenarios: true,
      resources: %{
        inventory_files: inventory_limits.files,
        inventory_bytes: inventory_limits.total_bytes,
        parsing_ast_nodes: 100_000,
        graph_statements: 250_000,
        rendered_bytes: 16_777_216,
        search_entries: 20_000,
        maintainer_concurrency: 32,
        storage_bytes: 67_108_864,
        recovery_milliseconds: 60_000
      }
    }
  end

  defp sign_members(members, signer) do
    Enum.reduce_while(@member_kinds, {:ok, %{}}, fn kind, {:ok, artifacts} ->
      case SignedEvidence.sign(kind, Map.fetch!(members, kind), signer) do
        {:ok, artifact} -> {:cont, {:ok, Map.put(artifacts, kind, artifact)}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp verify_members(artifacts, expected, verifier) do
    Enum.reduce_while(@member_kinds, :ok, fn kind, :ok ->
      artifact = Map.fetch!(artifacts, kind)

      with true <- artifact.payload == Map.fetch!(expected, kind),
           :ok <- SignedEvidence.verify(artifact, kind, verifier) do
        {:cont, :ok}
      else
        {:error, %Error{} = error} -> {:halt, {:error, error}}
        _invalid -> {:halt, unauthorized()}
      end
    end)
  end

  defp manifest_payload(artifacts) do
    %{
      revision: @revision,
      member_digests: Map.new(@member_kinds, &{&1, artifacts[&1].digest}),
      member_order: @member_kinds,
      protocol: %{
        ontology: Protocol.ontology_version(),
        semantic: Protocol.semantic_version(),
        wiki: "1.0.0",
        compiler: Protocol.compiler_digest()
      }
    }
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp unauthorized, do: {:error, Error.new(:unauthorized, :repository_wiki_qualification_corpus)}
end
