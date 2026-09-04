defmodule JidoCodeWeb.Qualification.HypermediaSignals do
  @moduledoc """
  Closed harmless signal schema for the HUI-B3 qualification consumer.

  Identity, authority, revisions, CSRF data, and durable results have no field
  in this schema. Unknown, duplicate, nested, malformed, or oversized input is
  rejected before a fragment or event is rendered.
  """

  alias Jason.OrderedObject
  alias JidoCodeWeb.QualificationRawBodyReader

  @max_bytes 512
  @max_keys 6
  @allowed_states ~w(ready loading empty error)
  @allowed_scenarios ~w(normal duplicate reorder drop slow sleep_wake restart terminal)
  @known_keys ~w(note page q state tabId scenario)
  @tab_id_pattern ~r/\A[a-zA-Z0-9_-]{8,48}\z/

  @type reason ::
          :duplicate_key
          | :duplicate_transport
          | :invalid_json
          | :invalid_shape
          | :invalid_value
          | :missing_signals
          | :oversized
          | :unknown_key

  @spec read_get(Plug.Conn.t(), [String.t()]) :: {:ok, map()} | {:error, reason()}
  def read_get(conn, allowed_keys) when is_list(allowed_keys) do
    values = for {"datastar", value} <- URI.query_decoder(conn.query_string), do: value

    case values do
      [] -> {:error, :missing_signals}
      [raw] -> decode(raw, allowed_keys)
      _duplicates -> {:error, :duplicate_transport}
    end
  end

  @spec read_body(Plug.Conn.t(), [String.t()]) :: {:ok, map()} | {:error, reason()}
  def read_body(conn, allowed_keys) when is_list(allowed_keys) do
    conn |> QualificationRawBodyReader.body() |> decode(allowed_keys)
  end

  @spec decode(binary(), [String.t()]) :: {:ok, map()} | {:error, reason()}
  def decode(raw, allowed_keys) when is_binary(raw) and is_list(allowed_keys) do
    with :ok <- validate_schema_keys(allowed_keys),
         :ok <- validate_size(raw),
         {:ok, %OrderedObject{values: pairs}} <- Jason.decode(raw, objects: :ordered_objects),
         :ok <- validate_pairs(pairs, allowed_keys) do
      {:ok, Map.new(pairs, &normalize_pair/1)}
    else
      {:ok, _other} -> {:error, :invalid_shape}
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      {:error, reason} -> {:error, reason}
    end
  end

  def decode(_raw, _allowed_keys), do: {:error, :invalid_json}

  defp validate_schema_keys(keys) do
    if length(keys) <= @max_keys and Enum.all?(keys, &(&1 in @known_keys)) do
      :ok
    else
      {:error, :invalid_shape}
    end
  end

  defp validate_size(raw) do
    cond do
      raw == "" -> {:error, :missing_signals}
      byte_size(raw) > @max_bytes -> {:error, :oversized}
      true -> :ok
    end
  end

  defp validate_pairs(pairs, allowed_keys) do
    keys = Enum.map(pairs, &elem(&1, 0))

    cond do
      length(keys) > @max_keys -> {:error, :invalid_shape}
      length(keys) != length(Enum.uniq(keys)) -> {:error, :duplicate_key}
      Enum.any?(keys, &(&1 not in allowed_keys)) -> {:error, :unknown_key}
      Enum.any?(pairs, &(not valid_pair?(&1))) -> {:error, :invalid_value}
      true -> :ok
    end
  end

  defp valid_pair?({"q", value}), do: is_binary(value) and String.length(value) <= 40
  defp valid_pair?({"note", value}), do: is_binary(value) and String.length(value) <= 80
  defp valid_pair?({"state", value}), do: value in @allowed_states
  defp valid_pair?({"scenario", value}), do: value in @allowed_scenarios

  defp valid_pair?({"tabId", value}),
    do: is_binary(value) and Regex.match?(@tab_id_pattern, value)

  defp valid_pair?({"page", value}) when is_integer(value), do: value in 1..20

  defp valid_pair?({"page", value}) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} -> page in 1..20
      _invalid -> false
    end
  end

  defp valid_pair?(_pair), do: false

  defp normalize_pair({"page", value}) when is_integer(value),
    do: {"page", Integer.to_string(value)}

  defp normalize_pair(pair), do: pair
end
