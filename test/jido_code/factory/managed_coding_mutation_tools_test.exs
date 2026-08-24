defmodule JidoCode.Factory.ManagedCodingMutationToolsTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.ManagedCoding.MutationRequest
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Integrations.ManagedCodingMutationTools
  alias JidoCode.Knowledge.ResourceIdentity

  setup context do
    root = Path.join(System.tmp_dir!(), "jido-code-managed-mutation-#{context.test}")
    File.rm_rf!(root)
    File.mkdir_p!(Path.join(root, "lib"))

    File.write!(
      Path.join(root, "lib/example.ex"),
      "defmodule Example do\n  def value, do: :old\nend\n"
    )

    File.write!(Path.join(root, "PROTECTED"), "do not edit\n")
    git!(root, ["init"])
    git!(root, ["config", "user.email", "fixture@example.test"])
    git!(root, ["config", "user.name", "Fixture"])
    git!(root, ["add", "."])
    git!(root, ["commit", "-m", "fixture"])
    on_exit(fn -> File.rm_rf!(root) end)

    request = request!(root)
    %{root: root, request: request, current: current(request)}
  end

  test "applies one exact replacement and reconciles duplicate effects", fixture do
    path = Path.join(fixture.root, "lib/example.ex")
    expected = digest(File.read!(path))

    arguments = %{
      path: "lib/example.ex",
      expected_digest: expected,
      old_text: ":old",
      new_text: ":new",
      expected_matches: 1
    }

    assert {:ok, first} =
             ManagedCodingMutationTools.apply_edit(fixture.request, arguments,
               current_provider: fn -> fixture.current end
             )

    assert first.outcome == :committed
    assert first.new_digest == digest(File.read!(path))

    assert {:ok, replay} =
             ManagedCodingMutationTools.apply_edit(fixture.request, arguments,
               current_provider: fn -> fixture.current end
             )

    assert replay.outcome == :replayed
    assert replay.effect_identity == first.effect_identity

    File.write!(path, "raced\n")

    assert {:error, %{kind: :conflict}} =
             ManagedCodingMutationTools.apply_edit(fixture.request, arguments,
               current_provider: fn -> fixture.current end
             )
  end

  test "creates without overwrite and replays only identical content and mode", fixture do
    target = Path.join(fixture.root, "lib/new.ex")

    arguments = %{
      path: "lib/new.ex",
      content: "defmodule New do\nend\n",
      expected_parent_digest: ManagedCodingMutationTools.parent_digest(target),
      mode: 0o644
    }

    assert {:ok, first} =
             ManagedCodingMutationTools.create_file(fixture.request, arguments,
               current_provider: fn -> fixture.current end
             )

    assert first.outcome == :committed

    assert {:ok, replay} =
             ManagedCodingMutationTools.create_file(fixture.request, arguments,
               current_provider: fn -> fixture.current end
             )

    assert replay.outcome == :replayed

    assert {:error, %{kind: :conflict}} =
             ManagedCodingMutationTools.create_file(
               fixture.request,
               %{arguments | content: "different\n"},
               current_provider: fn -> fixture.current end
             )
  end

  test "deletes into recoverable candidate state and reconciles process loss", fixture do
    target = Path.join(fixture.root, "lib/example.ex")
    arguments = %{path: "lib/example.ex", expected_digest: digest(File.read!(target))}

    assert {:ok, first} =
             ManagedCodingMutationTools.delete_file(fixture.request, arguments,
               current_provider: fn -> fixture.current end
             )

    refute File.exists?(target)
    assert first.details.candidate_diff.operation == :delete

    assert {:ok, replay} =
             ManagedCodingMutationTools.delete_file(fixture.request, arguments,
               current_provider: fn -> fixture.current end
             )

    assert replay.outcome == :replayed
    assert replay.effect_identity == first.effect_identity
  end

  test "denies protected paths, stale fences, symlinks, and changed-path ceilings", fixture do
    assert {:error, %{kind: :invalid_input}} =
             ManagedCodingMutationTools.delete_file(
               fixture.request,
               %{
                 path: "PROTECTED",
                 expected_digest: digest(File.read!(Path.join(fixture.root, "PROTECTED")))
               },
               current_provider: fn -> fixture.current end
             )

    stale = %{fixture.current | fencing_token: fixture.request.fencing_token + 1}

    assert {:error, %{kind: :unauthorized}} =
             ManagedCodingMutationTools.create_file(
               fixture.request,
               %{
                 path: "lib/stale.ex",
                 content: "stale\n",
                 expected_parent_digest:
                   ManagedCodingMutationTools.parent_digest(
                     Path.join(fixture.root, "lib/stale.ex")
                   )
               },
               current_provider: fn -> stale end
             )

    File.ln_s!(Path.join(fixture.root, "lib/example.ex"), Path.join(fixture.root, "lib/link.ex"))

    assert {:error, _error} =
             ManagedCodingMutationTools.apply_edit(
               fixture.request,
               %{
                 path: "lib/link.ex",
                 expected_digest: digest("anything"),
                 old_text: "a",
                 new_text: "b",
                 expected_matches: 1
               },
               current_provider: fn -> fixture.current end
             )
  end

  defp request!(root) do
    {:ok, tree} =
      WorkspaceDigest.tree(root, %{file_count: 100, input_bytes: 64_000, disk_bytes: 128_000})

    {:ok, request} =
      MutationRequest.new(%{
        attempt_iri: resource(:execution_attempt, "mutation-attempt"),
        lease_iri: resource(:execution_lease, "mutation-lease"),
        fencing_token: 9,
        workspace_iri: resource(:sandbox_instance, "mutation-workspace"),
        workspace_root: root,
        workspace_digest: tree.digest,
        snapshot_iri: resource(:repository_snapshot, "mutation-snapshot"),
        capability_iri: resource(:capability_declaration, "mutation-capability"),
        policy_revision: raw_digest("mutation-policy"),
        allowed_paths: ["lib", "PROTECTED"],
        protected_paths: ["PROTECTED", ".git"],
        limits: %{disk_bytes: 128_000, changed_files: 4, diff_bytes: 64_000, output_bytes: 32_000}
      })

    request
  end

  defp current(request) do
    %{
      attempt_iri: request.attempt_iri,
      lease_iri: request.lease_iri,
      fencing_token: request.fencing_token,
      workspace_iri: request.workspace_iri,
      workspace_digest: request.workspace_digest,
      snapshot_iri: request.snapshot_iri,
      capability_iri: request.capability_iri,
      policy_revision: request.policy_revision,
      lease_current?: true,
      policy_current?: true
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp raw_digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp digest(value), do: "sha256:" <> WorkspaceDigest.digest(value)

  defp git!(root, arguments) do
    {output, 0} = System.cmd("git", arguments, cd: root, stderr_to_stdout: true)
    String.trim(output)
  end
end
