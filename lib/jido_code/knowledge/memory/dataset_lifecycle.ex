defmodule JidoCode.Knowledge.Memory.DatasetLifecycle do
  @moduledoc "Propagates source policy, hold, revocation, and erasure into external dataset copies."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.MemoryDatasetArtifact
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @events ~w[hold_placed hold_released authorization_revoked source_invalidated erasure_requested deletion_attested]a

  def revision, do: @revision

  def transition(%MemoryDatasetArtifact{} = artifact, event, attributes)
      when event in @events and is_map(attributes) do
    with %DateTime{} = recorded_at <- attributes[:recorded_at],
         :ok <- ResourceIdentity.validate(attributes[:evidence_iri]),
         {:ok, next_state, required_action} <- next(artifact.availability_state, event),
         {:ok, transition_iri} <- identity(artifact, event, recorded_at) do
      {:ok,
       %{
         revision: @revision,
         transition_iri: transition_iri,
         artifact_iri: artifact.iri,
         prior_state: artifact.availability_state,
         next_state: next_state,
         event: event,
         evidence_iri: attributes.evidence_iri,
         recorded_at: DateTime.truncate(recorded_at, :microsecond),
         external_copy_actions:
           Enum.map(artifact.external_copy_iris, &%{copy_iri: &1, action: required_action}),
         artifact: %MemoryDatasetArtifact{artifact | availability_state: next_state}
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def transition(_artifact, _event, _attributes), do: invalid()

  defp next(:available, :hold_placed), do: {:ok, :quarantined, :quarantine}
  defp next(:quarantined, :hold_released), do: {:ok, :available, :release}

  defp next(state, event)
       when state in [:available, :quarantined] and
              event in [:authorization_revoked, :source_invalidated, :erasure_requested],
       do: {:ok, :deletion_required, :delete}

  defp next(:deletion_required, :deletion_attested), do: {:ok, :deleted, :verify_deleted}
  defp next(_state, _event), do: :error

  defp identity(artifact, event, recorded_at) do
    ResourceIdentity.deterministic(
      :dataset_lifecycle_transition,
      Enum.join([artifact.iri, Atom.to_string(event), DateTime.to_iso8601(recorded_at)], "\n")
    )
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :dataset_lifecycle)}
end
