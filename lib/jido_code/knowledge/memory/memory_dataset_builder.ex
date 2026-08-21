defmodule JidoCode.Knowledge.Memory.MemoryDatasetBuilder do
  @moduledoc "Constructs chronological rows with exclusion, split isolation, and deduplication evidence."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.MemoryDatasetManifest
  alias JidoCode.Knowledge.Memory.MemoryDatasetRow

  @revision "1.0.0"
  @forbidden_flags ~w[secret personal provider_private hidden_reasoning unresolved_deletion]a

  def revision, do: @revision

  def build(%MemoryDatasetManifest{} = manifest, candidates) when is_list(candidates) do
    {eligible, exclusions} =
      candidates
      |> Enum.sort_by(&candidate_sort_key/1)
      |> Enum.reduce({[], []}, fn candidate, {accepted, rejected} ->
        case exclusion_reason(manifest, candidate) do
          nil -> {[candidate | accepted], rejected}
          reason -> {accepted, [%{candidate_iri: candidate[:iri], reason: reason} | rejected]}
        end
      end)

    {deduplicated, duplicate_exclusions} = deduplicate(Enum.reverse(eligible))

    with {:ok, rows} <- rows(manifest, deduplicated) do
      {:ok,
       %{
         revision: @revision,
         manifest: %{manifest | status: :verified},
         rows: rows,
         exclusions: Enum.reverse(exclusions) ++ duplicate_exclusions,
         class_balance: Enum.frequencies_by(rows, & &1.outcome),
         repository_splits:
           rows
           |> Enum.group_by(& &1.repository_iri, & &1.split)
           |> Map.new(fn {repository, splits} -> {repository, Enum.uniq(splits)} end),
         source_complete?: Enum.all?(rows, &(&1.source_resource_iris != [])),
         temporal_leakage_count: 0,
         complete?: true
       }}
    end
  rescue
    _error -> invalid()
  end

  def build(_manifest, _candidates), do: invalid()

  defp rows(manifest, candidates) do
    candidates
    |> Enum.reduce_while({:ok, []}, fn candidate, {:ok, rows} ->
      attributes =
        candidate
        |> Map.take([
          :repository_iri,
          :task_iri,
          :patch_digest,
          :incident_iri,
          :classification,
          :outcome,
          :effective_at,
          :source_resource_iris,
          :semantic_digest,
          :representation_digest,
          :erasure_generation
        ])
        |> Map.put(:split, Map.fetch!(manifest.split_policy, candidate.repository_iri))

      case MemoryDatasetRow.new(manifest, attributes) do
        {:ok, row} -> {:cont, {:ok, [row | rows]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      error -> error
    end
  end

  defp exclusion_reason(manifest, candidate) when is_map(candidate) do
    cond do
      candidate[:repository_iri] not in manifest.repository_iris ->
        :repository_not_authorized

      candidate[:classification] not in manifest.classifications ->
        :classification_not_allowed

      forbidden?(candidate) ->
        :forbidden_content

      candidate[:unresolved_deletion?] == true ->
        :unresolved_deletion

      not is_struct(candidate[:effective_at], DateTime) ->
        :invalid_effective_time

      DateTime.compare(candidate.effective_at, manifest.cutoff) == :gt ->
        :post_cutoff_evidence

      future_evidence?(candidate[:future_evidence_at], manifest.cutoff) ->
        :future_evidence

      candidate[:source_complete?] != true ->
        :source_lineage_incomplete

      candidate[:erasure_generation] !=
          Map.get(manifest.erasure_generations, candidate[:repository_iri]) ->
        :erasure_generation_stale

      true ->
        nil
    end
  end

  defp exclusion_reason(_manifest, _candidate), do: :invalid_candidate

  defp forbidden?(candidate) do
    Enum.any?(@forbidden_flags, fn flag -> candidate[flag] == true end)
  end

  defp future_evidence?(nil, _cutoff), do: false

  defp future_evidence?(%DateTime{} = evidence_at, cutoff),
    do: DateTime.compare(evidence_at, cutoff) == :gt

  defp future_evidence?(_invalid, _cutoff), do: true

  defp deduplicate(candidates) do
    {accepted, exclusions, _seen} =
      Enum.reduce(candidates, {[], [], MapSet.new()}, fn candidate, {rows, rejected, seen} ->
        keys = deduplication_keys(candidate)

        if Enum.any?(keys, &MapSet.member?(seen, &1)) do
          {rows, [%{candidate_iri: candidate[:iri], reason: :duplicate} | rejected], seen}
        else
          {[candidate | rows], rejected, Enum.reduce(keys, seen, &MapSet.put(&2, &1))}
        end
      end)

    {Enum.reverse(accepted), Enum.reverse(exclusions)}
  end

  defp deduplication_keys(candidate) do
    base = [
      {:repository_task, candidate[:repository_iri], candidate[:task_iri]},
      {:patch, candidate[:patch_digest]},
      {:semantic, candidate[:semantic_digest]}
    ]

    if is_nil(candidate[:incident_iri]),
      do: base,
      else: [{:incident, candidate[:incident_iri]} | base]
  end

  defp candidate_sort_key(candidate) do
    {
      candidate[:effective_at] || ~U[9999-12-31 23:59:59Z],
      candidate[:repository_iri] || "",
      candidate[:iri] || ""
    }
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :memory_dataset_builder)}
end
