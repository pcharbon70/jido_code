defmodule JidoCode.Runtime.DelegatedAgentPhase02ReleaseTest do
  use ExUnit.Case, async: false

  alias JidoCode.Runtime.DelegatedRuntimeRegistry
  alias JidoCode.Runtime.JidoHarness.Adoption
  alias JidoCode.Runtime.JidoHarness.CodexRelease
  alias JidoCode.Runtime.JidoHarness.ExecutableRegistry
  alias JidoCode.Runtime.JidoHarnessAdapter

  test "pins one disabled Codex profile and keeps the built-in adapter blocked" do
    release = CodexRelease.manifest()
    profile = CodexRelease.profile()

    assert release.jido_harness.revision == "e41fc1651282469f2db4219a48d9f7feef1b0dbc"

    assert release.jido_harness.archive_sha256 ==
             "fbe4d49edf2e5ae7843231e45c47158a15fdcdbc494b40a3d766967c1b81f8b3"

    assert release.cli.version == "0.144.6"
    assert release.cli.model == "gpt-5.3-codex"

    assert release.cli.executable_sha256 ==
             "a31ae9450a26216eb1e7c53102fd42123dd675974310b0e2ca3aa4cb622a2c15"

    assert release.protocols.events == :codex_jsonl
    assert release.protocols.prompt_transport == :stdin
    assert release.built_in_codex_adapter == :blocked
    assert profile.state == :disabled
    assert profile.deployment_class == :developer_local
    assert profile.capability_class == :workspace_write_registered_checks
    assert profile.repository_envelope == ["jido_code"]
    assert profile.run_count == 2
    assert profile.session_turns == 2
    refute profile.managed_eligible
    assert byte_size(CodexRelease.digest()) == 64
    assert byte_size(CodexRelease.profile_digest()) == 64

    assert {:ok, runtime_profile} = Adoption.profile(:codex_dga1)
    assert runtime_profile.prompt_transport == :stdin
    assert runtime_profile.built_in_adapter == :blocked
    refute Adoption.built_in_adapter_enabled?(:codex)
  end

  test "maps only the exact accepted runtime identity to compiled code" do
    selection = %{
      runtime_class: :delegated_cli,
      provider: :codex,
      adapter_key: "codex_cli",
      executable_registry_key: "codex_cli",
      adapter_release_digest: CodexRelease.digest()
    }

    assert {:ok, resolved} = DelegatedRuntimeRegistry.lookup(selection)
    assert resolved.adapter == JidoHarnessAdapter
    assert resolved.profile == :codex_dga1
    assert resolved.release == CodexRelease.manifest()

    for mutation <- [
          &Map.put(&1, :runtime_class, :host_controlled),
          &Map.put(&1, :provider, :claude),
          &Map.put(&1, :adapter_key, "repository_adapter"),
          &Map.put(&1, :executable_registry_key, "arbitrary"),
          &Map.put(&1, :adapter_release_digest, String.duplicate("0", 64))
        ] do
      assert {:error, %{kind: :unauthorized}} =
               selection |> mutation.() |> DelegatedRuntimeRegistry.lookup()
    end
  end

  test "verifies regular owned immutable executables by exact digest and version", context do
    root = fixture_root(context)
    path = Path.join(root, "codex")
    body = "#!/bin/sh\nprintf 'codex-cli 0.144.6\\n'\n"
    File.write!(path, body)
    File.chmod!(path, 0o755)

    descriptor = %{
      key: "codex_cli",
      path: path,
      installation_root: root,
      sha256: sha256(body),
      version: "0.144.6",
      version_prefix: "codex-cli "
    }

    assert {:ok, verified} = ExecutableRegistry.verify(descriptor)
    assert verified.path == path
    assert verified.sha256 == sha256(body)
    assert verified.version == "0.144.6"

    symlink = Path.join(root, "codex-link")
    File.ln_s!(path, symlink)

    assert {:error, %{kind: :unauthorized}} =
             ExecutableRegistry.verify(%{descriptor | path: symlink})

    assert {:error, %{kind: :unauthorized}} =
             ExecutableRegistry.verify(%{descriptor | installation_root: Path.dirname(root)})

    assert {:error, %{kind: :unauthorized}} =
             ExecutableRegistry.verify(%{descriptor | version: "0.144.5"})

    File.chmod!(path, 0o775)
    assert {:error, %{kind: :unauthorized}} = ExecutableRegistry.verify(descriptor)

    File.chmod!(path, 0o755)
    File.write!(path, body <> "# changed\n")
    assert {:error, %{kind: :unauthorized}} = ExecutableRegistry.verify(descriptor)

    assert {:error, %{kind: :invalid_input}} = ExecutableRegistry.descriptor("unknown")
  end

  defp fixture_root(context) do
    root =
      Path.join(
        System.tmp_dir!(),
        "jido-code-codex-release-#{context.test}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    root
  end

  defp sha256(value),
    do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
