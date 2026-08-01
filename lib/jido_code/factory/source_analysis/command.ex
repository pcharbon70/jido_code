defmodule JidoCode.Factory.SourceAnalysis.Command do
  @moduledoc """
  Maps an analyzer result into the public immutable source publication command.

  This module deliberately carries no store handle. The Knowledge command
  remains the only publication authority.
  """

  alias JidoCode.Factory.SourceAnalysis.Result
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @spec build(Result.t(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def build(result, context, options \\ [])

  def build(%Result{} = result, context, options)
      when is_map(context) and is_list(options) do
    Knowledge.source_publication_command(
      %{
        repository_iri: context[:repository_iri],
        repository_scope_iri: context[:repository_scope_iri],
        snapshot_iri: context[:snapshot_iri],
        observation_graph_iri: context[:observation_graph_iri],
        observation_graph_revision: context[:observation_graph_revision],
        tree_digest: context[:tree_digest],
        principal_iri: context[:principal_iri],
        actor_iri: context[:actor_iri],
        delegated_agent_iri: Map.get(context, :delegated_agent_iri),
        delegation_iri: Map.get(context, :delegation_iri),
        correlation_iri: context[:correlation_iri],
        causation_iri: context[:causation_iri],
        expected_dataset_revision: context[:expected_dataset_revision],
        analyzed_at: context[:analyzed_at],
        reason: context[:reason],
        analysis: Map.from_struct(result)
      },
      options
    )
  end

  def build(_result, _context, _options),
    do: {:error, Error.new(:invalid_input, :source_analysis_command)}
end
