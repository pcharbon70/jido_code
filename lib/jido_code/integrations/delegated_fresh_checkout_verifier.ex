defmodule JidoCode.Integrations.DelegatedFreshCheckoutVerifier do
  @moduledoc "Reconstructs delegated candidates in a separate clone and emits governed evidence."

  @architecture_file_role :external_worktree

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.DelegatedCandidate
  alias JidoCode.Factory.DelegatedVerificationResult
  alias JidoCode.Factory.ManagedCoding.CheckCatalog
  alias JidoCode.Factory.ManagedCoding.CheckDefinition
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Security.Redactor

  @spec architecture_file_role() :: :external_worktree
  def architecture_file_role, do: @architecture_file_role

  @spec verify(DelegatedCandidate.t(), module(), term(), map(), keyword()) ::
          {:ok, DelegatedVerificationResult.t()} | {:error, AdapterError.t()}
  def verify(candidate, artifact_module, artifact_store, attributes, options \\ [])

  def verify(
        %DelegatedCandidate{} = candidate,
        artifact_module,
        artifact_store,
        attributes,
        options
      )
      when is_atom(artifact_module) and is_map(attributes) and is_list(options) do
    target = verifier_target(attributes, candidate)

    with :ok <- verifier_boundary(candidate, artifact_module, attributes, target),
         :ok <- absent(target),
         :ok <- prepare_root(attributes.verifier_root) do
      try do
        verify_fresh(candidate, artifact_module, artifact_store, attributes, options, target)
      after
        _ = File.rm_rf(target)
      end
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:delegated_fresh_checkout_verification)
    end
  rescue
    _error -> invalid(:delegated_fresh_checkout_verification)
  end

  def verify(_candidate, _artifact_module, _artifact_store, _attributes, _options),
    do: invalid(:delegated_fresh_checkout_verification)

  defp verify_fresh(candidate, artifact_module, artifact_store, attributes, options, target) do
    with {:ok, _clone} <-
           git(attributes.source_root, [
             "clone",
             "--no-local",
             "--no-checkout",
             "--",
             attributes.source_root,
             target
           ]),
         {:ok, _checkout} <- git(target, ["checkout", "--detach", candidate.base_commit]),
         {:ok, head} <- git(target, ["rev-parse", "HEAD"]),
         :ok <- ensure(String.trim(head) == candidate.base_commit, :delegated_verifier_base),
         {:ok, artifact} <- fetch_patch(candidate, artifact_module, artifact_store),
         :ok <- apply_patch(target, artifact.content),
         {:ok, changed_paths} <- changed_paths(target),
         :ok <-
           ensure(
             changed_paths == Enum.map(candidate.changed_files, & &1.path),
             :delegated_verifier_changed_paths
           ),
         :ok <- verify_files(target, candidate.changed_files),
         {:ok, tree} <- WorkspaceDigest.tree(target, attributes.limits),
         :ok <- ensure(tree.digest == candidate.tree_digest, :delegated_verifier_tree),
         :ok <- verify_generated(candidate),
         :ok <- secret_scan(target, candidate.changed_files),
         {:ok, checks} <- run_checks(target, candidate, attributes, options),
         status <- overall_status(checks),
         report <- report(candidate, attributes, target, tree, checks, status),
         {:ok, evidence} <- record_evidence(report, options),
         :ok <-
           ensure(
             evidence[:outcome] in [:committed, :idempotent],
             :delegated_verifier_evidence_commit
           ),
         {:ok, result} <-
           DelegatedVerificationResult.new(candidate, %{
             verifier_actor_iri: attributes.verifier_actor_iri,
             verifier_profile_revision: attributes.verifier_profile_revision,
             environment_revision: attributes.environment_revision,
             verifier_workspace_digest: WorkspaceDigest.digest({target, tree.digest}),
             status: status,
             checks: checks,
             patch_digest: artifact.digest,
             tree_digest: tree.digest,
             file_manifest_digest: WorkspaceDigest.digest(candidate.changed_files),
             generated_artifact_digest: WorkspaceDigest.digest(candidate.generated_artifacts),
             secret_scan_digest: WorkspaceDigest.digest({:clean, candidate.patch_digest}),
             evidence_iri: evidence.evidence_iri,
             evidence_digest: evidence.evidence_digest,
             completed_at: Keyword.get(options, :completed_at, DateTime.utc_now())
           }) do
      {:ok, result}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:delegated_fresh_checkout_integrity)
    end
  end

  defp verifier_boundary(candidate, artifact_module, attributes, target) do
    with true <-
           Code.ensure_loaded?(artifact_module) and function_exported?(artifact_module, :fetch, 2),
         actor when is_binary(actor) <- attributes[:verifier_actor_iri],
         producer when is_binary(producer) <- attributes[:producer_actor_iri],
         true <- actor != producer,
         root when is_binary(root) <- attributes[:source_root],
         true <- Path.type(root) == :absolute and File.dir?(root),
         verifier_root when is_binary(verifier_root) <- attributes[:verifier_root],
         true <- Path.type(verifier_root) == :absolute,
         producer_root when is_binary(producer_root) <- attributes[:producer_workspace_root],
         true <- Path.type(producer_root) == :absolute,
         true <- target != producer_root and not descendant?(target, producer_root),
         true <- attributes[:provider_session_ref] == nil,
         true <- attributes[:cli_process_ref] == nil,
         true <- is_map(attributes[:limits]),
         %CheckCatalog{} = catalog <- attributes[:check_catalog],
         true <- catalog.revision == candidate.check_registry_revision,
         checks when is_list(checks) and checks != [] <- attributes[:required_checks],
         true <- checks == Enum.uniq(checks),
         true <- Enum.all?(checks, &Map.has_key?(catalog.definitions, &1)) do
      :ok
    else
      _invalid -> unauthorized(:delegated_verifier_independence)
    end
  end

  defp verifier_target(attributes, candidate) do
    case attributes[:verifier_root] do
      root when is_binary(root) -> Path.join(root, candidate.candidate_digest)
      _invalid -> ""
    end
  end

  defp prepare_root(root) do
    with true <- is_binary(root) and Path.type(root) == :absolute,
         :ok <- File.mkdir_p(root),
         :ok <- File.chmod(root, 0o700) do
      :ok
    else
      _invalid -> invalid(:delegated_verifier_root)
    end
  end

  defp absent(path) do
    case File.lstat(path) do
      {:error, :enoent} -> :ok
      _present -> invalid(:delegated_verifier_workspace_identity)
    end
  end

  defp fetch_patch(candidate, artifact_module, artifact_store) do
    with {:ok, artifact} <-
           artifact_module.fetch(artifact_store, %{
             artifact_iri: candidate.patch_artifact_iri,
             digest: candidate.patch_digest,
             maximum_bytes: candidate.patch_bytes + 1
           }),
         :ok <-
           ensure(artifact.byte_count == candidate.patch_bytes, :delegated_verifier_patch_size) do
      {:ok, artifact}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:delegated_verifier_patch)
    end
  end

  defp apply_patch(target, content) do
    path = Path.join(target, ".jido-candidate.patch")

    with :ok <- File.write(path, content, [:binary, :exclusive]),
         {:ok, _output} <- git(target, ["apply", "--binary", "--whitespace=nowarn", "--", path]),
         :ok <- File.rm(path) do
      :ok
    else
      _invalid -> invalid(:delegated_verifier_apply_patch)
    end
  end

  defp changed_paths(target) do
    with {:ok, status} <-
           git(target, [
             "status",
             "--porcelain=v1",
             "-z",
             "--untracked-files=all",
             "--no-renames"
           ]) do
      paths =
        status
        |> String.split(<<0>>, trim: true)
        |> Enum.map(&binary_part(&1, 3, byte_size(&1) - 3))
        |> Enum.sort()

      {:ok, paths}
    end
  end

  defp verify_files(target, files) do
    Enum.reduce_while(files, :ok, fn file, :ok ->
      case verify_file(target, file) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp verify_file(target, %{operation: :delete, path: path}) do
    if File.exists?(Path.join(target, path)), do: invalid(:delegated_verifier_file), else: :ok
  end

  defp verify_file(target, file) do
    path = Path.join(target, file.path)

    with {:ok, %File.Stat{type: :regular, size: size, mode: mode}} <- File.lstat(path),
         {:ok, content} <- File.read(path),
         true <- size == file.size,
         true <- WorkspaceDigest.digest(content) == file.digest,
         expected_mode <- if(Bitwise.band(mode, 0o111) == 0, do: 0o644, else: 0o755),
         true <- expected_mode == file.mode,
         true <- not String.valid?(content) == file.binary? do
      :ok
    else
      _invalid -> invalid(:delegated_verifier_file)
    end
  end

  defp verify_generated(candidate) do
    changed = Map.new(candidate.changed_files, &{&1.path, &1.digest})

    if Enum.all?(candidate.generated_artifacts, fn artifact ->
         changed[artifact.path] == artifact.digest
       end),
       do: :ok,
       else: invalid(:delegated_verifier_generated_artifact)
  end

  defp secret_scan(target, files) do
    Enum.reduce_while(files, :ok, fn
      %{operation: :delete}, :ok ->
        {:cont, :ok}

      file, :ok ->
        with {:ok, content} <- File.read(Path.join(target, file.path)),
             :ok <- Redactor.reject_sensitive(content) do
          {:cont, :ok}
        else
          _invalid -> {:halt, unauthorized(:delegated_verifier_secret_scan)}
        end
    end)
  end

  defp run_checks(target, candidate, attributes, options) do
    catalog = attributes.check_catalog

    attributes.required_checks
    |> Enum.reduce_while({:ok, []}, fn name, {:ok, receipts} ->
      definition = Map.fetch!(catalog.definitions, name)

      case run_check(target, candidate, definition, options) do
        {:ok, receipt} -> {:cont, {:ok, [receipt | receipts]}}
        {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, receipts} -> {:ok, Enum.sort_by(receipts, & &1.check)}
      error -> error
    end
  end

  defp run_check(target, candidate, definition, options) do
    runner = Keyword.get(options, :check_runner, &default_runner/2)
    cwd = Path.expand(definition.cwd, target)

    with true <- descendant_or_same?(cwd, target),
         command <- %{
           executable: definition.executable,
           arguments: definition.arguments,
           cwd: cwd,
           environment: definition.environment,
           network: :deny
         },
         {:ok, execution} <- runner.(command, definition.timeout_ms),
         output when is_binary(output) <- execution[:output],
         :ok <- Redactor.reject_sensitive(output),
         true <- byte_size(output) <= definition.output_bytes,
         exit_code when is_integer(exit_code) <- execution[:exit_code] do
      status = if exit_code == 0, do: :passed, else: :failed

      material = %{
        check: definition.name,
        status: status,
        command_digest: CheckDefinition.digest(definition),
        output_digest: WorkspaceDigest.digest(output),
        exit_code: exit_code,
        duration_ms: Map.get(execution, :duration_ms, 0),
        candidate_digest: candidate.candidate_digest
      }

      {:ok, Map.put(material, :result_digest, WorkspaceDigest.digest(material))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:delegated_verifier_check)
    end
  end

  defp default_runner(command, timeout) do
    task =
      Task.async(fn ->
        started = System.monotonic_time(:millisecond)

        {output, exit_code} =
          System.cmd(command.executable, command.arguments,
            cd: command.cwd,
            env: Map.to_list(command.environment),
            stderr_to_stdout: true
          )

        {:ok,
         %{
           output: output,
           exit_code: exit_code,
           duration_ms: System.monotonic_time(:millisecond) - started
         }}
      end)

    case Task.yield(task, timeout) do
      {:ok, result} ->
        result

      nil ->
        _ = Task.shutdown(task, :brutal_kill)
        {:ok, %{output: "", exit_code: 124, duration_ms: timeout}}
    end
  end

  defp overall_status(checks) do
    if Enum.all?(checks, &(&1.status == :passed)), do: :passed, else: :failed
  end

  defp report(candidate, attributes, target, tree, checks, status) do
    %{
      candidate_iri: candidate.candidate_iri,
      candidate_digest: candidate.candidate_digest,
      verifier_actor_iri: attributes.verifier_actor_iri,
      verifier_profile_revision: attributes.verifier_profile_revision,
      environment_revision: attributes.environment_revision,
      verifier_workspace_digest: WorkspaceDigest.digest({target, tree.digest}),
      patch_digest: candidate.patch_digest,
      tree_digest: tree.digest,
      checks: checks,
      status: status,
      fresh_checkout: true,
      acceptance_authority: false,
      publication_authority: false,
      merge_authority: false,
      goal_satisfaction_authority: false
    }
  end

  defp record_evidence(report, options) do
    case Keyword.get(options, :record_evidence) do
      callback when is_function(callback, 1) ->
        case callback.(report) do
          {:ok, %{evidence_iri: iri, evidence_digest: digest} = receipt}
          when is_binary(iri) and is_binary(digest) ->
            {:ok, receipt}

          _invalid ->
            invalid(:delegated_verifier_evidence)
        end

      _missing ->
        invalid(:delegated_verifier_evidence)
    end
  end

  defp git(root, arguments) do
    environment = [
      {"GIT_CONFIG_NOSYSTEM", "1"},
      {"GIT_CONFIG_GLOBAL", "/dev/null"},
      {"GIT_TERMINAL_PROMPT", "0"},
      {"GIT_ASKPASS", "/bin/false"},
      {"SSH_AUTH_SOCK", nil}
    ]

    case System.cmd("git", arguments, cd: root, env: environment, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      _failure -> invalid(:delegated_verifier_git)
    end
  end

  defp descendant?(path, root) do
    relative = Path.relative_to(Path.expand(path), Path.expand(root))
    relative != "." and descendant_relative?(relative)
  end

  defp descendant_or_same?(path, root) do
    relative = Path.relative_to(Path.expand(path), Path.expand(root))
    relative == "." or descendant_relative?(relative)
  end

  defp descendant_relative?(relative) do
    Path.type(relative) != :absolute and relative != ".." and
      not String.starts_with?(relative, "../")
  end

  defp ensure(true, _operation), do: :ok
  defp ensure(false, operation), do: invalid(operation)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end
