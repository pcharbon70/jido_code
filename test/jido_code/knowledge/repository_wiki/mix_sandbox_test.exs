defmodule JidoCode.Knowledge.RepositoryWiki.MixSandboxTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.RepositoryWiki.MixSandbox
  alias JidoCode.Factory.Sandbox
  alias JidoCode.Factory.Sandbox.Request, as: SandboxRequest
  alias JidoCode.Integrations.MemorySandbox
  alias JidoCode.Knowledge.RepositoryWiki.MixStatic
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.AllowExecutionAuthority

  @source ~S'''
  defmodule Demo.MixProject do
    def project do
      [app: :demo, version: System.get_env("VERSION"), elixirc_paths: paths(Mix.env()), deps: []]
    end
  end
  '''

  setup do
    {:ok, static} = MixStatic.extract(@source)
    {:ok, repository_iri} = ResourceIdentity.conceptual_repository("wiki-mix-sandbox")
    {:ok, execution} = execution_request(repository_iri)
    {:ok, sandbox_request} = sandbox_request(execution)
    toolchain_digest = prefixed_digest("toolchain")
    parent = self()

    runner = fn command, files ->
      send(parent, {:mix_sandbox_command, command, files})

      payload = %{
        "schema" => "mix-sandbox/1.0.0",
        "source_digest" => static.source_digest,
        "toolchain_digest" => toolchain_digest,
        "fields" => [
          %{"name" => "elixirc_paths", "value" => ["lib"], "state" => "observed"},
          %{"name" => "version", "value" => "1.2.3", "state" => "observed"}
        ],
        "dependencies" => [],
        "diagnostics" => [],
        "truncated" => false
      }

      %{
        stdout: Jason.encode!(payload),
        stderr: "",
        exit_status: 0,
        usage: %{cpu_ms: 4, memory_bytes: 4_096, disk_bytes: 512},
        writes: %{}
      }
    end

    sandbox =
      start_supervised!(
        Supervisor.child_spec(
          {MemorySandbox, runners: %{"jido-wiki-mix-introspect" => runner}},
          id: make_ref()
        )
      )

    attributes = %{
      source_digest: static.source_digest,
      source_fence: "git:sha256:#{digest("source-fence")}",
      toolchain_digest: toolchain_digest,
      policy_revision: 7,
      policy_allows_sandbox: true,
      enrollment_state: :manual,
      generation_profile: :manual_deterministic,
      requested_fields: ["elixirc_paths", "version"],
      sandbox_request: sandbox_request,
      snapshot: %{
        snapshot_iri: execution.snapshot_iri,
        files: %{
          ".jido-code/wiki-mix/source/mix.exs" => @source,
          ".jido-code/wiki-mix/source/mix.lock" => "%{}\n"
        }
      }
    }

    %{
      static: static,
      execution: execution,
      sandbox_request: sandbox_request,
      sandbox: sandbox,
      attributes: attributes
    }
  end

  test "publishes one immutable network-denied container profile" do
    profile = MixSandbox.profile()
    assert profile.revision == "mix-sandbox/1.0.0"
    assert profile.executable == "jido-wiki-mix-introspect"
    assert profile.network == :deny
    assert profile.credentials == :deny
    assert profile.source_mount.mode == :read_only
    assert profile.scratch_mount.disposable
    assert profile.isolation.tier == :container_sandbox
    assert profile.isolation.technology == :gvisor
    assert profile.isolation.ambient_credentials == false
    assert profile.isolation.host_filesystem == false
    assert profile.isolation.docker_socket == false
    assert profile.isolation.network == :deny
    assert profile.digest == JidoCode.Factory.Sandbox.IsolationProfile.digest(profile.isolation)
    assert String.match?(profile.contract_digest, ~r/^[a-f0-9]{64}$/)
  end

  test "runs the fixed command through the sandbox seam and normalizes observed facts", context do
    assert {:ok, observation} = observe(context)
    assert observation.profile == "mix-sandbox/1.0.0"
    assert observation.source_digest == context.static.source_digest
    assert observation.status == :completed
    assert observation.exit_status == 0
    refute observation.truncated
    assert observation.model_calls == 0
    assert observation.model_input_tokens == 0
    assert observation.model_output_tokens == 0
    assert Enum.all?(observation.fields, &(&1.authority == :observed))
    assert Enum.map(observation.fields, & &1.name) == ["elixirc_paths", "version"]

    assert_receive {:mix_sandbox_command, command, files}
    assert command.name == "jido-wiki-mix-introspect"
    assert command.network == false
    assert command.environment == MixSandbox.profile().environment

    assert command.args ==
             MixSandbox.profile().argv ++ ["--source-digest", context.static.source_digest]

    assert Map.keys(files) |> Enum.sort() ==
             [
               ".jido-code/wiki-mix/source/mix.exs",
               ".jido-code/wiki-mix/source/mix.lock"
             ]

    assert {:error, %{kind: :conflict}} =
             Sandbox.inspect(
               MemorySandbox,
               context.sandbox,
               context.sandbox_request,
               authority: AllowExecutionAuthority
             )
  end

  test "denies opt-out, exact static facts, source drift, and relaxed request authority",
       context do
    assert {:error, %{kind: :unauthorized}} =
             observe(context, %{context.attributes | enrollment_state: :off})

    assert {:error, %{kind: :conflict}} =
             observe(context, %{context.attributes | source_digest: digest("stale")})

    assert {:ok, exact_static} =
             MixStatic.extract(
               "defmodule Demo.MixProject do\n def project, do: [app: :demo, version: \"1\", deps: []]\nend\n"
             )

    exact_attributes = %{
      context.attributes
      | source_digest: exact_static.source_digest,
        requested_fields: ["version"],
        snapshot: %{
          context.attributes.snapshot
          | files: %{
              context.attributes.snapshot.files
              | ".jido-code/wiki-mix/source/mix.exs" => "different"
            }
        }
    }

    assert {:error, %{kind: :conflict}} =
             MixSandbox.observe(exact_static, exact_attributes,
               adapter_module: MemorySandbox,
               adapter: context.sandbox,
               authority: AllowExecutionAuthority
             )

    relaxed_request = %{
      context.sandbox_request
      | command_allowlist: ["mix", "jido-wiki-mix-introspect"]
    }

    assert {:error, %{kind: :unauthorized}} =
             observe(context, %{context.attributes | sandbox_request: relaxed_request})
  end

  test "rejects sandbox writes that mutate the immutable input material", context do
    mutating = fn _command, _files ->
      payload = %{
        "schema" => "mix-sandbox/1.0.0",
        "source_digest" => context.static.source_digest,
        "toolchain_digest" => context.attributes.toolchain_digest,
        "fields" => [],
        "dependencies" => [],
        "diagnostics" => [],
        "truncated" => false
      }

      %{
        stdout: Jason.encode!(payload),
        stderr: "",
        exit_status: 0,
        usage: %{cpu_ms: 1, memory_bytes: 1_024},
        writes: %{".jido-code/wiki-mix/scratch/mutation" => "forbidden"}
      }
    end

    sandbox =
      start_supervised!(
        Supervisor.child_spec(
          {MemorySandbox, runners: %{"jido-wiki-mix-introspect" => mutating}},
          id: make_ref()
        )
      )

    assert {:error, %{kind: :invalid_input}} =
             MixSandbox.observe(context.static, context.attributes,
               adapter_module: MemorySandbox,
               adapter: sandbox,
               authority: AllowExecutionAuthority
             )
  end

  defp observe(context, attributes \\ nil) do
    MixSandbox.observe(context.static, attributes || context.attributes,
      adapter_module: MemorySandbox,
      adapter: context.sandbox,
      authority: AllowExecutionAuthority
    )
  end

  defp execution_request(repository_iri) do
    names = ~w[attempt lease task goal plan snapshot actor agent capability]

    resources =
      Map.new(names, fn name ->
        {:ok, iri} = ResourceIdentity.deterministic(:sandbox_activity, "wiki-mix-" <> name)
        {name, iri}
      end)

    ExecutionRequest.new(%{
      attempt_iri: resources["attempt"],
      lease_iri: resources["lease"],
      task_iri: resources["task"],
      goal_iri: resources["goal"],
      plan_iri: resources["plan"],
      repository_iri: repository_iri,
      snapshot_iri: resources["snapshot"],
      actor_iri: resources["actor"],
      agent_iri: resources["agent"],
      capability_iri: resources["capability"],
      fencing_token: 11,
      context_digest: digest("context"),
      runtime_version: "repository-wiki-mix/1.0.0",
      constraints: %{network: :deny}
    })
  end

  defp sandbox_request(execution) do
    SandboxRequest.new(%{
      execution: execution,
      base_snapshot_iri: execution.snapshot_iri,
      allowed_write_paths: [".jido-code/wiki-mix"],
      command_allowlist: ["jido-wiki-mix-introspect"],
      environment_allowlist: Map.keys(MixSandbox.profile().environment),
      secret_reference_iris: [],
      limits: %{
        cpu_ms: 1_000,
        memory_bytes: 16_777_216,
        process_count: 8,
        disk_bytes: 1_048_576,
        timeout_ms: 1_000,
        output_bytes: 8_192,
        network: :deny
      }
    })
  end

  defp digest(seed), do: :crypto.hash(:sha256, seed) |> Base.encode16(case: :lower)
  defp prefixed_digest(seed), do: "sha256:" <> digest(seed)
end
