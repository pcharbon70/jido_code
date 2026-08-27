defmodule JidoCode.Knowledge.RepositoryWiki.GuideDiscovery do
  @moduledoc """
  Discovers repository-authored guides through a fixed, bounded filesystem profile.

  Repository configuration may add roots inside the registered checkout, but it
  cannot select a parser, follow a symlink, or expand any profile limit.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

  @profile "wiki-guide-discovery/1.0.0"
  @maximums %{
    files: 512,
    file_bytes: 262_144,
    total_bytes: 16_777_216,
    path_bytes: 512,
    headings: 256,
    front_matter_bytes: 8_192
  }
  @roots ["docs", "guides"]
  @root_files ~w[
    README.md README.markdown CONTRIBUTING.md INSTALLATION.md DEPLOYMENT.md
    OPERATIONS.md TROUBLESHOOTING.md API.md USAGE.md UPGRADE.md SECURITY.md
    ARCHITECTURE.md CHANGELOG.md CODE_OF_CONDUCT.md
  ]
  @extensions ~w[.md .markdown .txt]
  @ignored ~w[.git .hg .svn _build deps node_modules vendor cover tmp]
  @front_matter_keys ~w[title audience kind order]
  @audiences ~w[user developer operator contributor reference architecture policy unknown]a

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      conventional_roots: @roots,
      root_files: @root_files,
      extensions: @extensions,
      front_matter_keys: @front_matter_keys,
      audiences: @audiences,
      limits: @maximums,
      parser_extensions: :forbidden,
      symlinks: :deny,
      devices: :deny,
      execution: :forbidden,
      network: :forbidden
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec discover(String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def discover(root, attributes) when is_binary(root) and is_map(attributes) do
    limits = Map.get(attributes, :limits, @maximums)

    with :ok <- validate_root(root),
         :ok <- validate_attributes(attributes),
         :ok <- validate_limits(limits),
         {:ok, roots} <- configured_roots(attributes),
         {:ok, paths, gaps} <- candidate_paths(root, roots, limits),
         {:ok, guides, read_gaps} <- read_guides(root, paths, attributes, limits),
         true <- length(guides) <= limits.files,
         true <- Enum.sum(Enum.map(guides, & &1.bytes)) <= limits.total_bytes,
         {:ok, changes} <- changes(guides, Map.get(attributes, :predecessor)) do
      ordered_guides = Enum.sort_by(guides, &{&1.order, &1.path, &1.iri})
      ordered_gaps = Enum.sort_by(gaps ++ read_gaps, &{&1.path, &1.reason})

      manifest = %{
        profile: @profile,
        profile_digest: profile().digest,
        repository_iri: attributes.repository_iri,
        tenant_iri: attributes.tenant_iri,
        source_snapshot_iri: attributes.source_snapshot_iri,
        source_revision: attributes.source_revision,
        roots: roots,
        guides: ordered_guides,
        gaps: ordered_gaps,
        changes: changes,
        guide_count: length(ordered_guides),
        total_bytes: Enum.sum(Enum.map(ordered_guides, & &1.bytes)),
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      {:ok, Map.put(manifest, :digest, Contract.digest(manifest))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_guide_discovery)
    end
  rescue
    _error -> invalid(:repository_wiki_guide_discovery)
  end

  def discover(_root, _attributes), do: invalid(:repository_wiki_guide_discovery)

  @doc "Reads one previously discovered guide and proves it still has the admitted digest."
  @spec read(String.t(), map()) :: {:ok, String.t()} | {:error, Error.t()}
  def read(root, guide) when is_binary(root) and is_map(guide) do
    with :ok <- validate_root(root),
         true <- safe_relative?(guide[:path]),
         true <- Contract.digest?(guide[:digest]),
         {:ok, content, stat} <- stable_read(root, guide.path, @maximums.file_bytes),
         true <- stat.type == :regular,
         true <- byte_size(content) == guide.bytes,
         normalized <- normalize_content(content),
         true <- digest(normalized) == guide.digest do
      {:ok, normalized}
    else
      _invalid -> conflict(:repository_wiki_guide_read)
    end
  rescue
    _error -> conflict(:repository_wiki_guide_read)
  end

  def read(_root, _guide), do: invalid(:repository_wiki_guide_read)

  defp validate_attributes(attributes) do
    with :ok <- Contract.resource(attributes[:repository_iri]),
         :ok <- Contract.resource(attributes[:tenant_iri]),
         :ok <- Contract.resource(attributes[:source_snapshot_iri]),
         true <- Contract.digest?(attributes[:source_revision]) do
      :ok
    else
      _invalid -> invalid(:repository_wiki_guide_attributes)
    end
  end

  defp configured_roots(attributes) do
    values = Map.get(attributes, :configured_roots, [])

    if is_list(values) and length(values) <= 8 and Enum.all?(values, &safe_relative?/1) do
      {:ok, (@roots ++ values) |> Enum.uniq() |> Enum.sort()}
    else
      invalid(:repository_wiki_guide_roots)
    end
  end

  defp candidate_paths(root, roots, limits) do
    initial =
      Enum.reduce(@root_files, {[], []}, fn path, {paths, gaps} ->
        case File.lstat(Path.join(root, path), time: :posix) do
          {:ok, %File.Stat{type: :regular}} -> {[path | paths], gaps}
          {:ok, %File.Stat{type: :symlink}} -> {paths, [gap(path, :symlinked) | gaps]}
          {:ok, _special} -> {paths, [gap(path, :unsupported_file_type) | gaps]}
          {:error, :enoent} -> {paths, gaps}
          {:error, _reason} -> {paths, [gap(path, :unreadable) | gaps]}
        end
      end)

    Enum.reduce_while(roots, {:ok, elem(initial, 0), elem(initial, 1)}, fn relative,
                                                                           {:ok, paths, gaps} ->
      case walk(root, relative, limits, paths, gaps) do
        {:ok, next_paths, next_gaps} -> {:cont, {:ok, next_paths, next_gaps}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, paths, gaps} -> {:ok, paths |> Enum.uniq() |> Enum.sort(), gaps}
      error -> error
    end
  end

  defp walk(root, relative, limits, paths, gaps) do
    case File.lstat(Path.join(root, relative), time: :posix) do
      {:ok, %File.Stat{type: :directory}} -> walk_directory(root, relative, limits, paths, gaps)
      {:ok, %File.Stat{type: :regular}} -> admit_path(relative, limits, paths, gaps)
      {:ok, %File.Stat{type: :symlink}} -> {:ok, paths, [gap(relative, :symlinked) | gaps]}
      {:ok, _special} -> {:ok, paths, [gap(relative, :unsupported_file_type) | gaps]}
      {:error, :enoent} -> {:ok, paths, gaps}
      {:error, _reason} -> {:ok, paths, [gap(relative, :unreadable) | gaps]}
    end
  end

  defp walk_directory(root, relative, limits, paths, gaps) do
    with {:ok, names} <- File.ls(Path.join(root, relative)) do
      Enum.sort(names)
      |> Enum.reduce_while({:ok, paths, gaps}, fn name, {:ok, found, omitted} ->
        child = Path.join(relative, name)

        result =
          if ignored?(name) do
            {:ok, found, omitted}
          else
            walk(root, child, limits, found, omitted)
          end

        case result do
          {:ok, next_found, next_omitted} when length(next_found) <= limits.files ->
            {:cont, {:ok, next_found, next_omitted}}

          {:ok, _next_found, _next_omitted} ->
            {:halt, invalid(:repository_wiki_guide_file_limit)}

          {:error, %Error{} = error} ->
            {:halt, {:error, error}}
        end
      end)
    else
      _failure -> {:ok, paths, [gap(relative, :unreadable) | gaps]}
    end
  end

  defp admit_path(relative, limits, paths, gaps) do
    cond do
      not safe_relative?(relative) ->
        invalid(:repository_wiki_guide_path)

      Path.extname(relative) |> String.downcase() |> then(&(&1 not in @extensions)) ->
        {:ok, paths, gaps}

      byte_size(relative) > limits.path_bytes ->
        {:ok, paths, [gap(relative, :path_oversized) | gaps]}

      true ->
        {:ok, [relative | paths], gaps}
    end
  end

  defp read_guides(root, paths, attributes, limits) do
    Enum.reduce_while(paths, {:ok, [], []}, fn path, {:ok, guides, gaps} ->
      case guide(root, path, attributes, limits) do
        {:ok, value} -> {:cont, {:ok, [value | guides], gaps}}
        {:gap, reason} -> {:cont, {:ok, guides, [gap(path, reason) | gaps]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, guides, gaps} -> {:ok, Enum.reverse(guides), gaps}
      error -> error
    end
  end

  defp guide(root, path, attributes, limits) do
    with {:ok, content, stat} <- stable_read(root, path, limits.file_bytes),
         true <- stat.type == :regular,
         :ok <- text_content(content),
         true <- String.valid?(content),
         normalized <- normalize_content(content),
         true <- String.normalize(normalized, :nfc) == normalized,
         {:ok, front_matter, body} <- front_matter(normalized, limits),
         {:ok, headings} <- headings(body, limits.headings),
         evidence <- classification_evidence(path, front_matter),
         {audience, ambiguous?} <- audience(evidence),
         title <- title(path, front_matter, headings),
         order <- order(front_matter),
         content_digest <- digest(normalized),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :wiki_source,
             Enum.join([attributes.repository_iri, attributes.source_snapshot_iri, path], "\n")
           ) do
      {:ok,
       %{
         iri: iri,
         path: path,
         source_snapshot_iri: attributes.source_snapshot_iri,
         source_revision: attributes.source_revision,
         digest: content_digest,
         bytes: byte_size(content),
         media_type: media_type(path),
         title: title,
         title_evidence: title_evidence(front_matter, headings),
         audience: audience,
         audience_evidence: evidence,
         ambiguous_classification?: ambiguous?,
         order: order,
         headings: headings,
         source_ref: source_ref(attributes.source_snapshot_iri, path, content_digest),
         freshness: :fresh
       }}
    else
      {:error, :oversized} -> {:gap, :oversized}
      {:error, :changed_during_read} -> {:gap, :changed_during_read}
      {:error, :binary} -> {:gap, :binary}
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:gap, :unsupported_encoding}
    end
  end

  defp stable_read(root, relative, maximum_bytes) do
    absolute = Path.join(root, relative)

    with {:ok, before_stat} <- File.lstat(absolute, time: :posix),
         true <- before_stat.type == :regular,
         :ok <- within_limit(before_stat, maximum_bytes),
         {:ok, content} <- File.read(absolute),
         {:ok, after_stat} <- File.lstat(absolute, time: :posix),
         :ok <- unchanged(before_stat, after_stat, content) do
      {:ok, content, after_stat}
    else
      false -> {:error, :unsupported_file_type}
      {:error, :oversized} -> {:error, :oversized}
      {:error, :changed_during_read} -> {:error, :changed_during_read}
      {:error, _reason} -> {:error, :unreadable}
    end
  end

  defp front_matter(content, limits) do
    lines = String.split(content, "\n")

    case lines do
      ["---" | rest] -> parse_front_matter(rest, limits, [], 0)
      _without -> {:ok, %{}, content}
    end
  end

  defp parse_front_matter([], _limits, _pairs, _bytes), do: invalid(:wiki_guide_front_matter)

  defp parse_front_matter(["---" | body], _limits, pairs, _bytes) do
    values = Map.new(Enum.reverse(pairs))
    {:ok, values, Enum.join(body, "\n")}
  end

  defp parse_front_matter([line | rest], limits, pairs, bytes) do
    next_bytes = bytes + byte_size(line) + 1

    if next_bytes <= limits.front_matter_bytes do
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          normalized_key = String.trim(key)
          normalized_value = value |> String.trim() |> trim_quotes()

          if normalized_key in @front_matter_keys and byte_size(normalized_value) <= 256 do
            parse_front_matter(
              rest,
              limits,
              [{normalized_key, normalized_value} | pairs],
              next_bytes
            )
          else
            parse_front_matter(rest, limits, pairs, next_bytes)
          end

        _nested_or_sequence ->
          parse_front_matter(rest, limits, pairs, next_bytes)
      end
    else
      invalid(:wiki_guide_front_matter)
    end
  end

  defp headings(content, maximum) do
    content
    |> String.split("\n")
    |> Enum.reduce_while({:ok, [], %{}, false}, fn line, {:ok, result, seen, fenced?} ->
      cond do
        String.starts_with?(String.trim_leading(line), "```") ->
          {:cont, {:ok, result, seen, not fenced?}}

        fenced? ->
          {:cont, {:ok, result, seen, fenced?}}

        true ->
          case Regex.run(~r/^(\x23{1,6})\s+(.+?)\s*\x23*$/u, line, capture: :all_but_first) do
            [marks, text] ->
              normalized = text |> strip_inline_markup() |> String.trim() |> String.slice(0, 256)
              base = slug(normalized)
              count = Map.get(seen, base, 0) + 1
              anchor = if count == 1, do: base, else: "#{base}-#{count}"
              item = %{level: String.length(marks), title: normalized, anchor: anchor}

              if length(result) < maximum do
                {:cont, {:ok, [item | result], Map.put(seen, base, count), fenced?}}
              else
                {:halt, invalid(:wiki_guide_heading_limit)}
              end

            _no_heading ->
              {:cont, {:ok, result, seen, fenced?}}
          end
      end
    end)
    |> case do
      {:ok, values, _seen, _fenced} -> {:ok, Enum.reverse(values)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp classification_evidence(path, front_matter) do
    declared =
      [front_matter["audience"], front_matter["kind"]]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&String.split(&1, [",", " "]))
      |> Enum.map(&String.downcase/1)
      |> Enum.filter(&(&1 in Enum.map(@audiences, fn value -> Atom.to_string(value) end)))
      |> Enum.map(&String.to_existing_atom/1)

    normalized = String.downcase(path)

    inferred =
      [
        {:contributor, ["contribut", "code_of_conduct"]},
        {:operator, ["deploy", "operation", "troubleshoot", "upgrade", "release"]},
        {:policy, ["security", "policy", "license"]},
        {:architecture, ["/adr/", "/architecture/", "/research/", "architecture.md"]},
        {:developer, ["developer", "development", "api", "internals"]},
        {:user, ["readme", "getting-started", "getting_started", "usage", "installation"]},
        {:reference, ["reference", "changelog", "glossary"]}
      ]
      |> Enum.filter(fn {_audience, needles} ->
        Enum.any?(needles, &String.contains?(normalized, &1))
      end)
      |> Enum.map(&elem(&1, 0))

    (declared ++ inferred) |> Enum.uniq() |> Enum.sort()
  end

  defp audience([]), do: {:unknown, false}
  defp audience([value]), do: {value, false}
  defp audience(values), do: {hd(values), true}

  defp title(path, front_matter, headings) do
    cond do
      present?(front_matter["title"]) ->
        String.slice(front_matter["title"], 0, 256)

      headings != [] ->
        headings |> hd() |> Map.fetch!(:title)

      true ->
        path
        |> Path.basename(Path.extname(path))
        |> String.replace(["_", "-"], " ")
        |> titlecase()
    end
  end

  defp title_evidence(front_matter, headings) do
    cond do
      present?(front_matter["title"]) -> :front_matter
      headings != [] -> :first_heading
      true -> :filename
    end
  end

  defp order(%{"order" => value}) do
    case Integer.parse(value) do
      {number, ""} when number in 0..10_000 -> number
      _invalid -> 5_000
    end
  end

  defp order(_front_matter), do: 5_000

  defp changes(guides, nil) do
    {:ok, change_set([], guides)}
  end

  defp changes(guides, predecessor) when is_map(predecessor) do
    prior = predecessor[:guides]

    if predecessor[:profile] == @profile and is_list(prior) and
         Contract.digest?(predecessor[:digest]) and
         Contract.digest(Map.delete(predecessor, :digest)) == predecessor.digest do
      {:ok, change_set(prior, guides)}
    else
      invalid(:repository_wiki_guide_predecessor)
    end
  end

  defp changes(_guides, _predecessor), do: invalid(:repository_wiki_guide_predecessor)

  defp change_set(prior, current) do
    prior_by_path = Map.new(prior, &{&1.path, &1})
    current_by_path = Map.new(current, &{&1.path, &1})
    prior_paths = Map.keys(prior_by_path) |> MapSet.new()
    current_paths = Map.keys(current_by_path) |> MapSet.new()
    added_paths = MapSet.difference(current_paths, prior_paths) |> Enum.sort()
    deleted_paths = MapSet.difference(prior_paths, current_paths) |> Enum.sort()

    renames =
      for old_path <- deleted_paths,
          new_path <- added_paths,
          prior_by_path[old_path].digest == current_by_path[new_path].digest do
        %{from: old_path, to: new_path, digest: current_by_path[new_path].digest}
      end
      |> Enum.sort_by(&{&1.from, &1.to})

    renamed_from = MapSet.new(renames, & &1.from)
    renamed_to = MapSet.new(renames, & &1.to)

    modified =
      MapSet.intersection(prior_paths, current_paths)
      |> Enum.filter(&(prior_by_path[&1].digest != current_by_path[&1].digest))
      |> Enum.sort()

    duplicates = duplicate_groups(current, :digest)
    title_collisions = duplicate_groups(current, :title)

    moved_anchors =
      modified
      |> Enum.flat_map(fn path ->
        moved_anchors(path, prior_by_path[path], current_by_path[path])
      end)
      |> Enum.sort_by(&{&1.path, &1.title, &1.from, &1.to})

    value = %{
      added: Enum.reject(added_paths, &MapSet.member?(renamed_to, &1)),
      deleted: Enum.reject(deleted_paths, &MapSet.member?(renamed_from, &1)),
      modified: modified,
      renamed: renames,
      duplicates: duplicates,
      title_collisions: title_collisions,
      moved_anchors: moved_anchors
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  defp duplicate_groups(guides, key) do
    guides
    |> Enum.group_by(&Map.fetch!(&1, key), & &1.path)
    |> Enum.filter(fn {_value, paths} -> length(paths) > 1 end)
    |> Enum.map(fn {value, paths} -> %{value: value, paths: Enum.sort(paths)} end)
    |> Enum.sort_by(&{&1.value, &1.paths})
  end

  defp moved_anchors(path, prior, current) do
    old = Map.new(prior.headings, &{&1.title, &1.anchor})
    new = Map.new(current.headings, &{&1.title, &1.anchor})

    Map.keys(old)
    |> Enum.filter(&(Map.has_key?(new, &1) and old[&1] != new[&1]))
    |> Enum.map(&%{path: path, title: &1, from: old[&1], to: new[&1]})
  end

  defp validate_root(root) do
    expanded = Path.expand(root)

    if root == expanded and safe_root_components?(expanded) and
         match?({:ok, %File.Stat{type: :directory}}, File.lstat(expanded)),
       do: :ok,
       else: invalid(:repository_wiki_guide_root)
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

  defp validate_limits(limits) when is_map(limits) do
    keys_match? = Map.keys(limits) |> Enum.sort() == Map.keys(@maximums) |> Enum.sort()

    if keys_match? and
         Enum.all?(@maximums, fn {key, maximum} ->
           value = limits[key]
           is_integer(value) and value > 0 and value <= maximum
         end),
       do: :ok,
       else: invalid(:repository_wiki_guide_limits)
  end

  defp validate_limits(_limits), do: invalid(:repository_wiki_guide_limits)

  defp safe_relative?(path) when is_binary(path) do
    normalized = :unicode.characters_to_nfc_binary(path)
    parts = Path.split(path)

    path == normalized and byte_size(path) in 1..@maximums.path_bytes and
      Path.type(path) == :relative and path == Path.join(parts) and
      not String.contains?(path, ["\\", "\0"]) and
      Enum.all?(parts, &(&1 not in ["", ".", ".."]))
  rescue
    _error -> false
  end

  defp safe_relative?(_path), do: false

  defp slug(value) do
    slug =
      value
      |> String.normalize(:nfc)
      |> String.downcase()
      |> String.replace(~r/[^\p{L}\p{N}]+/u, "-")
      |> String.trim("-")
      |> String.slice(0, 96)

    if slug == "", do: "section", else: slug
  end

  defp strip_inline_markup(value), do: String.replace(value, ~r/[`*_~\[\]]/u, "")
  defp trim_quotes(value), do: value |> String.trim_leading("\"") |> String.trim_trailing("\"")

  defp titlecase(value) do
    value
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
    |> String.slice(0, 256)
  end

  defp source_ref(snapshot, path, content_digest) do
    [snapshot, path, content_digest]
    |> Enum.join("\n")
    |> Base.url_encode64(padding: false)
  end

  defp media_type(path) do
    if String.downcase(Path.extname(path)) in [".md", ".markdown"],
      do: "text/markdown",
      else: "text/plain"
  end

  defp normalize_content(content) do
    content
    |> String.trim_leading(<<0xEF, 0xBB, 0xBF>>)
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
  end

  defp stable_stat?(left, right) do
    left.type == right.type and left.inode == right.inode and left.size == right.size and
      left.mtime == right.mtime
  end

  defp within_limit(stat, maximum),
    do: if(stat.size <= maximum, do: :ok, else: {:error, :oversized})

  defp unchanged(before_stat, after_stat, content) do
    if stable_stat?(before_stat, after_stat) and byte_size(content) == before_stat.size,
      do: :ok,
      else: {:error, :changed_during_read}
  end

  defp text_content(content), do: if(binary?(content), do: {:error, :binary}, else: :ok)

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
  defp ignored?(name), do: name in @ignored or String.starts_with?(name, ".")
  defp binary?(content), do: :binary.match(content, <<0>>) != :nomatch
  defp digest(content), do: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  defp gap(path, reason), do: %{path: path, reason: reason}
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, Error.new(:conflict, operation)}
end
