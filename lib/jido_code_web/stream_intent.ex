defmodule JidoCodeWeb.StreamIntent do
  @moduledoc "Closed transport correlation alongside the unchanged per-page read intent."
  alias Jason.OrderedObject
  alias JidoCodeWeb.ReadSignals

  def decode(surface, raw) do
    name = ReadSignals.namespace(surface)

    with {:ok, pairs} <- ReadSignals.decode_object(raw),
         true <- length(pairs) == 2,
         objects = Map.new(pairs),
         %OrderedObject{values: correlation} <- objects["stream"],
         %OrderedObject{} = query <- objects[name],
         true <- length(correlation) in 2..3,
         true <- length(Enum.uniq_by(correlation, &elem(&1, 0))) == length(correlation),
         true <- Enum.all?(correlation, fn {key, _} -> key in ~w(tab request cursor) end),
         correlation = Map.new(correlation),
         true <- random_id?(correlation["tab"]) and random_id?(correlation["request"]),
         true <- cursor?(correlation["cursor"]),
         {:ok, query} <- ReadSignals.decode(surface, Jason.encode!(%{name => query})) do
      {:ok,
       %{
         tab: correlation["tab"],
         request: correlation["request"],
         cursor: correlation["cursor"],
         query: query
       }}
    else
      _ -> {:error, :invalid_stream_intent}
    end
  end

  def random_id?(value) when is_binary(value) and byte_size(value) == 22 do
    case Base.url_decode64(value, padding: false) do
      {:ok, bytes} when byte_size(bytes) == 16 ->
        Base.url_encode64(bytes, padding: false) == value

      _ ->
        false
    end
  end

  def random_id?(_), do: false
  defp cursor?(nil), do: true

  defp cursor?(value) when is_binary(value) and byte_size(value) in 1..256,
    do: Regex.match?(~r/\A[A-Za-z0-9_.-]+\z/, value)

  defp cursor?(_), do: false
end
