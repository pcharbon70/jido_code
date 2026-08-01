defmodule JidoCode.Factory.Phase06AdapterBoundariesTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Observations.GitSnapshot
  alias JidoCode.Factory.Observations.Ingress
  alias JidoCode.Factory.Observations.ProviderObservation
  alias JidoCode.Factory.RepositoryLocator
  alias JidoCode.Integrations.FakeGit
  alias JidoCode.Integrations.FakeRepositoryProvider
  alias JidoCode.Integrations.GitRepository
  alias JidoCode.Integrations.ReqRepositoryProvider
  alias JidoCode.Knowledge.ResourceIdentity

  @observed_at ~U[2026-08-01 14:00:00Z]

  test "Req adapter returns bounded normalized repository evidence and redacts call-scoped data" do
    owner = self()
    credential = credential!()
    locator = locator!()
    secret = Enum.join(["phase", "six", "credential"], "-")

    body =
      Jason.encode!(%{
        "id" => locator.external_id,
        "node_id" => "R_node",
        "name" => "jido_code",
        "full_name" => "agentjido/jido_code",
        "owner" => %{"login" => "agentjido"},
        "default_branch" => "main",
        "visibility" => "private",
        "archived" => false,
        "disabled" => false,
        "fork" => false,
        "permissions" => %{"push" => true, "pull" => true},
        "updated_at" => "2026-08-01T13:59:00Z",
        "private_url" => "https://private.invalid/repository",
        "future_field" => %{"ignored" => true}
      })

    request_fun = fn options ->
      send(owner, {:request_options, options})

      {:ok,
       %Req.Response{
         status: 200,
         headers: %{
           "etag" => ["repository-etag"],
           "x-github-api-version" => ["2022-11-28"]
         },
         body: body
       }}
    end

    assert {:ok, adapter} =
             ReqRepositoryProvider.new(
               base_url: "https://api.github.test/",
               request_fun: request_fun,
               max_retries: 1
             )

    assert {:ok, %{observations: [observation], next_cursor: nil}} =
             ReqRepositoryProvider.observe_repository(adapter, locator, credential,
               secret_provider: fn ^credential -> {:ok, secret} end,
               clock: fn -> @observed_at end
             )

    assert observation.kind == :repository
    assert observation.external_id == locator.external_id
    assert observation.etag == "repository-etag"
    assert observation.data.default_branch == "main"
    assert observation.data.visibility == "private"
    assert observation.completeness.status == :complete
    assert "unknown_fields_ignored" in observation.warnings

    rendered = inspect(observation)
    refute String.contains?(rendered, secret)
    refute String.contains?(rendered, "private.invalid")
    refute Map.has_key?(observation.data, :private_url)

    assert_receive {:request_options, options}
    assert Keyword.fetch!(options, :receive_timeout) == 5_000
    assert Keyword.fetch!(options, :max_retries) == 1
    assert Keyword.fetch!(options, :redirect) == false
    assert Keyword.fetch!(options, :decode_body) == false

    assert {"authorization", "Bearer " <> ^secret} =
             Enum.find(Keyword.fetch!(options, :headers), &(elem(&1, 0) == "authorization"))
  end

  test "Req pagination is bounded and provider failures are explicit" do
    locator = locator!()
    credential = credential!()
    secret = Enum.join(["ephemeral", "test", "value"], "-")

    request_fun = fn options ->
      page = options |> Keyword.fetch!(:params) |> Keyword.fetch!(:page)

      items =
        if page == 1 do
          [
            %{"id" => 1, "number" => 1, "state" => "open"},
            %{"id" => 2, "number" => 2, "state" => "closed"}
          ]
        else
          [%{"id" => 3, "number" => 3, "state" => "open"}]
        end

      {:ok, %Req.Response{status: 200, headers: %{}, body: Jason.encode!(items)}}
    end

    assert {:ok, adapter} =
             ReqRepositoryProvider.new(
               base_url: "https://api.github.test/",
               request_fun: request_fun,
               page_size: 2,
               max_pages: 2
             )

    assert {:ok, %{observations: observations, next_cursor: nil}} =
             ReqRepositoryProvider.observe_collection(
               adapter,
               :issues,
               locator,
               credential,
               nil,
               secret_provider: fn _reference -> {:ok, secret} end,
               clock: fn -> @observed_at end
             )

    assert Enum.map(observations, & &1.external_id) == ["1", "2", "3"]

    rate_fun = fn _options ->
      {:ok, %Req.Response{status: 403, headers: %{"x-ratelimit-remaining" => ["0"]}, body: ""}}
    end

    assert {:ok, rate_adapter} =
             ReqRepositoryProvider.new(
               base_url: "https://api.github.test/",
               request_fun: rate_fun
             )

    assert {:error, %{kind: :unavailable, operation: :provider_rate_limit}} =
             ReqRepositoryProvider.observe_repository(rate_adapter, locator, credential,
               secret_provider: fn _reference -> {:ok, secret} end,
               clock: fn -> @observed_at end
             )
  end

  test "provider observation values reject credentials, raw bodies, paths, and graph placement" do
    base = observation_attributes()

    for forbidden <- [
          %{token: "value"},
          %{authorization: "value"},
          %{raw: "body"},
          %{local_path: "/tmp/repository"},
          %{graph_iri: "https://jido.run/graph/factory/catalog"}
        ] do
      assert {:error, %{kind: :invalid_input}} =
               ProviderObservation.new(%{base | data: forbidden})
    end
  end

  test "webhook and polling ingress share stable bounded semantics" do
    locator = locator!()
    enrollment = active_enrollment!()
    secret = Enum.join(["signed", "delivery", "value"], "-")

    body =
      Jason.encode!(%{
        "ref" => "refs/heads/main",
        "before" => String.duplicate("a", 40),
        "after" => String.duplicate("b", 40),
        "forced" => true,
        "repository" => %{
          "id" => locator.external_id,
          "updated_at" => "2026-08-01T13:59:30Z"
        }
      })

    signature =
      "sha256=" <>
        (:crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower))

    attributes = %{
      enrollment: enrollment,
      locator: locator,
      content_type: "application/json; charset=utf-8",
      body: body,
      signature: signature,
      secret: secret,
      delivery_id: "delivery-phase-06",
      event: "push",
      delivered_at: DateTime.add(@observed_at, -30),
      received_at: @observed_at
    }

    assert {:ok, first} = Ingress.webhook(attributes)
    assert {:ok, replay} = Ingress.webhook(attributes)
    assert first.delivery_identity == replay.delivery_identity
    assert first.observations == replay.observations
    assert first.observations |> hd() |> Map.fetch!(:data) |> Map.fetch!(:forced)

    assert {:error, %{kind: :unauthorized, operation: :webhook_signature}} =
             Ingress.webhook(%{attributes | signature: "sha256=" <> String.duplicate("0", 64)})

    assert {:error, %{kind: :unauthorized, operation: :webhook_delivery_time}} =
             Ingress.webhook(%{attributes | delivered_at: DateTime.add(@observed_at, -600)})

    assert {:error, %{kind: :conflict, operation: :observation_enrollment_inactive}} =
             Ingress.webhook(%{
               attributes
               | enrollment: %{enrollment | admission: {:blocked, :suspended}}
             })

    [observation] = first.observations

    poll_attributes = %{
      enrollment: enrollment,
      locator: locator,
      observations: [observation],
      retrieved_at: @observed_at,
      poll_identity: "poll-window-2026-08-01T14:00Z"
    }

    assert {:ok, poll} = Ingress.poll(poll_attributes)
    assert {:ok, duplicate_poll} = Ingress.poll(poll_attributes)
    assert poll.delivery_identity == duplicate_poll.delivery_identity
    assert poll.observations == first.observations
    assert poll.source == :poll
    assert first.source == :webhook
  end

  test "Git adapter recreates an identical snapshot after cleanup and rejects unsafe input",
       context do
    root = Path.join(System.tmp_dir!(), "jido-code-phase-06-git-#{context.test}")
    fixture_root = Path.join(root, "fixtures")
    operation_root = Path.join(root, "operations")
    source = Path.join(fixture_root, "repository")
    File.mkdir_p!(source)
    on_exit(fn -> File.rm_rf(root) end)

    git!(source, ["init", "--initial-branch=main"])
    File.write!(Path.join(source, "mix.exs"), "defmodule Fixture.MixProject do\nend\n")
    git!(source, ["add", "mix.exs"])

    git!(source, [
      "-c",
      "user.name=Phase Six",
      "-c",
      "user.email=phase-six@example.invalid",
      "commit",
      "-m",
      "fixture"
    ])

    assert {:ok, adapter} =
             GitRepository.new(
               operation_root: operation_root,
               allow_local_fixture?: true,
               fixture_root: fixture_root,
               max_disk_bytes: 20_000_000,
               clock: fn -> @observed_at end
             )

    assert {:ok, first_worktree} =
             GitRepository.materialize(adapter, %{
               remote: source,
               ref: "refs/heads/main",
               operation_id: "first",
               depth: 5
             })

    assert {:ok, first_snapshot} = GitRepository.inspect_snapshot(adapter, first_worktree)
    assert first_snapshot.clean?
    assert first_snapshot.object_format == :sha1
    refute first_snapshot.submodules?
    refute first_snapshot.lfs?
    refute inspect(first_worktree) =~ first_worktree.path
    assert :ok = GitRepository.cleanup(adapter, first_worktree)
    refute File.exists?(first_worktree.path)

    assert {:ok, second_worktree} =
             GitRepository.materialize(adapter, %{
               remote: source,
               ref: "refs/heads/main",
               operation_id: "second",
               depth: 5
             })

    assert {:ok, second_snapshot} = GitRepository.inspect_snapshot(adapter, second_worktree)
    assert first_snapshot.commit_sha == second_snapshot.commit_sha
    assert first_snapshot.tree_sha == second_snapshot.tree_sha
    assert first_snapshot.parents == second_snapshot.parents
    assert :match = GitRepository.compare_revision(first_snapshot.commit_sha, second_snapshot)
    assert :ok = GitRepository.cleanup(adapter, second_worktree)

    assert {:error, %{kind: :invalid_input, operation: :git_remote}} =
             GitRepository.materialize(adapter, %{
               remote: "file:///etc/passwd",
               ref: "HEAD",
               operation_id: "unsafe",
               depth: 1
             })

    assert {:error, %{kind: :invalid_input, operation: :git_materialize}} =
             GitRepository.materialize(adapter, %{
               remote: source,
               ref: "--upload-pack=malicious",
               operation_id: "unsafe-ref",
               depth: 1
             })
  end

  test "deterministic fake adapters model partial pages, missing refs, and force pushes" do
    locator = locator!()
    credential = credential!()
    observation = provider_observation!()

    assert {:ok, provider} =
             FakeRepositoryProvider.new(%{
               {:issues, locator.external_id, nil} => %{
                 observations: [observation],
                 next_cursor: "2"
               },
               {:issues, locator.external_id, "2"} => {:error, :unavailable, :provider_rate_limit}
             })

    assert {:ok, %{observations: [^observation], next_cursor: "2"}} =
             FakeRepositoryProvider.observe_collection(
               provider,
               :issues,
               locator,
               credential,
               nil,
               []
             )

    assert {:error, %{kind: :unavailable, operation: :provider_rate_limit}} =
             FakeRepositoryProvider.observe_collection(
               provider,
               :issues,
               locator,
               credential,
               "2",
               []
             )

    old = git_snapshot!(String.duplicate("a", 40), String.duplicate("b", 40))
    forced = git_snapshot!(String.duplicate("c", 40), String.duplicate("d", 40))

    assert {:ok, git} =
             FakeGit.new(
               snapshots: %{"before" => old, "after" => forced},
               failures: %{{:materialize, {"remote", "missing", "missing"}} => :unavailable}
             )

    assert {:ok, worktree} =
             FakeGit.materialize(git, %{remote: "remote", ref: "main", operation_id: "before"})

    assert {:ok, ^old} = FakeGit.inspect_snapshot(git, worktree)

    assert {:error, %{kind: :unavailable, operation: :fake_git_materialize}} =
             FakeGit.materialize(git, %{
               remote: "remote",
               ref: "missing",
               operation_id: "missing"
             })

    assert {:contradiction, contradiction} =
             GitRepository.compare_revision(String.duplicate("e", 40), forced)

    assert contradiction.kind == :provider_git_revision_mismatch
    refute inspect(contradiction) =~ String.duplicate("e", 40)
  end

  defp locator! do
    {:ok, locator} =
      RepositoryLocator.new(%{
        provider: "https://github.com",
        external_id: "9006001",
        owner: "agentjido",
        name: "jido_code",
        state: :active,
        observed_at: @observed_at,
        relationships: []
      })

    locator
  end

  defp credential! do
    {:ok, iri} = ResourceIdentity.repository("phase-06-credential-reference")
    {:ok, reference} = CredentialReference.new(%{iri: iri, provider: "test", key: "github/api"})
    reference
  end

  defp active_enrollment! do
    {:ok, enrollment_iri} =
      ResourceIdentity.management_enrollment(
        resource!("phase-06-factory"),
        resource!("phase-06-repository"),
        resource!("phase-06-policy-boundary")
      )

    %{enrollment_iri: enrollment_iri, admission: :allowed}
  end

  defp provider_observation! do
    {:ok, observation} = ProviderObservation.new(observation_attributes())
    observation
  end

  defp observation_attributes do
    %{
      kind: :issue,
      external_id: "issue-1",
      source_time: @observed_at,
      retrieved_at: @observed_at,
      etag: "etag",
      source_revision: "revision",
      response_digest: String.duplicate("a", 64),
      data: %{number: 1, state: "open"},
      completeness: %{status: :complete, covered: ["issues"], missing: []},
      limitations: [],
      warnings: []
    }
  end

  defp git_snapshot!(commit, tree) do
    {:ok, snapshot} =
      GitSnapshot.new(%{
        commit_sha: commit,
        tree_sha: tree,
        parents: [],
        ref: "refs/heads/main",
        object_format: :sha1,
        submodules?: false,
        lfs?: false,
        clean?: true,
        observed_at: @observed_at,
        limitations: []
      })

    snapshot
  end

  defp resource!(seed) do
    {:ok, iri} = ResourceIdentity.repository(seed)
    iri
  end

  defp git!(path, args) do
    {_output, 0} = System.cmd("git", args, cd: path, stderr_to_stdout: true)
    :ok
  end
end
