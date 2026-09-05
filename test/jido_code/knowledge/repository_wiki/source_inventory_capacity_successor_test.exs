defmodule JidoCode.Knowledge.RepositoryWiki.SourceInventoryCapacitySuccessorTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Compiler
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventory
  alias JidoCode.Knowledge.ResourceIdentity

  @now ~U[2026-09-05 16:00:00.000000Z]

  @tag :tmp_dir
  test "pins the versioned bounded capacity successor and rejects wider caller limits", %{
    tmp_dir: root
  } do
    readme = "# Capacity successor\n"
    File.write!(Path.join(root, "README.md"), readme)
    profile = SourceInventory.profile()

    assert profile.revision == "wiki-source-inventory/1.1.0"

    assert profile.limits == %{
             files: 2_000,
             file_bytes: 262_144,
             total_bytes: 16_777_216,
             path_bytes: 512
           }

    assert profile.traversal_limits == %{
             visited_paths: 4_000,
             directory_worker_heap_words: 4_000_000,
             directory_timeout_ms: 5_000,
             directory_enumerator: :bounded_python_scandir_port,
             directory_protocol: :streamed_uint16_frames_with_terminal_count,
             directory_max_record_bytes: 512,
             directory_max_output: :remaining_budget_derived,
             file_protocol: :bounded_header_content_terminal,
             file_max_output_bytes: 262_156,
             directory_helper_wall_seconds: 4,
             directory_helper_cpu_seconds: 4,
             directory_helper_address_space_bytes: 134_217_728,
             directory_helper_descriptors: 16,
             directory_helper_concurrency_per_vm: 4,
             traversal_deadline_ms: 60_000,
             directory_helper_executables: [
               "/usr/bin/timeout",
               "/usr/bin/prlimit",
               "/usr/bin/python3.12"
             ],
             directory_helper_runtime: "CPython 3.12",
             directory_helper_script_sha256:
               SourceInventory.profile().traversal_limits.directory_helper_script_sha256,
             file_helper_script_sha256:
               SourceInventory.profile().traversal_limits.file_helper_script_sha256,
             directory_helper_environment: :empty_except_c_locale,
             directory_helper_parent_death_signal: :sigkill,
             directory_helper_no_new_privileges: true,
             trusted_inventory_helper_execution: :required
           }

    assert byte_size(profile.traversal_limits.directory_helper_script_sha256) == 64
    assert byte_size(profile.traversal_limits.file_helper_script_sha256) == 64

    attributes = inventory_attributes(profile.limits)
    assert {:ok, inventory} = SourceInventory.scan(root, attributes)
    assert inventory.profile == profile.revision
    assert inventory.model_calls == 0
    assert inventory.model_tokens == 0

    for {key, maximum} <- profile.limits do
      too_wide = put_in(attributes, [:limits, key], maximum + 1)

      assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_inventory_limits}} =
               SourceInventory.scan(root, too_wide)
    end

    smaller_total = put_in(attributes, [:limits, :total_bytes], byte_size(readme) - 1)

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_total_bytes_limit}} =
             SourceInventory.scan(root, smaller_total)
  end

  test "pins directory enumeration to the bounded no-shell port worker" do
    source = File.read!("lib/jido_code/knowledge/repository_wiki/source_inventory.ex")

    protocol =
      File.read!("lib/jido_code/knowledge/repository_wiki/source_inventory_protocol.ex")

    assert source =~ "Port.open("
    assert source =~ "with os.scandir(descriptor) as entries:"
    assert source =~ "if index >= limit:"
    assert source =~ "os.open(component, flags, dir_fd=descriptor)"
    assert source =~ "resource.setrlimit(resource.RLIMIT_AS"
    assert source =~ "libc.prctl(1, signal.SIGKILL"
    assert source =~ ":stream"
    assert source =~ ":eof"
    assert source =~ "emitted.to_bytes(4, \"big\")"
    assert protocol =~ "<<\"JCF1\", size::unsigned-big-32"
    assert source =~ "@directory_timeout_executable \"/usr/bin/timeout\""
    assert source =~ "@directory_limit_executable \"/usr/bin/prlimit\""
    refute source =~ "{:packet, 2}"
    refute source =~ "File.ls(path)"
    refute source =~ ":file.list_dir_all(path)"
    refute source =~ ":prim_file.list_dir_all(path)"
    refute source =~ "File.read(absolute)"
  end

  @tag :tmp_dir
  test "rejects control characters in streamed directory names", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "docs"))
    File.write!(Path.join(root, "docs/unsafe\nname.md"), "unsafe")

    attributes =
      SourceInventory.profile().limits
      |> inventory_attributes()
      |> Map.put(:root_files, [])
      |> Map.put(:documentation_roots, ["docs"])

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_path_limit}} =
             SourceInventory.scan(root, attributes)
  end

  @tag :tmp_dir
  test "rejects non-UTF-8 bytes in streamed directory names", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "docs"))
    File.write!(Path.join(root, "docs") <> "/" <> <<0xFF>> <> ".md", "unsafe")

    attributes =
      SourceInventory.profile().limits
      |> inventory_attributes()
      |> Map.put(:root_files, [])
      |> Map.put(:documentation_roots, ["docs"])

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_path_limit}} =
             SourceInventory.scan(root, attributes)
  end

  @tag :tmp_dir
  test "classifies symlinks without reading their out-of-root targets", %{tmp_dir: root} do
    outside = root <> "-outside"
    File.mkdir_p!(Path.join(root, "docs"))
    File.mkdir_p!(outside)
    File.write!(Path.join(outside, "secret.md"), "must not be read")
    File.ln_s!(Path.join(outside, "secret.md"), Path.join(root, "docs/escape.md"))

    on_exit(fn -> File.rm_rf!(outside) end)

    attributes =
      SourceInventory.profile().limits
      |> inventory_attributes()
      |> Map.put(:root_files, [])
      |> Map.put(:documentation_roots, ["docs"])

    assert {:ok, inventory} = SourceInventory.scan(root, attributes)
    assert inventory.entries == []
    assert inventory.gaps == [%{path: "docs/escape.md", reason: :symlinked}]
  end

  @tag :tmp_dir
  test "refuses an intermediate directory symlink before reading its target", %{tmp_dir: root} do
    outside = root <> "-outside-directory"
    File.mkdir_p!(Path.join(root, "docs"))
    File.mkdir_p!(outside)
    File.write!(Path.join(outside, "secret.md"), "must not be read")
    File.ln_s!(outside, Path.join(root, "docs/bridge"))

    on_exit(fn -> File.rm_rf!(outside) end)

    attributes =
      SourceInventory.profile().limits
      |> inventory_attributes()
      |> Map.put(:root_files, [])
      |> Map.put(:documentation_roots, ["docs/bridge/secret.md"])

    assert {:ok, inventory} = SourceInventory.scan(root, attributes)
    assert inventory.entries == []
    assert inventory.gaps == [%{path: "docs/bridge/secret.md", reason: :unreadable}]
  end

  @tag :tmp_dir
  test "applies a smaller caller path ceiling to every discovered descendant", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "docs/deep"))
    File.write!(Path.join(root, "docs/deep/evidence.md"), "bounded\n")

    limits = %{SourceInventory.profile().limits | path_bytes: 12}

    attributes =
      inventory_attributes(limits)
      |> Map.put(:root_files, [])
      |> Map.put(:documentation_roots, ["docs"])

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_path_limit}} =
             SourceInventory.scan(root, attributes)
  end

  @tag :tmp_dir
  test "the compiler accepts only the current inventory profile", %{tmp_dir: root} do
    File.write!(Path.join(root, "README.md"), "# Compiler profile\n")
    profile = SourceInventory.profile()
    assert {:ok, inventory} = SourceInventory.scan(root, inventory_attributes(profile.limits))

    compile_attributes = %{
      repository_iri: inventory.repository_iri,
      tenant_iri: resource(:authorization_grant, "capacity-successor-tenant"),
      created_at: @now,
      purpose: :current
    }

    assert {:ok, compilation} = Compiler.compile(inventory, compile_attributes)
    assert compilation.model_calls == 0
    assert compilation.model_input_tokens == 0
    assert compilation.model_output_tokens == 0

    predecessor = with_profile(inventory, "wiki-source-inventory/1.0.0")

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_compile}} =
             Compiler.compile(predecessor, compile_attributes)

    for forged_revision <- [
          "wiki-source-inventory/1.1.0-forged",
          "wiki-source-inventory/999.0.0"
        ] do
      forged = with_profile(inventory, forged_revision)

      assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_compile}} =
               Compiler.compile(forged, compile_attributes)
    end

    tampered = put_in(inventory, [:entries, Access.at(0), :bytes], 1_000)

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_compile}} =
             Compiler.compile(tampered, compile_attributes)

    redigested_over_capacity =
      inventory
      |> put_in([:entries, Access.at(0), :bytes], 20_000_000)
      |> Map.put(:total_bytes, 20_000_000)
      |> redigest()

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_compile}} =
             Compiler.compile(redigested_over_capacity, compile_attributes)

    synthetic_entry = %{
      path: "lib/not-on-disk.ex",
      kind: :source,
      media_type: "text/x-elixir",
      bytes: 12,
      digest: String.duplicate("b", 64),
      module_names: ["NotOnDisk"]
    }

    unregistered =
      inventory
      |> Map.put(:entries, [synthetic_entry])
      |> Map.put(:file_count, 1)
      |> Map.put(:total_bytes, 12)
      |> Map.put(:module_names, ["NotOnDisk"])
      |> redigest()

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_inventory_manifest}} =
             SourceInventory.validate(unregistered)

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_compile}} =
             Compiler.compile(unregistered, compile_attributes)

    too_many_represented_paths =
      inventory
      |> Map.put(
        :gaps,
        Enum.map(1..4_000, fn index ->
          %{
            path: "missing/#{String.pad_leading(Integer.to_string(index), 4, "0")}",
            reason: :missing
          }
        end)
      )
      |> Map.put(:registrations, %{
        documentation_roots: ["missing"],
        guide_roots: [],
        root_files: ["README.md"],
        source_roots: [],
        test_roots: []
      })
      |> redigest()

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_inventory_manifest}} =
             SourceInventory.validate(too_many_represented_paths)
  end

  @tag :tmp_dir
  test "bounds every visited path including unsupported files and empty directories", %{
    tmp_dir: root
  } do
    File.mkdir_p!(Path.join(root, "docs"))

    for index <- 1..(SourceInventory.profile().traversal_limits.visited_paths + 1) do
      File.write!(Path.join(root, "docs/unsupported-#{index}.png"), "x")
    end

    attributes =
      SourceInventory.profile().limits
      |> inventory_attributes()
      |> Map.put(:root_files, [])
      |> Map.put(:documentation_roots, ["docs"])

    assert {:error, %Error{kind: :invalid_input, operation: :repository_wiki_traversal_limit}} =
             SourceInventory.scan(root, attributes)
  end

  @tag :tmp_dir
  test "keeps the published file limit scoped to accepted entries", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "docs"))
    File.write!(Path.join(root, "docs/only.md"), "one")

    limits = %{SourceInventory.profile().limits | files: 1}

    attributes =
      limits
      |> inventory_attributes()
      |> Map.put(:root_files, [])
      |> Map.put(:documentation_roots, ["docs"])

    assert {:ok, inventory} = SourceInventory.scan(root, attributes)
    assert inventory.file_count == 1
  end

  @tag :tmp_dir
  test "derives module names within the published source-byte envelope without hidden ceilings",
       %{
         tmp_dir: root
       } do
    File.mkdir_p!(Path.join(root, "lib"))

    source =
      1..513
      |> Enum.map_join("\n", fn index -> "defmodule Capacity.Module#{index}, do: nil" end)

    File.write!(Path.join(root, "lib/capacity.ex"), source)

    attributes =
      SourceInventory.profile().limits
      |> inventory_attributes()
      |> Map.put(:root_files, [])
      |> Map.put(:source_roots, ["lib"])

    assert {:ok, inventory} = SourceInventory.scan(root, attributes)
    assert length(inventory.module_names) == 513
    assert :ok = SourceInventory.validate(inventory)
  end

  defp with_profile(inventory, revision) do
    inventory
    |> Map.put(:profile, revision)
    |> Map.delete(:digest)
    |> then(&Map.put(&1, :digest, JidoCode.Knowledge.RepositoryWiki.Contract.digest(&1)))
  end

  defp redigest(inventory) do
    inventory
    |> Map.delete(:digest)
    |> then(&Map.put(&1, :digest, JidoCode.Knowledge.RepositoryWiki.Contract.digest(&1)))
  end

  defp inventory_attributes(limits) do
    %{
      repository_iri: repository("capacity-successor-repository"),
      source_snapshot_iri: resource(:repository_snapshot, "capacity-successor-source"),
      source_fence: "git:sha256:" <> String.duplicate("a", 64),
      documentation_roots: [],
      source_roots: [],
      test_roots: [],
      guide_roots: [],
      limits: limits
    }
  end

  defp resource(kind, seed) do
    assert {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp repository(seed) do
    assert {:ok, iri} = ResourceIdentity.conceptual_repository(seed)
    iri
  end
end
