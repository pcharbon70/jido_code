defmodule JidoCode.TestSupport.Phase06Fixture do
  @moduledoc false

  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Observations.Command, as: ObservationCommand
  alias JidoCode.Factory.Observations.Ingress
  alias JidoCode.Factory.Observations.ProviderObservation
  alias JidoCode.Factory.RepositoryLocator, as: ExternalLocator
  alias JidoCode.Factory.SourceAnalysis.Command, as: SourceCommand
  alias JidoCode.Factory.SourceAnalysis.Request
  alias JidoCode.Integrations.ElixirSourceAnalyzer
  alias JidoCode.Integrations.FakeRepositoryProvider
  alias JidoCode.Integrations.GitRepository
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Repositories.Enrollment
  alias JidoCode.Knowledge.Repositories.EnrollmentTransition
  alias JidoCode.Knowledge.Repositories.Locator
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture

  @provider "https://github.com"
  @external_id "R_phase_06_integration"

  def complete!(context) do
    fixture = context |> Phase04Fixture.start!() |> Phase04Fixture.bootstrap!()
    fixture = prepare_git!(fixture)
    fixture = prepare_identity!(fixture)
    fixture = enroll!(fixture)
    fixture = provider_observation!(fixture, "initial-poll", fixture.git_snapshot)
    fixture = analyze_and_publish!(fixture, fixture.worktree, fixture.git_snapshot)

    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: fixture.actor,
        actor_iri: fixture.actor,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    Map.put(fixture, :authority, authority)
  end

  def provider_observation!(fixture, poll_identity, snapshot, options \\ []) do
    source_time = Keyword.get(options, :source_time, fixture.issued_at)
    completeness = Keyword.get(options, :completeness, :complete)
    availability = Keyword.get(options, :availability, true)

    repository_observation =
      provider_value!(%{
        kind: :repository,
        external_id: @external_id,
        source_time: source_time,
        retrieved_at: fixture.issued_at,
        etag: "etag-#{poll_identity}",
        source_revision: snapshot.commit_sha,
        response_digest: digest("repository-#{poll_identity}"),
        data: %{
          default_branch: "main",
          visibility: "private",
          archived: false,
          fork: false,
          availability: availability
        },
        completeness: completeness(completeness),
        limitations: if(completeness == :complete, do: [], else: ["partial_provider_page"]),
        warnings: if(completeness == :complete, do: [], else: ["pagination_incomplete"])
      })

    branch_observation =
      provider_value!(%{
        kind: :branch,
        external_id: "refs/heads/main",
        source_time: source_time,
        retrieved_at: fixture.issued_at,
        etag: nil,
        source_revision: snapshot.commit_sha,
        response_digest: digest("branch-#{poll_identity}"),
        data: %{name: "refs/heads/main", commit_sha: snapshot.commit_sha},
        completeness: completeness(completeness),
        limitations: [],
        warnings: []
      })

    {:ok, provider} =
      FakeRepositoryProvider.new(%{
        {:repository, @external_id} => %{
          observations: [repository_observation, branch_observation],
          next_cursor: nil
        }
      })

    {:ok, %{observations: observations}} =
      FakeRepositoryProvider.observe_repository(
        provider,
        fixture.external_locator,
        fixture.credential_reference,
        []
      )

    {:ok, envelope} =
      Ingress.poll(%{
        enrollment: fixture.enrollment_resolution,
        locator: fixture.external_locator,
        observations: observations,
        retrieved_at: fixture.issued_at,
        poll_identity: poll_identity
      })

    {:ok, observation} =
      ObservationCommand.build(
        envelope,
        observation_context(fixture, snapshot),
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, observation.command)

    fixture
    |> Map.put(:provider_observations, observations)
    |> Map.put(:observation_envelope, envelope)
    |> Map.put(:observation, observation)
    |> Map.put(:observation_receipt, receipt)
  end

  def analyze_and_publish!(fixture, worktree, snapshot) do
    result = analyze!(fixture, worktree, snapshot)
    publication = publication_command!(fixture, result, snapshot)

    {:ok, receipt} = Writer.execute(fixture.writer, publication.command)

    fixture
    |> Map.put(:analysis_result, result)
    |> Map.put(:publication, publication)
    |> Map.put(:publication_receipt, receipt)
  end

  def publication_command!(fixture, result, snapshot) do
    {:ok, publication} =
      SourceCommand.build(
        result,
        publication_context(fixture, snapshot),
        clock: fn -> fixture.issued_at end
      )

    publication
  end

  def analyze!(fixture, worktree, snapshot) do
    {:ok, snapshot_iri} =
      ResourceIdentity.repository_snapshot(
        fixture.repository,
        snapshot.object_format,
        snapshot.tree_sha
      )

    {:ok, source_graph} = Knowledge.source_graph_identity(fixture.repository, snapshot_iri)

    {:ok, request} =
      Request.new(%{
        repository_iri: fixture.repository,
        snapshot_iri: snapshot_iri,
        worktree: worktree,
        git_snapshot: snapshot,
        profile: :elixir,
        include_paths: ["lib"],
        exclude_paths: ["deps", "_build"],
        limits: %{
          max_files: 20,
          max_total_bytes: 100_000,
          max_file_bytes: 20_000,
          max_symbols: 50,
          max_expressions: 10_000,
          max_statements: 400,
          timeout_ms: 5_000
        },
        ontology_version: "1.0.0",
        output_graph_iri: source_graph,
        input_tree_digest: snapshot.tree_sha
      })

    {:ok, analyzer} = ElixirSourceAnalyzer.new()
    {:ok, result} = ElixirSourceAnalyzer.analyze(analyzer, request)
    result
  end

  def rematerialize!(fixture, operation_id, ref) do
    {:ok, worktree} =
      GitRepository.materialize(fixture.git_adapter, %{
        remote: fixture.source_repository,
        ref: ref,
        operation_id: operation_id,
        depth: 10
      })

    {:ok, snapshot} = GitRepository.inspect_snapshot(fixture.git_adapter, worktree)
    {worktree, snapshot}
  end

  def force_push!(fixture) do
    transient_path = Path.join(fixture.source_repository, "lib/transient.ex")
    File.write!(transient_path, "defmodule Integration.Transient do\nend\n")
    git!(fixture.source_repository, ["add", "lib/transient.ex"])
    git_commit!(fixture.source_repository, "transient", "2026-08-01T15:01:00Z")
    transient_commit = git_output!(fixture.source_repository, ["rev-parse", "HEAD"])

    git!(fixture.source_repository, ["reset", "--hard", fixture.initial_commit])

    File.write!(
      Path.join(fixture.source_repository, "lib/server.ex"),
      source_body("replacement")
    )

    git!(fixture.source_repository, ["add", "lib/server.ex"])
    git_commit!(fixture.source_repository, "replacement", "2026-08-01T15:02:00Z")
    replacement_commit = git_output!(fixture.source_repository, ["rev-parse", "HEAD"])
    {worktree, snapshot} = rematerialize!(fixture, "force-pushed", "refs/heads/main")

    %{
      worktree: worktree,
      snapshot: snapshot,
      transient_commit: transient_commit,
      replacement_commit: replacement_commit
    }
  end

  def transition!(fixture, next_state, sequence, extra \\ %{}) do
    command_iri = Phase04Fixture.local!(:command, 660 + sequence)

    attributes =
      %{
        command_iri: command_iri,
        principal_iri: fixture.actor,
        actor_iri: fixture.actor,
        factory_scope_iri: fixture.factory_scope,
        idempotency_key: "phase-06-lifecycle-#{sequence}",
        correlation_iri: Phase04Fixture.local!(:activity, 660 + sequence),
        causation_iri: fixture.enrollment_resolution.current_transition,
        expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
        catalog_graph_iri: fixture.graphs.catalog,
        expected_catalog_revision:
          Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.catalog),
        reason: "phase 06 lifecycle transition #{next_state}",
        next_state: next_state,
        recorded_at: DateTime.add(fixture.issued_at, sequence, :second)
      }
      |> Map.merge(extra)

    {:ok, transition} =
      Enrollment.change_command(fixture.enrollment_resolution, attributes,
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, transition.command)
    transitions = fixture.transitions ++ [transition.transition]
    {:ok, resolution} = EnrollmentTransition.resolve(transitions)

    fixture
    |> Map.put(:transitions, transitions)
    |> Map.put(:enrollment_resolution, resolution)
    |> Map.put(:lifecycle_receipt, receipt)
  end

  def query(fixture, name, parameters, scope \\ nil) do
    QueryRunner.execute(
      name,
      "1.1.0",
      parameters,
      fixture.authority,
      scope || fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  def graph_digest(dataset, graph) do
    case RDF.Dataset.graph(dataset, RDF.iri(graph)) do
      nil ->
        nil

      graph_data ->
        graph_data
        |> RDF.Graph.triples()
        |> RDF.Graph.new()
        |> RDF.NTriples.write_string!(sort: true)
        |> digest()
    end
  end

  def canonical_dataset(%{dataset: dataset}), do: RDF.NQuads.write_string!(dataset, sort: true)

  def observation_context(fixture, snapshot) do
    %{
      repository_iri: fixture.repository,
      repository_scope_iri: fixture.repository_scope,
      locator_iri: fixture.knowledge_locator.iri,
      enrollment: %{
        enrollment_iri: fixture.enrollment.iri,
        current_transition: fixture.enrollment_resolution.current_transition,
        current_state: fixture.enrollment_resolution.current_state,
        admission: fixture.enrollment_resolution.admission,
        catalog_graph_iri: fixture.graphs.catalog,
        catalog_revision: Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.catalog)
      },
      actor_iri: fixture.actor,
      principal_iri: fixture.actor,
      adapter_iri: fixture.adapter_iri,
      adapter_version: "fake-provider/1.0.0",
      git_snapshot: snapshot,
      correlation_iri: Phase04Fixture.local!(:activity, 650),
      causation_iri: fixture.enrollment_command.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      reason: "record Phase 6 repository observation"
    }
  end

  defp prepare_git!(fixture) do
    repository_root = Path.join(fixture.root, "repositories")
    source = Path.join(repository_root, "managed-repository")
    operation_root = Path.join(fixture.root, "operations")
    File.mkdir_p!(Path.join(source, "lib"))
    git!(source, ["init", "--initial-branch=main"])
    File.write!(Path.join(source, "mix.exs"), "defmodule Integration.MixProject do\nend\n")
    File.write!(Path.join(source, "lib/server.ex"), source_body("initial"))
    git!(source, ["add", "mix.exs", "lib/server.ex"])
    git_commit!(source, "initial", "2026-08-01T15:00:00Z")
    initial_commit = git_output!(source, ["rev-parse", "HEAD"])

    {:ok, adapter} =
      GitRepository.new(
        operation_root: operation_root,
        allow_local_fixture?: true,
        fixture_root: repository_root,
        max_disk_bytes: 20_000_000,
        clock: fn -> fixture.issued_at end
      )

    {worktree, snapshot} =
      fixture
      |> Map.merge(%{git_adapter: adapter, source_repository: source})
      |> rematerialize!("initial", "refs/heads/main")

    Map.merge(fixture, %{
      git_adapter: adapter,
      source_repository: source,
      operation_root: operation_root,
      initial_commit: initial_commit,
      worktree: worktree,
      git_snapshot: snapshot
    })
  end

  defp prepare_identity!(fixture) do
    {:ok, repository} = ResourceIdentity.conceptual_repository("phase-06-managed-integration")
    repository_scope = Phase04Fixture.scope!(:repository, "phase-06-managed-integration")

    locator_attributes = %{
      provider: @provider,
      external_id: @external_id,
      owner: "agentjido",
      name: "managed-integration",
      state: :active,
      observed_at: fixture.issued_at,
      relationships: []
    }

    {:ok, external_locator} = ExternalLocator.new(locator_attributes)
    {:ok, knowledge_locator} = Locator.new(locator_attributes)
    credential_iri = Phase04Fixture.resource!("phase-06-credential-reference")

    {:ok, credential_reference} =
      CredentialReference.new(%{
        iri: credential_iri,
        provider: "github",
        key: "repository/read"
      })

    Map.merge(fixture, %{
      repository: repository,
      repository_scope: repository_scope,
      external_locator: external_locator,
      knowledge_locator: knowledge_locator,
      credential_reference: credential_reference,
      adapter_iri: Phase04Fixture.resource!("phase-06-fake-provider-adapter")
    })
  end

  defp enroll!(fixture) do
    command_iri = Phase04Fixture.local!(:command, 650)

    {:ok, enrollment} =
      Enrollment.new(%{
        factory_iri: fixture.factory_iri,
        repository_iri: fixture.repository,
        repository_scope_iri: fixture.repository_scope,
        policy_boundary_iri: Phase04Fixture.resource!("phase-06-integration-boundary"),
        policy_iris: [Phase04Fixture.resource!("phase-06-integration-policy")],
        locator: fixture.knowledge_locator,
        actor_iri: fixture.actor,
        cause_iri: command_iri,
        reason: "enroll Phase 6 integration repository",
        valid_from: fixture.issued_at,
        valid_to: DateTime.add(fixture.issued_at, 86_400 * 365)
      })

    {:ok, command} =
      Enrollment.enroll_command(
        enrollment,
        %{
          command_iri: command_iri,
          principal_iri: fixture.actor,
          factory_scope_iri: fixture.factory_scope,
          idempotency_key: "phase-06-integration-enrollment",
          correlation_iri: Phase04Fixture.local!(:activity, 650),
          causation_iri: fixture.bootstrap_command_iri,
          expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
          catalog_graph_iri: fixture.graphs.catalog,
          expected_catalog_revision:
            Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.catalog),
          reason: "enroll Phase 6 integration repository"
        },
        clock: fn -> fixture.issued_at end
      )

    {:ok, receipt} = Writer.execute(fixture.writer, command)
    {:ok, resolution} = EnrollmentTransition.resolve(enrollment.transitions)

    Map.merge(fixture, %{
      enrollment: enrollment,
      enrollment_command: command,
      enrollment_receipt: receipt,
      enrollment_resolution: resolution,
      transitions: enrollment.transitions
    })
  end

  defp publication_context(fixture, snapshot) do
    {:ok, snapshot_iri} =
      ResourceIdentity.repository_snapshot(
        fixture.repository,
        snapshot.object_format,
        snapshot.tree_sha
      )

    %{
      repository_iri: fixture.repository,
      repository_scope_iri: fixture.repository_scope,
      snapshot_iri: snapshot_iri,
      observation_graph_iri: fixture.observation.graph_iri,
      observation_graph_revision:
        Phase04Fixture.current_graph_revision!(fixture, fixture.observation.graph_iri),
      tree_digest: snapshot.tree_sha,
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      correlation_iri: Phase04Fixture.local!(:activity, 651),
      causation_iri: fixture.observation.command.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      analyzed_at: fixture.issued_at,
      reason: "publish Phase 6 source semantics"
    }
  end

  defp provider_value!(attributes) do
    {:ok, observation} = ProviderObservation.new(attributes)
    observation
  end

  defp completeness(:complete),
    do: %{status: :complete, covered: ["repository", "branch"], missing: []}

  defp completeness(:partial),
    do: %{status: :partial, covered: ["repository"], missing: ["branch_history"]}

  defp source_body(marker) do
    """
    defmodule Integration.Server do
      use GenServer
      alias Integration.Dependency

      def start_link(argument), do: GenServer.start_link(__MODULE__, argument)
      def handle_call(message, _from, state), do: {:reply, Dependency.value(message), state}
      def revision, do: \"#{marker}\"
    end

    defmodule Integration.Dependency do
      def value(message), do: message
    end
    """
  end

  defp git_commit!(path, message, timestamp) do
    env = [
      {"GIT_AUTHOR_DATE", timestamp},
      {"GIT_COMMITTER_DATE", timestamp},
      {"TZ", "UTC"}
    ]

    {_output, 0} =
      System.cmd(
        "git",
        [
          "-c",
          "user.name=Phase Six",
          "-c",
          "user.email=phase-six@example.invalid",
          "commit",
          "-m",
          message
        ],
        cd: path,
        env: env,
        stderr_to_stdout: true
      )

    :ok
  end

  defp git!(path, arguments) do
    {_output, 0} = System.cmd("git", arguments, cd: path, stderr_to_stdout: true)
    :ok
  end

  defp git_output!(path, arguments) do
    {output, 0} = System.cmd("git", arguments, cd: path, stderr_to_stdout: true)
    String.trim(output)
  end

  defp digest(value) do
    value |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
  end
end
