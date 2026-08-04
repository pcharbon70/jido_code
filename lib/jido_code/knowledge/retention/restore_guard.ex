defmodule JidoCode.Knowledge.Retention.RestoreGuard do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias TripleStore.SPARQL.Query

  @predicate "https://jido.run/ontology/factory#minimumRestoreRevision"
  @xsd_integer "http://www.w3.org/2001/XMLSchema#integer"
  @xsd_non_negative_integer "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"

  @spec floor(TripleStore.store()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def floor(store) do
    context = %{db: store.db, dict_manager: store.dict_manager, permit_all: true}

    query = """
    SELECT ?floor
    WHERE {
      GRAPH ?auditGraph {
        ?activity <#{@predicate}> ?floor .
      }
    }
    ORDER BY DESC(?floor)
    LIMIT 1
    """

    case Query.query(context, query, timeout: 5_000, use_cache: false) do
      {:ok, []} -> {:ok, 0}
      {:ok, [row]} -> decode_floor(row)
      {:ok, _rows} -> {:error, Error.new(:corrupt, :restore_retention_floor)}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :restore_retention_floor)}
    end
  end

  @spec authorize(non_neg_integer(), non_neg_integer()) :: :ok | {:error, Error.t()}
  def authorize(artifact_revision, floor)
      when is_integer(artifact_revision) and is_integer(floor) and artifact_revision >= floor,
      do: :ok

  def authorize(_artifact_revision, _floor),
    do: {:error, Error.new(:unauthorized, :restore_retention_floor)}

  defp decode_floor(row) do
    case Map.get(row, "floor") do
      {:literal, :typed, lexical, datatype}
      when datatype in [@xsd_integer, @xsd_non_negative_integer] ->
        case Integer.parse(lexical) do
          {floor, ""} when floor >= 0 -> {:ok, floor}
          _invalid -> {:error, Error.new(:corrupt, :restore_retention_floor)}
        end

      _invalid ->
        {:error, Error.new(:corrupt, :restore_retention_floor)}
    end
  end
end
