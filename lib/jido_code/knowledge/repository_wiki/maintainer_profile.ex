defmodule JidoCode.Knowledge.RepositoryWiki.MaintainerProfile do
  @moduledoc "Closed V1 maintainer behavior and exact repository eligibility."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "wiki-maintainer/1.0.0"
  @trigger_classes [
    :repository_change,
    :accepted_document,
    :dependency_metadata,
    :policy,
    :compiler,
    :manual,
    :recovery,
    :scheduled_refresh
  ]

  @spec profile(DateTime.t(), DateTime.t() | nil) :: {:ok, map()} | {:error, Error.t()}
  def profile(%DateTime{} = approved_at, expires_at) do
    with true <- Contract.valid_interval?(approved_at, expires_at),
         material <- %{
           revision: @revision,
           supported_generation_modes: [:deterministic_only],
           trigger_classes: @trigger_classes,
           debounce_ms: 250,
           coalescing: :latest_source_with_all_causes,
           repository_current_concurrency: 1,
           preview_concurrency: 4,
           maximum_pending: 64,
           retry: %{maximum_attempts: 3, base_backoff_ms: 250, maximum_backoff_ms: 5_000},
           lease: %{duration_ms: 30_000, heartbeat_ms: 10_000},
           cancellation: :semantic_fence_before_process_signal,
           recovery: :rescan_graph_state,
           executable_registry: :closed_application_registry,
           repository_selected_behavior: :forbidden,
           approved_at: DateTime.truncate(approved_at, :microsecond),
           expires_at: expires_at
         },
         digest <- Contract.digest(material),
         {:ok, iri} <- ResourceIdentity.deterministic(:wiki_maintainer, digest) do
      {:ok, material |> Map.put(:iri, iri) |> Map.put(:digest, digest)}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_maintainer_profile)
    end
  end

  def profile(_approved_at, _expires_at), do: invalid(:wiki_maintainer_profile)

  @spec eligible?(map(), map(), map()) :: :ok | {:error, atom()}
  def eligible?(profile, enrollment, context)
      when is_map(profile) and is_map(enrollment) and is_map(context) do
    with true <- enrollment[:state] == :automatic,
         true <- enrollment[:maintenance_mode] == :automatic,
         true <- enrollment[:generation_mode] == :deterministic_only,
         true <- enrollment[:repository_iri] == context[:repository_iri],
         true <- enrollment[:tenant_iri] == context[:tenant_iri],
         true <- enrollment[:generation_profile_iri] == context[:generation_profile_iri],
         true <- profile[:digest] == context[:maintainer_profile_digest],
         true <- enrollment[:revision] == context[:enrollment_revision],
         true <- enrollment[:cancellation_generation] == context[:cancellation_generation],
         true <- context[:policy_revision] == context[:current_policy_revision],
         true <- context[:worker_ready?] == true,
         true <- current?(profile, context[:evaluated_at]),
         true <- :deterministic_only in profile.supported_generation_modes do
      :ok
    else
      _invalid -> {:error, disabled_reason(enrollment, context)}
    end
  end

  def eligible?(_profile, _enrollment, _context), do: {:error, :invalid}

  @spec manual_eligible?(map(), map(), map()) :: :ok | {:error, atom()}
  def manual_eligible?(profile, enrollment, context) do
    automatic = Map.merge(enrollment, %{state: :automatic, maintenance_mode: :automatic})

    case eligible?(profile, automatic, context) do
      :ok -> if enrollment[:state] == :manual, do: :ok, else: {:error, :not_manual}
      error -> error
    end
  end

  @spec trigger_classes() :: [atom()]
  def trigger_classes, do: @trigger_classes

  defp current?(profile, %DateTime{} = evaluated_at) do
    DateTime.compare(profile.approved_at, evaluated_at) in [:lt, :eq] and
      (is_nil(profile.expires_at) or DateTime.compare(evaluated_at, profile.expires_at) == :lt)
  end

  defp current?(_profile, _evaluated_at), do: false

  defp disabled_reason(enrollment, context) do
    cond do
      enrollment[:state] == :off -> :off
      enrollment[:state] == :manual -> :manual_process_free
      context[:worker_ready?] != true -> :worker_unavailable
      enrollment[:revision] != context[:enrollment_revision] -> :stale_enrollment
      enrollment[:cancellation_generation] != context[:cancellation_generation] -> :cancelled
      context[:policy_revision] != context[:current_policy_revision] -> :stale_policy
      true -> :ineligible_profile
    end
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
