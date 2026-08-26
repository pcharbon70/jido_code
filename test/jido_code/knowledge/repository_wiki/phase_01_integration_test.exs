defmodule JidoCode.Knowledge.RepositoryWiki.Phase01IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.RepositoryWiki.Enrollment
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventory
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Vocabulary
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture

  @jf "https://jido.run/ontology/factory#"

  setup context do
    fixture =
      context
      |> Phase04Fixture.start!()
      |> Phase04Fixture.bootstrap!()
      |> Phase04Fixture.enroll!()
      |> Phase04Fixture.assert_outcome!()

    source_root = Path.join(fixture.root, "repository-source")
    File.mkdir_p!(Path.join(source_root, "docs/architecture"))
    File.mkdir_p!(Path.join(source_root, "lib/demo"))
    File.mkdir_p!(Path.join(source_root, "test/demo"))
    File.mkdir_p!(Path.join(source_root, "guides"))
    File.write!(Path.join(source_root, "README.md"), "# Wiki integration fixture\r\n")
    File.write!(Path.join(source_root, "mix.exs"), "raise \"must never execute\"\n")
    File.write!(Path.join(source_root, "mix.lock"), "%{}\n")
    File.write!(Path.join(source_root, "docs/architecture/0001-wiki.md"), "# Accepted ADR\n")
    File.write!(Path.join(source_root, "docs/naïve.md"), "# Unicode documentation\n")
    File.write!(Path.join(source_root, "lib/demo/wiki.ex"), "defmodule Demo.Wiki do\nend\n")

    File.write!(
      Path.join(source_root, "test/demo/wiki_test.exs"),
      "defmodule Demo.WikiTest do\nend\n"
    )

    File.write!(Path.join(source_root, "guides/user.md"), "# User guide\n")
    File.write!(Path.join(source_root, "docs/oversized.md"), String.duplicate("x", 262_145))
    File.ln_s!(Path.join(source_root, "README.md"), Path.join(source_root, "docs/readme-link.md"))

    snapshot = resource(:repository_snapshot, "wiki-phase-01-source-#{context.test}")

    Map.merge(fixture, %{
      source_root: source_root,
      tenant: fixture.factory_scope,
      snapshot: snapshot,
      source_fence: "git:sha256:#{digest("wiki-phase-01-source-#{context.test}")}"
    })
  end

  test "real store enforces opt-in, immutable edition lifecycle, accounting, and disable fences",
       fixture do
    assert :wiki_writer in Authorization.capabilities()

    assert {:ok, default} =
             Knowledge.repository_wiki_default(fixture.repository, fixture.tenant)

    refute default.configured?
    refute default.generation_allowed?
    refute default.product_available?

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.wiki_generation_profile(:hosted_synthesis, %{
               approved_at: fixture.issued_at
             })

    {:ok, manual} =
      Knowledge.wiki_generation_profile(:manual_deterministic, %{approved_at: fixture.issued_at})

    {:ok, automatic} =
      Knowledge.wiki_generation_profile(:automatic_deterministic, %{
        approved_at: fixture.issued_at
      })

    unauthorized_attributes =
      command_attributes(fixture)
      |> Map.put(:scope_iri, fixture.factory_scope)
      |> Map.put(:principal_iri, resource(:authorization_grant, "wiki-unauthorized"))
      |> Map.put(:actor_iri, resource(:authorization_grant, "wiki-unauthorized"))

    {:ok, unauthorized} =
      Knowledge.register_wiki_generation_profile(automatic, unauthorized_attributes,
        clock: clock(fixture)
      )

    assert {:ok, denied} = Writer.execute(fixture.writer, unauthorized)
    assert denied.outcome == :unauthorized

    register = register_profile!(fixture, manual)
    assert {:ok, replayed_registration} = Writer.execute(fixture.writer, register)
    assert replayed_registration.outcome == :already_committed

    enrollment = enroll_wiki!(fixture, manual)
    assert {:ok, replayed_enrollment} = Writer.execute(fixture.writer, enrollment.command)
    assert replayed_enrollment.outcome == :already_committed

    edition_fixture = compile_edition!(fixture, manual)
    admission = admit!(edition_fixture, enrollment.resolution)
    lifecycle = persist_edition!(edition_fixture)

    stale_activation_attributes =
      command_attributes(edition_fixture)
      |> Map.put(:source_fence, "git:sha256:#{digest("stale-source")}")

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.activate_repository_wiki_edition(
               edition_fixture.edition,
               enrollment.resolution,
               manual,
               stale_activation_attributes,
               clock: clock(fixture)
             )

    activation = activate!(edition_fixture, enrollment.resolution, manual)
    assert {:ok, replayed_activation} = Writer.execute(fixture.writer, activation.command)
    assert replayed_activation.outcome == :already_committed

    late_result_attributes = command_attributes(edition_fixture)

    {:ok, late_result} =
      Knowledge.mark_repository_wiki_edition_stale(
        edition_fixture.edition,
        late_result_attributes,
        clock: clock(fixture)
      )

    disabled = disable_wiki!(edition_fixture, activation.resolution)

    assert {:ok, rejected_late_result} = Writer.execute(fixture.writer, late_result)
    assert rejected_late_result.outcome == :conflicted

    off = disabled.enrollment
    refute Enrollment.generation_allowed?(off, :manual_request)
    assert Enrollment.retained_readable?(off)
    refute Enrollment.product_available?(off)

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.admit_repository_wiki_compilation(
               edition_fixture.edition,
               Map.merge(disabled.resolution, %{state: :off, revision: off.revision}),
               command_attributes(edition_fixture)
               |> Map.put(:trigger, :manual_request)
               |> Map.put(:enrollment_revision, off.revision),
               clock: clock(fixture)
             )

    dataset = Phase04Fixture.export_dataset!(fixture)

    assert typed?(
             dataset,
             edition_fixture.edition.iri,
             "WikiEdition",
             edition_fixture.edition.graph_iri
           )

    assert typed?(
             dataset,
             hd(edition_fixture.compilation.pages).iri,
             "WikiPage",
             edition_fixture.edition.graph_iri
           )

    assert lifecycle.close.outcome == :committed
    assert admission.outcome == :committed
    assert edition_fixture.compilation.model_calls == 0
    assert edition_fixture.compilation.model_input_tokens == 0
    assert edition_fixture.compilation.model_output_tokens == 0
    assert edition_fixture.compilation.usage.cost_microunits == 0
  end

  test "parallel sessions accept one enrollment successor and reject cross-repository scope",
       fixture do
    {:ok, manual} =
      Knowledge.wiki_generation_profile(:manual_deterministic, %{approved_at: fixture.issued_at})

    {:ok, automatic} =
      Knowledge.wiki_generation_profile(:automatic_deterministic, %{
        approved_at: fixture.issued_at
      })

    register_profile!(fixture, manual)
    register_profile!(fixture, automatic)
    enrollment = enroll_wiki!(fixture, manual)

    manual_command =
      transition_command!(fixture, enrollment.resolution, :manual, manual)

    automatic_command =
      transition_command!(fixture, enrollment.resolution, :automatic, automatic)

    outcomes =
      [manual_command, automatic_command]
      |> Task.async_stream(&Writer.execute(fixture.writer, &1),
        ordered: false,
        max_concurrency: 2,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, {:ok, receipt}} -> receipt.outcome end)
      |> Enum.sort()

    assert outcomes == [:committed, :conflicted]

    dataset = Phase04Fixture.export_dataset!(fixture)

    assert successor_count(
             dataset,
             fixture.control_graph,
             enrollment.resolution.current_transition_iri
           ) == 1

    {:ok, other_repository} = ResourceIdentity.repository("wiki-cross-scope-repository")

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.transition_repository_wiki_enrollment(
               other_repository,
               fixture.tenant,
               nil,
               :manual,
               command_attributes(fixture) |> Map.put(:generation_profile, manual),
               clock: clock(fixture)
             )

    refute typed?(dataset, other_repository, "RepositoryWiki", fixture.control_graph)
  end

  test "graph-only recovery, backup restore, retention, and startup contracts remain exact",
       fixture do
    {:ok, manual} =
      Knowledge.wiki_generation_profile(:manual_deterministic, %{approved_at: fixture.issued_at})

    register_profile!(fixture, manual)
    enrollment = enroll_wiki!(fixture, manual)
    edition_fixture = compile_edition!(fixture, manual)
    admit!(edition_fixture, enrollment.resolution)
    lifecycle = persist_edition!(edition_fixture)

    dataset = Phase04Fixture.export_dataset!(fixture)

    authority = %{
      enrollment_state: :manual,
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      source_snapshot_iri: fixture.snapshot,
      source_fence: fixture.source_fence,
      current_edition_iri: nil,
      read_visibility: :hidden
    }

    assert {:ok, recovered} =
             Knowledge.recover_repository_wiki(dataset, edition_fixture.edition.iri, authority)

    assert recovered.recovery_status == :closed
    assert recovered.reconstructed_from == :rdf_only
    refute recovered.visible?

    assert {:ok, indexes} =
             Knowledge.rebuild_repository_wiki_indexes(dataset, edition_fixture.edition.iri)

    assert length(indexes.navigation) == 7
    assert indexes.disposable?

    assert {:ok, manifest} =
             Knowledge.repository_wiki_backup_manifest(%{
               repository_iri: fixture.repository,
               tenant_iri: fixture.tenant,
               enrollment_iri: enrollment.current.iri,
               edition_iri: edition_fixture.edition.iri,
               graph_iri: edition_fixture.edition.graph_iri,
               source_snapshot_iri: fixture.snapshot,
               source_fence: fixture.source_fence,
               compiler_profile: Protocol.compiler_profile(),
               compiler_digest: Protocol.compiler_digest(),
               lineage: [],
               current_pointer: nil,
               retention_class: :superseded,
               audit_iris: [lifecycle.close.receipt_iri]
             })

    assert manifest.restore_order == [
             :repository_control,
             :repository_wiki,
             :render_cache,
             :search_index
           ]

    assert :ok = GraphRegistry.verify()
    assert {:ok, backup} = Maintenance.backup(fixture.maintenance, [])

    assert {:ok, restored} =
             Maintenance.restore(fixture.maintenance, backup.artifact_id,
               confirm: backup.artifact_id
             )

    assert restored.integrity_status == :ok
    restored_dataset = Phase04Fixture.export_dataset!(fixture)
    assert RDF.Dataset.equal?(application_dataset(dataset), application_dataset(restored_dataset))
  end

  defp register_profile!(fixture, profile) do
    attributes = command_attributes(fixture) |> Map.put(:scope_iri, fixture.factory_scope)

    {:ok, command} =
      Knowledge.register_wiki_generation_profile(profile, attributes, clock: clock(fixture))

    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed, inspect(receipt)
    command
  end

  defp enroll_wiki!(fixture, profile) do
    attributes = command_attributes(fixture) |> Map.put(:generation_profile, profile)

    {:ok, command} =
      Knowledge.transition_repository_wiki_enrollment(
        fixture.repository,
        fixture.tenant,
        nil,
        :manual,
        attributes,
        clock: clock(fixture)
      )

    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed

    {:ok, current} =
      Knowledge.repository_wiki_enrollment(%{
        repository_iri: fixture.repository,
        tenant_iri: fixture.tenant,
        revision: 1,
        state: :manual,
        generation_profile: profile,
        generation_mode: :deterministic_only,
        preview_mode: :disabled,
        read_visibility: :retained,
        cancellation_generation: 0,
        current_edition_iri: nil,
        recorded_at: fixture.issued_at
      })

    current_transition = transition_for_state!(command, "RepositoryWikiEnrollmentManual")

    resolution = %{
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      current_state: :manual,
      current_revision: 1,
      current_enrollment_iri: current.iri,
      current_transition_iri: current_transition,
      cancellation_generation: 0,
      current_edition_iri: nil,
      read_visibility: :retained
    }

    %{command: command, receipt: receipt, current: current, resolution: resolution}
  end

  defp compile_edition!(fixture, profile) do
    {:ok, inventory} =
      Knowledge.inventory_repository_wiki(fixture.source_root, %{
        repository_iri: fixture.repository,
        source_snapshot_iri: fixture.snapshot,
        source_fence: fixture.source_fence,
        accepted_graph_sources: [
          %{
            repository_iri: fixture.repository,
            graph_iri: fixture.control_graph,
            resource_iri: fixture.goal,
            revision: Phase04Fixture.current_graph_revision!(fixture, fixture.control_graph),
            digest: digest("accepted-control-fact")
          }
        ],
        limits: SourceInventory.profile().limits
      })

    assert Enum.any?(inventory.entries, &(&1.path == "docs/naïve.md"))
    assert %{path: "docs/readme-link.md", reason: :symlinked} in inventory.gaps
    assert %{path: "docs/oversized.md", reason: :oversized} in inventory.gaps

    {:ok, compilation} =
      Knowledge.compile_repository_wiki(inventory, %{
        repository_iri: fixture.repository,
        tenant_iri: fixture.tenant,
        created_at: fixture.issued_at,
        purpose: :current
      })

    {:ok, repeated} =
      Knowledge.compile_repository_wiki(inventory, %{
        repository_iri: fixture.repository,
        tenant_iri: fixture.tenant,
        created_at: fixture.issued_at,
        purpose: :current
      })

    assert repeated.compilation_digest == compilation.compilation_digest
    assert repeated.statements == compilation.statements
    assert compilation.compiler_digest == profile.compiler_digest

    {:ok, segments} =
      Knowledge.partition_repository_wiki(
        compilation.edition_iri,
        compilation.statements,
        fixture.issued_at
      )

    {:ok, edition} = Knowledge.repository_wiki_edition(compilation, segments)

    Map.merge(fixture, %{
      inventory: inventory,
      compilation: compilation,
      segments: segments,
      edition: edition,
      profile: profile
    })
  end

  defp admit!(fixture, resolution) do
    attributes =
      command_attributes(fixture)
      |> Map.put(:trigger, :manual_request)
      |> Map.put(:enrollment_revision, resolution.current_revision)

    {:ok, command} =
      Knowledge.admit_repository_wiki_compilation(
        fixture.edition,
        Map.merge(resolution, %{state: :manual, revision: resolution.current_revision}),
        attributes,
        clock: clock(fixture)
      )

    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed, inspect(receipt)
    receipt
  end

  defp persist_edition!(fixture) do
    {:ok, start} =
      Knowledge.start_repository_wiki_edition(
        fixture.edition,
        command_attributes(fixture),
        clock: clock(fixture)
      )

    assert {:ok, start_receipt} = Writer.execute(fixture.writer, start)
    assert start_receipt.outcome == :committed, inspect(start_receipt)

    append_receipts =
      Enum.map(fixture.segments, fn segment ->
        {:ok, append} =
          Knowledge.append_repository_wiki_segment(
            segment,
            command_attributes(fixture),
            clock: clock(fixture)
          )

        assert {:ok, receipt} = Writer.execute(fixture.writer, append)
        assert receipt.outcome == :committed, inspect(receipt)
        receipt
      end)

    {:ok, finalize} =
      Knowledge.finalize_repository_wiki_edition(
        fixture.edition,
        fixture.segments,
        command_attributes(fixture),
        clock: clock(fixture)
      )

    assert {:ok, finalize_receipt} = Writer.execute(fixture.writer, finalize)
    assert finalize_receipt.outcome == :committed

    {:ok, linted} =
      Knowledge.lint_repository_wiki_edition(
        fixture.edition,
        [],
        command_attributes(fixture),
        clock: clock(fixture)
      )

    assert {:ok, lint_receipt} = Writer.execute(fixture.writer, linted.command)
    assert lint_receipt.outcome == :committed

    {:ok, metadata} =
      StoreServer.request(fixture.store_server, {:graph_metadata, fixture.edition.graph_iri})

    {:ok, close} =
      Knowledge.close_repository_wiki_edition(
        fixture.edition,
        linted.report,
        metadata,
        command_attributes(fixture),
        clock: clock(fixture)
      )

    assert {:ok, close_receipt} = Writer.execute(fixture.writer, close)
    assert close_receipt.outcome == :committed, inspect(close_receipt)

    %{
      start: start_receipt,
      appends: append_receipts,
      finalize: finalize_receipt,
      lint: lint_receipt,
      close: close_receipt
    }
  end

  defp activate!(fixture, resolution, profile) do
    {:ok, command} =
      Knowledge.activate_repository_wiki_edition(
        fixture.edition,
        resolution,
        profile,
        command_attributes(fixture),
        clock: clock(fixture)
      )

    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed

    {:ok, current} =
      Knowledge.repository_wiki_enrollment(%{
        repository_iri: fixture.repository,
        tenant_iri: fixture.tenant,
        revision: 2,
        state: :manual,
        generation_profile: profile,
        generation_mode: :deterministic_only,
        preview_mode: :disabled,
        read_visibility: :retained,
        cancellation_generation: 0,
        current_edition_iri: fixture.edition.iri,
        recorded_at: fixture.issued_at
      })

    resolution = %{
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      current_state: :manual,
      current_revision: 2,
      current_enrollment_iri: current.iri,
      current_transition_iri: transition_for_state!(command, "RepositoryWikiEnrollmentManual"),
      cancellation_generation: 0,
      current_edition_iri: fixture.edition.iri,
      read_visibility: :retained
    }

    %{command: command, receipt: receipt, current: current, resolution: resolution}
  end

  defp disable_wiki!(fixture, resolution) do
    {:ok, command} =
      Knowledge.transition_repository_wiki_enrollment(
        fixture.repository,
        fixture.tenant,
        resolution,
        :off,
        command_attributes(fixture)
        |> Map.put(:generation_profile, nil)
        |> Map.put(:read_visibility, :retained),
        clock: clock(fixture)
      )

    assert :advance_cancellation_fence in command.payload.disable_effects
    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed

    {:ok, enrollment} =
      Knowledge.repository_wiki_enrollment(%{
        repository_iri: fixture.repository,
        tenant_iri: fixture.tenant,
        revision: resolution.current_revision + 1,
        state: :off,
        generation_profile: nil,
        generation_mode: :deterministic_only,
        preview_mode: :disabled,
        read_visibility: :retained,
        cancellation_generation: resolution.cancellation_generation + 1,
        current_edition_iri: fixture.edition.iri,
        recorded_at: fixture.issued_at
      })

    next_resolution = %{
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      current_state: :off,
      current_revision: enrollment.revision,
      current_enrollment_iri: enrollment.iri,
      current_transition_iri: transition_for_state!(command, "RepositoryWikiEnrollmentOff"),
      cancellation_generation: enrollment.cancellation_generation,
      current_edition_iri: fixture.edition.iri,
      read_visibility: :retained
    }

    %{command: command, receipt: receipt, enrollment: enrollment, resolution: next_resolution}
  end

  defp transition_command!(fixture, resolution, state, profile) do
    {:ok, command} =
      Knowledge.transition_repository_wiki_enrollment(
        fixture.repository,
        fixture.tenant,
        resolution,
        state,
        command_attributes(fixture) |> Map.put(:generation_profile, profile),
        clock: clock(fixture)
      )

    command
  end

  defp command_attributes(fixture) do
    wiki_revision =
      case Map.get(fixture, :edition) do
        nil -> 0
        edition -> graph_revision(fixture, edition.graph_iri)
      end

    %{
      repository_iri: fixture.repository,
      catalog_graph_iri: fixture.graphs.catalog,
      control_graph_iri: fixture.control_graph,
      wiki_graph_iri: get_in(fixture, [:edition, Access.key(:graph_iri)]),
      expected_catalog_revision: graph_revision(fixture, fixture.graphs.catalog),
      expected_control_revision: graph_revision(fixture, fixture.control_graph),
      expected_wiki_revision: wiki_revision,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      enrollment_revision: 1,
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      scope_iri: fixture.repository,
      correlation_iri: resource(:authorization_grant, "wiki-phase-01-correlation"),
      causation_iri: fixture.bootstrap_command_iri,
      reason: "repository wiki Phase 1 integration",
      recorded_at: fixture.issued_at,
      source_fence: fixture.source_fence
    }
  end

  defp graph_revision(fixture, graph) do
    case StoreServer.request(fixture.store_server, {:graph_metadata, graph}) do
      {:ok, %{graph_revision: revision}} -> revision
      {:error, _error} -> 0
      _missing -> 0
    end
  end

  defp transition_for_state!(command, state_suffix) do
    command.payload.changes
    |> hd()
    |> Map.fetch!(:additions)
    |> Enum.find_value(fn
      {subject, @jf <> "nextState", object} ->
        if String.ends_with?(RDF.IRI.to_string(object), state_suffix), do: to_string(subject)

      _other ->
        nil
    end)
  end

  defp successor_count(dataset, graph, predecessor) do
    dataset
    |> RDF.Dataset.quads()
    |> Enum.count(fn
      {_, predicate, object, stored_graph} ->
        RDF.IRI.to_string(predicate) == @jf <> "expectedPredecessor" and
          RDF.IRI.to_string(object) == predecessor and RDF.IRI.to_string(stored_graph) == graph

      _other ->
        false
    end)
  end

  defp typed?(dataset, subject, class, graph) do
    RDF.Dataset.include?(
      dataset,
      RDF.quad(subject, RDF.type(), RDF.iri(@jf <> class), graph)
    )
  end

  defp application_dataset(dataset) do
    dataset
    |> RDF.Dataset.named_graphs()
    |> Enum.reject(&(RDF.IRI.to_string(&1.name) == Vocabulary.system_graph()))
    |> Enum.reduce(RDF.Dataset.new(), &RDF.Dataset.add(&2, &1))
  end

  defp clock(fixture), do: fn -> fixture.issued_at end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(seed), do: :crypto.hash(:sha256, seed) |> Base.encode16(case: :lower)
end
