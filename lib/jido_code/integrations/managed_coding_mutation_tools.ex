defmodule JidoCode.Integrations.ManagedCodingMutationTools do
  @moduledoc "Concrete digest-, scope-, authority-, and fence-guarded file mutations."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.MutationRequest
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Factory.Tool.RepositoryPathGuard

  @spec apply_edit(MutationRequest.t(), map(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def apply_edit(%MutationRequest{} = request, arguments, options) when is_map(arguments) do
    with :ok <- revalidate(request, options),
         false <- protected?(arguments[:path], request.protected_paths),
         {:ok, resolved} <- resolve(request, arguments[:path], :existing_file),
         {:ok, content} <- File.read(resolved.absolute),
         true <- String.valid?(content),
         old when is_binary(old) and byte_size(old) > 0 <- arguments[:old_text],
         new when is_binary(new) <- arguments[:new_text],
         true <- arguments[:expected_matches] == 1,
         expected when is_binary(expected) <- arguments[:expected_digest],
         effect = effect_identity(request, :apply_edit, resolved.relative, expected, new),
         {:ok, outcome} <- edit_outcome(content, old, new, expected),
         {:ok, receipt} <- apply_outcome(outcome, resolved.absolute, request, effect, options) do
      {:ok, Map.put(receipt, :path, resolved.relative)}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:apply_edit)
    end
  rescue
    _error -> invalid(:apply_edit)
  end

  def apply_edit(_request, _arguments, _options), do: invalid(:apply_edit)

  @spec create_file(MutationRequest.t(), map(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def create_file(%MutationRequest{} = request, arguments, options) when is_map(arguments) do
    path = arguments[:path]
    content = arguments[:content]
    mode = Map.get(arguments, :mode, 0o644)

    with :ok <- revalidate(request, options),
         false <- protected?(path, request.protected_paths),
         true <- is_binary(content) and byte_size(content) <= request.limits.output_bytes,
         true <- mode in [0o644, 0o755],
         {:ok, resolved} <- resolve_create(request, path),
         expected when is_binary(expected) <- arguments[:expected_parent_digest],
         effect = effect_identity(request, :create_file, path, expected, content),
         {:ok, receipt} <-
           create_or_replay(resolved.absolute, content, mode, expected, request, effect, options) do
      {:ok, Map.put(receipt, :path, resolved.relative)}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:create_file)
    end
  rescue
    _error -> invalid(:create_file)
  end

  def create_file(_request, _arguments, _options), do: invalid(:create_file)

  @spec delete_file(MutationRequest.t(), map(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def delete_file(%MutationRequest{} = request, arguments, options) when is_map(arguments) do
    path = arguments[:path]
    expected = arguments[:expected_digest]
    effect = effect_identity(request, :delete_file, path, expected, :delete)

    with :ok <- revalidate(request, options),
         false <- protected?(path, request.protected_paths),
         {:ok, receipt} <- delete_or_replay(request, path, expected, effect, options) do
      {:ok, receipt}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:delete_file)
    end
  rescue
    _error -> invalid(:delete_file)
  end

  def delete_file(_request, _arguments, _options), do: invalid(:delete_file)

  @spec parent_digest(Path.t()) :: String.t() | nil
  def parent_digest(path) when is_binary(path) do
    parent = Path.dirname(path)

    case File.ls(parent) do
      {:ok, names} ->
        names
        |> Enum.reject(&String.starts_with?(&1, ".jido-code-tmp-"))
        |> Enum.sort()
        |> WorkspaceDigest.digest()
        |> then(&("sha256:" <> &1))

      _error ->
        nil
    end
  end

  defp edit_outcome(content, old, new, expected) do
    current = digest(content)

    cond do
      current == expected and occurrences(content, old) == 1 ->
        updated = String.replace(content, old, new, global: false)
        {:ok, {:write, updated, content, expected}}

      occurrences(content, new) == 1 and
          content |> String.replace(new, old, global: false) |> digest() == expected ->
        {:ok, {:replay, content}}

      true ->
        {:error, AdapterError.new(:conflict, :apply_edit_digest)}
    end
  end

  defp apply_outcome({:replay, content}, _path, _request, effect, _options),
    do: {:ok, receipt(:replayed, effect, content, nil)}

  defp apply_outcome({:write, content, prior, expected}, path, request, effect, options) do
    with true <- byte_size(content) <= request.limits.output_bytes,
         :ok <- revalidate(request, options),
         :ok <- atomic_replace(path, content, expected) do
      case workspace_limits(request) do
        :ok ->
          {:ok, receipt(:committed, effect, content, nil)}

        {:error, %AdapterError{} = error} ->
          _rollback = atomic_replace(path, prior, digest(content))
          {:error, error}
      end
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:unauthorized, :apply_edit_limits)}
    end
  end

  defp create_or_replay(path, content, mode, expected_parent, request, effect, options) do
    case File.lstat(path) do
      {:error, :enoent} ->
        with ^expected_parent <- parent_digest(path),
             :ok <- revalidate(request, options),
             :ok <- atomic_write(path, content),
             :ok <- File.chmod(path, mode) do
          case workspace_limits(request) do
            :ok ->
              {:ok, receipt(:committed, effect, content, %{mode: mode})}

            {:error, %AdapterError{} = error} ->
              _rollback = File.rm(path)
              {:error, error}
          end
        else
          {:error, %AdapterError{} = error} -> {:error, error}
          _invalid -> {:error, AdapterError.new(:unavailable, :create_file)}
        end

      {:ok, %File.Stat{type: :regular, mode: current_mode}} ->
        with {:ok, existing} <- File.read(path),
             true <- existing == content and Bitwise.band(current_mode, 0o777) == mode do
          {:ok, receipt(:replayed, effect, content, %{mode: mode})}
        else
          _invalid -> {:error, AdapterError.new(:conflict, :create_file_exists)}
        end

      _unsafe ->
        {:error, AdapterError.new(:unauthorized, :create_file_type)}
    end
  end

  defp delete_or_replay(request, path, expected, effect, options) do
    journal = journal_path(request, effect)

    case resolve(request, path, :existing_file) do
      {:ok, resolved} ->
        with {:ok, content} <- File.read(resolved.absolute),
             ^expected <- digest(content),
             :ok <- File.mkdir_p(Path.dirname(journal)),
             :ok <- revalidate(request, options),
             :ok <- File.rename(resolved.absolute, journal) do
          case workspace_limits(request) do
            :ok ->
              {:ok,
               receipt(:committed, effect, content, %{
                 path: resolved.relative,
                 candidate_diff: %{operation: :delete, prior_digest: expected}
               })}

            {:error, %AdapterError{} = error} ->
              _rollback = restore_deleted(journal, resolved.absolute)
              {:error, error}
          end
        else
          {:error, %AdapterError{} = error} -> {:error, error}
          _invalid -> {:error, AdapterError.new(:conflict, :delete_file_digest)}
        end

      {:error, %AdapterError{}} ->
        case File.read(journal) do
          {:ok, content} ->
            if digest(content) == expected do
              {:ok,
               receipt(:replayed, effect, content, %{
                 path: path,
                 candidate_diff: %{operation: :delete, prior_digest: expected}
               })}
            else
              {:error, AdapterError.new(:conflict, :delete_file_missing)}
            end

          _missing ->
            {:error, AdapterError.new(:conflict, :delete_file_missing)}
        end
    end
  end

  defp revalidate(request, options) do
    with provider when is_function(provider, 0) <- Keyword.get(options, :current_provider),
         current when is_map(current) <- provider.(),
         true <- current[:attempt_iri] == request.attempt_iri,
         true <- current[:lease_iri] == request.lease_iri,
         true <- current[:fencing_token] == request.fencing_token,
         true <- current[:workspace_iri] == request.workspace_iri,
         true <- current[:workspace_digest] == request.workspace_digest,
         true <- current[:snapshot_iri] == request.snapshot_iri,
         true <- current[:capability_iri] == request.capability_iri,
         true <- current[:policy_revision] == request.policy_revision,
         true <- current[:lease_current?] == true and current[:policy_current?] == true do
      :ok
    else
      _stale -> {:error, AdapterError.new(:unauthorized, :mutation_revalidation)}
    end
  end

  defp workspace_limits(request) do
    with {:ok, tree} <-
           WorkspaceDigest.tree(request.workspace_root, %{
             file_count: request.limits.changed_files + 10_000,
             input_bytes: request.limits.disk_bytes,
             disk_bytes: request.limits.disk_bytes
           }),
         {:ok, {changed, diff_bytes}} <- git_diff_limits(request.workspace_root),
         true <-
           changed <= request.limits.changed_files and diff_bytes <= request.limits.diff_bytes do
      _tree = tree
      :ok
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :workspace_mutation_limits)}
    end
  end

  defp git_diff_limits(root) do
    with {paths, 0} <- System.cmd("git", ["diff", "--name-only", "HEAD"], cd: root),
         {untracked, 0} <-
           System.cmd("git", ["ls-files", "--others", "--exclude-standard"], cd: root),
         {diff, 0} <- System.cmd("git", ["diff", "--binary", "HEAD"], cd: root) do
      changed_paths = String.split(paths <> untracked, "\n", trim: true) |> Enum.uniq()

      untracked_bytes =
        untracked
        |> String.split("\n", trim: true)
        |> Enum.reduce(0, fn path, bytes ->
          case File.stat(Path.join(root, path)) do
            {:ok, stat} -> bytes + stat.size
            _error -> bytes
          end
        end)

      {:ok, {length(changed_paths), byte_size(diff) + untracked_bytes}}
    else
      _failure -> {:error, AdapterError.new(:unavailable, :workspace_diff)}
    end
  end

  defp resolve(request, path, mode),
    do: RepositoryPathGuard.resolve(request.workspace_root, path, request.allowed_paths, mode)

  defp resolve_create(request, path) do
    case resolve(request, path, :new_file) do
      {:ok, resolved} -> {:ok, resolved}
      {:error, %AdapterError{}} -> resolve(request, path, :existing_file)
    end
  end

  defp atomic_write(path, content) do
    temporary = Path.join(Path.dirname(path), ".jido-code-tmp-#{WorkspaceDigest.digest(content)}")

    with :ok <- File.write(temporary, content, [:binary, :exclusive]),
         :ok <- File.rename(temporary, path) do
      :ok
    else
      {:error, :eexist} -> {:error, AdapterError.new(:conflict, :workspace_atomic_write)}
      _failure -> {:error, AdapterError.new(:unavailable, :workspace_atomic_write)}
    end
  end

  defp atomic_replace(path, content, expected) do
    with {:ok, current} <- File.read(path),
         ^expected <- digest(current) do
      temporary =
        Path.join(Path.dirname(path), ".jido-code-tmp-#{WorkspaceDigest.digest(content)}")

      with :ok <- File.write(temporary, content, [:binary, :exclusive]),
           :ok <- File.rename(temporary, path) do
        :ok
      else
        {:error, :eexist} -> {:error, AdapterError.new(:conflict, :workspace_atomic_write)}
        _failure -> {:error, AdapterError.new(:unavailable, :workspace_atomic_write)}
      end
    else
      _stale -> {:error, AdapterError.new(:conflict, :workspace_atomic_write)}
    end
  end

  defp restore_deleted(journal, path) do
    case {File.exists?(journal), File.exists?(path)} do
      {true, false} -> File.rename(journal, path)
      _other -> :ok
    end
  end

  defp journal_path(request, effect) do
    Path.join([request.workspace_root <> ".jido-effects", effect, "deleted"])
  end

  defp protected?(path, protected) when is_binary(path),
    do: Enum.any?(protected, &(path == &1 or String.starts_with?(path, &1 <> "/")))

  defp protected?(_path, _protected), do: true

  defp effect_identity(request, tool, path, expected, material) do
    WorkspaceDigest.digest({
      request.attempt_iri,
      request.fencing_token,
      request.workspace_iri,
      tool,
      path,
      expected,
      WorkspaceDigest.digest(material)
    })
  end

  defp receipt(outcome, effect, content, extra) do
    %{
      outcome: outcome,
      effect_identity: effect,
      new_digest: digest(content),
      byte_count: byte_size(content),
      details: extra
    }
  end

  defp digest(content), do: "sha256:" <> WorkspaceDigest.digest(content)
  defp occurrences(content, text), do: length(String.split(content, text)) - 1
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
