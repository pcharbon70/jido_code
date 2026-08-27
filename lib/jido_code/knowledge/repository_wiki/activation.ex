defmodule JidoCode.Knowledge.RepositoryWiki.Activation do
  @moduledoc """
  Reviewed compare-and-swap activation boundary for repository wiki editions.

  Qualification is recalculated from immutable evidence immediately before the
  command is built. Only a committed receipt invalidates disposable current-
  edition projections; duplicates and every failed/stale race preserve them.
  """

  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Edition
  alias JidoCode.Knowledge.RepositoryWiki.GenerationProfile
  alias JidoCode.Knowledge.RepositoryWiki.Qualification
  alias JidoCode.Knowledge.RepositoryWiki.ReviewDecision

  @spec prepare(
          Edition.t(),
          map(),
          GenerationProfile.t(),
          ReviewDecision.t(),
          map(),
          map(),
          keyword()
        ) :: {:ok, map()} | {:error, map() | Error.t()}
  def prepare(edition, resolution, profile, review, context, attributes, options \\ [])

  def prepare(
        %Edition{} = edition,
        resolution,
        %GenerationProfile{} = profile,
        %ReviewDecision{} = review,
        context,
        attributes,
        options
      )
      when is_map(resolution) and is_map(context) and is_map(attributes) and is_list(options) do
    qualification = Qualification.assess(edition, resolution, profile, review, context)

    with :qualified <- qualification.outcome,
         true <- edition.purpose != :candidate_preview,
         true <- qualification.expected_graph_revisions == attributes[:expected_graph_revisions],
         true <- attributes[:expected_graph_revisions] == context[:current_graph_revisions],
         true <- attributes[:control_graph_iri] == context[:control_graph_iri],
         true <- attributes[:source_fence] == qualification.source_fence,
         command_attributes <-
           attributes
           |> Map.put(:qualification_digest, qualification.qualification_digest)
           |> Map.put(:qualification_guards, qualification.guards),
         {:ok, command} <-
           Edition.activate_command(edition, resolution, profile, command_attributes, options) do
      {:ok,
       %{
         command: command,
         qualification: qualification,
         outcome: :prepared,
         activation_authority: :reviewed_compare_and_swap
       }}
    else
      outcome
      when outcome in [:stale, :competing, :disabled, :unqualified, :duplicate, :unauthorized] ->
        {:error, qualification}

      {:error, %Error{} = error} ->
        {:error, error}

      _invalid ->
        {:error, %{qualification | outcome: :competing, activation_authorized?: false}}
    end
  end

  def prepare(_edition, _resolution, _profile, _review, _context, _attributes, _options),
    do: {:error, %{outcome: :unqualified, activation_authorized?: false}}

  @spec outcome(CommandReceipt.t()) :: atom()
  def outcome(%CommandReceipt{outcome: :committed}), do: :accepted
  def outcome(%CommandReceipt{outcome: :already_committed}), do: :duplicate
  def outcome(%CommandReceipt{outcome: :conflicted}), do: :competing
  def outcome(%CommandReceipt{outcome: :unauthorized}), do: :unauthorized

  def outcome(%CommandReceipt{outcome: outcome}) when outcome in [:rejected, :invalid],
    do: :unqualified

  def outcome(%CommandReceipt{}), do: :stale

  @spec cache_directive(CommandReceipt.t(), Edition.t()) :: :retain | {:invalidate, map()}
  def cache_directive(%CommandReceipt{outcome: :committed} = receipt, %Edition{} = edition) do
    {:invalidate,
     %{
       repository_iri: edition.repository_iri,
       edition_iri: edition.iri,
       dataset_revision: receipt.dataset_revision,
       projections: [:navigation, :search],
       rebuild_from: :accepted_graph_state
     }}
  end

  def cache_directive(%CommandReceipt{}, %Edition{}), do: :retain
end
