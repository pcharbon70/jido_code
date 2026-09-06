defmodule JidoCodeWeb.ReadSignals do
  @moduledoc """
  Closed per-page read intent. JSON is decoded with ordered objects so duplicate
  keys cannot disappear before validation. Nothing in this schema is authority.

  A request contains exactly one `read_<surface>` object. Local UI state stays
  local; route changes discard it. Cursors and alternative views are unavailable
  until a reviewed query supports them, so this version admits page numbers only.
  """

  alias Jason.OrderedObject

  @surfaces ~w(factory fleet projects project project_attempts project_wiki project_dependencies attempt account sessions)a
  @collection ~w(factory fleet projects project project_attempts project_wiki project_dependencies)a
  @states ~w(all active waiting blocked verifying complete)
  @sorts ~w(project work agent stage health freshness)
  @directions ~w(ascending descending)
  @max_bytes 2_048
  @max_keys 5

  @type diagnostic ::
          :invalid_shape
          | :invalid_json
          | :invalid_utf8
          | :oversized
          | :too_deep
          | :duplicate_key
          | :too_many_keys
          | :unknown_key
          | :invalid_value

  def surfaces, do: @surfaces
  def max_bytes, do: @max_bytes
  def namespace(surface) when surface in @surfaces, do: "read_" <> Atom.to_string(surface)

  def keys(surface) when surface in @collection, do: ~w(q state sort direction page)
  def keys(:attempt), do: ~w(q state page)
  def keys(surface) when surface in [:account, :sessions], do: []

  def schema(surface) when surface in @surfaces do
    %{
      namespace: namespace(surface),
      keys: keys(surface),
      local_only: ~w(_pending _overlay _pauseVisualUpdates _selectedRow),
      max_bytes: @max_bytes,
      max_keys: @max_keys,
      max_depth: 2,
      max_list_length: 0,
      max_scalar_bytes: 128,
      defaults: %{},
      scope_reset: :discard_all
    }
  end

  @spec decode(atom(), term()) :: {:ok, map()} | {:error, diagnostic()}
  def decode(surface, raw) when surface in @surfaces and is_binary(raw) do
    with {:ok, pairs} <- decode_object(raw),
         [{name, %OrderedObject{values: values}}] <- pairs,
         true <- name == namespace(surface),
         :ok <- unique(values),
         :ok <- allowed(surface, values) do
      Enum.reduce_while(values, {:ok, %{}}, fn {key, value}, {:ok, result} ->
        case normalize(key, value) do
          {:ok, nil} -> {:cont, {:ok, result}}
          {:ok, normalized} -> {:cont, {:ok, Map.put(result, key, normalized)}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      {:error, reason} -> {:error, reason}
      _shape -> {:error, :invalid_shape}
    end
  end

  def decode(_surface, _raw), do: {:error, :invalid_shape}

  @doc "Shared bounded, depth-two, duplicate-preserving outer object decoder."
  def decode_object(raw) when is_binary(raw) do
    with :ok <- bounded(raw),
         :ok <- shallow(raw),
         {:ok, %OrderedObject{values: pairs}} <- Jason.decode(raw, objects: :ordered_objects),
         :ok <- unique(pairs) do
      {:ok, pairs}
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_shape}
    end
  end

  def decode_object(_raw), do: {:error, :invalid_shape}

  # Scan depth before JSON allocation, respecting quoted/escaped delimiters.
  defp shallow(raw), do: shallow(raw, 0, false, false)
  defp shallow(<<>>, _depth, _quoted, _escaped), do: :ok
  defp shallow(<<_, rest::binary>>, depth, true, true), do: shallow(rest, depth, true, false)
  defp shallow(<<92, rest::binary>>, depth, true, false), do: shallow(rest, depth, true, true)

  defp shallow(<<34, rest::binary>>, depth, quoted, false),
    do: shallow(rest, depth, not quoted, false)

  defp shallow(<<c, _rest::binary>>, 2, false, false) when c in [123, 91], do: {:error, :too_deep}

  defp shallow(<<c, rest::binary>>, depth, false, false) when c in [123, 91],
    do: shallow(rest, depth + 1, false, false)

  defp shallow(<<c, rest::binary>>, depth, false, false) when c in [125, 93],
    do: shallow(rest, depth - 1, false, false)

  defp shallow(<<_, rest::binary>>, depth, quoted, escaped),
    do: shallow(rest, depth, quoted, escaped)

  defp bounded(raw) do
    cond do
      byte_size(raw) > @max_bytes -> {:error, :oversized}
      not String.valid?(raw) -> {:error, :invalid_utf8}
      true -> :ok
    end
  end

  defp unique(pairs) do
    keys = Enum.map(pairs, &elem(&1, 0))
    if length(keys) == length(Enum.uniq(keys)), do: :ok, else: {:error, :duplicate_key}
  end

  defp allowed(surface, values) do
    cond do
      length(values) > @max_keys -> {:error, :too_many_keys}
      Enum.any?(values, fn {key, _} -> key not in keys(surface) end) -> {:error, :unknown_key}
      true -> :ok
    end
  end

  defp normalize("q", value) when is_binary(value) and byte_size(value) <= 128 do
    normalized = value |> String.normalize(:nfc) |> String.trim()

    if byte_size(normalized) <= 128 and not Regex.match?(~r/[\x00-\x1f\x7f]/u, normalized),
      do: {:ok, if(normalized == "", do: nil, else: normalized)},
      else: {:error, :invalid_value}
  end

  defp normalize("state", value) when value in @states,
    do: {:ok, if(value == "all", do: nil, else: value)}

  defp normalize("sort", value) when value in @sorts,
    do: {:ok, if(value == "project", do: nil, else: value)}

  defp normalize("direction", value) when value in @directions,
    do: {:ok, if(value == "ascending", do: nil, else: value)}

  defp normalize("page", value) when is_integer(value) and value in 1..100,
    do: {:ok, if(value == 1, do: nil, else: value)}

  defp normalize("page", value) when is_binary(value) and byte_size(value) in 1..3 do
    case Integer.parse(value) do
      {page, ""} -> normalize("page", page)
      _invalid -> {:error, :invalid_value}
    end
  end

  defp normalize(_key, _value), do: {:error, :invalid_value}
end
