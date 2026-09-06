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

  @spec project_metadata(ReadProjection.t()) :: [map()]
  def project_metadata(%ReadProjection{project: project}) when is_map(project) do
    [
      item("Repository", project[:repository_identity]),
      item("Alias semantics", project[:project_alias]),
      item("Enrollment", project[:enrollment]),
      item("Desired state", project[:desired_state]),
      item("Current state", project[:current_state]),
      item("Branch and worktree", project[:branch_policy]),
      item("Owner", project[:owner]),
      item("Evidence posture", project[:evidence]),
      item("Wiki", project[:wiki]),
      item("Dependencies", project[:dependencies]),
      item("Budget", project[:budget]),
      item("Cost", project[:cost]),
      item("Provenance", project[:provenance])
    ]
  end

  def project_metadata(_projection), do: []

  @spec wiki_metadata(ReadProjection.t()) :: [map()]
  def wiki_metadata(%ReadProjection{wiki: wiki}) when is_map(wiki) do
    [
      item("Enrollment", wiki[:state]),
      item("Enrollment revision", wiki[:enrollment_revision]),
      item("Generation", wiki[:generation]),
      item("Current edition", wiki[:current_edition]),
      item("Freshness", wiki[:freshness]),
      item("Cost", wiki[:cost])
    ]
  end

  def wiki_metadata(_projection), do: []

  @spec work_health(ReadProjection.t()) :: [map()]
  def work_health(%ReadProjection{summaries: %{work: work}}) when is_map(work) do
    [
      count_health("Eligible work", work[:eligible]),
      count_health("Blocked work", work[:blocked]),
      count_health("Executing work", work[:executing]),
      count_health("Awaiting decision", work[:awaiting_decision])
    ]
  end

  def work_health(_projection), do: []

  @spec attempt_count_health(ReadProjection.t()) :: [map()]
  def attempt_count_health(%ReadProjection{summaries: %{counts: counts}}) when is_list(counts) do
    Enum.map(counts, fn count ->
      %{
        label: count.label,
        value: if(is_integer(count.value), do: count.value, else: "Unavailable"),
        status: count_status(count.state),
        detail: count_detail(count.state)
      }
    end)
  end

  def attempt_count_health(_projection), do: []

  @spec attempt_items(ReadProjection.t()) :: [map()]
  def attempt_items(%ReadProjection{attempts: attempts}) do
    Enum.map(attempts, fn attempt ->
      %{
        label: attempt.label,
        detail: attempt.task,
        href: attempt.href,
        metadata: [
          item("Lifecycle", attempt.lifecycle),
          item("Fence", attempt.fence),
          item("Freshness", attempt.freshness),
          item("Owner", attempt.owner)
        ]
      }
    end)
  end

  @spec dependency_items(ReadProjection.t()) :: [map()]
  def dependency_items(%ReadProjection{dependencies: dependencies}) do
    Enum.map(dependencies, fn dependency ->
      %{
        label: dependency.label,
        detail: dependency.status,
        metadata: [item("Dependency", dependency.dependency)]
      }
    end)
  end

  @spec recent_attempt_items(ReadProjection.t()) :: [map()]
  def recent_attempt_items(%ReadProjection{summaries: summaries}) do
    summaries
    |> Map.get(:recent_items, [])
    |> Enum.map(fn recent ->
      %{
        label: recent.label,
        detail: recent.detail,
        metadata: [item("Kind", recent.kind |> Atom.to_string() |> String.capitalize())]
      }
    end)
  end

  @spec semantic_truth(ReadProjection.t()) :: [map()]
  def semantic_truth(%ReadProjection{summaries: summaries}) do
    [
      item("Plan and runtime", summaries[:plan_state]),
      item("Claims and evidence", summaries[:evidence_state]),
      item("Candidate and source", summaries[:source_state]),
      item("Liveness and progress", summaries[:progress_state])
    ]
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

  defp count_status(:ready), do: :healthy
  defp count_status(state) when state in [:stale, :incomplete, :truncated], do: :attention
  defp count_status(_state), do: :unknown

  defp count_detail(:ready), do: "Counted from the current authorized projection."
  defp count_detail(:unauthorized), do: "Not authorized; no count is inferred."
  defp count_detail(:unconfigured), do: "Not composed; no count is inferred."
  defp count_detail(_state), do: "Count is not currently available."

  defp count_health(label, value) do
    %{
      label: label,
      value: if(is_integer(value), do: value, else: "Unavailable"),
      status: if(is_integer(value), do: :healthy, else: :unknown),
      detail:
        if(is_integer(value),
          do: "Counted from the current authorized project projection.",
          else: "Observation unavailable; no zero is inferred."
        )
    }
  end

  defp item(label, value), do: %{label: label, value: value || "Unavailable"}

  defp family_detail(:ready), do: "Current reviewed binding."
  defp family_detail(:unconfigured), do: "No accepted read binding; no count is inferred."
  defp family_detail(_state), do: "Coverage is partial or currently unavailable."

  defp capability_detail(:ready), do: "Available through the current read-only boundary."
  defp capability_detail(:unconfigured), do: "Not composed; no runnable control is presented."
  defp capability_detail(_state), do: "Capability is limited by current projection evidence."
end
