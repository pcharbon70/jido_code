defmodule JidoCodeWeb.Qualification.HypermediaFixture do
  @moduledoc """
  Bounded, immutable fixture data for the HUI-B3 non-product consumer.

  This module performs no product query, command, graph access, or durable
  mutation. It exists only to exercise controller, HEEx, and browser behavior.
  """

  @page_size 2
  @states ~w(ready loading empty error)
  @items [
    %{id: "fixture-alpha", label: "Alpha fixture", state: "ready", detail: "Stable native row"},
    %{
      id: "fixture-hostile",
      label: "<unsafe>& hostile label",
      state: "attention",
      detail: "Escaped text, never executable content"
    },
    %{id: "fixture-charlie", label: "Charlie fixture", state: "ready", detail: "Second page row"},
    %{id: "fixture-delta", label: "Delta fixture", state: "idle", detail: "Bounded final row"}
  ]

  @spec view(map()) :: map()
  def view(params) when is_map(params) do
    query = params |> Map.get("q", "") |> normalize_text(40)
    state = params |> Map.get("state", "ready") |> normalize_state()
    page = params |> Map.get("page", "1") |> normalize_page()

    filtered =
      if query == "" do
        @items
      else
        downcased = String.downcase(query)
        Enum.filter(@items, &String.contains?(String.downcase(&1.label), downcased))
      end

    filtered = if state == "empty", do: [], else: filtered
    page_count = max(ceil(length(filtered) / @page_size), 1)
    page = min(page, page_count)

    %{
      items: Enum.slice(filtered, (page - 1) * @page_size, @page_size),
      query: query,
      state: state,
      page: page,
      page_count: page_count,
      total: length(filtered),
      disclosure_open?: Map.get(params, "disclosure") == "open",
      dialog_open?: Map.get(params, "dialog") == "open"
    }
  end

  @spec validate_note(map()) :: {:ok, String.t()} | {:error, String.t(), keyword()}
  def validate_note(params) when is_map(params) do
    {note, submitted_length} = params |> Map.get("note", "") |> normalize_note()

    cond do
      submitted_length < 3 ->
        {:error, note, [note: {"must contain at least 3 characters", []}]}

      submitted_length > 80 ->
        {:error, note, [note: {"must contain at most 80 characters", []}]}

      true ->
        {:ok, note}
    end
  end

  def validate_note(_params), do: {:error, "", [note: {"is required", []}]}

  defp normalize_text(value, max_length) when is_binary(value) do
    value |> String.trim() |> String.slice(0, max_length)
  end

  defp normalize_text(_value, _max_length), do: ""

  defp normalize_note(value) when is_binary(value) do
    normalized = String.trim(value)
    {String.slice(normalized, 0, 80), String.length(normalized)}
  end

  defp normalize_note(_value), do: {"", 0}

  defp normalize_state(value) when value in @states, do: value
  defp normalize_state(_value), do: "ready"

  defp normalize_page(value) when is_binary(value) do
    case Integer.parse(value) do
      {page, ""} when page in 1..20 -> page
      _invalid -> 1
    end
  end

  defp normalize_page(_value), do: 1
end
