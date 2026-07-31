defmodule JidoCode.Knowledge.CommandOutcome do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias TripleStore.SPARQL.Query

  @jf "https://jido.run/ontology/factory#"
  @prov_generated "http://www.w3.org/ns/prov#generated"
  @prov_invalidated "http://www.w3.org/ns/prov#invalidatedAtTime"
  @outcome_base "https://jido.run/ontology/outcome/"
  @outcomes %{
    (@outcome_base <> "committed") => :committed,
    (@outcome_base <> "rejected") => :rejected
  }

  @spec lookup(TripleStore.store(), String.t(), String.t(), String.t()) ::
          {:ok, :committed | :rejected | :superseded | nil} | {:error, Error.t()}
  def lookup(store, audit_graph, command_iri, receipt_iri) do
    with {:ok, :security_audit} <- GraphRegistry.identify(audit_graph),
         :ok <- ResourceIdentity.validate(command_iri),
         :ok <- ResourceIdentity.validate(receipt_iri) do
      context = %{db: store.db, dict_manager: store.dict_manager, permit_all: true}

      case Query.query(
             context,
             outcome_query(audit_graph, command_iri, receipt_iri),
             timeout: 5_000,
             use_cache: false
           ) do
        {:ok, []} -> {:ok, nil}
        {:ok, rows} when length(rows) <= 4 -> decode(rows)
        {:ok, _rows} -> corrupt()
        {:error, reason} -> {:error, BackendFailure.translate(reason, :command_outcome)}
      end
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :command_outcome)}
    end
  rescue
    _error -> {:error, Error.new(:unavailable, :command_outcome)}
  end

  defp decode(rows) do
    outcomes =
      rows
      |> Enum.map(&decode_row/1)
      |> Enum.uniq()

    case outcomes do
      [outcome] when outcome in [:committed, :rejected, :superseded] -> {:ok, outcome}
      _invalid -> corrupt()
    end
  end

  defp decode_row(row) do
    with {:named_node, outcome_iri} <- Map.get(row, "outcome"),
         {:ok, outcome} <- Map.fetch(@outcomes, outcome_iri) do
      if Map.get(row, "invalidated") in [nil, :unbound], do: outcome, else: :superseded
    else
      _invalid -> :invalid
    end
  end

  defp outcome_query(audit_graph, command_iri, receipt_iri) do
    """
    SELECT ?outcome ?invalidated WHERE {
      GRAPH <#{audit_graph}> {
        <#{command_iri}> <#{@prov_generated}> <#{receipt_iri}> .
        <#{command_iri}/audit> <#{@jf}auditsCommand> <#{command_iri}> ;
          <#{@jf}outcome> ?outcome .
        OPTIONAL {
          <#{receipt_iri}> <#{@prov_invalidated}> ?invalidated .
        }
      }
    }
    LIMIT 4
    """
  end

  defp corrupt, do: {:error, Error.new(:corrupt, :command_outcome)}
end
