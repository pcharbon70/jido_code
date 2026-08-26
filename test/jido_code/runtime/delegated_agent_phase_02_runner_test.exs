defmodule JidoCode.Runtime.DelegatedAgentPhase02RunnerTest do
  use ExUnit.Case, async: false

  alias JidoCode.Runtime.JidoHarness.CodexEventMapper
  alias JidoCode.Runtime.JidoHarness.CodexProcessRunner
  alias JidoCode.Runtime.JidoHarness.CodexRelease
  alias JidoCode.TestSupport.FakeJidoHarnessProcessAPI

  @now ~U[2026-08-26 14:00:00Z]

  setup context do
    root =
      Path.join(
        System.tmp_dir!(),
        "jido-code-codex-runner-#{context.test}-#{System.unique_integer([:positive])}"
      )

    workspace = Path.join(root, "workspace")
    retention = Path.join(root, "retention")
    File.mkdir_p!(workspace)
    File.mkdir_p!(retention)
    on_exit(fn -> File.rm_rf!(root) end)

    {:ok, profile} = CodexRelease.runtime_profile()

    launch = %{
      deployment_class: :developer_local,
      explicit_opt_in: true,
      managed_eligible: false,
      prompt: "bounded compiled context canary-#{System.unique_integer([:positive])}",
      run_id: "run_phase_02",
      workspace_path: workspace,
      executable: "/opt/jido-code/codex/0.144.6/bin/codex",
      executable_digest: "sha256:" <> CodexRelease.executable_sha256(),
      environment: %{
        "PATH" => "/usr/bin",
        "HOME" => "/runtime/home",
        "TMPDIR" => "/runtime/tmp",
        "LANG" => "C.UTF-8"
      },
      limits: %{wall_ms: 60_000, idle_ms: 30_000},
      cli_version: CodexRelease.cli_version(),
      provider_version: CodexRelease.model(),
      context_digest: String.duplicate("a", 64),
      occurred_at: @now
    }

    options = [
      retention_base: retention,
      process_api: FakeJidoHarnessProcessAPI,
      process_api_options: [owner: self()],
      clock: fn -> @now end
    ]

    {:ok, profile: profile, launch: launch, options: options}
  end

  test "constructs the exact fixed launch and sends context only through stdin", context do
    assert {:ok, receipt} =
             CodexProcessRunner.start(context.profile, context.launch, context.options)

    assert_receive {:jido_harness_process_api, :start, spec}
    assert spec.executable == context.launch.executable

    assert spec.argv ==
             context.profile.argv ++
               ["--output-schema", Enum.at(spec.argv, -2), "-"]

    schema_path = Enum.at(spec.argv, -2)
    assert Path.basename(schema_path) == "codex-output.schema.json"
    assert {:ok, schema} = schema_path |> File.read!() |> Jason.decode()
    assert schema["additionalProperties"] == false
    assert schema["required"] == ["classification", "summary"]
    assert File.stat!(schema_path).mode |> Bitwise.band(0o777) == 0o600

    refute inspect(spec.argv, limit: :infinity) =~ context.launch.prompt
    refute inspect(spec.env, limit: :infinity) =~ context.launch.prompt
    refute inspect(spec.metadata, limit: :infinity) =~ context.launch.prompt
    refute inspect(receipt, limit: :infinity) =~ context.launch.prompt
    assert spec.env_mode == :replace
    assert spec.stdin
    refute spec.pty

    assert_receive {:jido_harness_process_api, :input, "proc_developer_local", input}

    assert input == context.launch.prompt <> "\n"
    assert_receive {:jido_harness_process_api, :close_input, "proc_developer_local"}
    assert receipt.provider_session_ref == nil
    assert receipt.versions.cli == "codex-cli/0.144.6"
    assert receipt.versions.model == "gpt-5.3-codex"
  end

  test "rejects profile, launch, environment, and prompt expansion before process creation",
       context do
    mutations = [
      {Map.put(context.profile, :argv, context.profile.argv ++ ["--add-dir", "/tmp"]),
       context.launch},
      {Map.put(context.profile, :built_in_adapter, :enabled), context.launch},
      {context.profile, Map.put(context.launch, :deployment_class, :managed_fleet)},
      {context.profile, Map.put(context.launch, :executable, "codex")},
      {context.profile, put_in(context.launch, [:environment, "PROMPT"], context.launch.prompt)},
      {context.profile, put_in(context.launch, [:environment, "HOME"], context.launch.prompt)},
      {context.profile, Map.put(context.launch, :cli_version, "latest")},
      {context.profile, Map.put(context.launch, :provider_version, "fallback-model")}
    ]

    for {profile, launch} <- mutations do
      assert {:error, _error} = CodexProcessRunner.start(profile, launch, context.options)
      refute_received {:jido_harness_process_api, :start, _spec}
    end
  end

  test "normalizes bounded JSONL and classifies controller-enforced final output", context do
    final = Jason.encode!(%{"classification" => "candidate", "summary" => "ready"})

    events = [
      event(2, "thread.started", %{"thread_id" => "opaque"}),
      event(3, "turn.started", %{}),
      event(4, "item.completed", %{
        "item" => %{"type" => "agent_message", "text" => final}
      }),
      event(5, "turn.completed", %{
        "usage" => %{"input_tokens" => 20, "cached_input_tokens" => 5, "output_tokens" => 10}
      }),
      %{sequence: 6, type: :exited, data: "0"}
    ]

    handle = %{
      run_id: "run_phase_02",
      runtime_ref: "proc_developer_local",
      event_cursor: 1
    }

    options =
      put_in(context.options, [:process_api_options],
        owner: self(),
        info_result: %{state: :exited},
        replay_result: events
      )

    assert {:ok, receipt} = CodexProcessRunner.status(handle, options)
    assert receipt.state == :completed
    assert receipt.usage.result_classification == :candidate
    assert receipt.usage.input_tokens == 20
    assert receipt.usage.cached_input_tokens == 5
    assert receipt.usage.output_tokens == 10
    assert receipt.usage.observation_completeness == :partial
    assert length(receipt.observations) == 5
    refute inspect(receipt, limit: :infinity) =~ "ready"
    refute inspect(receipt, limit: :infinity) =~ "opaque"
    assert receipt.workspace_digest == nil
    assert receipt.candidate_diff_digest == nil
  end

  test "fails closed on malformed, unknown, oversized, and secret-bearing events" do
    oversized = String.duplicate("x", 65_537)

    for event <- [
          %{sequence: 2, type: :stdout, data: "{"},
          event(2, "future.event", %{}),
          %{sequence: 2, type: :stdout, data: oversized},
          event(2, "item.completed", %{
            "item" => %{
              "type" => "agent_message",
              "text" => "secret=sk-abcdefghijklmnopqrstuvwxyz123456"
            }
          })
        ] do
      assert {:error, %{operation: operation}} = CodexEventMapper.normalize([event], @now)
      assert operation in [:codex_jsonl_event, :codex_final_output]
    end
  end

  test "classifies clarification, checkpoint, and failure without trusting CLI claims" do
    for {classification, expected} <- [
          {"clarification", :clarification},
          {"checkpoint", :checkpoint},
          {"failure", :failure}
        ] do
      final = Jason.encode!(%{"classification" => classification, "summary" => "bounded"})

      assert {:ok, normalized} =
               CodexEventMapper.normalize(
                 [
                   event(2, "item.completed", %{
                     "item" => %{
                       "type" => "agent_message",
                       "text" => final,
                       "file_changes" => ["untrusted"],
                       "checks_passed" => true
                     }
                   })
                 ],
                 @now
               )

      assert normalized.result.classification == expected
      refute inspect(normalized, limit: :infinity) =~ "file_changes"
      refute inspect(normalized, limit: :infinity) =~ "checks_passed"
    end
  end

  defp event(sequence, type, attributes) do
    %{sequence: sequence, type: :stdout, data: Jason.encode!(Map.put(attributes, "type", type))}
  end
end
