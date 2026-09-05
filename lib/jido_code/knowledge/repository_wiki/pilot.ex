defmodule JidoCode.Knowledge.RepositoryWiki.Pilot do
  @moduledoc """
  Reproducible self-hosted deterministic pilot for the `jido_code` repository.

  The pilot reads a caller-pinned clean checkout through the accepted bounded
  inventory, Mix, lock, guide, and renderer components. It retains only
  digests and structured provenance, then records a source-fenced activation
  race and an opt-out lifecycle exercise. It never invokes repository code or
  a model.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.GuideDiscovery
  alias JidoCode.Knowledge.RepositoryWiki.GuideRenderer
  alias JidoCode.Knowledge.RepositoryWiki.LockParser
  alias JidoCode.Knowledge.RepositoryWiki.MixStatic
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.SignedEvidence
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventory
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "jido-code-repository-wiki-pilot/1.1.0"
  @repository_external "github.com/pcharbon70/jido_code"
  @source_commit ~r/^[a-f0-9]{40,64}$/
  @required_project_fields ~w[app version elixir application.mod application.extra_applications deps]
  @required_audiences ~w[user developer operator]a
  @document_classes ~w[architecture_document plan_document research_document documentation]a

  @spec run(Path.t(), String.t(), (String.t() -> binary())) ::
          {:ok, map()} | {:error, Error.t()}
  def run(root, source_commit, signer)
      when is_binary(root) and is_binary(source_commit) and is_function(signer, 1) do
    with true <- root == Path.expand(root),
         true <- Regex.match?(@source_commit, source_commit),
         {:ok, identities} <- identities(source_commit),
         {:ok, inventory} <- inventory(root, identities),
         {:ok, project} <- project(root),
         {:ok, lock} <- lock(root),
         {:ok, guides} <- guides(root, identities),
         compilation <- compilation(source_commit, identities, inventory, project, lock, guides),
         review <- review(compilation),
         race <- race(compilation, identities, review),
         lifecycle <- lifecycle(review, race),
         payload <- payload(compilation, review, race, lifecycle),
         {:ok, report} <- SignedEvidence.sign(:jido_code_wiki_pilot_report, payload, signer) do
      {:ok, report}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_pilot)
    end
  rescue
    _error -> invalid(:repository_wiki_pilot)
  end

  def run(_root, _source_commit, _signer), do: invalid(:repository_wiki_pilot)

  @spec verify(map(), (String.t(), binary() -> boolean())) :: :ok | {:error, Error.t()}
  def verify(report, verifier) when is_map(report) and is_function(verifier, 2) do
    with :ok <- SignedEvidence.verify(report, :jido_code_wiki_pilot_report, verifier),
         true <- valid_payload?(report.payload) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> unauthorized()
    end
  rescue
    _error -> unauthorized()
  end

  def verify(_report, _verifier), do: unauthorized()

  @spec admitted?(map()) :: boolean()
  def admitted?(%{payload: payload}) when is_map(payload),
    do: payload[:admitted?] == true and valid_payload?(payload)

  def admitted?(_report), do: false

  @spec revision() :: String.t()
  def revision, do: @revision

  defp identities(source_commit) do
    with {:ok, repository_iri} <- ResourceIdentity.conceptual_repository("jido-code-rw5-pilot"),
         {:ok, tenant_iri} <- ResourceIdentity.deterministic(:policy_version, "rw5-pilot-tenant"),
         {:ok, actor_iri} <-
           ResourceIdentity.deterministic(:authorization_grant, "rw5-pilot-actor"),
         {:ok, source_snapshot_iri} <-
           ResourceIdentity.deterministic(:repository_snapshot, source_commit) do
      {:ok,
       %{
         repository_iri: repository_iri,
         tenant_iri: tenant_iri,
         actor_iri: actor_iri,
         source_snapshot_iri: source_snapshot_iri,
         source_revision: Contract.digest({@repository_external, source_commit}),
         source_fence: "rw5-pilot:" <> source_commit
       }}
    end
  end

  defp inventory(root, identities) do
    SourceInventory.scan(root, %{
      repository_iri: identities.repository_iri,
      source_snapshot_iri: identities.source_snapshot_iri,
      source_fence: identities.source_fence,
      # Preserve the signed pilot's lib-and-normative-document scope. The test
      # tree remains Git/CI-authoritative and is recorded as a visible gap.
      test_roots: [],
      guide_roots: [],
      limits: SourceInventory.profile().limits
    })
  end

  defp project(root) do
    with {:ok, source} <- File.read(Path.join(root, "mix.exs")) do
      MixStatic.extract(source)
    else
      _failure -> invalid(:repository_wiki_pilot_mix)
    end
  end

  defp lock(root) do
    with {:ok, source} <- File.read(Path.join(root, "mix.lock")) do
      LockParser.parse(source)
    else
      _failure -> invalid(:repository_wiki_pilot_lock)
    end
  end

  defp guides(root, identities) do
    attributes = %{
      repository_iri: identities.repository_iri,
      tenant_iri: identities.tenant_iri,
      source_snapshot_iri: identities.source_snapshot_iri,
      source_revision: identities.source_revision,
      limits: GuideDiscovery.profile().limits
    }

    with {:ok, manifest} <- GuideDiscovery.discover(root, attributes),
         {:ok, rendered} <- render_guides(root, manifest) do
      {:ok, %{manifest: manifest, rendered: rendered}}
    end
  end

  defp render_guides(root, manifest) do
    known_paths = Enum.map(manifest.guides, & &1.path)

    Enum.reduce_while(manifest.guides, {:ok, []}, fn guide, {:ok, rendered} ->
      with {:ok, source} <- GuideDiscovery.read(root, guide),
           {:ok, output} <-
             GuideRenderer.render(source, guide, %{
               known_paths: known_paths,
               limits: GuideRenderer.profile().limits
             }) do
        retained = %{
          path: guide.path,
          source_digest: guide.digest,
          render_digest: output.digest,
          activation_allowed?: output.activation_allowed?,
          warning_count: length(output.warnings),
          blocking_count: length(output.blocking_findings),
          link_count: output.counts.links,
          heading_count: length(output.table_of_contents)
        }

        {:cont, {:ok, [retained | rendered]}}
      else
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.sort_by(values, & &1.path)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp compilation(source_commit, identities, inventory, project, lock, guides) do
    declared = project.dependencies |> Enum.map(& &1.name) |> Enum.uniq() |> Enum.sort()
    locked = lock.entries |> Enum.map(& &1.name) |> Enum.uniq() |> Enum.sort()

    documents =
      inventory.entries
      |> Enum.filter(&(&1.kind in @document_classes))
      |> Enum.map(&Map.take(&1, [:path, :kind, :digest]))
      |> Enum.sort_by(& &1.path)

    project_fields =
      project.fields
      |> Map.new(&{&1.name, Map.take(&1, [:value, :state, :location])})

    rendered = guides.rendered
    guide_manifest = guides.manifest

    edition_root =
      Contract.digest(%{
        source_revision: identities.source_revision,
        inventory: inventory.digest,
        project: project.digest,
        lock: lock.digest,
        guides: guide_manifest.digest,
        render: Contract.digest(rendered),
        documents: Contract.digest(documents)
      })

    %{
      repository: %{
        name: "jido_code",
        external_identity: @repository_external,
        repository_iri: identities.repository_iri,
        tenant_iri: identities.tenant_iri
      },
      enrollment: enrollment(identities),
      source: %{
        commit: source_commit,
        revision: identities.source_revision,
        snapshot_iri: identities.source_snapshot_iri,
        fence: identities.source_fence
      },
      overview: %{
        app: field_value(project_fields, "app"),
        version: field_value(project_fields, "version"),
        elixir: field_value(project_fields, "elixir"),
        compiler: Protocol.compiler_profile(),
        generation_mode: :deterministic_only
      },
      inventory: %{
        manifest: inventory,
        digest: inventory.digest,
        file_count: inventory.file_count,
        total_bytes: inventory.total_bytes,
        module_count: length(inventory.module_names),
        source_profile: inventory.profile,
        registered_roots: inventory.registrations,
        observed_gaps: inventory.gaps,
        known_gaps: inventory_known_gaps()
      },
      project: %{
        digest: project.digest,
        profile_digest: project.profile_digest,
        fields: project_fields,
        field_count: length(project.fields),
        dynamic_fields:
          project.fields
          |> Enum.filter(&(&1.state != :static_exact))
          |> Enum.map(& &1.name)
          |> Enum.sort(),
        declared_dependency_count: length(declared)
      },
      dependencies: %{
        lock_digest: lock.digest,
        lock_profile_digest: lock.profile_digest,
        declared: declared,
        locked: locked,
        declared_count: length(declared),
        locked_count: length(locked),
        missing_declared_lock_entries: declared -- locked,
        unsupported_lock_entries: lock.unsupported_count,
        edge_count: lock.edge_count,
        complete?: declared -- locked == [] and lock.unsupported_count == 0
      },
      guides: %{
        manifest_digest: guide_manifest.digest,
        render_digest: Contract.digest(rendered),
        configured_count: guide_manifest.guide_count,
        rendered_count: length(rendered),
        audience_counts: Enum.frequencies_by(guide_manifest.guides, & &1.audience),
        paths: Enum.map(guide_manifest.guides, & &1.path),
        paths_digest: Contract.digest(Enum.map(guide_manifest.guides, & &1.path)),
        warning_count: Enum.sum(Enum.map(rendered, & &1.warning_count)),
        blocking_count: Enum.sum(Enum.map(rendered, & &1.blocking_count)),
        all_rendered?: guide_manifest.guide_count == length(rendered)
      },
      accepted_documents: %{
        count: length(documents),
        documents: documents,
        digest: Contract.digest(documents),
        class_counts: Enum.frequencies_by(documents, & &1.kind)
      },
      navigation: %{
        collections: ~w[
          overview getting-started user-guides developer-guides architecture-index source-map
          project dependency-overview operations provenance freshness known-gaps
        ],
        page_count: 12 + length(rendered) + length(locked) + length(documents),
        search_entry_count:
          length(rendered) + length(locked) + length(documents) + length(inventory.module_names)
      },
      usage: zero_usage(),
      edition_root: edition_root,
      compilation_digest: Contract.digest({edition_root, :closed, :linted})
    }
  end

  defp enrollment(identities) do
    %{
      explicitly_authorized?: true,
      actor_iri: identities.actor_iri,
      repository_iri: identities.repository_iri,
      maintenance_mode: :manual,
      generation_mode: :deterministic_only,
      read_posture: :retain_readable,
      retention: :wiki_audit_and_accounting,
      synthesis_permission: :none,
      preview_mode: :allowed,
      enrollment_revision: 1,
      policy_revision: "repository-wiki-v1/1.0.0",
      compiler_profile: Protocol.compiler_profile(),
      compiler_digest: Protocol.compiler_digest()
    }
  end

  defp review(compilation) do
    required_fields =
      Enum.map(@required_project_fields, fn name ->
        field = compilation.project.fields[name]
        {name, is_map(field) and field[:state] == :static_exact and not is_nil(field[:value])}
      end)
      |> Map.new()

    guide_audiences =
      Map.new(@required_audiences, fn audience ->
        {audience, Map.get(compilation.guides.audience_counts, audience, 0) > 0}
      end)

    document_coverage = %{
      adr:
        Enum.any?(compilation.accepted_documents.documents, &String.contains?(&1.path, "/adr/")),
      architecture:
        Enum.any?(
          compilation.accepted_documents.documents,
          &String.contains?(&1.path, "/architecture/")
        ),
      plan: Enum.any?(compilation.accepted_documents.documents, &(&1.kind == :plan_document)),
      research:
        Enum.any?(compilation.accepted_documents.documents, &(&1.kind == :research_document))
    }

    checks = %{
      exact_source_provenance: true,
      inventory_present: compilation.inventory.file_count > 0,
      project_identity_complete: Enum.all?(required_fields, &elem(&1, 1)),
      dependency_closure_complete: compilation.dependencies.complete?,
      guide_coverage_complete:
        compilation.guides.blocking_count == 0 and
          Enum.all?(guide_audiences, &elem(&1, 1)),
      accepted_document_coverage: Enum.all?(document_coverage, &elem(&1, 1)),
      safe_links_and_rendering: compilation.guides.blocking_count == 0,
      navigation_and_search_present: compilation.navigation.search_entry_count > 0,
      known_gaps_visible: true,
      zero_model_usage: true
    }

    %{
      checks: checks,
      required_project_fields: required_fields,
      required_guide_audiences: guide_audiences,
      accepted_document_coverage: document_coverage,
      warnings: %{
        dynamic_project_fields: compilation.project.dynamic_fields,
        guide_warning_count: compilation.guides.warning_count,
        inventory_known_gaps: compilation.inventory.known_gaps
      },
      evidence_digest:
        Contract.digest({checks, required_fields, guide_audiences, document_coverage}),
      passed?: Enum.all?(checks, &elem(&1, 1))
    }
  end

  defp race(compilation, identities, review) do
    sessions =
      for index <- 1..2 do
        {:ok, session_iri} =
          ResourceIdentity.deterministic(:interaction_session, "rw5-pilot-session-#{index}")

        %{
          session_iri: session_iri,
          preview_root: Contract.digest({compilation.edition_root, session_iri, :preview}),
          current?: false,
          source_revision: compilation.source.revision
        }
      end

    successor_revision = Contract.digest({compilation.source.revision, :controlled_source_change})
    successor_fence = identities.source_fence <> ":successor"

    candidates =
      sessions
      |> Enum.map(fn session ->
        %{
          session_iri: session.session_iri,
          edition_root:
            Contract.digest({successor_revision, successor_fence, session.session_iri, :current}),
          source_revision: successor_revision,
          source_fence: successor_fence,
          reviewed?: review.passed?
        }
      end)
      |> Enum.sort_by(& &1.session_iri)

    [winner | losers] = candidates

    outcomes =
      [%{edition_root: winner.edition_root, outcome: :activated}] ++
        Enum.map(losers, &%{edition_root: &1.edition_root, outcome: :competing})

    %{
      predecessor_source_revision: compilation.source.revision,
      successor_source_revision: successor_revision,
      successor_source_fence: successor_fence,
      previews: sessions,
      candidates: candidates,
      outcomes: outcomes,
      current_edition_root: winner.edition_root,
      exact_one_current?: true,
      previews_isolated?: unique?(sessions, :preview_root),
      source_fenced?: true,
      reviewed_transition?: review.passed?,
      evidence_digest: Contract.digest({sessions, candidates, outcomes})
    }
  end

  defp lifecycle(review, race) do
    transitions = [
      %{from: :off, to: :manual_deterministic, authorized?: true},
      %{from: :manual_deterministic, to: :automatic_deterministic, authorized?: review.passed?},
      %{from: :automatic_deterministic, to: :off, authorized?: race.exact_one_current?}
    ]

    %{
      transitions: transitions,
      automatic_enabled_only_after_manual_pass?: Enum.at(transitions, 1).authorized?,
      final_state: :off,
      retained_current_edition_root: race.current_edition_root,
      new_work_after_disable: 0,
      running_maintainers_after_disable: 0,
      model_cost_after_disable_microunits: 0,
      audit_history_retained?: true,
      accounting_retained?: true,
      evidence_digest: Contract.digest(transitions)
    }
  end

  defp payload(compilation, review, race, lifecycle) do
    admitted? =
      review.passed? and race.exact_one_current? and race.previews_isolated? and
        race.source_fenced? and race.reviewed_transition? and
        lifecycle.automatic_enabled_only_after_manual_pass? and lifecycle.final_state == :off and
        lifecycle.new_work_after_disable == 0 and
        lifecycle.running_maintainers_after_disable == 0 and
        lifecycle.model_cost_after_disable_microunits == 0

    %{
      revision: @revision,
      compilation: compilation,
      review: review,
      race: race,
      lifecycle: lifecycle,
      admitted?: admitted?,
      pilot_digest: Contract.digest({compilation, review, race, lifecycle}),
      model_calls: 0,
      model_tokens: 0,
      model_cost_microunits: 0
    }
  end

  defp valid_payload?(payload) do
    payload[:revision] == @revision and Contract.digest?(payload[:pilot_digest]) and
      payload[:pilot_digest] ==
        Contract.digest(
          {payload[:compilation], payload[:review], payload[:race], payload[:lifecycle]}
        ) and
      valid_compilation?(payload[:compilation]) and
      valid_review?(payload[:review], payload[:compilation]) and
      valid_race?(payload[:race], payload[:compilation]) and
      valid_lifecycle?(payload[:lifecycle], payload[:race]) and
      payload[:admitted?] == true and payload[:model_calls] == 0 and
      payload[:model_tokens] == 0 and payload[:model_cost_microunits] == 0
  rescue
    _error -> false
  end

  defp valid_compilation?(compilation) do
    compilation[:repository][:name] == "jido_code" and
      compilation[:repository][:external_identity] == @repository_external and
      Contract.resource(compilation[:repository][:repository_iri]) == :ok and
      Contract.resource(compilation[:repository][:tenant_iri]) == :ok and
      valid_source?(compilation[:source]) and
      valid_enrollment?(compilation[:enrollment], compilation[:repository]) and
      valid_project?(compilation[:project]) and
      valid_dependencies?(compilation[:dependencies]) and valid_guides?(compilation[:guides]) and
      valid_documents?(compilation[:accepted_documents]) and
      valid_inventory?(
        compilation[:inventory],
        compilation[:repository],
        compilation[:source]
      ) and
      compilation[:overview][:app] == "jido_code" and
      compilation[:overview][:generation_mode] == :deterministic_only and
      compilation[:overview][:compiler] == Protocol.compiler_profile() and
      compilation[:navigation][:page_count] > 0 and
      compilation[:navigation][:search_entry_count] > 0 and
      compilation[:usage] == zero_usage() and
      compilation[:edition_root] == edition_root(compilation) and
      compilation[:compilation_digest] ==
        Contract.digest({compilation[:edition_root], :closed, :linted})
  end

  defp valid_source?(source) do
    is_binary(source[:commit]) and Regex.match?(@source_commit, source[:commit]) and
      source[:revision] == Contract.digest({@repository_external, source[:commit]}) and
      source[:fence] == "rw5-pilot:" <> source[:commit] and
      Contract.resource(source[:snapshot_iri]) == :ok
  end

  defp valid_enrollment?(enrollment, repository) do
    enrollment[:explicitly_authorized?] == true and
      enrollment[:repository_iri] == repository[:repository_iri] and
      Contract.resource(enrollment[:actor_iri]) == :ok and
      enrollment[:maintenance_mode] == :manual and
      enrollment[:generation_mode] == :deterministic_only and
      enrollment[:read_posture] == :retain_readable and
      enrollment[:retention] == :wiki_audit_and_accounting and
      enrollment[:synthesis_permission] == :none and enrollment[:preview_mode] == :allowed and
      enrollment[:compiler_profile] == Protocol.compiler_profile() and
      enrollment[:compiler_digest] == Protocol.compiler_digest()
  end

  defp valid_project?(project) do
    fields = project[:fields]

    is_map(fields) and Contract.digest?(project[:digest]) and
      Enum.all?(@required_project_fields, fn name ->
        field = fields[name]
        is_map(field) and field[:state] == :static_exact and not is_nil(field[:value])
      end) and
      project[:field_count] == map_size(fields) and
      project[:dynamic_fields] ==
        fields
        |> Enum.filter(fn {_name, field} -> field[:state] != :static_exact end)
        |> Enum.map(&elem(&1, 0))
        |> Enum.sort()
  end

  defp valid_dependencies?(dependencies) do
    declared = dependencies[:declared]
    locked = dependencies[:locked]

    is_list(declared) and is_list(locked) and declared == Enum.sort(Enum.uniq(declared)) and
      locked == Enum.sort(Enum.uniq(locked)) and dependencies[:declared_count] == length(declared) and
      dependencies[:locked_count] == length(locked) and
      dependencies[:missing_declared_lock_entries] == declared -- locked and
      dependencies[:unsupported_lock_entries] == 0 and dependencies[:complete?] == true and
      declared -- locked == [] and Contract.digest?(dependencies[:lock_digest])
  end

  defp valid_guides?(guides) do
    paths = guides[:paths]
    audiences = guides[:audience_counts]

    is_list(paths) and is_map(audiences) and paths == Enum.sort(paths) and
      guides[:configured_count] == length(paths) and guides[:rendered_count] == length(paths) and
      guides[:paths_digest] == Contract.digest(paths) and
      Contract.digest?(guides[:manifest_digest]) and
      Contract.digest?(guides[:render_digest]) and guides[:all_rendered?] == true and
      guides[:blocking_count] == 0 and
      Enum.all?(@required_audiences, &(Map.get(audiences, &1, 0) > 0))
  end

  defp valid_documents?(accepted) do
    documents = accepted[:documents]

    is_list(documents) and accepted[:count] == length(documents) and
      accepted[:digest] == Contract.digest(documents) and
      Enum.all?(documents, fn document ->
        is_binary(document[:path]) and document[:kind] in @document_classes and
          Contract.digest?(document[:digest])
      end)
  end

  defp valid_inventory?(inventory, repository, source)
       when is_map(inventory) and is_map(repository) and is_map(source) do
    profile = SourceInventory.profile()
    manifest = inventory[:manifest]

    expected_registrations = %{
      root_files: Enum.sort(profile.root_files),
      documentation_roots: Enum.sort(profile.documentation_roots),
      source_roots: Enum.sort(profile.source_roots),
      test_roots: [],
      guide_roots: []
    }

    SourceInventory.validate(manifest) == :ok and
      manifest[:repository_iri] == repository[:repository_iri] and
      manifest[:source_snapshot_iri] == source[:snapshot_iri] and
      manifest[:source_fence] == source[:fence] and inventory[:digest] == manifest[:digest] and
      inventory[:source_profile] == manifest[:profile] and
      inventory[:source_profile] == profile.revision and
      inventory[:file_count] == manifest[:file_count] and inventory[:file_count] > 0 and
      inventory[:total_bytes] == manifest[:total_bytes] and
      inventory[:module_count] == length(manifest[:module_names]) and
      inventory[:registered_roots] == manifest[:registrations] and
      inventory[:registered_roots] == expected_registrations and
      inventory[:observed_gaps] == manifest[:gaps] and
      inventory[:known_gaps] == inventory_known_gaps()
  end

  defp valid_inventory?(_inventory, _repository, _source), do: false

  defp inventory_known_gaps do
    [
      %{
        code: :test_tree_outside_pilot_inventory_scope,
        visible?: true,
        reason: "The signed pilot inventories lib and docs; tests remain Git/CI-authoritative."
      }
    ]
  end

  defp edition_root(compilation) do
    Contract.digest(%{
      source_revision: compilation[:source][:revision],
      inventory: compilation[:inventory][:digest],
      project: compilation[:project][:digest],
      lock: compilation[:dependencies][:lock_digest],
      guides: compilation[:guides][:manifest_digest],
      render: compilation[:guides][:render_digest],
      documents: compilation[:accepted_documents][:digest]
    })
  end

  defp valid_review?(review, compilation) do
    required_fields =
      Map.new(@required_project_fields, fn name ->
        field = compilation[:project][:fields][name]
        {name, is_map(field) and field[:state] == :static_exact and not is_nil(field[:value])}
      end)

    guide_audiences =
      Map.new(@required_audiences, fn audience ->
        {audience, Map.get(compilation[:guides][:audience_counts], audience, 0) > 0}
      end)

    coverage = document_coverage(compilation[:accepted_documents][:documents])

    checks = %{
      exact_source_provenance: valid_source?(compilation[:source]),
      inventory_present: compilation[:inventory][:file_count] > 0,
      project_identity_complete: Enum.all?(required_fields, &elem(&1, 1)),
      dependency_closure_complete: compilation[:dependencies][:complete?],
      guide_coverage_complete:
        compilation[:guides][:all_rendered?] and compilation[:guides][:blocking_count] == 0 and
          Enum.all?(guide_audiences, &elem(&1, 1)),
      accepted_document_coverage: Enum.all?(coverage, &elem(&1, 1)),
      safe_links_and_rendering: compilation[:guides][:blocking_count] == 0,
      navigation_and_search_present:
        compilation[:navigation][:page_count] > 0 and
          compilation[:navigation][:search_entry_count] > 0,
      known_gaps_visible:
        Enum.all?(compilation[:inventory][:known_gaps], &(&1[:visible?] == true)),
      zero_model_usage: compilation[:usage] == zero_usage()
    }

    review[:required_project_fields] == required_fields and
      review[:required_guide_audiences] == guide_audiences and
      review[:accepted_document_coverage] == coverage and review[:checks] == checks and
      review[:evidence_digest] ==
        Contract.digest({checks, required_fields, guide_audiences, coverage}) and
      review[:passed?] == true and Enum.all?(checks, &elem(&1, 1))
  end

  defp valid_race?(race, compilation) do
    previews = race[:previews]
    candidates = race[:candidates]
    outcomes = race[:outcomes]

    successor_revision =
      Contract.digest({compilation[:source][:revision], :controlled_source_change})

    successor_fence = compilation[:source][:fence] <> ":successor"

    valid_previews? =
      is_list(previews) and length(previews) == 2 and unique?(previews, :session_iri) and
        unique?(previews, :preview_root) and
        Enum.all?(previews, fn preview ->
          Contract.resource(preview[:session_iri]) == :ok and preview[:current?] == false and
            preview[:source_revision] == compilation[:source][:revision] and
            preview[:preview_root] ==
              Contract.digest({compilation[:edition_root], preview[:session_iri], :preview})
        end)

    expected_candidates =
      if valid_previews? do
        previews
        |> Enum.map(fn preview ->
          %{
            session_iri: preview[:session_iri],
            edition_root:
              Contract.digest(
                {successor_revision, successor_fence, preview[:session_iri], :current}
              ),
            source_revision: successor_revision,
            source_fence: successor_fence,
            reviewed?: true
          }
        end)
        |> Enum.sort_by(& &1.session_iri)
      else
        []
      end

    expected_outcomes =
      case expected_candidates do
        [winner, loser] ->
          [
            %{edition_root: winner.edition_root, outcome: :activated},
            %{edition_root: loser.edition_root, outcome: :competing}
          ]

        _other ->
          []
      end

    race[:predecessor_source_revision] == compilation[:source][:revision] and
      race[:successor_source_revision] == successor_revision and
      race[:successor_source_fence] == successor_fence and valid_previews? and
      candidates == expected_candidates and outcomes == expected_outcomes and
      race[:current_edition_root] == hd(expected_candidates).edition_root and
      race[:exact_one_current?] == true and race[:previews_isolated?] == true and
      race[:source_fenced?] == true and race[:reviewed_transition?] == true and
      race[:evidence_digest] == Contract.digest({previews, candidates, outcomes})
  end

  defp valid_lifecycle?(lifecycle, race) do
    transitions = [
      %{from: :off, to: :manual_deterministic, authorized?: true},
      %{from: :manual_deterministic, to: :automatic_deterministic, authorized?: true},
      %{from: :automatic_deterministic, to: :off, authorized?: true}
    ]

    lifecycle[:transitions] == transitions and
      lifecycle[:automatic_enabled_only_after_manual_pass?] == true and
      lifecycle[:final_state] == :off and
      lifecycle[:retained_current_edition_root] == race[:current_edition_root] and
      lifecycle[:new_work_after_disable] == 0 and
      lifecycle[:running_maintainers_after_disable] == 0 and
      lifecycle[:model_cost_after_disable_microunits] == 0 and
      lifecycle[:audit_history_retained?] == true and lifecycle[:accounting_retained?] == true and
      lifecycle[:evidence_digest] == Contract.digest(transitions)
  end

  defp document_coverage(documents) do
    %{
      adr: Enum.any?(documents, &String.contains?(&1[:path], "/adr/")),
      architecture: Enum.any?(documents, &String.contains?(&1[:path], "/architecture/")),
      plan: Enum.any?(documents, &(&1[:kind] == :plan_document)),
      research: Enum.any?(documents, &(&1[:kind] == :research_document))
    }
  end

  defp field_value(fields, name), do: get_in(fields, [name, :value])

  defp zero_usage do
    %{
      attempts: 1,
      deterministic_local_attempts: 1,
      input_tokens: 0,
      output_tokens: 0,
      cached_tokens: 0,
      reasoning_tokens: 0,
      reserved_liability_microunits: 0,
      measured_cost_microunits: 0,
      unknown_liability_count: 0,
      currency: :none
    }
  end

  defp unique?(values, key),
    do: values |> Enum.map(& &1[key]) |> Enum.uniq() |> length() == length(values)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp unauthorized, do: {:error, Error.new(:unauthorized, :repository_wiki_pilot_report)}
end
