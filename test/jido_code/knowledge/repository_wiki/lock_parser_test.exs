defmodule JidoCode.Knowledge.RepositoryWiki.LockParserTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.LockParser

  @checksum String.duplicate("a", 64)
  @outer_checksum String.duplicate("b", 64)
  @revision String.duplicate("c", 40)

  test "parses supported Hex, git, and path entries with complete deterministic edges" do
    source = """
    %{
      "alpha" => {:hex, :alpha_pkg, "1.2.3", "#{@checksum}", [:mix], [{:beta, "~> 2.0", [hex: :beta_pkg, repo: "hexpm", optional: false]}], "hexpm", "#{@outer_checksum}"},
      "beta" => {:hex, :beta_pkg, "2.1.0", "#{@outer_checksum}", [:rebar3], [], "hexpm", "#{@checksum}"},
      "source_dep" => {:git, "https://example.invalid/source.git", "#{@revision}", [ref: "#{@revision}", sparse: "apps/source"]},
      "local_child" => {:path, "apps/local_child", [app: false]}
    }
    """

    assert {:ok, first} = LockParser.parse(source)
    assert {:ok, second} = LockParser.parse(source)
    assert first == second
    assert first.profile_digest == LockParser.profile().digest
    assert first.entry_count == 4
    assert first.edge_count == 1
    assert first.supported_count == 4
    assert first.unsupported_count == 0
    assert first.model_calls == 0
    assert first.model_input_tokens == 0
    assert first.model_output_tokens == 0

    alpha = entry(first, "alpha")
    assert alpha.kind == "hex"
    assert alpha.package == "alpha_pkg"
    assert alpha.version == "1.2.3"
    assert alpha.managers == ["mix"]

    assert alpha.edges == [
             %{
               name: "beta",
               package: "beta_pkg",
               repository: "hexpm",
               requirement: "~> 2.0",
               optional: false
             }
           ]

    git = entry(first, "source_dep")
    assert git.kind == "git"
    assert git.revision == @revision
    assert git.options["sparse"] == "apps/source"

    path = entry(first, "local_child")
    assert path.kind == "path"
    assert path.path == "apps/local_child"
  end

  test "preserves future literal lock shapes as explicit unsupported entries" do
    source = ~S'''
    %{
      "future" => {:workspace_v2, "opaque", [new_option: true]}
    }
    '''

    assert {:ok, result} = LockParser.parse(source)
    assert result.supported_count == 0
    assert result.unsupported_count == 1
    assert [%{kind: "unsupported", status: :unsupported, shape_digest: digest}] = result.entries
    assert byte_size(digest) == 64
    assert [%{entry: "future", code: :unsupported_lock_shape}] = result.diagnostics
  end

  test "rejects executable expressions, malformed checksums, duplicates, traversal, and excess bounds" do
    executable = ~S'''
    %{"bad" => System.get_env("LOCK")}
    '''

    assert {:error, %{kind: :invalid_input}} = LockParser.parse(executable)

    invalid_checksum = """
    %{"bad" => {:hex, :bad, "1.0.0", "short", [:mix], [], "hexpm", "#{@outer_checksum}"}}
    """

    assert {:error, %{kind: :invalid_input}} = LockParser.parse(invalid_checksum)

    duplicate = """
    %{
      "same" => {:git, "https://example.invalid/a.git", "#{@revision}", []},
      "same" => {:git, "https://example.invalid/b.git", "#{@revision}", []}
    }
    """

    assert {:error, %{kind: :invalid_input}} = LockParser.parse(duplicate)

    assert {:error, %{kind: :invalid_input}} =
             LockParser.parse("%{}", %{source_path: "../../mix.lock"})

    raised = %{LockParser.profile().limits | entries: 2_049}
    assert {:error, %{kind: :invalid_input}} = LockParser.parse("%{}", %{limits: raised})
  end

  test "parses the repository lock without term decoding or network access" do
    assert {:ok, result} = LockParser.parse(File.read!("mix.lock"))
    assert result.entry_count > 70
    assert result.edge_count > 100
    assert result.unsupported_count == 0
    assert entry(result, "req").version
    assert entry(result, "jido_harness").kind == "git"
  end

  defp entry(result, name), do: Enum.find(result.entries, &(&1.name == name))
end
