defmodule JidoCode.Knowledge.RepositoryWiki.SourceInventory do
  @moduledoc "Bounded, non-executing inventory adapter for one registered repository root."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

  @profile "wiki-source-inventory/1.0.0"
  @maximums %{files: 2_000, file_bytes: 262_144, total_bytes: 8_388_608, path_bytes: 512}
  @ignored ~w[.git .hg .svn _build deps node_modules vendor cover tmp]
  @text_extensions ~w[.md .markdown .txt .ex .exs .heex .json .toml .yaml .yml .lock .css .js .ts]
  @manifest_names ~w[mix.exs mix.lock]

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

    with :ok <- valid_root(root),
         :ok <- valid_limits(limits),
         :ok <- ResourceIdentity.validate(attributes[:repository_iri]),
         :ok <- ResourceIdentity.validate(attributes[:source_snapshot_iri]),
         true <- valid_fence?(attributes[:source_fence]),
         {:ok, registrations} <- registrations(attributes),
         {:ok, graph_sources} <- accepted_graph_sources(attributes, attributes.repository_iri),
         {:ok, entries, gaps} <- walk_registrations(root, registrations, limits),
         true <- length(entries) <= limits.files,
         true <- Enum.sum(Enum.map(entries, & &1.bytes)) <= limits.total_bytes do
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

      {:ok, Map.put(manifest, :digest, Contract.digest(manifest))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_inventory)
    end
  rescue
    _error -> invalid(:repository_wiki_inventory)
  end

  def scan(_root, _attributes), do: invalid(:repository_wiki_inventory)

  defp registrations(attributes) do
    profile = profile()

    values = %{
      root_files: Map.get(attributes, :root_files, profile.root_files),
      documentation_roots: Map.get(attributes, :documentation_roots, profile.documentation_roots),
      source_roots: Map.get(attributes, :source_roots, profile.source_roots),
      test_roots: Map.get(attributes, :test_roots, profile.test_roots),
      guide_roots: Map.get(attributes, :guide_roots, profile.guide_roots)
    }

    if Enum.all?(values, fn {_kind, paths} ->
         is_list(paths) and length(paths) <= 32 and Enum.all?(paths, &safe_relative?/1)
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

  defp walk_registrations(root, registrations, limits) do
    registrations
    |> Enum.sort()
    |> Enum.reduce_while({:ok, [], []}, fn {kind, paths}, {:ok, entries, gaps} ->
      Enum.reduce_while(paths, {:ok, entries, gaps}, fn relative, {:ok, found, missing} ->
        case walk_path(root, relative, kind, limits) do
          {:ok, new_entries, new_gaps} ->
            combined = found ++ new_entries

            if length(combined) <= limits.files do
              {:cont, {:ok, combined, missing ++ new_gaps}}
            else
              {:halt, invalid(:repository_wiki_file_limit)}
            end

          {:error, %Error{} = error} ->
            {:halt, {:error, error}}
        end
      end)
      |> case do
        {:ok, next_entries, next_gaps} -> {:cont, {:ok, next_entries, next_gaps}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp walk_path(root, relative, kind, limits) do
    absolute = Path.join(root, relative)

    case File.lstat(absolute, time: :posix) do
      {:ok, %File.Stat{type: :regular}} -> read_entry(root, relative, kind, limits)
      {:ok, %File.Stat{type: :directory}} -> walk_directory(root, relative, kind, limits)
      {:ok, %File.Stat{type: :symlink}} -> {:ok, [], [gap(relative, :symlinked)]}
      {:ok, _special} -> {:ok, [], [gap(relative, :unsupported)]}
      {:error, :enoent} -> {:ok, [], [gap(relative, :missing)]}
      {:error, _reason} -> {:ok, [], [gap(relative, :unreadable)]}
    end
  end

  defp walk_directory(root, relative, kind, limits) do
    case File.ls(Path.join(root, relative)) do
      {:ok, names} ->
        names
        |> Enum.sort()
        |> Enum.reduce_while({:ok, [], []}, fn name, {:ok, entries, gaps} ->
          child = Path.join(relative, name)

          result =
            if ignored?(name) do
              {:ok, [], [gap(child, :ignored)]}
            else
              walk_path(root, child, kind, limits)
            end

          case result do
            {:ok, child_entries, child_gaps} ->
              combined = entries ++ child_entries

              if length(combined) <= limits.files do
                {:cont, {:ok, combined, gaps ++ child_gaps}}
              else
                {:halt, invalid(:repository_wiki_file_limit)}
              end

            {:error, %Error{} = error} ->
              {:halt, {:error, error}}
          end
        end)

      {:error, _reason} ->
        {:ok, [], [gap(relative, :unreadable)]}
    end
  end

  defp read_entry(root, relative, registered_kind, limits) do
    absolute = Path.join(root, relative)

    with {:ok, before_stat} <- File.lstat(absolute, time: :posix),
         true <- before_stat.type == :regular,
         :ok <- within_file_limit(before_stat, limits),
         {:ok, contents} <- File.read(absolute),
         {:ok, after_stat} <- File.lstat(absolute, time: :posix),
         :ok <- unchanged?(before_stat, after_stat, contents),
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
      {:error, :oversized} -> {:ok, [], [gap(relative, :oversized)]}
      {:error, :changed_during_read} -> {:ok, [], [gap(relative, :changed_during_read)]}
      {:error, :binary} -> {:ok, [], [gap(relative, :binary)]}
      {:error, :unsupported} -> {:ok, [], [gap(relative, :unsupported)]}
      {:error, _reason} -> {:ok, [], [gap(relative, :unreadable)]}
      _invalid -> {:ok, [], [gap(relative, :unreadable)]}
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

  defp safe_relative?(path) when is_binary(path) do
    normalized = :unicode.characters_to_nfc_binary(path)
    parts = Path.split(path)

    path == normalized and byte_size(path) in 1..@maximums.path_bytes and
      Path.type(path) == :relative and path == normalize_path(path) and
      not String.contains?(path, ["\\", "\0"]) and
      Enum.all?(parts, &(&1 not in ["", ".", ".."]))
  end

  defp safe_relative?(_path), do: false

  defp stable_stat?(first, second),
    do:
      first.type == second.type and first.inode == second.inode and first.size == second.size and
        first.mtime == second.mtime

  defp within_file_limit(stat, limits),
    do: if(stat.size <= limits.file_bytes, do: :ok, else: {:error, :oversized})

  defp unchanged?(before_stat, after_stat, contents) do
    if stable_stat?(before_stat, after_stat) and byte_size(contents) == before_stat.size,
      do: :ok,
      else: {:error, :changed_during_read}
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
