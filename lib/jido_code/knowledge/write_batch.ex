defmodule JidoCode.Knowledge.WriteBatch do
  @moduledoc """
  Backend-neutral, transient input for one atomic graph commit.

  This struct is an execution envelope, not a persisted domain model. Its RDF
  additions and immutable receipt are compiled to one ground update by the
  knowledge adapter.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Identity
  alias JidoCode.Knowledge.Vocabulary

  @max_graphs 256
  @max_operation_metadata_bytes 4_096

  @enforce_keys [
    :commit_id,
    :batch_digest,
    :additions,
    :removals,
    :target_graphs,
    :expected_dataset_revision,
    :expected_graph_revisions,
    :removal_policy,
    :operation_metadata
  ]
  defstruct [
    :commit_id,
    :batch_digest,
    :additions,
    :removals,
    :target_graphs,
    :expected_dataset_revision,
    :expected_graph_revisions,
    :removal_policy,
    :operation_metadata
  ]

  @type t :: %__MODULE__{
          commit_id: String.t(),
          batch_digest: String.t(),
          additions: [RDF.Quad.t()],
          removals: [RDF.Quad.t()],
          target_graphs: [String.t()],
          expected_dataset_revision: non_neg_integer(),
          expected_graph_revisions: %{String.t() => non_neg_integer()},
          removal_policy: :forbid | :maintenance,
          operation_metadata: map()
        }

  @spec new([RDF.Quad.coercible()], keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(additions, options) when is_list(additions) and is_list(options) do
    commit_id = Keyword.get_lazy(options, :commit_id, &Identity.commit_iri/0)
    removals = Keyword.get(options, :removals, [])
    removal_policy = Keyword.get(options, :removal_policy, :forbid)
    operation_metadata = Keyword.get(options, :operation_metadata, %{})

    with :ok <- validate_commit_id(commit_id),
         {:ok, normalized_additions} <- normalize_quads(additions),
         {:ok, normalized_removals} <- normalize_quads(removals),
         :ok <- require_additions(normalized_additions),
         :ok <- validate_removal_policy(normalized_removals, removal_policy),
         {:ok, target_graphs} <- target_graphs(normalized_additions, normalized_removals),
         {:ok, expected_dataset_revision} <- expected_dataset_revision(options),
         {:ok, expected_graph_revisions} <-
           expected_graph_revisions(options, target_graphs),
         :ok <- validate_operation_metadata(operation_metadata),
         {:ok, digest} <-
           digest(
             normalized_additions,
             normalized_removals,
             expected_dataset_revision,
             expected_graph_revisions,
             removal_policy
           ) do
      {:ok,
       %__MODULE__{
         commit_id: commit_id,
         batch_digest: digest,
         additions: normalized_additions,
         removals: normalized_removals,
         target_graphs: target_graphs,
         expected_dataset_revision: expected_dataset_revision,
         expected_graph_revisions: expected_graph_revisions,
         removal_policy: removal_policy,
         operation_metadata: operation_metadata
       }}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :build_write_batch)}
  catch
    _kind, _reason -> {:error, Error.new(:invalid_input, :build_write_batch)}
  end

  def new(_additions, _options), do: {:error, Error.new(:invalid_input, :build_write_batch)}

  defp validate_commit_id(commit_id) do
    if Identity.valid_commit_iri?(commit_id) do
      :ok
    else
      {:error, Error.new(:invalid_input, :validate_commit_identity)}
    end
  end

  defp normalize_quads(quads) when is_list(quads) do
    normalized = quads |> Enum.map(&RDF.Quad.new/1) |> Enum.uniq()

    if Enum.all?(normalized, &valid_application_quad?/1) do
      {:ok, normalized}
    else
      {:error, Error.new(:invalid_input, :validate_write_quads)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :validate_write_quads)}
  end

  defp normalize_quads(_quads), do: {:error, Error.new(:invalid_input, :validate_write_quads)}

  defp valid_application_quad?({_, _, _, %RDF.IRI{value: graph}} = quad) do
    RDF.Quad.valid?(quad) and not RDF.Quad.has_bnode?(quad) and
      graph != Vocabulary.system_graph()
  end

  defp valid_application_quad?(_quad), do: false

  defp require_additions([]), do: {:error, Error.new(:invalid_input, :validate_write_additions)}
  defp require_additions(_additions), do: :ok

  defp validate_removal_policy([], policy) when policy in [:forbid, :maintenance], do: :ok
  defp validate_removal_policy(_removals, :maintenance), do: :ok

  defp validate_removal_policy(_removals, _policy) do
    {:error, Error.new(:invalid_input, :validate_removal_policy)}
  end

  defp target_graphs(additions, removals) do
    graphs =
      (additions ++ removals)
      |> Enum.map(fn {_, _, _, %RDF.IRI{value: graph}} -> graph end)
      |> Enum.uniq()
      |> Enum.sort()

    if length(graphs) <= @max_graphs do
      {:ok, graphs}
    else
      {:error, Error.new(:invalid_input, :validate_target_graphs)}
    end
  end

  defp expected_dataset_revision(options) do
    case Keyword.fetch(options, :expected_dataset_revision) do
      {:ok, revision} when is_integer(revision) and revision >= 0 -> {:ok, revision}
      _missing_or_invalid -> {:error, Error.new(:invalid_input, :validate_expected_revision)}
    end
  end

  defp expected_graph_revisions(options, target_graphs) do
    with {:ok, revisions} <- Keyword.fetch(options, :expected_graph_revisions),
         {:ok, normalized} <- normalize_revision_map(revisions),
         true <- Map.keys(normalized) |> Enum.sort() == target_graphs do
      {:ok, normalized}
    else
      _missing_or_invalid -> {:error, Error.new(:invalid_input, :validate_expected_revision)}
    end
  end

  defp normalize_revision_map(revisions) when is_map(revisions) do
    Enum.reduce_while(revisions, {:ok, %{}}, fn {graph, revision}, {:ok, acc} ->
      with {:ok, graph_iri} <- normalize_graph_iri(graph),
           true <- is_integer(revision) and revision >= 0,
           false <- Map.has_key?(acc, graph_iri) do
        {:cont, {:ok, Map.put(acc, graph_iri, revision)}}
      else
        _invalid -> {:halt, :error}
      end
    end)
  end

  defp normalize_revision_map(_revisions), do: :error

  defp normalize_graph_iri(%RDF.IRI{value: value}), do: normalize_graph_iri(value)

  defp normalize_graph_iri(value) when is_binary(value) do
    if RDF.IRI.valid?(value) and value != Vocabulary.system_graph() do
      {:ok, value}
    else
      :error
    end
  end

  defp normalize_graph_iri(_value), do: :error

  defp validate_operation_metadata(metadata) when is_map(metadata) do
    encoded = :erlang.term_to_binary(metadata, [:deterministic])

    if byte_size(encoded) <= @max_operation_metadata_bytes do
      :ok
    else
      {:error, Error.new(:invalid_input, :validate_operation_metadata)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :validate_operation_metadata)}
  end

  defp validate_operation_metadata(_metadata) do
    {:error, Error.new(:invalid_input, :validate_operation_metadata)}
  end

  defp digest(additions, removals, dataset_revision, graph_revisions, removal_policy) do
    canonical_additions = canonical_nquads(additions)
    canonical_removals = canonical_nquads(removals)

    digest =
      {
        canonical_additions,
        canonical_removals,
        dataset_revision,
        Enum.sort(graph_revisions),
        removal_policy
      }
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    {:ok, digest}
  rescue
    _error -> {:error, Error.new(:invalid_input, :digest_write_batch)}
  end

  defp canonical_nquads([]), do: ""

  defp canonical_nquads(quads) do
    quads
    |> RDF.Dataset.new()
    |> RDF.NQuads.write_string!(sort: true)
  end
end
