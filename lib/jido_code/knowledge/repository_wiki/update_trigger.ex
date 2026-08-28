defmodule JidoCode.Knowledge.RepositoryWiki.UpdateTrigger do
  @moduledoc "Closed controller-authenticated repository wiki update trigger."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

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
  @priorities [:low, :normal, :high, :critical]

  @spec new(atom(), map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def new(type, payload, context)
      when type in @trigger_classes and is_map(payload) and is_map(context) do
    with true <- context[:controller_authenticated?] == true,
         :ok <- resources(payload, context),
         true <- bounded?(payload[:source_fence], 512),
         true <- is_integer(payload[:policy_revision]) and payload.policy_revision >= 0,
         true <- Contract.digest?(payload[:profile_digest]),
         true <- Contract.digest?(payload[:classification_digest]),
         priority when priority in @priorities <- payload[:priority],
         true <- bounded?(payload[:idempotency_key], 160),
         %DateTime{} = recorded_at <- payload[:recorded_at],
         true <- recorded_at == DateTime.truncate(recorded_at, :microsecond),
         causal <- normalize_causes(payload[:causal_iris]),
         true <- causal != :invalid,
         material <- %{
           type: type,
           repository_iri: payload.repository_iri,
           tenant_iri: payload.tenant_iri,
           controller_iri: context.controller_iri,
           source_fence: payload.source_fence,
           policy_revision: payload.policy_revision,
           profile_digest: payload.profile_digest,
           classification_digest: payload.classification_digest,
           classification: payload[:classification],
           priority: priority,
           idempotency_key: payload.idempotency_key,
           causal_iris: causal,
           recorded_at: recorded_at
         },
         digest <- Contract.digest(material),
         {:ok, iri} <-
           ResourceIdentity.deterministic(:wiki_compilation_attempt, "trigger\n" <> digest) do
      {:ok, material |> Map.put(:iri, iri) |> Map.put(:digest, digest)}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_update_trigger)
    end
  rescue
    _error -> invalid(:wiki_update_trigger)
  end

  def new(_type, _payload, _context), do: invalid(:wiki_update_trigger)

  @spec priority_weight(atom()) :: non_neg_integer()
  def priority_weight(:critical), do: 4
  def priority_weight(:high), do: 3
  def priority_weight(:normal), do: 2
  def priority_weight(:low), do: 1
  def priority_weight(_priority), do: 0

  defp resources(payload, context) do
    values = [payload[:repository_iri], payload[:tenant_iri], context[:controller_iri]]

    if Enum.all?(values, &(Contract.resource(&1) == :ok)) do
      :ok
    else
      invalid(:wiki_update_trigger_scope)
    end
  end

  defp normalize_causes(values) when is_list(values) and length(values) in 1..64 do
    if Enum.all?(values, &(Contract.resource(&1) == :ok)) do
      values |> Enum.uniq() |> Enum.sort()
    else
      :invalid
    end
  end

  defp normalize_causes(_values), do: :invalid
  defp bounded?(value, maximum), do: is_binary(value) and byte_size(value) in 1..maximum
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
