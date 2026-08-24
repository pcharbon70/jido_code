defmodule JidoCode.Integrations.ManagedCodingCandidateTools do
  @moduledoc "Registered check, bounded diff, and immutable candidate-capture effects."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CheckCatalog
  alias JidoCode.Factory.ManagedCoding.CheckDefinition
  alias JidoCode.Factory.ManagedCoding.MutationRequest
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Security.Redactor

  @spec run_registered_check(MutationRequest.t(), map(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def run_registered_check(%MutationRequest{} = request, %{check: name}, options)
      when is_binary(name) do
    with :ok <- revalidate(request, options),
         %CheckCatalog{} = catalog <- Keyword.get(options, :check_catalog),
         {:ok, %CheckDefinition{} = definition} <- CheckCatalog.fetch(catalog, name),
         runner when is_function(runner, 2) <- Keyword.get(options, :check_runner),
         command = command(definition, request.workspace_root),
         {:ok, observation} <- runner.(command, definition.timeout_ms),
         {:ok, result} <- check_result(definition, observation) do
      {:ok, Map.put(result, :catalog_revision, catalog.revision)}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:run_registered_check)
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :run_registered_check)}
  end

  def run_registered_check(_request, _arguments, _options),
    do: invalid(:run_registered_check)

  @spec show_candidate_diff(MutationRequest.t(), map(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def show_candidate_diff(%MutationRequest{} = request, arguments, options) do
    maximum =
      min(Map.get(arguments, :max_bytes, request.limits.diff_bytes), request.limits.diff_bytes)

    with :ok <- revalidate(request, options),
         true <- arguments[:snapshot_ref] == request.snapshot_iri,
         true <- is_integer(maximum) and maximum > 0,
         {:ok, candidate} <- candidate_state(request, maximum) do
      {:ok, Map.drop(candidate, [:raw_patch])}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:show_candidate_diff)
    end
  end

  @spec capture_candidate(MutationRequest.t(), map(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def capture_candidate(%MutationRequest{} = request, attributes, options)
      when is_map(attributes) do
    with :ok <- revalidate(request, options),
         toolchain when is_binary(toolchain) and byte_size(toolchain) == 64 <-
           attributes[:toolchain_revision],
         profile when is_binary(profile) and byte_size(profile) == 64 <-
           attributes[:profile_revision],
         {:ok, candidate} <- candidate_state(request, request.limits.diff_bytes) do
      artifact = %{
        schema_revision: "managed-candidate/1.0.0",
        base_snapshot_iri: request.snapshot_iri,
        base_tree_digest: candidate.base_tree_digest,
        current_tree_digest: candidate.current_tree_digest,
        workspace_iri: request.workspace_iri,
        workspace_digest: request.workspace_digest,
        patch_digest: "sha256:" <> WorkspaceDigest.digest(candidate.raw_patch),
        changed_paths: candidate.changed_paths,
        file_modes: candidate.file_modes,
        submodules: candidate.submodules,
        toolchain_revision: toolchain,
        profile_revision: profile,
        omissions: candidate.omissions
      }

      {:ok, Map.put(artifact, :artifact_digest, WorkspaceDigest.digest(artifact))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:capture_candidate)
    end
  end

  def capture_candidate(_request, _attributes, _options), do: invalid(:capture_candidate)

  defp command(definition, root) do
    %{
      name: definition.name,
      executable: definition.executable,
      arguments: definition.arguments,
      cwd: Path.expand(definition.cwd, root),
      environment: definition.environment,
      network: definition.network,
      resources: definition.resources,
      toolchain_digest: definition.toolchain_digest,
      output_bytes: definition.output_bytes,
      retry_policy: definition.retry_policy
    }
  end

  defp check_result(definition, observation) when is_map(observation) do
    output = Map.get(observation, :output, "")

    with true <- is_binary(output),
         {:ok, safe_output, redacted?} <- sanitize_text(output, definition.output_bytes) do
      status =
        cond do
          observation[:cancelled?] == true -> :cancelled
          observation[:timed_out?] == true -> :timeout
          observation[:infrastructure_error?] == true -> :infrastructure_failure
          not is_integer(observation[:exit_code]) -> :unavailable
          observation[:exit_code] == 0 -> :success
          true -> :failure
        end

      {:ok,
       %{
         check: definition.name,
         check_revision: CheckDefinition.digest(definition),
         status: status,
         exit_code: observation[:exit_code],
         duration_ms: Map.get(observation, :duration_ms),
         output: safe_output,
         truncated?: byte_size(output) > definition.output_bytes,
         redacted?: redacted?,
         flake_suspected?: observation[:flake_suspected?] == true
       }}
    else
      _invalid -> invalid(:registered_check_observation)
    end
  end

  defp candidate_state(request, maximum) do
    root = request.workspace_root

    with {:ok, base} <- git(root, ["rev-parse", "HEAD^{tree}"]),
         {:ok, status} <- git(root, ["status", "--porcelain=v1", "-z", "--untracked-files=all"]),
         {:ok, patch} <- candidate_patch(root, status),
         {:ok, safe_patch, redacted?} <- sanitize_text(patch, maximum),
         {:ok, tree} <-
           WorkspaceDigest.tree(root, %{
             file_count: 10_000,
             input_bytes: request.limits.disk_bytes,
             disk_bytes: request.limits.disk_bytes
           }),
         {:ok, submodules} <- submodule_state(root) do
      changed_paths = changed_paths(status)

      {:ok,
       %{
         base_tree_digest: "git-tree:" <> String.trim(base),
         current_tree_digest: "sha256:" <> tree.digest,
         changed_paths: changed_paths,
         file_modes: file_modes(root, changed_paths),
         submodules: submodules,
         diff: safe_patch,
         raw_patch: patch,
         byte_count: byte_size(safe_patch),
         truncated?: byte_size(patch) > maximum,
         redacted?: redacted?,
         omissions: omissions(patch, maximum, redacted?)
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:unavailable, :candidate_state)}
    end
  end

  defp candidate_patch(root, status) do
    with {:ok, tracked} <-
           git(root, ["diff", "--binary", "--no-ext-diff", "--no-renames", "HEAD", "--"]),
         {:ok, untracked} <- untracked_patch(root, changed_paths(status)) do
      {:ok, tracked <> untracked}
    end
  end

  defp untracked_patch(root, paths) do
    paths
    |> Enum.filter(&(git_untracked?(root, &1) and File.regular?(Path.join(root, &1))))
    |> Enum.reduce_while({:ok, ""}, fn path, {:ok, output} ->
      absolute = Path.join(root, path)

      case System.cmd("git", ["diff", "--no-index", "--binary", "--", "/dev/null", absolute],
             cd: root,
             env: git_environment(),
             stderr_to_stdout: true
           ) do
        {patch, code} when code in [0, 1] ->
          normalized = String.replace(patch, absolute, "b/" <> path)
          {:cont, {:ok, output <> normalized}}

        _failure ->
          {:halt, {:error, AdapterError.new(:unavailable, :candidate_untracked_diff)}}
      end
    end)
  end

  defp changed_paths(status) do
    status
    |> String.split(<<0>>, trim: true)
    |> Enum.map(fn entry -> entry |> binary_part(3, byte_size(entry) - 3) end)
    |> Enum.sort()
  end

  defp file_modes(root, paths) do
    Map.new(paths, fn path ->
      mode =
        case File.lstat(Path.join(root, path)) do
          {:ok, %File.Stat{type: :regular, mode: value}} ->
            if Bitwise.band(value, 0o111) == 0, do: 0o644, else: 0o755

          {:error, :enoent} ->
            :deleted

          _other ->
            :unsupported
        end

      {path, mode}
    end)
  end

  defp submodule_state(root) do
    case git(root, ["submodule", "status", "--recursive"]) do
      {:ok, output} -> {:ok, String.split(output, "\n", trim: true)}
      {:error, %AdapterError{}} -> {:ok, [:unavailable]}
    end
  end

  defp git_untracked?(root, path) do
    case System.cmd("git", ["ls-files", "--error-unmatch", "--", path],
           cd: root,
           env: git_environment(),
           stderr_to_stdout: true
         ) do
      {_output, 0} -> false
      {_output, _code} -> true
    end
  end

  defp sanitize_text(text, maximum) do
    bounded = binary_part(text, 0, min(byte_size(text), maximum))

    bounded
    |> chunks(8_000)
    |> Enum.reduce_while({:ok, [], false}, fn chunk, {:ok, safe, redacted?} ->
      case Redactor.sanitize(chunk) do
        {:ok, sanitized, receipt} ->
          {:cont, {:ok, [sanitized | safe], redacted? or receipt.redacted_count > 0}}

        _error ->
          {:halt, {:error, AdapterError.new(:unauthorized, :candidate_content_policy)}}
      end
    end)
    |> case do
      {:ok, safe, redacted?} -> {:ok, safe |> Enum.reverse() |> IO.iodata_to_binary(), redacted?}
      error -> error
    end
  end

  defp chunks("", _size), do: []

  defp chunks(text, size),
    do: for(<<chunk::binary-size(size) <- text>>, do: chunk) ++ tail(text, size)

  defp tail(text, size) do
    remainder = rem(byte_size(text), size)
    if remainder == 0, do: [], else: [binary_part(text, byte_size(text) - remainder, remainder)]
  end

  defp omissions(patch, maximum, redacted?) do
    []
    |> maybe_add(byte_size(patch) > maximum, :byte_limit)
    |> maybe_add(redacted?, :sensitive_content)
  end

  defp maybe_add(values, true, value), do: values ++ [value]
  defp maybe_add(values, false, _value), do: values

  defp revalidate(request, options) do
    with provider when is_function(provider, 0) <- Keyword.get(options, :current_provider),
         current when is_map(current) <- provider.(),
         true <- current[:attempt_iri] == request.attempt_iri,
         true <- current[:lease_iri] == request.lease_iri,
         true <- current[:fencing_token] == request.fencing_token,
         true <- current[:workspace_iri] == request.workspace_iri,
         true <- current[:snapshot_iri] == request.snapshot_iri,
         true <- current[:capability_iri] == request.capability_iri,
         true <- current[:policy_revision] == request.policy_revision,
         true <- current[:lease_current?] == true and current[:policy_current?] == true do
      :ok
    else
      _stale -> {:error, AdapterError.new(:unauthorized, :candidate_revalidation)}
    end
  end

  defp git(root, arguments) do
    case System.cmd("git", arguments, cd: root, env: git_environment(), stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      _failure -> {:error, AdapterError.new(:unavailable, :candidate_git)}
    end
  end

  defp git_environment do
    [
      {"GIT_CONFIG_NOSYSTEM", "1"},
      {"GIT_CONFIG_GLOBAL", "/dev/null"},
      {"GIT_TERMINAL_PROMPT", "0"},
      {"GIT_ASKPASS", "/bin/false"},
      {"SSH_AUTH_SOCK", nil}
    ]
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
