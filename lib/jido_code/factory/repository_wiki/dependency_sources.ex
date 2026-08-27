defmodule JidoCode.Factory.RepositoryWiki.DependencySources do
  @moduledoc "Filesystem and source-locator classification for repository wiki dependencies."

  alias JidoCode.Knowledge.Error

  @profile "wiki-dependency-sources/1.0.0"
  @maximums %{
    nodes: 2_048,
    path_bytes: 512,
    url_bytes: 2_048,
    public_hosts: 3,
    path_entries: 4_096,
    path_file_bytes: 1_048_576,
    path_total_bytes: 16_777_216
  }
  @closed_public_git_hosts ["bitbucket.org", "github.com", "gitlab.com"]

  @spec classify(map(), Path.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def classify(catalog, workspace_root, attributes)
      when is_map(catalog) and is_binary(workspace_root) and is_map(attributes) do
    with :ok <- validate(catalog, workspace_root, attributes),
         {:ok, nodes} <- classify_nodes(catalog.nodes, workspace_root, attributes) do
      result = %{
        catalog
        | nodes: nodes,
          gaps: source_gaps(nodes, catalog.gaps),
          completeness: source_completeness(nodes, catalog.completeness)
      }

      result =
        result
        |> Map.put(:source_profile, @profile)
        |> Map.put(:source_profile_digest, digest(profile(attributes)))

      {:ok, Map.put(result, :digest, digest(Map.delete(result, :digest)))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def classify(_catalog, _workspace_root, _attributes), do: invalid()

  defp profile(attributes) do
    %{
      revision: @profile,
      limits: @maximums,
      registered_path_prefixes: Enum.sort(attributes.registered_path_prefixes),
      public_git_hosts: Enum.sort(attributes.public_git_hosts),
      symlinks: :deny,
      credentials: :redact,
      moving_refs: :text_only,
      unsafe_schemes: :deny
    }
  end

  defp validate(catalog, workspace_root, attributes) do
    cond do
      catalog[:profile] != "wiki-dependency-resolver/1.0.0" or not digest?(catalog[:digest]) ->
        invalid()

      length(catalog[:nodes] || []) > @maximums.nodes ->
        invalid()

      Path.type(workspace_root) != :absolute or Path.expand(workspace_root) != workspace_root ->
        invalid()

      not match?({:ok, %File.Stat{type: :directory}}, File.lstat(workspace_root)) ->
        invalid()

      not valid_prefixes?(attributes[:registered_path_prefixes]) ->
        invalid()

      not valid_hosts?(attributes[:public_git_hosts]) ->
        invalid()

      not is_map(attributes[:umbrella_children] || %{}) ->
        invalid()

      true ->
        :ok
    end
  end

  defp classify_nodes(nodes, root, attributes) do
    classified =
      Enum.map(nodes, fn node ->
        {:ok, value} = classify_node(node, root, attributes)
        value
      end)

    {:ok, Enum.sort_by(classified, & &1.name)}
  end

  defp classify_node(%{scm: scm} = node, root, attributes) when scm in ["path", "umbrella"] do
    declared_path =
      cond do
        scm == "umbrella" -> (attributes[:umbrella_children] || %{})[node.name]
        node.declaration -> node.declaration.options["path"]
        node.lock -> node.lock[:path]
        true -> nil
      end

    source = path_source(root, declared_path, attributes.registered_path_prefixes)
    {:ok, node |> sanitize_path_node(source) |> Map.put(:source, source)}
  end

  defp classify_node(%{scm: "git"} = node, _root, attributes) do
    url =
      cond do
        node.lock && node.lock[:url] ->
          node.lock.url

        node.declaration ->
          node.declaration.options["git"] || github_url(node.declaration.options["github"])

        true ->
          nil
      end

    revision = if node.lock, do: node.lock[:revision], else: nil
    source = git_source(url, revision, attributes.public_git_hosts)
    {:ok, node |> sanitize_git_node(source) |> Map.put(:source, source)}
  end

  defp classify_node(%{scm: "hex"} = node, _root, _attributes) do
    {:ok,
     Map.put(node, :source, %{
       class: :hex,
       state: if(node.lock, do: :verified_lock, else: :unavailable),
       external_link_eligible: not is_nil(node.lock),
       reason: if(node.lock, do: nil, else: :missing_lock)
     })}
  end

  defp classify_node(node, _root, _attributes) do
    {:ok,
     Map.put(node, :source, %{
       class: :unsupported,
       state: :unsupported,
       external_link_eligible: false,
       reason: :unsupported_scm
     })}
  end

  defp path_source(_root, nil, _prefixes),
    do: %{class: :path, state: :unavailable, external_link_eligible: false, reason: :missing_path}

  defp path_source(root, relative, prefixes) do
    with :ok <- safe_relative(relative),
         true <- Enum.any?(prefixes, &inside?(relative, &1)),
         {:ok, absolute} <- walk_directory(root, Path.split(relative)) do
      case directory_digest(absolute, relative) do
        {:ok, target_digest, entry_count, byte_count} ->
          %{
            class: :path,
            state: :available,
            relative: relative,
            target_digest: target_digest,
            entry_count: entry_count,
            byte_count: byte_count,
            external_link_eligible: false,
            reason: nil
          }

        {:error, reason} ->
          %{
            class: :path,
            state: :unavailable,
            external_link_eligible: false,
            reason: reason
          }
      end
    else
      false ->
        %{
          class: :path,
          state: :unavailable,
          external_link_eligible: false,
          reason: :outside_envelope
        }

      _invalid ->
        %{
          class: :path,
          state: :unavailable,
          external_link_eligible: false,
          reason: :missing_or_unsafe
        }
    end
  end

  defp git_source(nil, _revision, _public_hosts),
    do: %{
      class: :git,
      state: :unavailable,
      display: nil,
      external_link_eligible: false,
      reason: :missing_url
    }

  defp git_source(url, revision, public_hosts)
       when is_binary(url) and byte_size(url) <= @maximums.url_bytes do
    uri = URI.parse(url)
    host = if is_binary(uri.host), do: String.downcase(uri.host), else: nil
    credentialed = not is_nil(uri.userinfo)
    exact_revision = is_binary(revision) and Regex.match?(~r/^[a-fA-F0-9]{40,64}$/, revision)

    safe_path =
      String.valid?(url) and is_binary(uri.path) and uri.path != "" and
        not String.contains?(uri.path, [<<0>>, "\\", "\r", "\n"]) and is_nil(uri.query) and
        is_nil(uri.fragment)

    cond do
      uri.scheme != "https" or is_nil(host) or not safe_path ->
        %{
          class: :git,
          state: :unavailable,
          display: "[unavailable]",
          external_link_eligible: false,
          reason: :unsafe_scheme_or_locator
        }

      credentialed ->
        %{
          class: :git,
          state: :redacted,
          display: "[redacted source]",
          external_link_eligible: false,
          reason: :credentials_redacted
        }

      host not in public_hosts ->
        %{
          class: :git,
          state: :private,
          display: "[private source]",
          external_link_eligible: false,
          reason: :private_or_unverified_host
        }

      not exact_revision ->
        %{
          class: :git,
          state: :moving,
          display: "https://#{host}#{uri.path}",
          external_link_eligible: false,
          reason: :missing_immutable_revision
        }

      true ->
        canonical = "https://#{host}#{uri.path}"

        %{
          class: :git,
          state: :verified,
          display: canonical,
          canonical_url: canonical,
          revision: String.downcase(revision),
          external_link_eligible: true,
          reason: nil
        }
    end
  end

  defp git_source(_url, _revision, _public_hosts),
    do: %{
      class: :git,
      state: :unavailable,
      display: nil,
      external_link_eligible: false,
      reason: :invalid_locator
    }

  defp github_url(value) when is_binary(value), do: "https://github.com/" <> value <> ".git"
  defp github_url(_value), do: nil

  defp sanitize_git_node(node, source) do
    safe_url = if source.state == :verified, do: source.canonical_url, else: nil

    node
    |> Map.put(:identity, safe_git_identity(safe_url, source[:revision]))
    |> Map.update(:source_options, %{}, &sanitize_git_options(&1, safe_url))
    |> Map.update(:lock_options, %{}, &sanitize_git_options(&1, safe_url))
    |> Map.update(:declaration, nil, &sanitize_declaration_options(&1, "git", safe_url))
    |> Map.update(:lock, nil, fn
      nil -> nil
      lock -> lock |> Map.drop([:url, :identity]) |> Map.put(:locator_state, source.state)
    end)
  end

  defp sanitize_path_node(node, %{state: :available, relative: relative}) do
    node
    |> Map.put(:identity, "path:" <> relative)
    |> Map.update(:source_options, %{}, &Map.put(&1, "path", relative))
    |> Map.update(:lock_options, %{}, &Map.put(&1, "path", relative))
    |> Map.update(:declaration, nil, &sanitize_declaration_options(&1, "path", relative))
    |> Map.update(:lock, nil, fn
      nil -> nil
      lock -> lock |> Map.drop([:path, :identity]) |> Map.put(:relative_path, relative)
    end)
  end

  defp sanitize_path_node(node, source) do
    node
    |> Map.put(:identity, nil)
    |> Map.update(:source_options, %{}, &Map.drop(&1, ["path"]))
    |> Map.update(:lock_options, %{}, &Map.drop(&1, ["path"]))
    |> Map.update(:declaration, nil, &sanitize_declaration_options(&1, "path", nil))
    |> Map.update(:lock, nil, fn
      nil -> nil
      lock -> lock |> Map.drop([:path, :identity]) |> Map.put(:locator_state, source.state)
    end)
  end

  defp sanitize_git_options(options, safe_url) do
    sanitized = Map.drop(options, ["git", "github"])
    if safe_url, do: Map.put(sanitized, "git", safe_url), else: sanitized
  end

  defp sanitize_declaration_options(nil, _key, _safe_value), do: nil

  defp sanitize_declaration_options(declaration, key, safe_value) do
    sanitized = Map.drop(declaration.options, [key, "github"])
    options = if safe_value, do: Map.put(sanitized, key, safe_value), else: sanitized
    %{declaration | options: options}
  end

  defp safe_git_identity(nil, _revision), do: nil
  defp safe_git_identity(url, revision), do: Enum.join(["git", url, revision], ":")

  defp walk_directory(root, components) do
    Enum.reduce_while(components, {:ok, root}, fn component, {:ok, parent} ->
      candidate = Path.join(parent, component)

      case File.lstat(candidate) do
        {:ok, %File.Stat{type: :directory}} -> {:cont, {:ok, candidate}}
        _symlink_missing_or_file -> {:halt, :error}
      end
    end)
  end

  defp safe_relative(path)
       when is_binary(path) and byte_size(path) in 1..@maximums.path_bytes//1 do
    valid =
      String.valid?(path) and String.normalize(path, :nfc) == path and
        Path.type(path) == :relative and not String.contains?(path, ["\\", <<0>>, "//"]) and
        path == Path.join(Path.split(path)) and
        Enum.all?(Path.split(path), &(&1 not in ["", ".", ".."]))

    if valid, do: :ok, else: :error
  end

  defp safe_relative(_path), do: :error

  defp inside?(path, prefix) do
    relative = Path.relative_to(path, prefix)

    relative == "." or
      (Path.type(relative) == :relative and not String.starts_with?(relative, "../"))
  end

  defp valid_prefixes?(values) when is_list(values) and values != [] and length(values) <= 32,
    do: Enum.all?(values, &(safe_relative(&1) == :ok))

  defp valid_prefixes?(_values), do: false

  defp valid_hosts?(values) when is_list(values) and length(values) <= @maximums.public_hosts do
    values != [] and values == Enum.sort(Enum.uniq(values)) and
      Enum.all?(values, &(&1 in @closed_public_git_hosts))
  end

  defp valid_hosts?(_values), do: false

  defp source_gaps(nodes, existing) do
    source =
      nodes
      |> Enum.reject(&(&1.source.state in [:verified, :verified_lock, :available]))
      |> Enum.map(
        &%{
          kind: :source_unavailable,
          dependency: &1.name,
          reason: &1.source.reason,
          blocking: &1.scm in ["path", "umbrella"]
        }
      )

    (existing ++ source)
    |> Enum.uniq()
    |> Enum.sort_by(&{to_string(&1.kind), &1[:dependency] || "", to_string(&1[:reason] || "")})
  end

  defp source_completeness(nodes, existing) do
    blocking_sources =
      Enum.count(nodes, &(&1.scm in ["path", "umbrella"] and &1.source.state != :available))

    existing
    |> Map.put(
      :source_available,
      Enum.count(nodes, &(&1.source.state in [:verified, :verified_lock, :available]))
    )
    |> Map.put(
      :source_unavailable,
      Enum.count(nodes, &(&1.source.state not in [:verified, :verified_lock, :available]))
    )
    |> Map.put(:blocking_source_gaps, blocking_sources)
    |> Map.put(
      :state,
      if(existing.blocking_gap_count + blocking_sources == 0, do: :complete, else: :partial)
    )
  end

  defp directory_digest(absolute, relative) do
    with {:ok, entries, byte_count} <- directory_manifest(absolute, "", [], 0),
         true <- length(entries) <= @maximums.path_entries,
         true <- byte_count <= @maximums.path_total_bytes do
      {:ok, digest({relative, Enum.sort(entries)}), length(entries), byte_count}
    else
      {:error, reason} -> {:error, reason}
      _limit -> {:error, :path_source_limit}
    end
  end

  defp directory_manifest(absolute, relative, entries, byte_count) do
    with {:ok, names} <- File.ls(absolute) do
      names
      |> Enum.sort()
      |> Enum.reduce_while({:ok, entries, byte_count}, fn name, {:ok, acc, total} ->
        path = Path.join(absolute, name)
        child_relative = if relative == "", do: name, else: Path.join(relative, name)

        case File.lstat(path) do
          {:ok, %File.Stat{type: :directory, mode: mode}} ->
            next = [{child_relative, :directory, mode} | acc]

            case bounded_manifest(path, child_relative, next, total) do
              {:ok, _next, _next_total} = result -> {:cont, result}
              {:error, reason} -> {:halt, {:error, reason}}
            end

          {:ok, %File.Stat{type: :regular, mode: mode, size: size}}
          when size <= @maximums.path_file_bytes and total + size <= @maximums.path_total_bytes ->
            case File.read(path) do
              {:ok, body} when byte_size(body) == size ->
                entry = {child_relative, :file, mode, size, digest(body)}
                {:cont, {:ok, [entry | acc], total + size}}

              _error ->
                {:halt, {:error, :path_source_changed}}
            end

          {:ok, %File.Stat{type: :regular}} ->
            {:halt, {:error, :path_source_limit}}

          {:ok, %File.Stat{type: :symlink}} ->
            {:halt, {:error, :path_source_symlink}}

          _unsupported ->
            {:halt, {:error, :path_source_unsupported}}
        end
      end)
    else
      _error -> {:error, :path_source_changed}
    end
  end

  defp bounded_manifest(absolute, relative, entries, byte_count) do
    if length(entries) > @maximums.path_entries do
      {:error, :path_source_limit}
    else
      directory_manifest(absolute, relative, entries, byte_count)
    end
  end

  defp digest(value),
    do:
      value
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

  defp digest?(value) when is_binary(value), do: Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp digest?(_value), do: false

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_dependency_sources)}
end
