defmodule JidoCodeWeb.ReadProjectionView do
  @moduledoc "Presentation helpers for already-shaped HUI-C4 read projections."

  alias JidoCode.Product.ReadProjection

  @spec trust(ReadProjection.t()) :: map()
  def trust(%ReadProjection{} = projection) do
    %{
      state: projection.state,
      revision: revision_label(projection.dataset_revision),
      freshness: projection.freshness |> Atom.to_string() |> String.capitalize(),
      source: "Reviewed graph queries #{projection.query_version}",
      as_of: DateTime.to_iso8601(projection.generated_at),
      completeness: completeness_label(projection)
    }
  end

  @spec retry_href(map()) :: String.t()
  def retry_href(page) do
    uri = URI.parse(page.canonical_url)
    if uri.query, do: uri.path <> "?" <> uri.query, else: uri.path
  end

  @spec sort_column(ReadProjection.t()) :: atom()
  def sort_column(%ReadProjection{summaries: summaries}) do
    case summaries[:sort_column] do
      "work" -> :work
      "agent" -> :agent
      "stage" -> :stage
      "health" -> :health
      "freshness" -> :freshness
      _project -> :project
    end
  end

  @spec sort_direction(ReadProjection.t()) :: atom()
  def sort_direction(%ReadProjection{summaries: summaries}) do
    if summaries[:sort_direction] == "descending", do: :descending, else: :ascending
  end

  @spec sort_hrefs(ReadProjection.t()) :: map()
  def sort_hrefs(%ReadProjection{summaries: summaries}), do: summaries[:sort_hrefs] || %{}

  @spec family_health(ReadProjection.t()) :: [map()]
  def family_health(%ReadProjection{attention_families: families}) do
    Enum.map(families, fn family ->
      %{
        label: family.label,
        value: if(is_integer(family.count), do: family.count, else: "Not configured"),
        status: health_status(family.state),
        detail: family_detail(family.state)
      }
    end)
  end

  @spec capability_health(ReadProjection.t()) :: [map()]
  def capability_health(%ReadProjection{capabilities: capabilities}) do
    Enum.map(capabilities, fn capability ->
      %{
        label: capability.label,
        value:
          capability.state |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize(),
        status: health_status(capability.state),
        detail: capability_detail(capability.state)
      }
    end)
  end

  defp revision_label(nil), do: "Unavailable"
  defp revision_label(revision), do: Integer.to_string(revision)

  defp completeness_label(%ReadProjection{complete?: true, truncated?: false}), do: "Complete"
  defp completeness_label(%ReadProjection{truncated?: true}), do: "Bounded and truncated"
  defp completeness_label(_projection), do: "Incomplete or unavailable"

  defp health_status(state) when state in [:ready], do: :healthy
  defp health_status(state) when state in [:incomplete, :stale, :truncated], do: :attention
  defp health_status(:unavailable), do: :failure
  defp health_status(_state), do: :unknown

  defp family_detail(:ready), do: "Current reviewed binding."
  defp family_detail(:unconfigured), do: "No accepted read binding; no count is inferred."
  defp family_detail(_state), do: "Coverage is partial or currently unavailable."

  defp capability_detail(:ready), do: "Available through the current read-only boundary."
  defp capability_detail(:unconfigured), do: "Not composed; no runnable control is presented."
  defp capability_detail(_state), do: "Capability is limited by current projection evidence."
end
