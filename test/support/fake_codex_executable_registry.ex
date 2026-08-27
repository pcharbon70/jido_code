defmodule JidoCode.TestSupport.FakeCodexExecutableRegistry do
  @moduledoc false

  alias JidoCode.Runtime.JidoHarness.CodexRelease

  def resolve("codex_cli") do
    {:ok,
     %{
       key: "codex_cli",
       path: "/opt/jido-code/codex/0.144.6/bin/codex",
       installation_root: "/opt/jido-code/codex/0.144.6/bin",
       sha256: CodexRelease.executable_sha256(),
       version: CodexRelease.cli_version(),
       owner_uid: 1_000,
       mode: 0o500
     }}
  end

  def resolve(_key), do: {:error, :unknown}
end
