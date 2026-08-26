defmodule JidoCode.Knowledge.RepositoryWiki.EditionProtocolTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.ChangeSet
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Segment
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventory
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-26 18:00:00Z]

  setup do
    root = Path.join(System.tmp_dir!(), "jido-wiki-edition-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "docs/architecture"))
    File.mkdir_p!(Path.join(root, "lib/demo"))
    File.mkdir_p!(Path.join(root, "test/demo"))
    File.write!(Path.join(root, "README.md"), "# Demo\n")
    File.write!(Path.join(root, "mix.exs"), "def project, do: raise(\"never execute\")\n")
    File.write!(Path.join(root, "mix.lock"), "%{}\n")
    File.write!(Path.join(root, "docs/architecture/0001-demo.md"), "# Accepted ADR\n")
    File.write!(Path.join(root, "lib/demo/example.ex"), "defmodule Demo.Example do\nend\n")

    File.write!(
      Path.join(root, "test/demo/example_test.exs"),
      "defmodule Demo.ExampleTest do\nend\n"
    )

    {:ok, repository} = ResourceIdentity.conceptual_repository("wiki-edition-fixture")
    tenant = resource(:authorization_grant, "wiki-edition-tenant")
    snapshot = resource(:repository_snapshot, "wiki-edition-source")
    {:ok, catalog_graph} = GraphRegistry.graph_iri(:factory_catalog, %{})
    {:ok, control_graph} = GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    {:ok, profile} =
      Knowledge.wiki_generation_profile(:manual_deterministic, %{approved_at: @now})

    on_exit(fn -> File.rm_rf!(root) end)

    fixture = %{
      root: root,
      repository: repository,
      tenant: tenant,
      snapshot: snapshot,
      source_fence: "git:sha256:#{digest("edition-source")}",
      catalog_graph: catalog_graph,
      control_graph: control_graph,
      profile: profile
    }

    {:ok, inventory} = SourceInventory.scan(root, inventory_attributes(fixture))

    {:ok, compilation} =
      Knowledge.compile_repository_wiki(inventory, %{
        repository_iri: repository,
        tenant_iri: tenant,
        created_at: @now,
        purpose: :current
      })

    {:ok, segments} =
      Knowledge.partition_repository_wiki(
        compilation.edition_iri,
        compilation.statements,
        @now
      )

    {:ok, edition} = Knowledge.repository_wiki_edition(compilation, segments)

    Map.merge(fixture, %{
      inventory: inventory,
      compilation: compilation,
      segments: segments,
      edition: edition
    })
  end

  test "compiles seven stable attributed pages and explicit zero-token accounting", fixture do
    compilation = fixture.compilation

    assert Enum.map(compilation.pages, & &1.slug) == [
             "overview",
             "repository-inventory",
             "architecture-index",
             "source-map",
             "documentation-index",
             "provenance",
             "known-gaps"
           ]

    assert Enum.all?(compilation.pages, &(&1.source_iris != []))
    assert compilation.model_calls == 0
    assert compilation.model_input_tokens == 0
    assert compilation.model_output_tokens == 0
    assert compilation.usage.accounting_state == :success
    assert compilation.usage.cost_microunits == 0
    assert compilation.compiler_profile == "wiki-deterministic-elixir/1.0.0"
    assert compilation.compiler_digest == fixture.profile.compiler_digest

    {:ok, repeated} =
      Knowledge.compile_repository_wiki(fixture.inventory, %{
        repository_iri: fixture.repository,
        tenant_iri: fixture.tenant,
        created_at: @now,
        purpose: :current
      })

    assert repeated.edition_root == compilation.edition_root
    assert repeated.compilation_digest == compilation.compilation_digest
    assert repeated.statements == compilation.statements
  end

  test "partitions unique statements under exact segment ceilings and rejects an oversized segment",
       fixture do
    statements =
      Enum.map(1..1_500, fn index ->
        {resource(:wiki_source, "segment-source-#{index}"),
         "https://jido.run/ontology/factory#stableKey", RDF.XSD.String.new("item-#{index}")}
      end)

    assert {:ok, segments} = Segment.partition(fixture.edition.iri, statements, @now)
    assert length(segments) == 2

    assert Enum.all?(segments, fn segment ->
             segment.statement_count <= 800 and segment.content_bytes <= 192 * 1024
           end)

    assert Enum.at(segments, 1).predecessor_iri == hd(segments).iri

    huge =
      {resource(:wiki_source, "huge-segment"), "https://jido.run/ontology/factory#title",
       RDF.XSD.String.new(String.duplicate("x", 200_000))}

    assert {:error, %{kind: :invalid_input}} =
             Segment.new(fixture.edition.iri, 0, nil, [huge], @now)
  end

  test "builds revision-fenced admit, start, append, finalize, lint, close, and activate commands",
       fixture do
    current = current_enrollment(fixture)
    resolution = enrollment_resolution(fixture, current)

    assert {:ok, admission} =
             Knowledge.admit_repository_wiki_compilation(
               fixture.edition,
               Map.merge(resolution, %{state: :manual, revision: 1}),
               command_attributes(fixture, 1, 1)
               |> Map.put(:trigger, :manual_request)
               |> Map.put(:enrollment_revision, 1),
               clock: fn -> @now end
             )

    assert admission.command_type == "AdmitDeterministicWikiCompilation"

    start_attributes = command_attributes(fixture, 1, 0)

    assert {:ok, start} =
             Knowledge.start_repository_wiki_edition(fixture.edition, start_attributes,
               clock: fn -> @now end
             )

    assert start.command_type == "StartWikiEdition"
    assert hd(start.payload.changes).operation == :create

    first = hd(fixture.segments)

    assert {:ok, append} =
             Knowledge.append_repository_wiki_segment(
               first,
               command_attributes(fixture, 1, 1),
               clock: fn -> @now end
             )

    assert append.command_type == "AppendWikiEditionSegment"

    assert {:ok, finalize} =
             Knowledge.finalize_repository_wiki_edition(
               fixture.edition,
               fixture.segments,
               command_attributes(fixture, 1, 2),
               clock: fn -> @now end
             )

    assert finalize.command_type == "FinalizeWikiEdition"

    assert {:ok, linted} =
             Knowledge.lint_repository_wiki_edition(
               fixture.edition,
               [],
               command_attributes(fixture, 1, 3),
               clock: fn -> @now end
             )

    assert linted.report.blocking_count == 0

    metadata = %{hd(start.payload.changes).metadata | graph_revision: 4}

    assert {:ok, close} =
             Knowledge.close_repository_wiki_edition(
               fixture.edition,
               linted.report,
               metadata,
               command_attributes(fixture, 1, 4),
               clock: fn -> @now end
             )

    assert close.command_type == "CloseWikiEdition"
    assert hd(close.payload.changes).operation == :close
    assert {:ok, change_set} = ChangeSet.new(close)
    assert change_set.removals != []

    activate_attributes =
      command_attributes(fixture, 2, 5)
      |> Map.put(:expected_catalog_revision, 1)
      |> Map.put(:enrollment_revision, 1)

    assert {:ok, activation} =
             Knowledge.activate_repository_wiki_edition(
               fixture.edition,
               resolution,
               fixture.profile,
               activate_attributes,
               clock: fn -> @now end
             )

    assert activation.command_type == "ActivateWikiEdition"

    assert activation.expected_graph_revisions == %{
             fixture.catalog_graph => 1,
             fixture.control_graph => 2,
             fixture.edition.graph_iri => 5
           }
  end

  test "rejects automatic admission under manual enrollment and stale source activation",
       fixture do
    current = current_enrollment(fixture)
    resolution = enrollment_resolution(fixture, current)

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.admit_repository_wiki_compilation(
               fixture.edition,
               Map.merge(resolution, %{state: :manual, revision: 1}),
               command_attributes(fixture, 1, 1)
               |> Map.put(:trigger, :automatic_reconciliation)
               |> Map.put(:enrollment_revision, 1),
               clock: fn -> @now end
             )

    stale =
      command_attributes(fixture, 2, 5)
      |> Map.put(:source_fence, "git:sha256:#{digest("stale")}")
      |> Map.put(:expected_catalog_revision, 1)

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.activate_repository_wiki_edition(
               fixture.edition,
               resolution,
               fixture.profile,
               stale,
               clock: fn -> @now end
             )
  end

  test "recovers open and closed editions from RDF alone and rebuilds disposable indexes",
       fixture do
    commands = lifecycle_commands(fixture)

    open_dataset =
      dataset_from_targets(
        [hd(commands.start.payload.changes)] ++
          Enum.map(commands.appends, &hd(&1.payload.changes)),
        fixture.edition.graph_iri
      )

    authority = recovery_authority(fixture)

    assert {:ok, open} =
             Knowledge.recover_repository_wiki(open_dataset, fixture.edition.iri, authority)

    assert open.recovery_status == :resumable
    assert open.next_segment_index == length(fixture.segments)
    assert open.reconstructed_from == :rdf_only

    assert {:ok, abandoned} =
             Knowledge.recover_repository_wiki(
               open_dataset,
               fixture.edition.iri,
               %{authority | source_fence: "git:sha256:#{digest("new-source")}"}
             )

    assert abandoned.recovery_status == :abandoned
    refute abandoned.visible?

    closed_dataset =
      dataset_from_targets(
        [hd(commands.start.payload.changes)] ++
          Enum.map(commands.appends, &hd(&1.payload.changes)) ++
          [
            hd(commands.finalize.payload.changes),
            hd(commands.linted.command.payload.changes),
            hd(commands.close.payload.changes)
          ],
        fixture.edition.graph_iri
      )

    assert {:ok, closed} =
             Knowledge.recover_repository_wiki(
               closed_dataset,
               fixture.edition.iri,
               %{authority | current_edition_iri: fixture.edition.iri, read_visibility: :retained}
             )

    assert closed.recovery_status == :closed
    assert closed.visible?
    refute closed.resumable?

    assert {:ok, indexes} =
             Knowledge.rebuild_repository_wiki_indexes(closed_dataset, fixture.edition.iri)

    assert length(indexes.navigation) == 7
    assert indexes.disposable?
    assert indexes.rebuilt_from == :rdf_only
  end

  test "pins retention, backup, and fail-closed restore invariants", fixture do
    classes = Knowledge.repository_wiki_retention_classes()
    assert classes.current.backup
    refute classes.preview.backup
    refute classes.incomplete.readable
    assert classes.accounting.backup
    assert classes.audit.backup

    audit = resource(:cross_repository_audit, "wiki-backup-audit")

    assert {:ok, manifest} =
             Knowledge.repository_wiki_backup_manifest(%{
               repository_iri: fixture.repository,
               tenant_iri: fixture.tenant,
               enrollment_iri: resource(:repository_wiki_enrollment, "wiki-backup-enrollment"),
               edition_iri: fixture.edition.iri,
               graph_iri: fixture.edition.graph_iri,
               source_snapshot_iri: fixture.snapshot,
               source_fence: fixture.source_fence,
               compiler_profile: fixture.edition.compiler_profile,
               compiler_digest: fixture.edition.compiler_digest,
               lineage: [],
               current_pointer: fixture.edition.iri,
               retention_class: :current,
               audit_iris: [audit]
             })

    assert manifest.restore_order == [
             :repository_control,
             :repository_wiki,
             :render_cache,
             :search_index
           ]

    valid_restore = %{
      current_edition_iris: [fixture.edition.iri],
      enrollment_state: :manual,
      repository_iri: fixture.repository,
      edition_repository_iri: fixture.repository,
      audit_iris: [audit],
      graph_lifecycle: :closed
    }

    assert :ok = Knowledge.verify_repository_wiki_restore(valid_restore)

    assert {:error, %{kind: :corrupt}} =
             Knowledge.verify_repository_wiki_restore(%{
               valid_restore
               | current_edition_iris: [fixture.edition.iri, fixture.edition.iri <> "/other"]
             })

    assert {:error, %{kind: :corrupt}} =
             Knowledge.verify_repository_wiki_restore(%{valid_restore | enrollment_state: :off})
  end

  defp lifecycle_commands(fixture) do
    {:ok, start} =
      Knowledge.start_repository_wiki_edition(
        fixture.edition,
        command_attributes(fixture, 1, 0),
        clock: fn -> @now end
      )

    appends =
      Enum.with_index(fixture.segments, 1)
      |> Enum.map(fn {segment, revision} ->
        {:ok, command} =
          Knowledge.append_repository_wiki_segment(
            segment,
            command_attributes(fixture, 1, revision),
            clock: fn -> @now end
          )

        command
      end)

    final_revision = length(appends) + 1

    {:ok, finalize} =
      Knowledge.finalize_repository_wiki_edition(
        fixture.edition,
        fixture.segments,
        command_attributes(fixture, 1, final_revision),
        clock: fn -> @now end
      )

    {:ok, linted} =
      Knowledge.lint_repository_wiki_edition(
        fixture.edition,
        [],
        command_attributes(fixture, 1, final_revision + 1),
        clock: fn -> @now end
      )

    metadata = %{hd(start.payload.changes).metadata | graph_revision: final_revision + 2}

    {:ok, close} =
      Knowledge.close_repository_wiki_edition(
        fixture.edition,
        linted.report,
        metadata,
        command_attributes(fixture, 1, final_revision + 2),
        clock: fn -> @now end
      )

    %{start: start, appends: appends, finalize: finalize, linted: linted, close: close}
  end

  defp current_enrollment(fixture) do
    {:ok, enrollment} =
      Knowledge.repository_wiki_enrollment(%{
        repository_iri: fixture.repository,
        tenant_iri: fixture.tenant,
        revision: 1,
        state: :manual,
        generation_profile: fixture.profile,
        generation_mode: :deterministic_only,
        preview_mode: :disabled,
        read_visibility: :retained,
        cancellation_generation: 0,
        current_edition_iri: nil,
        recorded_at: @now
      })

    enrollment
  end

  defp enrollment_resolution(fixture, current) do
    %{
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      current_state: :manual,
      current_revision: 1,
      current_enrollment_iri: current.iri,
      current_transition_iri: resource(:control_transition, "wiki-edition-current-transition"),
      cancellation_generation: 0,
      current_edition_iri: nil,
      read_visibility: :retained
    }
  end

  defp inventory_attributes(fixture) do
    %{
      repository_iri: fixture.repository,
      source_snapshot_iri: fixture.snapshot,
      source_fence: fixture.source_fence,
      accepted_graph_sources: [
        %{
          repository_iri: fixture.repository,
          graph_iri: fixture.control_graph,
          resource_iri: resource(:control_constraint, "edition-accepted-fact"),
          revision: 1,
          digest: digest("edition-accepted-fact")
        }
      ],
      limits: SourceInventory.profile().limits
    }
  end

  defp command_attributes(fixture, control_revision, wiki_revision) do
    %{
      repository_iri: fixture.repository,
      catalog_graph_iri: fixture.catalog_graph,
      control_graph_iri: fixture.control_graph,
      wiki_graph_iri: fixture.edition.graph_iri,
      expected_catalog_revision: 1,
      expected_control_revision: control_revision,
      expected_wiki_revision: wiki_revision,
      expected_dataset_revision: control_revision + wiki_revision,
      enrollment_revision: 1,
      principal_iri: resource(:authorization_grant, "wiki-edition-principal"),
      actor_iri: resource(:authorization_grant, "wiki-edition-actor"),
      scope_iri: fixture.repository,
      correlation_iri: resource(:authorization_grant, "wiki-edition-correlation"),
      causation_iri: resource(:authorization_grant, "wiki-edition-causation"),
      reason: "compile deterministic repository wiki",
      recorded_at: @now,
      source_fence: fixture.source_fence
    }
  end

  defp recovery_authority(fixture) do
    %{
      enrollment_state: :manual,
      repository_iri: fixture.repository,
      tenant_iri: fixture.tenant,
      source_snapshot_iri: fixture.snapshot,
      source_fence: fixture.source_fence,
      current_edition_iri: nil,
      read_visibility: :hidden
    }
  end

  defp dataset_from_targets(targets, graph_iri) do
    {additions, removals} =
      Enum.reduce(targets, {[], []}, fn target, {added, removed} ->
        {added ++ quadify(target.additions, graph_iri),
         removed ++ quadify(target.removals, graph_iri)}
      end)

    additions
    |> MapSet.new()
    |> MapSet.difference(MapSet.new(removals))
    |> MapSet.to_list()
    |> RDF.Dataset.new()
  end

  defp quadify(statements, graph_iri) do
    Enum.map(statements, fn
      {_subject, _predicate, _object, _graph} = quad -> RDF.Quad.new(quad)
      {subject, predicate, object} -> RDF.Quad.new({subject, predicate, object, graph_iri})
    end)
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(seed), do: :crypto.hash(:sha256, seed) |> Base.encode16(case: :lower)
end
