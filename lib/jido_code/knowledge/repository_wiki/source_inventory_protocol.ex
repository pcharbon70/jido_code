defmodule JidoCode.Knowledge.RepositoryWiki.SourceInventoryProtocol do
  @moduledoc false

  @maximum_name_bytes 512

  @spec decode_directory(binary(), integer() | nil, boolean(), non_neg_integer()) ::
          {:ok, [String.t()]}
          | {:error,
             :directory_enumeration_limit
             | :directory_enumeration_resource_limit
             | :directory_enumeration_timeout
             | :directory_name_encoding
             | :directory_protocol
             | :directory_unreadable
             | :directory_changed_during_read
             | :directory_enumerator_unavailable}
  def decode_directory(body, status, eof?, remaining)
      when is_binary(body) and is_integer(remaining) and remaining >= 0 do
    case common_status(status, eof?) do
      :success -> parse_directory_frames(body, remaining, [], 0)
      {:error, :limit} -> {:error, :directory_enumeration_limit}
      {:error, :invalid} -> {:error, :directory_name_encoding}
      {:error, :unavailable} -> {:error, :directory_enumerator_unavailable}
      {:error, :timeout} -> {:error, :directory_enumeration_timeout}
      {:error, :unreadable} -> {:error, :directory_unreadable}
      {:error, :changed} -> {:error, :directory_changed_during_read}
      {:error, :resource} -> {:error, :directory_enumeration_resource_limit}
      {:error, :protocol} -> {:error, :directory_protocol}
      {:error, _other} -> {:error, :directory_enumerator_unavailable}
    end
  end

  def decode_directory(_body, _status, _eof?, _remaining),
    do: {:error, :directory_protocol}

  @spec decode_file(binary(), integer() | nil, boolean(), pos_integer()) ::
          {:ok, binary()}
          | {:type, :directory | :symlink | :unsupported}
          | {:error,
             :path_changed_during_read
             | :path_helper_unavailable
             | :path_missing
             | :path_oversized
             | :path_protocol
             | :path_resource_limit
             | :path_timeout
             | :path_unreadable}
  def decode_file(body, status, eof?, file_limit)
      when is_binary(body) and is_integer(file_limit) and file_limit > 0 do
    case common_status(status, eof?) do
      :success -> decode_file_body(body, file_limit)
      {:error, :invalid} -> {:error, :path_protocol}
      {:error, :unavailable} -> {:error, :path_helper_unavailable}
      {:error, :timeout} -> {:error, :path_timeout}
      {:error, :unreadable} -> {:error, :path_unreadable}
      {:error, :changed} -> {:error, :path_changed_during_read}
      {:error, :oversized} -> {:error, :path_oversized}
      {:error, :unsupported} -> {:type, :unsupported}
      {:error, :directory} -> {:type, :directory}
      {:error, :symlink} -> {:type, :symlink}
      {:error, :missing} -> {:error, :path_missing}
      {:error, :resource} -> {:error, :path_resource_limit}
      {:error, :protocol} -> {:error, :path_protocol}
      {:error, _other} -> {:error, :path_helper_unavailable}
    end
  end

  def decode_file(_body, _status, _eof?, _file_limit), do: {:error, :path_protocol}

  defp common_status(_status, false), do: {:error, :protocol}
  defp common_status(nil, true), do: {:error, :protocol}
  defp common_status(0, true), do: :success
  defp common_status(75, true), do: {:error, :limit}
  defp common_status(76, true), do: {:error, :invalid}
  defp common_status(77, true), do: {:error, :unavailable}
  defp common_status(78, true), do: {:error, :timeout}
  defp common_status(79, true), do: {:error, :unreadable}
  defp common_status(80, true), do: {:error, :changed}
  defp common_status(81, true), do: {:error, :oversized}
  defp common_status(82, true), do: {:error, :unsupported}
  defp common_status(83, true), do: {:error, :directory}
  defp common_status(84, true), do: {:error, :symlink}
  defp common_status(85, true), do: {:error, :missing}
  defp common_status(86, true), do: {:error, :resource}
  defp common_status(status, true) when status in [124, 137], do: {:error, :timeout}
  defp common_status(152, true), do: {:error, :resource}
  defp common_status(_status, true), do: {:error, :unavailable}

  defp parse_directory_frames(<<>>, _remaining, _names, _count),
    do: {:error, :directory_protocol}

  defp parse_directory_frames(
         <<5::unsigned-big-16, 0, expected_count::unsigned-big-32, tail::binary>>,
         _remaining,
         names,
         count
       ) do
    if expected_count == count and tail == <<>>,
      do: {:ok, Enum.reverse(names)},
      else: {:error, :directory_protocol}
  end

  defp parse_directory_frames(
         <<size::unsigned-big-16, rest::binary>>,
         remaining,
         names,
         count
       )
       when size in 1..@maximum_name_bytes and byte_size(rest) >= size do
    <<name::binary-size(size), tail::binary>> = rest

    cond do
      count >= remaining ->
        {:error, :directory_enumeration_limit}

      not valid_directory_name?(name) ->
        {:error, :directory_name_encoding}

      true ->
        parse_directory_frames(tail, remaining, [name | names], count + 1)
    end
  end

  defp parse_directory_frames(_body, _remaining, _names, _count),
    do: {:error, :directory_protocol}

  defp decode_file_body(<<"JCF1", size::unsigned-big-32, rest::binary>>, file_limit)
       when size <= file_limit do
    case rest do
      <<contents::binary-size(size), "JCE1">> -> {:ok, contents}
      _invalid -> {:error, :path_protocol}
    end
  end

  defp decode_file_body(_body, _file_limit), do: {:error, :path_protocol}

  defp valid_directory_name?(name) when is_binary(name) do
    String.valid?(name) and byte_size(name) in 1..@maximum_name_bytes and
      name == :unicode.characters_to_nfc_binary(name) and name not in [".", ".."] and
      not String.contains?(name, ["/", "\\", "\0"]) and
      not Regex.match?(~r/[\x00-\x1F\x7F]/u, name)
  rescue
    _error -> false
  end
end
