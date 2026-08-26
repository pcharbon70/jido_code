defmodule JidoCode.Runtime.DelegatedAgentPhase02IntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Runtime.JidoHarness.CodexRelease

  setup context do
    root =
      Path.join(
        System.tmp_dir!(),
        "jido-code-dca-phase-02-integration-#{context.test}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, root: root}
  end

  test "the real JidoHarness path keeps compiled context out of process surfaces", %{root: root} do
    shell = System.find_executable("sh") || flunk("the process-path proof requires sh")

    canaries = [
      "prompt-canary-78a2",
      "memory-canary-4b19",
      "repository-canary-c612",
      "credential-canary-f903"
    ]

    prompt = Enum.join(canaries, " ")

    assert {:ok, process_id} =
             Jido.Harness.Process.start(%{
               executable: shell,
               argv: ["-c", "IFS= read -r _bounded_context; sleep 30"],
               cwd: root,
               env: %{
                 "PATH" => "/usr/bin:/bin",
                 "HOME" => root,
                 "TMPDIR" => root
               },
               env_mode: :replace,
               stdin: true,
               pty: false,
               runtime_timeout_ms: 5_000,
               idle_timeout_ms: 5_000,
               metadata: %{
                 purpose: :protected_stdin_conformance,
                 context_digest: digest(prompt)
               },
               retention: %{memory_bytes: 64 * 1_024}
             })

    on_exit(fn -> cleanup_process(process_id) end)

    assert :ok = Jido.Harness.Process.send_input(process_id, prompt <> "\n")
    assert :ok = Jido.Harness.Process.close_input(process_id)
    info = await_running_info(process_id)

    surfaces = [
      File.read!("/proc/#{info.os_pid}/cmdline"),
      File.read!("/proc/#{info.os_pid}/environ"),
      File.read!("/proc/#{info.os_pid}/comm"),
      File.read!("/proc/#{info.os_pid}/status"),
      inspect(info, limit: :infinity),
      process_events(process_id) |> inspect(limit: :infinity)
    ]

    for canary <- canaries, surface <- surfaces do
      refute surface =~ canary
    end

    assert info.metadata.purpose == :protected_stdin_conformance
    assert info.metadata.context_digest == digest(prompt)
    refute Map.has_key?(info.metadata, :prompt)
  end

  test "the real JidoHarness path enforces a stalled-process timeout", %{root: root} do
    shell = System.find_executable("sh") || flunk("the timeout proof requires sh")

    assert {:ok, process_id} =
             Jido.Harness.Process.start(%{
               executable: shell,
               argv: ["-c", "sleep 30"],
               cwd: root,
               env: %{"PATH" => "/usr/bin:/bin", "HOME" => root, "TMPDIR" => root},
               env_mode: :replace,
               stdin: false,
               pty: false,
               runtime_timeout_ms: 75,
               idle_timeout_ms: 75,
               retention: %{memory_bytes: 64 * 1_024}
             })

    on_exit(fn -> cleanup_process(process_id) end)

    assert {:ok, info} = Jido.Harness.Process.await(process_id, 2_000)
    assert info.state == :timed_out
  end

  test "the release exposes one disabled closed Codex profile and no provider resume" do
    assert {:ok, profile} = CodexRelease.runtime_profile()
    selection = CodexRelease.profile()
    assert selection.state == :disabled
    assert selection.managed_eligible == false
    assert profile.built_in_adapter == :blocked
    assert profile.session_policy == :controller_reconstructed_turns
    assert profile.run_count == 2
    assert profile.session_turns == 2
    assert selection.capability_class == :workspace_write_registered_checks

    serialized = inspect(profile, limit: :infinity)
    refute serialized =~ "danger-full-access"
    refute serialized =~ "resume"
    refute serialized =~ "--add-dir"
    refute serialized =~ "--config"
    refute serialized =~ "dangerously-bypass"
  end

  defp await_running_info(process_id, attempts \\ 100)

  defp await_running_info(_process_id, 0),
    do: flunk("managed process did not expose a running OS process")

  defp await_running_info(process_id, attempts) do
    case Jido.Harness.Process.info(process_id) do
      {:ok, %{state: :running, os_pid: os_pid} = info} when is_integer(os_pid) ->
        info

      _other ->
        Process.sleep(10)
        await_running_info(process_id, attempts - 1)
    end
  end

  defp process_events(process_id) do
    case Jido.Harness.Process.replay(process_id, limit: 20) do
      {:ok, events} -> events
      {:error, reason} -> flunk("could not inspect process diagnostics: #{inspect(reason)}")
    end
  end

  defp cleanup_process(process_id) do
    _ = Jido.Harness.Process.kill(process_id)
    _ = Jido.Harness.Process.prune(process_id)
    :ok
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
