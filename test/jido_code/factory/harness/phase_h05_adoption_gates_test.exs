defmodule JidoCode.Factory.Harness.PhaseH05AdoptionGatesTest do
  use ExUnit.Case, async: true

  alias JidoCode.Runtime.JidoHarness.Adoption
  alias JidoCode.Runtime.JidoHarness.MemoryOnlyRetention

  test "pins the unreleased source, archive digest, and accepted toolchain" do
    receipt = Adoption.receipt()

    assert receipt.revision == "e41fc1651282469f2db4219a48d9f7feef1b0dbc"

    assert receipt.archive_sha256 ==
             "fbe4d49edf2e5ae7843231e45c47158a15fdcdbc494b40a3d766967c1b81f8b3"

    assert receipt.upstream_version == "2.0.0"
    assert receipt.toolchain == %{elixir: "1.19.5", otp: "28.3.1"}
    assert receipt.dependency_state == :exact_unreleased_git_revision
    assert receipt.built_in_adapters == :blocked
    assert receipt.managed_fleet == :blocked
  end

  test "admits only protected stdin profiles without prompt-bearing argv" do
    prompt = "PROMPT-CANARY-" <> String.duplicate("x", 32)

    for name <- [:pi_rpc_deny_all, :pi_rpc_read_only] do
      assert {:ok, profile} = Adoption.profile(name)
      assert profile.prompt_transport == :stdin_jsonl
      refute Enum.any?(profile.argv, &String.contains?(&1, prompt))
      refute "--prompt" in profile.argv
      refute "-p" in profile.argv
      assert profile.env_mode == :replace
      assert profile.deployment_class == :developer_local_cli
      refute profile.managed_eligible
    end

    assert {:error, _error} = Adoption.profile(:codex)
  end

  test "represents deny-all and bounded tools without empty-list ambiguity" do
    assert {:ok, deny_all} = Adoption.profile(:pi_rpc_deny_all)
    assert deny_all.tools == []
    assert deny_all.tool_profile == :deny_all
    assert "--no-tools" in deny_all.argv
    refute "--tools" in deny_all.argv

    assert {:ok, read_only} = Adoption.profile(:pi_rpc_read_only)
    assert read_only.tools == ["read", "grep", "find", "ls"]
    assert read_only.tool_profile == :bounded_read_only
    assert pair(read_only.argv, "--tools") == "read,grep,find,ls"

    tampered = %{deny_all | argv: Enum.reject(deny_all.argv, &(&1 == "--no-tools"))}
    assert {:error, _error} = Adoption.validate_profile(tampered)
  end

  test "keeps all raw upstream adapters blocked and Z.AI cancellation disabled" do
    for adapter <- [:amp, :claude, :codex, :gemini, :grok, :kimi, :opencode, :pi, :zai] do
      refute Adoption.built_in_adapter_enabled?(adapter)
    end

    assert Adoption.receipt().disabled_adapters.zai == :native_cancellation_unproven
  end

  test "creates a protected barrier for the bounded memory-only journal fallback" do
    base =
      Path.join(System.tmp_dir!(), "phase-h05-retention-#{System.unique_integer([:positive])}")

    File.mkdir_p!(base)
    on_exit(fn -> File.rm_rf!(base) end)
    runtime_key = String.duplicate("a", 64)
    assert {:ok, profile} = Adoption.profile(:pi_rpc_deny_all)

    assert {:ok, retention} =
             MemoryOnlyRetention.prepare(base, runtime_key, profile.journal)

    assert File.regular?(retention.journal_barrier)
    assert retention.retention.memory_bytes == profile.journal.memory_bytes
    assert retention.retention.journal_dir == retention.journal_barrier
    refute File.dir?(retention.retention.journal_dir)

    assert :ok = MemoryOnlyRetention.cleanup(retention)
    refute File.exists?(retention.root)
  end

  defp pair(argv, flag) do
    argv
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find_value(fn
      [^flag, value] -> value
      _pair -> nil
    end)
  end
end
