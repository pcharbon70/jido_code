defmodule JidoCode.Knowledge.Memory.Phase01IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.Contract
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Retention.Planner
  alias JidoCode.Knowledge.Retention.Policy, as: RetentionPolicy
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Validation.ShapeCatalog
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Security.DataPolicy

  @future_families ~w[experience content_lifecycle episode_content]a
  @command_versions ~w[1.0.0 1.1.0 1.2.0 1.3.0 1.4.0 1.5.0 1.6.0 1.7.0 1.8.0]
  @jf "https://jido.run/ontology/factory#"

  test "ratified ontology loads into and reopens from the real dataset", context do
    root = unique_root(context)
    on_exit(fn -> remove_root!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))

    first = start_substrate!(config)

    assert {:ok, loaded} =
             Release.load(version: "1.1.0", store_server: first.server, writer: first.writer)

    assert loaded.version == "1.1.0"

    assert {:ok, %{"https://jido.run/graph/ontology/1.1.0" => 1_474}} =
             StoreServer.request(
               first.server,
               {:graph_counts, ["https://jido.run/graph/ontology/1.1.0"]}
             )

    stop_process(first.writer)
    stop_process(first.server)

    second = start_substrate!(config)
    assert StoreServer.summary(second.server).ready?
    assert StoreServer.summary(second.server).dataset_revision == 1
  end

  test "every current content class has one policy, topology, retention, and derivative posture" do
    assert :ok = DataPolicy.verify()
    assert :ok = RetentionPolicy.verify()

    assert Contract.content_inventory() |> Enum.map(& &1.content_class) |> Enum.sort() ==
             [
               :backup_derivative,
               :command_receipt_commitment,
               :embedded_artifact,
               :export,
               :instruction_content,
               :interaction_message,
               :model_outcome,
               :tool_stdout_stderr
             ]

    Enum.each(Contract.content_inventory(), fn content ->
      assert {:ok, policy} = DataPolicy.rule(content.classification)
      assert policy.outputs != []

      Enum.each(content.current_graphs, fn family ->
        assert DataPolicy.durable_allowed?(content.classification, family)
        assert {:ok, retention_class} = RetentionPolicy.class_for_family(family)
        assert Map.has_key?(RetentionPolicy.classes(), retention_class)
      end)

      if content.current_graphs == [] do
        assert policy.graphs == []
      end
    end)

    assert DataPolicy.output_allowed?(:export_derivative, :authorized_audit)
    assert DataPolicy.output_allowed?(:backup_derivative, :authorized_audit)
    refute DataPolicy.provider_egress_allowed?(:backup_derivative, :approved)
    refute DataPolicy.provider_egress_allowed?(:export_derivative, :approved)
  end

  test "post-MG1 families remain closed and unreachable by legacy commands" do
    {:ok, repository} = ResourceIdentity.repository("memory-phase-01")
    {:ok, attempt} = ResourceIdentity.local(:attempt, 1_000, <<1::80>>)
    {:ok, content} = ResourceIdentity.local(:claim, 1_001, <<2::80>>)

    families = %{
      experience: %{repository: repository},
      content_lifecycle: %{repository: repository},
      episode_content: %{repository: repository, content: content}
    }

    Enum.each(families, fn {family, scopes} ->
      assert {:ok, graph} = GraphRegistry.graph_iri(family, scopes)
      assert {:ok, contract} = GraphRegistry.fetch(family)
      refute contract.enabled
      assert {:ok, _retention} = RetentionPolicy.class_for_family(family)

      assert {:error, %Error{kind: :unauthorized}} =
               GraphRegistry.validate_target(graph, contract.capability)

      assert {:error, %Error{kind: :unauthorized}} =
               GraphRegistry.validate_target(graph, :policy_writer)

      for operation <- [:create, :append, :close, :replace] do
        refute GraphRegistry.write_allowed?(family, operation, %{lifecycle_state: :open})
      end
    end)

    assert {:ok, segment_graph} =
             GraphRegistry.graph_iri(:run_event_segment, %{attempt: attempt, segment: 0})

    assert {:ok, %{enabled: true}} = GraphRegistry.fetch(:run_event_segment)
    assert GraphRegistry.write_allowed?(:run_event_segment, :create)

    assert {:ok, %{family: :run_event_segment}} =
             GraphRegistry.validate_target(segment_graph, :execution_writer)

    assert ShapeCatalog.allowed_class?(:run_event_segment, @jf <> "SegmentManifest")
    assert ShapeCatalog.allowed_class?(:experience, @jf <> "ExperienceCase")
    assert ShapeCatalog.allowed_class?(:content_lifecycle, @jf <> "ContentLifecycleActivity")
    assert ShapeCatalog.allowed_class?(:episode_content, @jf <> "ContentChunk")
    refute ShapeCatalog.allowed_class?(:episode_content, @jf <> "KnowledgeAssertion")
    refute GraphRegistry.allowed_link?(:episode_content, :memory)

    for version <- @command_versions,
        name <- CommandRegistry.names(version) do
      assert {:ok, definition} = CommandRegistry.resolve(name, version)
      refute Enum.any?(@future_families, &(&1 in definition.graph_families))
    end

    refute Enum.any?(QueryCatalog.names(), fn name ->
             name in [
               :attempt_timeline,
               :attempt_capture_completeness,
               :exact_failure_occurrences
             ]
           end)
  end

  test "forbidden bodies, profiles, commitments, and cross-scope candidates fail closed" do
    assert Contract.forbidden_content() == [
             :secret_value,
             :provider_private_state,
             :hidden_reasoning
           ]

    refute DataPolicy.durable_allowed?(:secret_value, :run_attempt)
    refute DataPolicy.durable_allowed?(:prompt, :run_attempt)

    refute DataPolicy.durable_allowed?(
             :tool_output,
             :run_attempt,
             :exact_text,
             :semantic_history
           )

    refute DataPolicy.profile_enabled?(:diagnostic_capture)
    refute DataPolicy.profile_enabled?(:project_total_history)
    refute DataPolicy.profile_enabled?(:incident_hold)
    refute DataPolicy.profile_enabled?(:unknown)
    refute DataPolicy.new_commitment_allowed?(:legacy_unkeyed_digest, :prompt_representation, %{})

    allowed = partition_attributes()
    assert {:ok, repository_partition} = Guardrails.authorize_candidate_partition(allowed)

    assert {:ok, other_partition} =
             Guardrails.authorize_candidate_partition(%{
               allowed
               | repository_iri: "https://jido.run/id/repository/01J00000000000000000000010"
             })

    refute repository_partition.partition_digest == other_partition.partition_digest

    assert {:error, %Error{kind: :unauthorized}} =
             Guardrails.authorize_candidate_partition(%{
               allowed
               | authorization_decision: :denied
             })
  end

  test "archive, removal, erasure, legacy, and receipt commitments remain honest" do
    repository = "https://jido.run/id/repository/01J00000000000000000000020"
    audit = graph!(:security_audit, %{period: "2026-08"})

    observation =
      graph!(:observation_batch, %{
        repository: repository,
        batch: "https://jido.run/id/batch/01J00000000000000000000021"
      })

    derived = graph!(:derived, %{rule_set: "memory-phase-01", revision: 1})
    expired = resource("observation", observation, :observation_batch, 181)

    assert {:error, %Error{kind: :unavailable, operation: :retention_archive_unavailable}} =
             Planner.plan(retention_snapshot([expired], audit))

    disposable = resource("derived", derived, :derived, 1)
    assert {:ok, removal} = Planner.plan(retention_snapshot([disposable], audit))
    assert removal.remove == [disposable.iri]
    assert removal.erase == []
    assert removal.archive == []

    assert {:ok, erasure} =
             [expired]
             |> retention_snapshot(audit)
             |> Map.put(:legal_erase, [expired.iri])
             |> Planner.plan()

    assert erasure.erase == [expired.iri]
    assert erasure.remove == []
    assert erasure.archive == []

    assert Contract.legacy_run_contract().completeness_claim == :bounded_observable_subset
    refute Contract.legacy_run_contract().rewrite_allowed

    assert DataPolicy.new_commitment_allowed?(:ciphertext_commitment, :confidential, %{
             encrypted_before_commit: true
           })

    refute DataPolicy.new_commitment_allowed?(:ciphertext_commitment, :secret_value, %{
             encrypted_before_commit: true
           })
  end

  defp start_substrate!(config) do
    readiness = start_child!({Readiness, name: nil})
    writer_name = {:global, {__MODULE__, :writer, make_ref()}}

    server =
      start_child!(
        {StoreServer,
         name: nil,
         readiness: readiness,
         config: config,
         authorized_callers: %{
           read: [self()],
           write: [writer_name],
           maintenance: [self()]
         }}
      )

    assert await_health(server, :ready).ready?
    writer = start_child!({Writer, name: writer_name, store_server: server})
    %{server: server, writer: writer}
  end

  defp start_child!(child) do
    child
    |> Supervisor.child_spec(id: make_ref(), restart: :temporary)
    |> start_supervised!()
  end

  defp stop_process(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
  catch
    :exit, _reason -> :ok
  end

  defp await_health(server, expected, attempts \\ 500)
  defp await_health(server, _expected, 0), do: StoreServer.summary(server)

  defp await_health(server, expected, attempts) do
    summary = StoreServer.summary(server)

    if summary.health_state == expected do
      summary
    else
      Process.sleep(10)
      await_health(server, expected, attempts - 1)
    end
  end

  defp retention_snapshot(resources, audit) do
    graphs = resources |> Enum.map(& &1.graph_iri) |> Enum.uniq()

    %{
      resources: resources,
      roots: [],
      legal_holds: [],
      legal_erase: [],
      dataset_revision: 10,
      graph_revisions: Map.new([audit | graphs], &{&1, 1}),
      actor_iri: "https://jido.run/id/actor/01J00000000000000000000022",
      activity_iri: "https://jido.run/id/activity/01J00000000000000000000023",
      audit_graph_iri: audit,
      rationale: "Verify the ratified total-memory lifecycle contract",
      validation_report_iri: "https://jido.run/id/validation/01J00000000000000000000024"
    }
  end

  defp resource(suffix, graph, family, age_days) do
    iri = "https://jido.run/id/resource/#{suffix}"

    %{
      iri: iri,
      graph_iri: graph,
      family: family,
      age_days: age_days,
      links: [],
      quads: [RDF.quad(iri, "https://jido.run/ontology/factory#displayId", suffix, graph)]
    }
  end

  defp graph!(family, scopes) do
    {:ok, graph} = GraphRegistry.graph_iri(family, scopes)
    graph
  end

  defp partition_attributes do
    %{
      authorization_iri: "https://jido.run/id/authorization/01J00000000000000000000030",
      authorization_decision: :allowed,
      authorization_revision: 1,
      repository_iri: "https://jido.run/id/repository/01J00000000000000000000031",
      tenant_iri: "https://jido.run/id/scope/01J00000000000000000000032",
      actor_scope_iri: "https://jido.run/id/scope/01J00000000000000000000033",
      purpose: :managed_continuity,
      data_ceiling: :confidential,
      effective_time_generation: 1,
      erasure_generation: 1
    }
  end

  defp remove_root!(root, attempts \\ 20)
  defp remove_root!(root, 0), do: File.rm_rf!(root)

  defp remove_root!(root, attempts) do
    case File.rm_rf(root) do
      {:ok, _paths} -> :ok
      {:error, _reason, _path} -> remove_root!(root, attempts - 1)
    end
  end

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-memory-phase-01-#{name}-#{unique}")
  end
end
