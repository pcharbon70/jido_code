defmodule JidoCode.Knowledge.RestoreLog do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Identity
  alias JidoCode.Knowledge.Metadata
  alias JidoCode.Knowledge.Vocabulary

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  @spec record(TripleStore.store(), Metadata.t(), String.t()) ::
          {:ok, Metadata.t()} | {:error, Error.t()}
  def record(store, metadata, source_digest) do
    if valid_digest?(source_digest) do
      activity = Identity.restore_activity_iri()
      dataset_revision = metadata.dataset_revision + 1
      system_graph_revision = metadata.system_graph_revision + 1

      case TripleStore.update(
             store,
             update(
               activity,
               source_digest,
               metadata.dataset_revision,
               dataset_revision,
               system_graph_revision
             )
           ) do
        {:ok, 7} -> Metadata.read(store)
        {:ok, _count} -> {:error, Error.new(:persistence_failure, :record_restore_activity)}
        {:error, reason} -> {:error, BackendFailure.translate(reason, :record_restore_activity)}
      end
    else
      {:error, Error.new(:invalid_input, :record_restore_activity)}
    end
  end

  defp update(activity, digest, prior_revision, dataset_revision, system_graph_revision) do
    """
    INSERT DATA {
      GRAPH <#{Vocabulary.system_graph()}> {
        <#{activity}>
          <#{@rdf_type}> <#{Vocabulary.restore_activity_class()}> ;
          <#{Vocabulary.predicate(:status)}> <#{Vocabulary.restored()}> ;
          <#{Vocabulary.predicate(:source_digest)}> "#{digest}" ;
          <#{Vocabulary.predicate(:prior_dataset_revision)}> #{prior_revision} ;
          <#{Vocabulary.predicate(:dataset_revision)}> #{dataset_revision} .

        <#{Vocabulary.dataset()}>
          <#{Vocabulary.predicate(:dataset_revision)}> #{dataset_revision} .

        <#{Vocabulary.system_graph()}>
          <#{Vocabulary.predicate(:graph_revision)}> #{system_graph_revision} .
      }
    }
    """
  end

  defp valid_digest?(digest) when is_binary(digest) do
    byte_size(digest) == 64 and Regex.match?(~r/^[0-9a-f]{64}$/, digest)
  end

  defp valid_digest?(_digest), do: false
end
