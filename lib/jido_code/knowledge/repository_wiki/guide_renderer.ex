defmodule JidoCode.Knowledge.RepositoryWiki.GuideRenderer do
  @moduledoc """
  Bounded renderer for the controller-owned repository guide Markdown subset.

  The result is a safe structural value, not trusted HTML. Product templates
  render its text and link records through ordinary HEEx escaping.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.DependencyLinks

  @profile "wiki-renderer/1.0.0"
  @maximums %{
    source_bytes: 262_144,
    output_bytes: 524_288,
    nodes: 4_096,
    depth: 6,
    links: 256,
    code_block_bytes: 65_536,
    table_cells: 1_024,
    line_bytes: 8_192
  }
  @link ~r/!?\[[^\]\n]{0,256}\]\([^\)\n]{1,2048}\)/u
  @secret_patterns [
    {:private_key, ~r/-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----/u},
    {:aws_access_key, ~r/\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/u},
    {:github_token, ~r/\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b/u},
    {:credential_assignment,
     ~r/\b(?:password|passwd|api[_-]?key|client[_-]?secret|access[_-]?token)\s*[:=]\s*["']?[A-Za-z0-9\/+_=.-]{12,}/iu},
    {:jwt, ~r/\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/u}
  ]

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      subset: [
        :heading,
        :paragraph,
        :unordered_list_item,
        :ordered_list_item,
        :blockquote,
        :code_block,
        :table_row,
        :thematic_break
      ],
      limits: @maximums,
      raw_html: :escaped_text,
      scripts: :escaped_text,
      styles: :escaped_text,
      embeds: :escaped_text,
      forms: :escaped_text,
      parser_extensions: :forbidden,
      internal_links: :reviewed_repository_reference,
      external_links: DependencyLinks.profile().digest,
      secrets: :block_activation_and_redact_diagnostics,
      model_calls: 0
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec render(String.t(), map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def render(source, guide, attributes)
      when is_binary(source) and is_map(guide) and is_map(attributes) do
    limits = Map.get(attributes, :limits, @maximums)

    with :ok <- validate(source, guide, attributes, limits),
         body <- strip_front_matter(source),
         {redacted, secret_findings} <- redact_secrets(body, guide.path),
         {:ok, parsed} <- parse(redacted, guide, attributes, limits),
         result <- result(parsed, guide, secret_findings, limits),
         true <-
           byte_size(:erlang.term_to_binary(result, [:deterministic])) <= limits.output_bytes do
      {:ok, Map.put(result, :digest, Contract.digest(result))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_guide_render)
    end
  rescue
    _error -> invalid(:repository_wiki_guide_render)
  end

  def render(_source, _guide, _attributes), do: invalid(:repository_wiki_guide_render)

  defp validate(source, guide, attributes, limits) do
    known_paths = Map.get(attributes, :known_paths, [])

    cond do
      not is_binary(guide[:path]) or not Contract.digest?(guide[:digest]) or
          not is_binary(guide[:iri]) ->
        invalid(:repository_wiki_guide_render_input)

      byte_size(source) > limits.source_bytes or digest(source) != guide.digest ->
        conflict(:repository_wiki_guide_render_source)

      not valid_limits?(limits) ->
        invalid(:repository_wiki_guide_render_limits)

      not is_list(known_paths) or length(known_paths) > 4_096 or
          not Enum.all?(known_paths, &safe_relative?/1) ->
        invalid(:repository_wiki_guide_render_paths)

      Map.get(attributes, :parser_extensions, []) != [] ->
        invalid(:repository_wiki_guide_parser_extension)

      true ->
        :ok
    end
  end

  defp parse(source, guide, attributes, limits) do
    initial = %{
      blocks: [],
      links: [],
      warnings: [],
      anchors: %{},
      toc: [],
      fenced: nil,
      table_cells: 0
    }

    source
    |> String.split("\n")
    |> Enum.reduce_while({:ok, initial}, fn line, {:ok, state} ->
      if byte_size(line) <= limits.line_bytes do
        case parse_line(line, state, guide, attributes, limits) do
          {:ok, next}
          when length(next.blocks) <= limits.nodes and length(next.links) <= limits.links ->
            {:cont, {:ok, next}}

          {:ok, _next} ->
            {:halt, invalid(:repository_wiki_guide_render_limit)}

          {:error, %Error{} = error} ->
            {:halt, {:error, error}}
        end
      else
        {:halt, invalid(:repository_wiki_guide_line_limit)}
      end
    end)
    |> close_fence(limits)
  end

  defp parse_line(line, %{fenced: fenced} = state, _guide, _attributes, limits)
       when not is_nil(fenced) do
    if String.starts_with?(String.trim_leading(line), "```") do
      code = fenced.lines |> Enum.reverse() |> Enum.join("\n")

      if byte_size(code) <= limits.code_block_bytes do
        block = %{type: :code_block, language: fenced.language, text: code}
        {:ok, %{state | blocks: [block | state.blocks], fenced: nil}}
      else
        invalid(:repository_wiki_guide_code_limit)
      end
    else
      bytes = fenced.bytes + byte_size(line) + 1

      if bytes <= limits.code_block_bytes do
        {:ok, %{state | fenced: %{fenced | lines: [line | fenced.lines], bytes: bytes}}}
      else
        invalid(:repository_wiki_guide_code_limit)
      end
    end
  end

  defp parse_line(line, state, guide, attributes, limits) do
    trimmed = String.trim(line)

    cond do
      String.starts_with?(String.trim_leading(line), "```") ->
        language =
          line
          |> String.trim_leading()
          |> String.trim_leading("```")
          |> String.trim()
          |> String.replace(~r/[^A-Za-z0-9_+-]/u, "")
          |> String.slice(0, 32)

        {:ok, %{state | fenced: %{language: language, lines: [], bytes: 0}}}

      trimmed == "" ->
        {:ok, state}

      Regex.match?(~r/^(?:-{3,}|\*{3,}|_{3,})$/u, trimmed) ->
        add_block(state, %{type: :thematic_break})

      heading = Regex.run(~r/^(\x23{1,6})\s+(.+?)\s*\x23*$/u, line, capture: :all_but_first) ->
        [marks, text] = heading
        heading_block(state, String.length(marks), text, guide, attributes)

      String.starts_with?(trimmed, ">") ->
        inline_block(
          :blockquote,
          String.trim_leading(trimmed, ">") |> String.trim(),
          state,
          guide,
          attributes
        )

      Regex.match?(~r/^[-+*]\s+/u, trimmed) ->
        text = Regex.replace(~r/^[-+*]\s+/u, trimmed, "")
        inline_block(:unordered_list_item, text, state, guide, attributes)

      Regex.match?(~r/^\d{1,6}[.)]\s+/u, trimmed) ->
        text = Regex.replace(~r/^\d{1,6}[.)]\s+/u, trimmed, "")
        inline_block(:ordered_list_item, text, state, guide, attributes)

      table_row?(trimmed) ->
        table_block(trimmed, state, guide, attributes, limits)

      raw_html?(line) ->
        inline_block(:paragraph, line, add_warning(state, :raw_html_escaped), guide, attributes)

      true ->
        inline_block(:paragraph, line, state, guide, attributes)
    end
  end

  defp heading_block(state, level, text, guide, attributes) do
    title = text |> strip_inline_markup() |> String.trim() |> String.slice(0, 256)
    base = slug(title)
    count = Map.get(state.anchors, base, 0) + 1
    anchor = if count == 1, do: base, else: "#{base}-#{count}"

    with {:ok, segments, links} <- inline(text, state.links, guide, attributes) do
      block = %{type: :heading, level: level, anchor: anchor, segments: segments, text: title}
      toc = %{level: level, anchor: anchor, title: title}

      {:ok,
       %{
         state
         | blocks: [block | state.blocks],
           links: links,
           anchors: Map.put(state.anchors, base, count),
           toc: [toc | state.toc]
       }}
    end
  end

  defp inline_block(type, text, state, guide, attributes) do
    with {:ok, segments, links} <- inline(text, state.links, guide, attributes) do
      add_block(%{state | links: links}, %{
        type: type,
        segments: segments,
        text: plain_text(segments)
      })
    end
  end

  defp table_block(line, state, guide, attributes, limits) do
    cells = line |> String.trim("|") |> String.split("|") |> Enum.map(&String.trim/1)
    next_cells = state.table_cells + length(cells)

    if next_cells <= limits.table_cells and length(cells) <= 32 do
      Enum.reduce_while(cells, {:ok, [], state.links}, fn cell, {:ok, parsed, links} ->
        case inline(cell, links, guide, attributes) do
          {:ok, segments, next_links} -> {:cont, {:ok, [segments | parsed], next_links}}
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end
      end)
      |> case do
        {:ok, parsed, links} ->
          block = %{type: :table_row, cells: Enum.reverse(parsed)}
          add_block(%{state | links: links, table_cells: next_cells}, block)

        {:error, %Error{} = error} ->
          {:error, error}
      end
    else
      invalid(:repository_wiki_guide_table_limit)
    end
  end

  defp inline(text, existing_links, guide, attributes) do
    parts = Regex.split(@link, text, include_captures: true, trim: false)

    Enum.reduce_while(parts, {:ok, [], existing_links}, fn part, {:ok, segments, links} ->
      case Regex.run(~r/^(!?)\[([^\]\n]{0,256})\]\(([^\)\n]{1,2048})\)$/u, part,
             capture: :all_but_first
           ) do
        [image, label, destination] ->
          record = rewrite_link(image == "!", label, destination, guide, attributes)
          index = length(links)

          segment = %{
            type: if(image == "!", do: :image, else: :link),
            index: index,
            label: safe_text(label, 256)
          }

          {:cont, {:ok, [segment | segments], links ++ [record]}}

        _text ->
          {:cont, {:ok, [%{type: :text, text: escape_html(part)} | segments], links}}
      end
    end)
    |> case do
      {:ok, segments, links} -> {:ok, Enum.reverse(segments), links}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp rewrite_link(image?, label, destination, guide, attributes) do
    display = safe_text(destination, 2_048)

    cond do
      image? ->
        relative_reference(:image, label, destination, display, guide, attributes)

      String.starts_with?(destination, "#") ->
        anchor = String.trim_leading(destination, "#")
        known? = Enum.any?(guide.headings, &(&1.anchor == anchor))

        %{
          kind: :guide_anchor,
          label: safe_text(label, 256),
          destination: if(known?, do: destination, else: nil),
          display: display,
          status: if(known?, do: :resolved, else: :unresolved),
          reason: if(known?, do: nil, else: :unknown_anchor),
          presentation_ref:
            if(known?, do: presentation_ref(guide.path, anchor, guide.digest), else: nil)
        }

      URI.parse(destination).scheme in ["https", "http", "mailto", "data", "javascript"] ->
        external_reference(label, destination, display)

      true ->
        relative_reference(:repository_reference, label, destination, display, guide, attributes)
    end
  rescue
    _error -> text_only_link(label, safe_text(destination, 2_048), :invalid_destination)
  end

  defp external_reference(label, destination, display) do
    case DependencyLinks.admit_external_url(destination) do
      {:ok, canonical} ->
        %{
          kind: :external,
          label: safe_text(label, 256),
          destination: canonical,
          display: canonical,
          status: :verified,
          reason: nil,
          presentation_ref: nil,
          navigation: :external_noopener_noreferrer_nofollow
        }

      {:error, reason} ->
        text_only_link(label, display, reason)
    end
  end

  defp relative_reference(kind, label, destination, display, guide, attributes) do
    with true <- safe_destination?(destination),
         {path_part, fragment} <- split_fragment(destination),
         {:ok, path} <- resolve_path(guide.path, path_part),
         known_paths <- Map.get(attributes, :known_paths, []),
         true <- path == guide.path or path in known_paths do
      %{
        kind: kind,
        label: safe_text(label, 256),
        destination: nil,
        display: display,
        status: :resolved,
        reason: nil,
        source_path: path,
        fragment: fragment,
        presentation_ref: presentation_ref(path, fragment, guide.digest),
        navigation: :reviewed_repository_route
      }
    else
      _invalid -> text_only_link(label, display, :unresolved_repository_reference)
    end
  end

  defp resolve_path(current_path, ""), do: {:ok, current_path}

  defp resolve_path(current_path, path) do
    candidate =
      if String.starts_with?(path, "/") do
        Path.expand(path, "/")
      else
        Path.expand(path, Path.join("/", Path.dirname(current_path)))
      end

    relative = String.trim_leading(candidate, "/")

    if candidate != "/" and safe_relative?(relative),
      do: {:ok, relative},
      else: :error
  end

  defp split_fragment(destination) do
    case String.split(destination, "#", parts: 2) do
      [path, fragment] -> {path, safe_text(fragment, 256)}
      [path] -> {path, nil}
    end
  end

  defp safe_destination?(value) do
    is_binary(value) and byte_size(value) in 1..2_048 and String.valid?(value) and
      value == String.normalize(value, :nfc) and
      not String.contains?(String.downcase(value), [
        "\\",
        "\0",
        "%00",
        "%0a",
        "%0d",
        "%2e",
        "%2f",
        "%5c"
      ]) and
      not String.contains?(value, ["?", "//"])
  end

  defp text_only_link(label, display, reason) do
    %{
      kind: :external_or_unsupported,
      label: safe_text(label, 256),
      destination: nil,
      display: display,
      status: :text_only,
      reason: reason,
      presentation_ref: nil,
      navigation: :none
    }
  end

  defp result(parsed, guide, findings, limits) do
    blocks = Enum.reverse(parsed.blocks)
    toc = Enum.reverse(parsed.toc)
    warnings = Enum.reverse(parsed.warnings) |> Enum.uniq()

    value = %{
      profile: @profile,
      profile_digest: profile().digest,
      guide_iri: guide.iri,
      source_path: guide.path,
      source_revision: guide.source_revision,
      source_digest: guide.digest,
      source_ref: guide.source_ref,
      title: guide.title,
      audience: guide.audience,
      freshness: guide.freshness,
      blocks: blocks,
      table_of_contents: toc,
      links: parsed.links,
      warnings: warnings,
      blocking_findings: findings,
      activation_allowed?: findings == [],
      counts: %{
        nodes: length(blocks),
        links: length(parsed.links),
        table_cells: parsed.table_cells,
        secrets: length(findings)
      },
      limits: limits,
      model_calls: 0,
      model_input_tokens: 0,
      model_output_tokens: 0,
      usage_cost_microunits: 0
    }

    Map.put(value, :render_digest, Contract.digest(value))
  end

  defp close_fence({:ok, %{fenced: nil} = state}, _limits), do: {:ok, state}

  defp close_fence({:ok, %{fenced: fenced} = state}, limits) do
    code = fenced.lines |> Enum.reverse() |> Enum.join("\n")

    if byte_size(code) <= limits.code_block_bytes do
      block = %{type: :code_block, language: fenced.language, text: code}

      {:ok,
       %{
         state
         | blocks: [block | state.blocks],
           fenced: nil,
           warnings: [:unclosed_code_fence | state.warnings]
       }}
    else
      invalid(:repository_wiki_guide_code_limit)
    end
  end

  defp close_fence({:error, %Error{} = error}, _limits), do: {:error, error}

  defp redact_secrets(source, path) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce({[], []}, fn {line, number}, {lines, findings} ->
      matches =
        Enum.filter(@secret_patterns, fn {_kind, pattern} -> Regex.match?(pattern, line) end)

      if matches == [] do
        {[line | lines], findings}
      else
        diagnostics =
          Enum.map(matches, fn {kind, _pattern} ->
            %{
              kind: kind,
              path: path,
              line: number,
              fingerprint: Contract.digest(%{kind: kind, path: path, line: number}),
              diagnostic: "redacted high-risk credential pattern"
            }
          end)

        {["[REDACTED HIGH-RISK CONTENT]" | lines], diagnostics ++ findings}
      end
    end)
    |> then(fn {lines, findings} ->
      {lines |> Enum.reverse() |> Enum.join("\n"), Enum.reverse(findings)}
    end)
  end

  defp strip_front_matter(source) do
    case String.split(source, "\n") do
      ["---" | rest] ->
        case Enum.split_while(rest, &(&1 != "---")) do
          {_front, ["---" | body]} -> Enum.join(body, "\n")
          _unterminated -> source
        end

      _plain ->
        source
    end
  end

  defp add_block(state, block), do: {:ok, %{state | blocks: [block | state.blocks]}}
  defp add_warning(state, warning), do: %{state | warnings: [warning | state.warnings]}
  defp table_row?(line), do: String.starts_with?(line, "|") and String.ends_with?(line, "|")
  defp raw_html?(line), do: Regex.match?(~r/<\/?[A-Za-z][^>]*>/u, line)

  defp plain_text(segments) do
    Enum.map_join(segments, fn
      %{type: :text, text: text} -> text
      %{label: label} -> label
    end)
  end

  defp escape_html(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp safe_text(value, maximum) when is_binary(value) do
    value
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u, "")
    |> String.normalize(:nfc)
    |> String.slice(0, maximum)
  end

  defp safe_text(_value, _maximum), do: ""

  defp slug(value) do
    result =
      value
      |> String.normalize(:nfc)
      |> String.downcase()
      |> String.replace(~r/[^\p{L}\p{N}]+/u, "-")
      |> String.trim("-")
      |> String.slice(0, 96)

    if result == "", do: "section", else: result
  end

  defp strip_inline_markup(value), do: String.replace(value, ~r/[`*_~\[\]]/u, "")

  defp presentation_ref(path, fragment, digest) do
    [path, fragment || "", digest]
    |> Enum.join("\n")
    |> Base.url_encode64(padding: false)
  end

  defp safe_relative?(path) when is_binary(path) do
    parts = Path.split(path)

    byte_size(path) in 1..512 and path == String.normalize(path, :nfc) and
      Path.type(path) == :relative and path == Path.join(parts) and
      Enum.all?(parts, &(&1 not in ["", ".", ".."])) and
      not String.contains?(path, ["\\", "\0"])
  rescue
    _error -> false
  end

  defp safe_relative?(_path), do: false

  defp valid_limits?(limits) when is_map(limits) do
    Map.keys(limits) |> Enum.sort() == Map.keys(@maximums) |> Enum.sort() and
      Enum.all?(@maximums, fn {key, maximum} ->
        value = limits[key]
        is_integer(value) and value > 0 and value <= maximum
      end)
  end

  defp valid_limits?(_limits), do: false
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, Error.new(:conflict, operation)}
end
