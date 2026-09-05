defmodule JidoCode.Knowledge.RepositoryWiki.SourceInventory do
  @moduledoc "Bounded, non-repository-executing inventory adapter for one registered root."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventoryHelperBoundary
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventoryProtocol
  alias JidoCode.Knowledge.ResourceIdentity

  @profile "wiki-source-inventory/1.1.0"
  @maximums %{files: 2_000, file_bytes: 262_144, total_bytes: 16_777_216, path_bytes: 512}
  @maximum_visited_paths 4_000
  @directory_heap_words 4_000_000
  @directory_timeout_ms 5_000
  @directory_helper_wall_seconds 4
  @directory_helper_cpu_seconds 4
  @directory_helper_address_space_bytes 134_217_728
  @directory_helper_descriptors 16
  @directory_helper_concurrency 4
  @traversal_deadline_ms 60_000
  @directory_timeout_executable "/usr/bin/timeout"
  @directory_limit_executable "/usr/bin/prlimit"
  @directory_python_executable "/usr/bin/python3.12"
  @directory_helper_script """
  import ctypes
  import errno
  import os
  import resource
  import signal
  import sys

  null = os.open("/dev/null", os.O_WRONLY | os.O_CLOEXEC)
  os.dup2(null, 2)
  os.close(null)

  if sys.implementation.name != "cpython" or sys.version_info[:2] != (3, 12):
      raise SystemExit(77)

  parent = os.getppid()
  libc = ctypes.CDLL(None, use_errno=True)
  if libc.prctl(1, signal.SIGKILL, 0, 0, 0) != 0:
      raise SystemExit(77)
  if os.getppid() != parent:
      os.kill(os.getpid(), signal.SIGKILL)
  if libc.prctl(38, 1, 0, 0, 0) != 0:
      raise SystemExit(77)

  resource.setrlimit(resource.RLIMIT_AS, (134217728, 134217728))
  resource.setrlimit(resource.RLIMIT_CPU, (4, 5))
  resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
  resource.setrlimit(resource.RLIMIT_NOFILE, (16, 16))
  signal.signal(signal.SIGALRM, lambda _signum, _frame: os._exit(78))
  signal.alarm(4)

  root = os.fsencode(sys.argv[1])
  relative = os.fsencode(sys.argv[2])
  limit = int(sys.argv[3])
  flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW

  if limit < 0 or limit > 4000 or not root.startswith(b"/") or relative.startswith(b"/"):
      raise SystemExit(76)

  components = [part for part in root.split(b"/") if part]
  components.extend(part for part in relative.split(b"/") if part)
  if any(part in (b".", b"..") or b"/" in part or b"\\x00" in part for part in components):
      raise SystemExit(76)

  def fail_os(error):
      if error.errno in (errno.ENOMEM, errno.EMFILE, errno.ENFILE):
          raise SystemExit(86)
      raise SystemExit(79)

  try:
      descriptor = os.open(b"/", flags)
      for component in components:
          next_descriptor = os.open(component, flags, dir_fd=descriptor)
          os.close(descriptor)
          descriptor = next_descriptor
  except OSError as error:
      fail_os(error)

  def write_all(payload):
      while payload:
          try:
              written = os.write(1, payload)
          except OSError as error:
              fail_os(error)
          if written < 1:
              raise SystemExit(76)
          payload = payload[written:]

  try:
      before = os.fstat(descriptor)
      emitted = 0
      try:
          with os.scandir(descriptor) as entries:
              for index, entry in enumerate(entries):
                  if index >= limit:
                      raise SystemExit(75)
                  name = os.fsencode(entry.name)
                  if not name or len(name) > 512:
                      raise SystemExit(76)
                  write_all(len(name).to_bytes(2, "big") + name)
                  emitted += 1
      except OSError as error:
          fail_os(error)
      after = os.fstat(descriptor)
      if (before.st_dev, before.st_ino, before.st_mtime_ns, before.st_ctime_ns) != (after.st_dev, after.st_ino, after.st_mtime_ns, after.st_ctime_ns):
          raise SystemExit(80)
  finally:
      os.close(descriptor)

  terminal = b"\\x00" + emitted.to_bytes(4, "big")
  write_all(len(terminal).to_bytes(2, "big") + terminal)
  """
  @file_helper_script """
  import ctypes
  import errno
  import os
  import resource
  import signal
  import stat
  import sys

  null = os.open("/dev/null", os.O_WRONLY | os.O_CLOEXEC)
  os.dup2(null, 2)
  os.close(null)

  if sys.implementation.name != "cpython" or sys.version_info[:2] != (3, 12):
      raise SystemExit(77)

  parent = os.getppid()
  libc = ctypes.CDLL(None, use_errno=True)
  if libc.prctl(1, signal.SIGKILL, 0, 0, 0) != 0:
      raise SystemExit(77)
  if os.getppid() != parent:
      os.kill(os.getpid(), signal.SIGKILL)
  if libc.prctl(38, 1, 0, 0, 0) != 0:
      raise SystemExit(77)

  resource.setrlimit(resource.RLIMIT_AS, (134217728, 134217728))
  resource.setrlimit(resource.RLIMIT_CPU, (4, 5))
  resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
  resource.setrlimit(resource.RLIMIT_NOFILE, (16, 16))
  signal.signal(signal.SIGALRM, lambda _signum, _frame: os._exit(78))
  signal.alarm(4)

  root = os.fsencode(sys.argv[1])
  relative = os.fsencode(sys.argv[2])
  limit = int(sys.argv[3])
  directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
  file_flags = os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK

  if limit < 1 or limit > 262144 or not root.startswith(b"/") or relative.startswith(b"/"):
      raise SystemExit(76)

  root_components = [part for part in root.split(b"/") if part]
  relative_components = [part for part in relative.split(b"/") if part]
  components = root_components + relative_components
  if not relative_components or any(part in (b".", b"..") or b"/" in part or b"\\x00" in part for part in components):
      raise SystemExit(76)

  def fail_os(error):
      if error.errno in (errno.ENOMEM, errno.EMFILE, errno.ENFILE):
          raise SystemExit(86)
      raise SystemExit(79)

  try:
      descriptor = os.open(b"/", directory_flags)
      for component in components[:-1]:
          next_descriptor = os.open(component, directory_flags, dir_fd=descriptor)
          os.close(descriptor)
          descriptor = next_descriptor
  except OSError as error:
      fail_os(error)

  try:
      try:
          file_descriptor = os.open(components[-1], file_flags, dir_fd=descriptor)
      except OSError as error:
          if error.errno == errno.ELOOP:
              raise SystemExit(84)
          if error.errno == errno.ENOENT:
              raise SystemExit(85)
          fail_os(error)
  finally:
      os.close(descriptor)

  def write_all(payload):
      while payload:
          try:
              written = os.write(1, payload)
          except OSError as error:
              fail_os(error)
          if written < 1:
              raise SystemExit(76)
          payload = payload[written:]

  try:
      before = os.fstat(file_descriptor)
      if stat.S_ISDIR(before.st_mode):
          raise SystemExit(83)
      if not stat.S_ISREG(before.st_mode):
          raise SystemExit(82)
      if before.st_size > limit:
          raise SystemExit(81)

      write_all(b"JCF1" + before.st_size.to_bytes(4, "big"))
      remaining = before.st_size
      while remaining:
          chunk = os.read(file_descriptor, min(65536, remaining))
          if not chunk:
              raise SystemExit(80)
          write_all(chunk)
          remaining -= len(chunk)
      if os.read(file_descriptor, 1):
          raise SystemExit(80)

      after = os.fstat(file_descriptor)
      if (before.st_dev, before.st_ino, before.st_mode, before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (after.st_dev, after.st_ino, after.st_mode, after.st_size, after.st_mtime_ns, after.st_ctime_ns):
          raise SystemExit(80)
  except OSError as error:
      fail_os(error)
  finally:
      os.close(file_descriptor)

  write_all(b"JCE1")
  """
  @ignored ~w[.git .hg .svn _build deps node_modules vendor cover tmp]
  @text_extensions ~w[.md .markdown .txt .ex .exs .heex .json .toml .yaml .yml .lock .css .js .ts]
  @manifest_names ~w[mix.exs mix.lock]
  @inventory_keys ~w[profile repository_iri source_snapshot_iri source_fence registrations entries graph_sources gaps file_count total_bytes module_names generated_at model_calls model_tokens digest]a
  @registration_keys ~w[root_files documentation_roots source_roots test_roots guide_roots]a
  @entry_keys ~w[path kind media_type bytes digest module_names]a
  @entry_kinds ~w[readme mix_manifest mix_lock root_document architecture_document plan_document research_document documentation source test guide]a
  @gap_reasons ~w[symlinked unsupported missing unreadable ignored oversized changed_during_read binary]a

  @spec profile() :: map()
  def profile do
    %{
      revision: @profile,
      root_files: ["README.md", "mix.exs", "mix.lock"],
      documentation_roots: ["docs"],
      source_roots: ["lib"],
      test_roots: ["test"],
      guide_roots: ["guides"],
      limits: @maximums,
      traversal_limits: %{
        visited_paths: @maximum_visited_paths,
        directory_worker_heap_words: @directory_heap_words,
        directory_timeout_ms: @directory_timeout_ms,
        directory_enumerator: :bounded_python_scandir_port,
        directory_protocol: :streamed_uint16_frames_with_terminal_count,
        directory_max_record_bytes: @maximums.path_bytes,
        directory_max_output: :remaining_budget_derived,
        file_protocol: :bounded_header_content_terminal,
        file_max_output_bytes: @maximums.file_bytes + 12,
        directory_helper_wall_seconds: @directory_helper_wall_seconds,
        directory_helper_cpu_seconds: @directory_helper_cpu_seconds,
        directory_helper_address_space_bytes: @directory_helper_address_space_bytes,
        directory_helper_descriptors: @directory_helper_descriptors,
        directory_helper_concurrency_per_vm: @directory_helper_concurrency,
        traversal_deadline_ms: @traversal_deadline_ms,
        directory_helper_executables: [
          @directory_timeout_executable,
          @directory_limit_executable,
          @directory_python_executable
        ],
        directory_helper_runtime: "CPython 3.12",
        directory_helper_script_sha256: sha256(@directory_helper_script),
        file_helper_script_sha256: sha256(@file_helper_script),
        directory_helper_environment: :empty_except_c_locale,
        directory_helper_parent_death_signal: :sigkill,
        directory_helper_no_new_privileges: true,
        trusted_inventory_helper_execution: :required
      },
      execution: :forbidden,
      network: :forbidden,
      symlinks: :record_gap,
      accepted_graph_families: [
        :factory_catalog,
        :factory_policy,
        :repository_control,
        :source_revision,
        :evidence,
        :memory
      ]
    }
  end

  @spec scan(String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def scan(root, attributes) when is_binary(root) and is_map(attributes) do
    limits = Map.get(attributes, :limits, @maximums)
    deadline = System.monotonic_time(:millisecond) + @traversal_deadline_ms

    with :ok <- valid_root(root),
         :ok <- valid_limits(limits),
         :ok <- directory_helpers_available(),
         :ok <- ResourceIdentity.validate(attributes[:repository_iri]),
         :ok <- ResourceIdentity.validate(attributes[:source_snapshot_iri]),
         true <- valid_fence?(attributes[:source_fence]),
         {:ok, registrations} <- registrations(attributes, limits),
         {:ok, graph_sources} <- accepted_graph_sources(attributes, attributes.repository_iri),
         {:ok, entries, gaps} <- walk_registrations(root, registrations, limits, deadline),
         :ok <- entry_capacity(entries, limits) do
      ordered_entries = Enum.sort_by(entries, & &1.path)
      ordered_gaps = Enum.sort_by(gaps, &{&1.path, &1.reason})

      manifest = %{
        profile: @profile,
        repository_iri: attributes.repository_iri,
        source_snapshot_iri: attributes.source_snapshot_iri,
        source_fence: attributes.source_fence,
        registrations: registrations,
        entries: ordered_entries,
        graph_sources: graph_sources,
        gaps: ordered_gaps,
        file_count: length(ordered_entries),
        total_bytes: Enum.sum(Enum.map(ordered_entries, & &1.bytes)),
        module_names:
          ordered_entries |> Enum.flat_map(& &1.module_names) |> Enum.uniq() |> Enum.sort(),
        generated_at: nil,
        model_calls: 0,
        model_tokens: 0
      }

      inventory = Map.put(manifest, :digest, Contract.digest(manifest))

      case validate(inventory) do
        :ok -> {:ok, inventory}
        {:error, %Error{} = error} -> {:error, error}
      end
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_inventory)
    end
  rescue
    _error -> invalid(:repository_wiki_inventory)
  end

  def scan(_root, _attributes), do: invalid(:repository_wiki_inventory)

  @doc "Validates a detached inventory manifest against the current closed profile."
  @spec validate(map()) :: :ok | {:error, Error.t()}
  def validate(inventory) when is_map(inventory) and not is_struct(inventory) do
    limits = @maximums

    with true <- Enum.sort(Map.keys(inventory)) == Enum.sort(@inventory_keys),
         true <- inventory.profile == @profile,
         :ok <- ResourceIdentity.validate(inventory.repository_iri),
         :ok <- ResourceIdentity.validate(inventory.source_snapshot_iri),
         true <- valid_fence?(inventory.source_fence),
         true <- valid_registrations?(inventory.registrations, limits),
         true <- valid_entries?(inventory.entries, inventory.registrations, limits),
         true <- valid_graph_sources?(inventory.graph_sources, inventory.repository_iri),
         true <- valid_gaps?(inventory.gaps, inventory.registrations, limits),
         true <- inventory.file_count == length(inventory.entries),
         true <- inventory.total_bytes == Enum.sum(Enum.map(inventory.entries, & &1.bytes)),
         true <- inventory.total_bytes <= limits.total_bytes,
         true <- length(inventory.entries) + length(inventory.gaps) <= @maximum_visited_paths,
         true <- inventory.module_names == inventory_module_names(inventory.entries),
         true <- is_nil(inventory.generated_at),
         true <- inventory.model_calls == 0 and inventory.model_tokens == 0,
         true <- Contract.digest?(inventory.digest),
         true <- inventory.digest == Contract.digest(Map.delete(inventory, :digest)) do
      :ok
    else
      _invalid -> invalid(:repository_wiki_inventory_manifest)
    end
  rescue
    _error -> invalid(:repository_wiki_inventory_manifest)
  end

  def validate(_inventory), do: invalid(:repository_wiki_inventory_manifest)

  defp registrations(attributes, limits) do
    profile = profile()

    values = %{
      root_files: Map.get(attributes, :root_files, profile.root_files),
      documentation_roots: Map.get(attributes, :documentation_roots, profile.documentation_roots),
      source_roots: Map.get(attributes, :source_roots, profile.source_roots),
      test_roots: Map.get(attributes, :test_roots, profile.test_roots),
      guide_roots: Map.get(attributes, :guide_roots, profile.guide_roots)
    }

    if Enum.all?(values, fn {_kind, paths} ->
         is_list(paths) and length(paths) <= 32 and
           Enum.all?(paths, &safe_relative?(&1, limits.path_bytes))
       end) do
      {:ok, Map.new(values, fn {kind, paths} -> {kind, paths |> Enum.uniq() |> Enum.sort()} end)}
    else
      invalid(:repository_wiki_registrations)
    end
  end

  defp accepted_graph_sources(attributes, repository_iri) do
    allowed = profile().accepted_graph_families
    sources = Map.get(attributes, :accepted_graph_sources, [])

    if is_list(sources) and length(sources) <= 100 do
      Enum.reduce_while(sources, {:ok, []}, fn source, {:ok, result} ->
        with true <- is_map(source),
             true <- source[:repository_iri] == repository_iri,
             {:ok, family} <- GraphRegistry.identify(source[:graph_iri]),
             true <- family in allowed,
             :ok <- ResourceIdentity.validate(source[:resource_iri]),
             revision when is_integer(revision) and revision >= 0 <- source[:revision],
             true <- Contract.digest?(source[:digest]) do
          normalized = %{
            repository_iri: repository_iri,
            family: family,
            graph_iri: source.graph_iri,
            resource_iri: source.resource_iri,
            revision: revision,
            digest: source.digest
          }

          {:cont, {:ok, [normalized | result]}}
        else
          _invalid -> {:halt, invalid(:repository_wiki_graph_source)}
        end
      end)
      |> case do
        {:ok, values} -> {:ok, Enum.sort_by(values, &{&1.family, &1.graph_iri, &1.resource_iri})}
        error -> error
      end
    else
      invalid(:repository_wiki_graph_sources)
    end
  end

  defp walk_registrations(root, registrations, limits, deadline) do
    traversal_limit = @maximum_visited_paths

    registrations
    |> Enum.sort()
    |> Enum.reduce_while({:ok, [], [], 0}, fn {kind, paths}, {:ok, entries, gaps, visited} ->
      Enum.reduce_while(paths, {:ok, entries, gaps, visited}, fn relative,
                                                                 {:ok, found, missing, path_count} ->
        remaining = traversal_limit - path_count

        case walk_path(root, relative, kind, limits, remaining, deadline) do
          {:ok, new_entries, new_gaps, new_count} ->
            combined = found ++ new_entries

            case entry_capacity(combined, limits) do
              :ok -> {:cont, {:ok, combined, missing ++ new_gaps, path_count + new_count}}
              {:error, %Error{} = error} -> {:halt, {:error, error}}
            end

          {:error, %Error{} = error} ->
            {:halt, {:error, error}}
        end
      end)
      |> case do
        {:ok, next_entries, next_gaps, next_count} ->
          {:cont, {:ok, next_entries, next_gaps, next_count}}

        {:error, %Error{} = error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, entries, gaps, _visited} -> {:ok, entries, gaps}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp walk_path(_root, _relative, _kind, _limits, remaining, _deadline) when remaining < 1,
    do: invalid(:repository_wiki_traversal_limit)

  defp walk_path(root, relative, kind, limits, remaining, deadline) do
    cond do
      not before_deadline?(deadline) ->
        invalid(:repository_wiki_traversal_limit)

      not safe_relative?(relative, limits.path_bytes) ->
        invalid(:repository_wiki_path_limit)

      true ->
        case bounded_read_path(root, relative, limits.file_bytes, deadline) do
          {:ok, contents} ->
            case read_entry(relative, kind, contents, limits) do
              {:ok, entries, gaps} -> {:ok, entries, gaps, 1}
            end

          {:type, :directory} ->
            case walk_directory(root, relative, kind, limits, remaining - 1, deadline) do
              {:ok, entries, gaps, visited} -> {:ok, entries, gaps, visited + 1}
              {:error, %Error{} = error} -> {:error, error}
            end

          {:type, :symlink} ->
            {:ok, [], [gap(relative, :symlinked)], 1}

          {:type, :unsupported} ->
            {:ok, [], [gap(relative, :unsupported)], 1}

          {:error, :path_missing} ->
            {:ok, [], [gap(relative, :missing)], 1}

          {:error, :path_oversized} ->
            {:ok, [], [gap(relative, :oversized)], 1}

          {:error, :path_changed_during_read} ->
            {:ok, [], [gap(relative, :changed_during_read)], 1}

          {:error, :path_unreadable} ->
            {:ok, [], [gap(relative, :unreadable)], 1}

          {:error, reason}
          when reason in [
                 :path_protocol,
                 :path_helper_unavailable,
                 :path_resource_limit
               ] ->
            invalid(:repository_wiki_directory_enumerator)

          {:error, :path_timeout} ->
            invalid(:repository_wiki_traversal_limit)

          {:error, _reason} ->
            invalid(:repository_wiki_inventory)
        end
    end
  end

  defp walk_directory(root, relative, kind, limits, remaining, deadline) do
    case bounded_list_dir(root, relative, remaining, deadline) do
      {:ok, names} ->
        names
        |> Enum.sort()
        |> Enum.reduce_while({:ok, [], [], 0}, fn name, {:ok, entries, gaps, visited} ->
          child = Path.join(relative, name)

          if safe_relative?(child, limits.path_bytes) do
            result =
              if ignored?(name) do
                if visited < remaining,
                  do: {:ok, [], [gap(child, :ignored)], 1},
                  else: invalid(:repository_wiki_traversal_limit)
              else
                walk_path(root, child, kind, limits, remaining - visited, deadline)
              end

            case result do
              {:ok, child_entries, child_gaps, child_count} ->
                combined = entries ++ child_entries

                case entry_capacity(combined, limits) do
                  :ok ->
                    {:cont, {:ok, combined, gaps ++ child_gaps, visited + child_count}}

                  {:error, %Error{} = error} ->
                    {:halt, {:error, error}}
                end

              {:error, %Error{} = error} ->
                {:halt, {:error, error}}
            end
          else
            {:halt, invalid(:repository_wiki_path_limit)}
          end
        end)

      {:error, reason}
      when reason in [:directory_enumeration_limit, :directory_enumeration_timeout] ->
        invalid(:repository_wiki_traversal_limit)

      {:error, :directory_name_encoding} ->
        invalid(:repository_wiki_path_limit)

      {:error, :directory_enumerator_unavailable} ->
        invalid(:repository_wiki_directory_enumerator)

      {:error, reason}
      when reason in [:directory_protocol, :directory_enumeration_resource_limit] ->
        invalid(:repository_wiki_directory_enumerator)

      {:error, :directory_changed_during_read} ->
        {:ok, [], [gap(relative, :changed_during_read)], 0}

      {:error, :directory_unreadable} ->
        {:ok, [], [gap(relative, :unreadable)], 0}

      {:error, _reason} ->
        invalid(:repository_wiki_directory_enumerator)
    end
  end

  defp bounded_list_dir(root, relative, remaining, deadline)
       when is_integer(remaining) and remaining >= 0 do
    SourceInventoryHelperBoundary.run(
      fn -> bounded_port_list_dir(root, relative, remaining) end,
      deadline,
      :directory_enumeration_limit,
      :directory_enumeration_timeout,
      helper_boundary_options()
    )
  end

  defp bounded_read_path(root, relative, file_limit, deadline) do
    SourceInventoryHelperBoundary.run(
      fn -> bounded_port_read_path(root, relative, file_limit) end,
      deadline,
      :path_resource_limit,
      :path_timeout,
      helper_boundary_options()
    )
  end

  defp helper_boundary_options do
    %{
      slot_scope: __MODULE__,
      concurrency: @directory_helper_concurrency,
      receiver_timeout_ms: @directory_timeout_ms,
      helper_wall_ms: @directory_helper_wall_seconds * 1_000,
      heap_words: @directory_heap_words
    }
  end

  defp remaining_milliseconds(deadline) do
    max(deadline - System.monotonic_time(:millisecond), 0)
  end

  defp before_deadline?(deadline), do: remaining_milliseconds(deadline) > 0

  # OTP's list-dir APIs and primitive NIF both materialize every entry before
  # returning. This fixed, no-shell port helper opens every path component by
  # descriptor, yields at most `remaining` length-prefixed names plus a terminal
  # count, and applies independent wall-clock, CPU, address-space, descriptor,
  # aggregate-output, concurrency, and BEAM worker limits.
  defp bounded_port_list_dir(root, relative, remaining) do
    with {:ok, port} <- open_directory_port(root, relative, remaining) do
      collect_directory_names(port, remaining, %{
        chunks: [],
        total_bytes: 0,
        eof?: false,
        status: nil
      })
    end
  end

  defp open_directory_port(root, relative, remaining) do
    args = [
      "--signal=KILL",
      Integer.to_string(@directory_helper_wall_seconds) <> "s",
      @directory_limit_executable,
      "--as=#{@directory_helper_address_space_bytes}",
      "--cpu=#{@directory_helper_cpu_seconds}:#{@directory_helper_cpu_seconds + 1}",
      "--core=0",
      "--nofile=#{@directory_helper_descriptors}",
      "--",
      @directory_python_executable,
      "-I",
      "-S",
      "-E",
      "-c",
      @directory_helper_script,
      root,
      relative,
      Integer.to_string(remaining)
    ]

    {:ok,
     Port.open(
       {:spawn_executable, @directory_timeout_executable},
       [
         :binary,
         :stream,
         :eof,
         :exit_status,
         :use_stdio,
         :stderr_to_stdout,
         {:args, args},
         {:env, directory_port_environment()},
         {:cd, ~c"/"}
       ]
     )}
  rescue
    _error -> {:error, :directory_enumerator_unavailable}
  end

  defp collect_directory_names(port, remaining, state) do
    receive do
      {^port, {:data, data}} when is_binary(data) ->
        total_bytes = state.total_bytes + byte_size(data)

        if state.eof? or total_bytes > maximum_directory_output(remaining) do
          directory_protocol_error(port, :directory_protocol, state)
        else
          state
          |> Map.put(:chunks, [data | state.chunks])
          |> Map.put(:total_bytes, total_bytes)
          |> then(&collect_directory_names(port, remaining, &1))
        end

      {^port, :eof} ->
        if state.eof? do
          directory_protocol_error(port, :directory_protocol, state)
        else
          state
          |> Map.put(:eof?, true)
          |> finish_or_collect_directory_names(port, remaining)
        end

      {^port, {:exit_status, status}} when is_integer(status) ->
        if is_nil(state.status) do
          state
          |> Map.put(:status, status)
          |> finish_or_collect_directory_names(port, remaining)
        else
          directory_protocol_error(port, :directory_protocol, state)
        end
    end
  end

  defp finish_or_collect_directory_names(%{eof?: true, status: status} = state, port, remaining)
       when is_integer(status) do
    close_port(port)
    body = state.chunks |> Enum.reverse() |> IO.iodata_to_binary()
    SourceInventoryProtocol.decode_directory(body, status, state.eof?, remaining)
  end

  defp finish_or_collect_directory_names(state, port, remaining),
    do: collect_directory_names(port, remaining, state)

  defp directory_protocol_error(port, reason, state) do
    reject_port_response(port, {:error, reason}, state.eof?, not is_nil(state.status))
  end

  defp maximum_directory_output(remaining) do
    remaining * (@maximums.path_bytes + 2) + 7
  end

  # File classification and content reads use the same descriptor-relative,
  # externally supervised boundary. This prevents an intermediate symlink swap
  # from turning a later absolute File.read into an out-of-root read, and the
  # producer never emits more than the caller's accepted per-file envelope.
  defp bounded_port_read_path(root, relative, file_limit) do
    with {:ok, port} <- open_file_port(root, relative, file_limit) do
      collect_file_response(port, file_limit, %{
        chunks: [],
        total_bytes: 0,
        eof?: false,
        status: nil
      })
    end
  end

  defp open_file_port(root, relative, file_limit) do
    args = [
      "--signal=KILL",
      Integer.to_string(@directory_helper_wall_seconds) <> "s",
      @directory_limit_executable,
      "--as=#{@directory_helper_address_space_bytes}",
      "--cpu=#{@directory_helper_cpu_seconds}:#{@directory_helper_cpu_seconds + 1}",
      "--core=0",
      "--nofile=#{@directory_helper_descriptors}",
      "--",
      @directory_python_executable,
      "-I",
      "-S",
      "-E",
      "-c",
      @file_helper_script,
      root,
      relative,
      Integer.to_string(file_limit)
    ]

    {:ok,
     Port.open(
       {:spawn_executable, @directory_timeout_executable},
       [
         :binary,
         :stream,
         :eof,
         :exit_status,
         :use_stdio,
         :stderr_to_stdout,
         {:args, args},
         {:env, directory_port_environment()},
         {:cd, ~c"/"}
       ]
     )}
  rescue
    _error -> {:error, :path_helper_unavailable}
  end

  defp collect_file_response(port, file_limit, state) do
    receive do
      {^port, {:data, data}} when is_binary(data) ->
        total_bytes = state.total_bytes + byte_size(data)

        if state.eof? or total_bytes > file_limit + 12 do
          file_protocol_error(port, state)
        else
          state
          |> Map.put(:chunks, [data | state.chunks])
          |> Map.put(:total_bytes, total_bytes)
          |> then(&collect_file_response(port, file_limit, &1))
        end

      {^port, :eof} ->
        if state.eof? do
          file_protocol_error(port, state)
        else
          state
          |> Map.put(:eof?, true)
          |> finish_or_collect_file_response(port, file_limit)
        end

      {^port, {:exit_status, status}} when is_integer(status) ->
        if is_nil(state.status) do
          state
          |> Map.put(:status, status)
          |> finish_or_collect_file_response(port, file_limit)
        else
          file_protocol_error(port, state)
        end
    end
  end

  defp finish_or_collect_file_response(%{eof?: true, status: status} = state, port, file_limit)
       when is_integer(status) do
    close_port(port)
    body = state.chunks |> Enum.reverse() |> IO.iodata_to_binary()
    SourceInventoryProtocol.decode_file(body, status, state.eof?, file_limit)
  end

  defp finish_or_collect_file_response(state, port, file_limit),
    do: collect_file_response(port, file_limit, state)

  defp file_protocol_error(port, state) do
    reject_port_response(port, {:error, :path_protocol}, state.eof?, not is_nil(state.status))
  end

  defp reject_port_response(port, result, true, true) do
    close_port(port)
    result
  end

  defp reject_port_response(port, result, eof?, status?) do
    receive do
      {^port, {:data, _discarded}} ->
        reject_port_response(port, result, eof?, status?)

      {^port, :eof} ->
        reject_port_response(port, result, true, status?)

      {^port, {:exit_status, _status}} ->
        reject_port_response(port, result, eof?, true)
    after
      @directory_timeout_ms ->
        close_port(port)
        result
    end
  end

  defp close_port(port) do
    if Port.info(port), do: Port.close(port)
    :ok
  rescue
    _error -> :ok
  end

  defp directory_port_environment do
    removed =
      System.get_env()
      |> Map.keys()
      |> Enum.reject(&(&1 == "LC_ALL"))
      |> Enum.map(&{String.to_charlist(&1), false})

    [{~c"LC_ALL", ~c"C"} | removed]
  end

  defp directory_helpers_available do
    helpers = [
      @directory_timeout_executable,
      @directory_limit_executable,
      @directory_python_executable
    ]

    if Enum.all?(helpers, &trusted_directory_helper?/1),
      do: :ok,
      else: invalid(:repository_wiki_directory_enumerator)
  end

  defp trusted_directory_helper?(path) do
    case File.lstat(path, time: :posix) do
      {:ok, %File.Stat{type: :regular, mode: mode}} ->
        Bitwise.band(mode, 0o111) != 0 and Bitwise.band(mode, 0o022) == 0

      _invalid ->
        false
    end
  end

  defp read_entry(relative, registered_kind, contents, limits) do
    with true <- byte_size(contents) <= limits.file_bytes,
         :ok <- text?(contents),
         {:ok, media_type} <- media_type(relative) do
      normalized = normalize_content(contents)

      {:ok,
       [
         %{
           path: normalize_path(relative),
           kind: classify(relative, registered_kind),
           media_type: media_type,
           bytes: byte_size(contents),
           digest: sha256(normalized),
           module_names: module_names(relative, normalized)
         }
       ], []}
    else
      false -> {:ok, [], [gap(relative, :oversized)]}
      {:error, :binary} -> {:ok, [], [gap(relative, :binary)]}
      {:error, :unsupported} -> {:ok, [], [gap(relative, :unsupported)]}
    end
  rescue
    _error -> {:ok, [], [gap(relative, :unreadable)]}
  end

  defp valid_root(root) do
    expanded = Path.expand(root)

    if root == expanded and safe_root_components?(expanded) and
         match?({:ok, %File.Stat{type: :directory}}, File.lstat(expanded)),
       do: :ok,
       else: invalid(:repository_wiki_root)
  end

  defp safe_root_components?(root) do
    root
    |> Path.split()
    |> Enum.reduce({true, ""}, fn component, {safe?, current} ->
      path =
        if current in ["", "/"],
          do: Path.join("/", component),
          else: Path.join(current, component)

      symlink? = match?({:ok, %File.Stat{type: :symlink}}, File.lstat(path))
      {safe? and not symlink?, path}
    end)
    |> elem(0)
  end

  defp valid_limits(limits) when is_map(limits) do
    if Map.keys(limits) |> Enum.sort() == Map.keys(@maximums) |> Enum.sort() and
         Enum.all?(@maximums, fn {key, maximum} ->
           value = limits[key]
           is_integer(value) and value > 0 and value <= maximum
         end),
       do: :ok,
       else: invalid(:repository_wiki_inventory_limits)
  end

  defp valid_limits(_limits), do: invalid(:repository_wiki_inventory_limits)

  defp valid_registrations?(registrations, limits)
       when is_map(registrations) and not is_struct(registrations) do
    all_paths = registrations |> Map.values() |> List.flatten()

    Enum.sort(Map.keys(registrations)) == Enum.sort(@registration_keys) and
      length(all_paths) == length(Enum.uniq(all_paths)) and
      Enum.all?(@registration_keys, fn kind ->
        paths = Map.get(registrations, kind)

        is_list(paths) and length(paths) <= 32 and paths == Enum.sort(Enum.uniq(paths)) and
          Enum.all?(paths, &safe_relative?(&1, limits.path_bytes))
      end)
  end

  defp valid_registrations?(_registrations, _limits), do: false

  defp valid_entries?(entries, registrations, limits) when is_list(entries) do
    length(entries) <= limits.files and entries == Enum.sort_by(entries, & &1[:path]) and
      unique_field?(entries, :path) and
      Enum.all?(entries, &valid_entry?(&1, registrations, limits))
  end

  defp valid_entries?(_entries, _registrations, _limits), do: false

  defp valid_entry?(entry, registrations, limits)
       when is_map(entry) and not is_struct(entry) do
    Enum.sort(Map.keys(entry)) == Enum.sort(@entry_keys) and
      safe_relative?(entry.path, limits.path_bytes) and entry.kind in @entry_kinds and
      registered_entry?(entry.path, entry.kind, registrations) and
      media_type(entry.path) == {:ok, entry.media_type} and is_integer(entry.bytes) and
      entry.bytes in 0..limits.file_bytes and Contract.digest?(entry.digest) and
      valid_module_names?(entry.module_names, entry.bytes)
  rescue
    _error -> false
  end

  defp valid_entry?(_entry, _registrations, _limits), do: false

  defp valid_module_names?(names, source_bytes)
       when is_list(names) and is_integer(source_bytes) do
    length(names) <= source_bytes and names == Enum.sort(Enum.uniq(names)) and
      Enum.all?(names, fn name ->
        is_binary(name) and byte_size(name) in 1..max(source_bytes, 1) and
          Regex.match?(~r/^[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*$/u, name)
      end)
  end

  defp valid_module_names?(_names, _source_bytes), do: false

  defp valid_graph_sources?(sources, repository_iri) when is_list(sources) do
    case accepted_graph_sources(%{accepted_graph_sources: sources}, repository_iri) do
      {:ok, normalized} -> normalized == sources
      _error -> false
    end
  end

  defp valid_graph_sources?(_sources, _repository_iri), do: false

  defp valid_gaps?(gaps, registrations, limits) when is_list(gaps) do
    length(gaps) <= @maximum_visited_paths and
      gaps == Enum.sort_by(gaps, &{&1[:path], &1[:reason]}) and
      unique_field?(gaps, :path) and
      Enum.all?(gaps, fn gap ->
        is_map(gap) and not is_struct(gap) and Enum.sort(Map.keys(gap)) == [:path, :reason] and
          safe_relative?(gap.path, limits.path_bytes) and
          registered_path?(gap.path, registrations) and gap.reason in @gap_reasons
      end)
  rescue
    _error -> false
  end

  defp valid_gaps?(_gaps, _registrations, _limits), do: false

  defp registered_entry?(path, kind, registrations) do
    Enum.any?(registrations, fn {registered_kind, roots} ->
      Enum.any?(roots, fn root ->
        registered_path?(path, root) and classify(path, registered_kind) == kind
      end)
    end)
  end

  defp registered_path?(path, registrations) when is_map(registrations) do
    Enum.any?(registrations, fn {_kind, roots} ->
      Enum.any?(roots, &registered_path?(path, &1))
    end)
  end

  defp registered_path?(path, root), do: path == root or String.starts_with?(path, root <> "/")

  defp inventory_module_names(entries) do
    entries
    |> Enum.flat_map(& &1.module_names)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp unique_field?(items, field) do
    values = Enum.map(items, &Map.get(&1, field))
    length(values) == length(Enum.uniq(values))
  end

  defp safe_relative?(path, maximum_bytes) when is_binary(path) and is_integer(maximum_bytes) do
    normalized = :unicode.characters_to_nfc_binary(path)
    parts = Path.split(path)

    path == normalized and byte_size(path) in 1..maximum_bytes and
      Path.type(path) == :relative and path == normalize_path(path) and
      not String.contains?(path, ["\\", "\0"]) and
      not Regex.match?(~r/[\x00-\x1F\x7F]/u, path) and
      Enum.all?(parts, &(&1 not in ["", ".", ".."]))
  end

  defp safe_relative?(_path, _maximum_bytes), do: false

  defp entry_capacity(entries, limits) do
    cond do
      length(entries) > limits.files ->
        invalid(:repository_wiki_file_limit)

      Enum.sum(Enum.map(entries, & &1.bytes)) > limits.total_bytes ->
        invalid(:repository_wiki_total_bytes_limit)

      true ->
        :ok
    end
  end

  defp text?(contents), do: if(binary?(contents), do: {:error, :binary}, else: :ok)

  defp media_type(relative) do
    extension = Path.extname(relative) |> String.downcase()

    cond do
      Path.basename(relative) in @manifest_names -> {:ok, "text/x-elixir"}
      extension in @text_extensions -> {:ok, media_type_for(extension)}
      true -> {:error, :unsupported}
    end
  end

  defp media_type_for(extension) when extension in [".md", ".markdown"], do: "text/markdown"
  defp media_type_for(extension) when extension in [".ex", ".exs", ".heex"], do: "text/x-elixir"
  defp media_type_for(".json"), do: "application/json"
  defp media_type_for(_extension), do: "text/plain"

  defp classify(relative, :root_files) do
    case Path.basename(relative) do
      "README.md" -> :readme
      "mix.exs" -> :mix_manifest
      "mix.lock" -> :mix_lock
      _other -> :root_document
    end
  end

  defp classify(relative, :documentation_roots) do
    cond do
      String.contains?(relative, "/adr/") or String.contains?(relative, "/architecture/") ->
        :architecture_document

      String.contains?(relative, "/planning/") ->
        :plan_document

      String.contains?(relative, "/research/") ->
        :research_document

      true ->
        :documentation
    end
  end

  defp classify(_relative, :source_roots), do: :source
  defp classify(_relative, :test_roots), do: :test
  defp classify(_relative, :guide_roots), do: :guide

  defp module_names(relative, contents) do
    if Path.extname(relative) in [".ex", ".exs"] do
      Regex.scan(~r/\bdefmodule\s+([A-Z][A-Za-z0-9_.]*)\b/u, contents, capture: :all_but_first)
      |> Enum.map(&List.first/1)
      |> Enum.uniq()
      |> Enum.sort()
    else
      []
    end
  end

  defp normalize_content(contents),
    do: contents |> String.replace("\r\n", "\n") |> String.replace("\r", "\n")

  defp normalize_path(path), do: path |> Path.split() |> Path.join()
  defp ignored?(name), do: name in @ignored or String.starts_with?(name, ".")
  defp binary?(contents), do: :binary.match(contents, <<0>>) != :nomatch
  defp valid_fence?(value), do: is_binary(value) and byte_size(value) in 1..512
  defp gap(path, reason), do: %{path: normalize_path(path), reason: reason}
  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
