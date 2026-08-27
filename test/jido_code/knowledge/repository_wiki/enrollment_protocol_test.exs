defmodule JidoCode.Knowledge.RepositoryWiki.EnrollmentProtocolTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryParameters
  alias JidoCode.Knowledge.RepositoryWiki.Enrollment
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-08-26 17:00:00Z]

  setup do
    {:ok, repository} = ResourceIdentity.conceptual_repository("wiki-enrollment-protocol")
    tenant = resource(:authorization_grant, "wiki-tenant")
    {:ok, catalog_graph} = GraphRegistry.graph_iri(:factory_catalog, %{})
    {:ok, control_graph} = GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    %{
      repository: repository,
      tenant: tenant,
      catalog_graph: catalog_graph,
      control_graph: control_graph
    }
  end

  test "publishes reviewed protocol 2.10.0 and keeps later-effect commands disabled", context do
    assert CommandRegistry.repository_wiki_version() == "2.10.0"
    assert QueryCatalog.repository_wiki_version() == "2.10.0"

    for command <- [
          "RegisterWikiGenerationProfile",
          "TransitionRepositoryWikiEnrollment",
          "AdmitDeterministicWikiCompilation",
          "StartWikiEdition",
          "AppendWikiEditionSegment",
          "FinalizeWikiEdition",
          "RecordWikiLintResult",
          "CloseWikiEdition",
          "MarkWikiEditionStale",
          "InvalidateWikiEdition",
          "ActivateWikiEdition"
        ] do
      assert {:ok, %{name: ^command, version: "2.10.0"}} =
               CommandRegistry.resolve(command, "2.10.0")
    end

    for command <- Protocol.reserved_commands() do
      assert {:ok, %{availability: :reserved_disabled}} =
               CommandRegistry.resolve(command, "2.10.0")

      assert {:error, %{kind: :invalid_input, operation: :command_envelope}} =
               CommandEnvelope.new(
                 reserved_command_attributes(command, context),
                 clock: fn -> @now end
               )
    end

    assert {:error, %{kind: :invalid_input}} =
             CommandRegistry.resolve("StartWikiEdition", "2.9.0")

    for query <- [
          :repository_wiki_enrollment_detail,
          :repository_wiki_current_edition,
          :repository_wiki_edition_history,
          :repository_wiki_page_detail,
          :repository_wiki_generation_profiles,
          :repository_wiki_navigation_tree,
          :repository_wiki_page_by_slug,
          :repository_wiki_backlinks,
          :repository_wiki_source_references,
          :repository_wiki_dependency_lookup,
          :repository_wiki_guide_collection,
          :repository_wiki_known_gaps,
          :repository_wiki_source_coverage,
          :repository_wiki_freshness,
          :repository_wiki_compilation_status
        ] do
      assert query in QueryCatalog.names("2.10.0")
      refute query in QueryCatalog.names("2.9.0")
      assert {:ok, %{version: "2.10.0"}} = QueryCatalog.fetch(query, "2.10.0")
    end

    assert :ok = QueryCatalog.verify()
  end

  test "absent configuration is repository-local off with no read or generation surface",
       context do
    assert {:ok, first} = Knowledge.repository_wiki_default(context.repository, context.tenant)

    other_repository = repository("other-wiki")
    assert {:ok, other} = Knowledge.repository_wiki_default(other_repository, context.tenant)

    assert first.state == :off
    refute first.configured?
    refute first.generation_allowed?
    refute first.retained_readable?
    refute first.product_available?
    refute first.wiki_iri == other.wiki_iri
  end

  test "constructs only the two exact zero-model generation profiles", context do
    assert {:ok, manual} = profile(:manual_deterministic)
    assert {:ok, automatic} = profile(:automatic_deterministic)

    assert manual.maintenance_mode == :manual
    assert automatic.maintenance_mode == :automatic
    assert manual.generation_mode == :deterministic_only
    assert manual.preview_mode == :disabled
    assert manual.compiler_profile == "wiki-deterministic-elixir/1.0.0"
    assert manual.compiler_digest == Protocol.compiler_digest()
    refute manual.iri == automatic.iri

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.wiki_generation_profile(:manual_synthesis, %{approved_at: @now})

    attributes = command_attributes(context)

    assert {:ok, command} =
             Knowledge.register_wiki_generation_profile(manual, attributes, clock: fn -> @now end)

    assert command.command_type == "RegisterWikiGenerationProfile"
    assert command.command_version == "2.10.0"
    assert command.ontology_version == "1.5.0"
    assert get_in(command.payload, [:changes, Access.at(0), :family]) == :factory_catalog
  end

  test "enrolls from absent through off to manual in one revision-fenced command", context do
    {:ok, manual} = profile(:manual_deterministic)

    attributes =
      context
      |> command_attributes()
      |> Map.put(:generation_profile, manual)
      |> Map.put(:read_visibility, :retained)

    assert {:ok, command} =
             Knowledge.transition_repository_wiki_enrollment(
               context.repository,
               context.tenant,
               nil,
               :manual,
               attributes,
               clock: fn -> @now end
             )

    assert command.command_type == "TransitionRepositoryWikiEnrollment"

    assert command.expected_graph_revisions == %{
             context.catalog_graph => 1,
             context.control_graph => 1
           }

    changes = get_in(command.payload, [:changes, Access.at(0)])
    assert changes.family == :repository_control

    transition_states =
      changes.additions
      |> Enum.filter(fn {_subject, predicate, _object} ->
        predicate == "https://jido.run/ontology/factory#nextState"
      end)
      |> Enum.map(fn {_subject, _predicate, object} -> RDF.IRI.to_string(object) end)

    assert transition_states == [
             "https://jido.run/ontology/concept/RepositoryWikiEnrollmentOff",
             "https://jido.run/ontology/concept/RepositoryWikiEnrollmentManual"
           ]

    assert {:error, %{kind: :invalid_input}} =
             Knowledge.transition_repository_wiki_enrollment(
               context.repository,
               context.tenant,
               nil,
               :automatic,
               attributes,
               clock: fn -> @now end
             )
  end

  test "disable advances the fence, rejects future work, and retains distinct history policy",
       context do
    {:ok, manual} = profile(:manual_deterministic)
    {:ok, edition} = ResourceIdentity.wiki_edition(context.repository, digest("edition"))

    assert {:ok, current} =
             Knowledge.repository_wiki_enrollment(%{
               repository_iri: context.repository,
               tenant_iri: context.tenant,
               revision: 4,
               state: :manual,
               generation_profile: manual,
               generation_mode: :deterministic_only,
               preview_mode: :disabled,
               read_visibility: :retained,
               cancellation_generation: 2,
               current_edition_iri: edition,
               recorded_at: @now
             })

    assert Enrollment.generation_allowed?(current, :manual_request)
    assert Enrollment.retained_readable?(current)
    assert Enrollment.product_available?(current)

    resolution = %{
      repository_iri: context.repository,
      tenant_iri: context.tenant,
      current_state: :manual,
      current_revision: 4,
      current_enrollment_iri: current.iri,
      current_transition_iri: resource(:control_transition, "wiki-current-transition"),
      cancellation_generation: 2,
      current_edition_iri: edition
    }

    attributes =
      context
      |> command_attributes()
      |> Map.put(:generation_profile, nil)
      |> Map.put(:read_visibility, :retained)

    assert {:ok, command} =
             Knowledge.transition_repository_wiki_enrollment(
               context.repository,
               context.tenant,
               resolution,
               :off,
               attributes,
               clock: fn -> @now end
             )

    assert :advance_cancellation_fence in command.payload.disable_effects
    assert :release_effect_free_reservations in command.payload.disable_effects
    assert :preserve_accounting_and_audit_history in command.payload.disable_effects

    additions = get_in(command.payload, [:changes, Access.at(0), :additions])

    assert Enum.any?(additions, fn {_subject, predicate, object} ->
             predicate == "https://jido.run/ontology/factory#wikiCancellationGeneration" and
               RDF.Literal.value(object) == 3
           end)
  end

  test "binds exact reviewed graphs and rejects a graph from another family", context do
    {:ok, definition} =
      QueryCatalog.fetch(:repository_wiki_current_edition, "2.10.0")

    {:ok, edition} = ResourceIdentity.wiki_edition(context.repository, digest("query-edition"))

    {:ok, wiki_graph} =
      GraphRegistry.graph_iri(:repository_wiki, %{
        repository: context.repository,
        edition: edition
      })

    parameters = %{
      control_graph: context.control_graph,
      wiki_graph: wiki_graph,
      resource: context.repository
    }

    assert {:ok, bound} = QueryParameters.bind(definition, parameters)
    assert bound.graph_iris == Enum.sort([context.control_graph, wiki_graph])
    refute bound.query =~ "{{"

    assert {:error, %{kind: :invalid_input}} =
             QueryParameters.bind(definition, %{parameters | wiki_graph: context.catalog_graph})
  end

  defp profile(key), do: Knowledge.wiki_generation_profile(key, %{approved_at: @now})

  defp command_attributes(context) do
    %{
      catalog_graph_iri: context.catalog_graph,
      control_graph_iri: context.control_graph,
      expected_catalog_revision: 1,
      expected_control_revision: 1,
      expected_dataset_revision: 1,
      principal_iri: resource(:authorization_grant, "wiki-principal"),
      actor_iri: resource(:authorization_grant, "wiki-actor"),
      scope_iri: context.repository,
      correlation_iri: resource(:authorization_grant, "wiki-correlation"),
      causation_iri: resource(:authorization_grant, "wiki-causation"),
      reason: "configure repository wiki",
      recorded_at: @now
    }
  end

  defp reserved_command_attributes(command, context) do
    attributes = command_attributes(context)

    %{
      command_type: command,
      command_version: "2.10.0",
      command_iri: resource(:command_request, "reserved-#{command}"),
      principal_iri: attributes.principal_iri,
      actor_iri: attributes.actor_iri,
      delegated_agent_iri: nil,
      delegation_iri: nil,
      scope_iri: context.repository,
      idempotency_key: "reserved-#{command}",
      correlation_iri: attributes.correlation_iri,
      causation_iri: attributes.causation_iri,
      ontology_version: "1.5.0",
      shape_version: "1.5.0",
      expected_dataset_revision: 1,
      expected_graph_revisions: %{context.control_graph => 1},
      reason: "reserved command must remain disabled",
      payload: %{}
    }
  end

  defp repository(seed) do
    {:ok, iri} = ResourceIdentity.conceptual_repository(seed)
    iri
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(seed), do: :crypto.hash(:sha256, seed) |> Base.encode16(case: :lower)
end
