defmodule JidoCode.Integrations.ManagedCodingReadTools do
  @moduledoc "Concrete bounded source search, symbol inspection, and exact file reads."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.ReadRequest
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Factory.Tool.RepositoryPathGuard
  alias JidoCode.Security.Redactor

  @spec search_source(ReadRequest.t(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def search_source(%ReadRequest{} = request, arguments) when is_map(arguments) do
    with query when is_binary(query) and byte_size(query) in 1..1_024 <- arguments[:query],
         true <- String.valid?(query),
         limit <- min(Map.get(arguments, :max_results, request.max_results), request.max_results),
         true <- is_integer(limit) and limit > 0,
         {:ok, offset} <-
           continuation_offset(request, :search_source, query, arguments[:continuation]),
         {:ok, matches} <- search_files(request, query),
         page <- matches |> Enum.drop(offset) |> Enum.take(limit),
         {:ok, bounded, omitted_bytes?} <- bound_rows(page, request.max_bytes),
         next_offset = offset + length(bounded),
         continuation <-
           continuation(request, :search_source, query, next_offset, length(matches)) do
      {:ok,
       envelope(request, %{
         results: bounded,
         total_matches: length(matches),
         omitted?: omitted_bytes? or next_offset < length(matches),
         continuation: continuation
       })}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:search_source)
    end
  rescue
    _error -> invalid(:search_source)
  end

  def search_source(_request, _arguments), do: invalid(:search_source)

  @spec inspect_symbol(ReadRequest.t(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def inspect_symbol(%ReadRequest{} = request, arguments) when is_map(arguments) do
    analysis_revision = request.analysis_revision

    with symbol when is_binary(symbol) and byte_size(symbol) in 1..512 <- arguments[:symbol],
         ^analysis_revision <- arguments[:expected_analysis_revision],
         {:ok, rows} <- symbol_rows(request, symbol),
         {:ok, bounded, omitted?} <-
           bound_rows(Enum.take(rows, request.max_results), request.max_bytes) do
      {:ok,
       envelope(request, %{
         symbol: symbol,
         analysis_revision: request.analysis_revision,
         matches: bounded,
         uncertainty: if(rows == [], do: :not_found, else: :syntactic),
         truncated?: omitted? or length(rows) > length(bounded)
       })}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:inspect_symbol)
    end
  rescue
    _error -> invalid(:inspect_symbol)
  end

  def inspect_symbol(_request, _arguments), do: invalid(:inspect_symbol)

  @spec read_file(ReadRequest.t(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def read_file(%ReadRequest{} = request, arguments) when is_map(arguments) do
    path = arguments[:path]
    maximum = min(Map.get(arguments, :max_bytes, request.max_bytes), request.max_bytes)
    classification = Map.get(arguments, :classification, :internal)

    with true <- is_integer(maximum) and maximum > 0,
         true <- classification in request.visible_classifications,
         {:ok, resolved} <-
           RepositoryPathGuard.resolve(
             request.workspace_root,
             path,
             request.allowed_paths,
             :existing_file
           ),
         {:ok, content} <- File.read(resolved.absolute),
         digest = "sha256:" <> WorkspaceDigest.digest(content),
         ^digest <- arguments[:expected_digest],
         :ok <- safe_content(content),
         {:ok, selected, range} <- select_range(content, arguments[:range], maximum) do
      {:ok,
       envelope(request, %{
         path: resolved.relative,
         digest: digest,
         bytes: byte_size(selected),
         total_bytes: byte_size(content),
         range: range,
         classification: classification,
         encoding: if(String.valid?(selected), do: :utf8, else: :binary),
         content: selected,
         truncated?: byte_size(selected) < byte_size(content),
         untrusted_data?: true
       })}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:read_file)
    end
  rescue
    _error -> invalid(:read_file)
  end

  def read_file(_request, _arguments), do: invalid(:read_file)

  defp search_files(request, query) do
    needle = String.downcase(query)

    with {:ok, files} <- files(request) do
      rows =
        files
        |> Enum.flat_map(fn {absolute, relative} ->
          case text_file(absolute, request.max_bytes) do
            {:ok, content} ->
              content
              |> String.split("\n")
              |> Enum.with_index(1)
              |> Enum.filter(fn {line, _number} ->
                String.contains?(String.downcase(line), needle)
              end)
              |> Enum.map(fn {line, number} ->
                %{
                  path: relative,
                  line: number,
                  excerpt: truncate(line, 512),
                  score: occurrences(String.downcase(line), needle),
                  untrusted_data?: true
                }
              end)

            _unavailable ->
              []
          end
        end)
        |> Enum.sort_by(&{-&1.score, &1.path, &1.line})

      {:ok, rows}
    end
  end

  defp symbol_rows(request, symbol) do
    with {:ok, files} <- files(request) do
      rows =
        files
        |> Enum.flat_map(fn {absolute, relative} ->
          case text_file(absolute, request.max_bytes) do
            {:ok, source} ->
              source
              |> String.split("\n")
              |> Enum.with_index(1)
              |> Enum.filter(fn {line, _number} -> symbol_definition?(line, symbol) end)
              |> Enum.map(fn {line, number} ->
                %{
                  path: relative,
                  start_line: number,
                  end_line: number,
                  excerpt: truncate(line, 512),
                  confidence: :syntactic,
                  untrusted_data?: true
                }
              end)

            _unavailable ->
              []
          end
        end)
        |> Enum.sort_by(&{&1.path, &1.start_line})

      {:ok, rows}
    end
  end

  defp files(request) do
    request.allowed_paths
    |> Enum.flat_map(fn prefix ->
      Path.wildcard(Path.join([request.workspace_root, prefix, "**/*"]))
    end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, files} ->
      case File.lstat(path) do
        {:ok, %File.Stat{type: :regular}} ->
          relative = Path.relative_to(path, request.workspace_root)
          {:cont, {:ok, [{path, relative} | files]}}

        {:ok, %File.Stat{type: :directory}} ->
          {:cont, {:ok, files}}

        _unsafe ->
          {:halt, {:error, AdapterError.new(:unauthorized, :source_discovery)}}
      end
    end)
    |> case do
      {:ok, files} -> {:ok, Enum.reverse(files)}
      error -> error
    end
  end

  defp safe_content(content) do
    content
    |> overlapping_chunks(8_000)
    |> Enum.reduce_while(:ok, fn chunk, :ok ->
      case Redactor.reject_sensitive(chunk) do
        :ok -> {:cont, :ok}
        _sensitive -> {:halt, {:error, AdapterError.new(:unauthorized, :source_content)}}
      end
    end)
  end

  defp overlapping_chunks(content, size) when byte_size(content) <= size, do: [content]

  defp overlapping_chunks(content, size) do
    step = size - 256
    last = byte_size(content) - 1

    0..last//step
    |> Enum.map(fn offset ->
      binary_part(content, offset, min(size, byte_size(content) - offset))
    end)
  end

  defp select_range(content, nil, maximum) do
    selected = binary_part(content, 0, min(byte_size(content), maximum))
    {:ok, selected, %{offset: 0, length: byte_size(selected)}}
  end

  defp select_range(content, %{offset: offset, length: length}, maximum)
       when is_integer(offset) and offset >= 0 and is_integer(length) and length > 0 do
    if offset < byte_size(content) do
      selected_length = min(min(length, maximum), byte_size(content) - offset)

      {:ok, binary_part(content, offset, selected_length),
       %{offset: offset, length: selected_length}}
    else
      {:error, AdapterError.new(:unavailable, :read_file_range)}
    end
  end

  defp select_range(_content, _range, _maximum), do: invalid(:read_file_range)

  defp continuation_offset(_request, _tool, _material, nil), do: {:ok, 0}

  defp continuation_offset(request, tool, material, %{offset: offset, digest: digest})
       when is_integer(offset) and offset >= 0 do
    if digest == continuation_digest(request, tool, material, offset),
      do: {:ok, offset},
      else: {:error, AdapterError.new(:unauthorized, :read_continuation)}
  end

  defp continuation_offset(_request, _tool, _material, _continuation),
    do: {:error, AdapterError.new(:invalid_input, :read_continuation)}

  defp continuation(request, tool, material, offset, total) when offset < total,
    do: %{offset: offset, digest: continuation_digest(request, tool, material, offset)}

  defp continuation(_request, _tool, _material, _offset, _total), do: nil

  defp continuation_digest(request, tool, material, offset) do
    WorkspaceDigest.digest({
      tool,
      material,
      offset,
      request.repository_iri,
      request.snapshot_iri,
      request.actor_iri,
      request.workspace_digest,
      request.allowed_paths,
      request.visible_classifications
    })
  end

  defp bound_rows(rows, maximum) do
    Enum.reduce_while(rows, {:ok, [], 0, false}, fn row, {:ok, acc, bytes, _omitted} ->
      size = byte_size(:erlang.term_to_binary(row, [:deterministic]))

      if bytes + size <= maximum,
        do: {:cont, {:ok, [row | acc], bytes + size, false}},
        else: {:halt, {:ok, acc, bytes, true}}
    end)
    |> then(fn {:ok, rows, _bytes, omitted?} -> {:ok, Enum.reverse(rows), omitted?} end)
  end

  defp envelope(request, data) do
    %{
      authority: %{
        repository_iri: request.repository_iri,
        snapshot_iri: request.snapshot_iri,
        actor_iri: request.actor_iri,
        workspace_iri: request.workspace_iri,
        workspace_digest: request.workspace_digest
      },
      data: data,
      content_trust: :untrusted
    }
  end

  defp symbol_definition?(line, symbol) do
    escaped = Regex.escape(symbol)
    Regex.match?(~r/^\s*(?:defmodule|def|defp|defmacro|defmacrop)\s+#{escaped}(?:\b|\()/, line)
  end

  defp text_file(path, maximum) do
    case File.read(path) do
      {:ok, content} when byte_size(content) <= maximum ->
        if String.valid?(content), do: {:ok, content}, else: :unavailable

      _unavailable ->
        :unavailable
    end
  end

  defp occurrences(_line, ""), do: 0
  defp occurrences(line, needle), do: length(String.split(line, needle)) - 1
  defp truncate(value, maximum), do: binary_part(value, 0, min(byte_size(value), maximum))
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
