defmodule JidoCode.Knowledge.Memory.DatasetExportVerifier do
  @moduledoc "Zero-copy verification gate before governed dataset export release."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.DatasetExportPermit
  alias JidoCode.Knowledge.Memory.MemoryDatasetArtifact

  @revision "1.0.0"
  @forbidden_row_keys ~w[payload plaintext prompt personal_data provider_private hidden_reasoning]a

  def revision, do: @revision

  def verify(result, %DatasetExportPermit{} = permit, attributes, now)
      when is_map(result) and is_map(attributes) and is_struct(now, DateTime) do
    rows = result[:rows]
    manifest = result[:manifest]

    with true <- DatasetExportPermit.current?(permit, now),
         true <- is_list(rows) and rows != [],
         true <- manifest.iri == permit.manifest_iri,
         true <- result[:complete?] == true,
         true <- result[:source_complete?] == true,
         true <- result[:temporal_leakage_count] == 0,
         true <- chronology?(rows, manifest.cutoff),
         true <- repository_split_isolated?(rows),
         true <- deduplicated?(rows),
         true <- classifications_allowed?(rows, permit),
         true <- forbidden_absent?(rows),
         true <- Enum.frequencies_by(rows, & &1.outcome) == result[:class_balance],
         true <- attributes[:class_balance] == result[:class_balance],
         true <- attributes[:row_count] == length(rows),
         {:ok, artifact} <- MemoryDatasetArtifact.new(manifest, permit, attributes) do
      {:ok,
       %{
         revision: @revision,
         artifact: artifact,
         chronology_verified?: true,
         split_isolation_verified?: true,
         deduplication_verified?: true,
         source_completeness_verified?: true,
         class_balance_verified?: true,
         forbidden_content_absent?: true
       }}
    else
      _invalid -> {:error, Error.new(:unauthorized, :dataset_export_verification)}
    end
  rescue
    _error -> {:error, Error.new(:unauthorized, :dataset_export_verification)}
  end

  def verify(_result, _permit, _attributes, _now),
    do: {:error, Error.new(:unauthorized, :dataset_export_verification)}

  defp chronology?(rows, cutoff),
    do: Enum.all?(rows, &(DateTime.compare(&1.effective_at, cutoff) in [:lt, :eq]))

  defp repository_split_isolated?(rows) do
    rows
    |> Enum.group_by(& &1.repository_iri, & &1.split)
    |> Enum.all?(fn {_repository, splits} -> length(Enum.uniq(splits)) == 1 end)
  end

  defp deduplicated?(rows) do
    unique?(rows, &{&1.repository_iri, &1.task_iri}) and
      unique?(rows, & &1.patch_digest) and unique?(rows, & &1.semantic_digest) and
      unique?(Enum.reject(rows, &is_nil(&1.incident_iri)), & &1.incident_iri)
  end

  defp unique?(values, mapper),
    do: length(values) == values |> Enum.map(mapper) |> Enum.uniq() |> length()

  defp classifications_allowed?(rows, permit),
    do: Enum.all?(rows, &(&1.classification in permit.classifications))

  defp forbidden_absent?(rows) do
    Enum.all?(rows, fn row ->
      map = Map.from_struct(row)
      Enum.all?(@forbidden_row_keys, &(not Map.has_key?(map, &1)))
    end)
  end
end
