defmodule JidoCode.Knowledge.Memory.CrossRepositoryPolicy do
  @moduledoc "Fail-closed cohort partitioning before cross-repository candidate enumeration."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.CrossRepositoryAuthorization
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @protected_classes ~w[encrypted_content prompt prompt_representation personal confidential]a

  def revision, do: @revision

  def partition_key(%CrossRepositoryAuthorization{} = authorization) do
    material =
      [
        authorization.iri,
        Enum.join(authorization.repository_iris, "\n"),
        Enum.map_join(authorization.erasure_generations, "\n", fn {repository, generation} ->
          repository <> ":" <> Integer.to_string(generation)
        end),
        authorization.policy_revision,
        DateTime.to_iso8601(authorization.effective_cutoff)
      ]
      |> Enum.join("\n--\n")

    :crypto.hash(:sha256, material) |> Base.encode16(case: :lower)
  end

  def authorize_request(authorization, request, now)
      when is_struct(authorization, CrossRepositoryAuthorization) and is_map(request) and
             is_struct(now, DateTime) do
    with true <-
           CrossRepositoryAuthorization.current?(
             authorization,
             request[:actor_iri],
             request[:purpose],
             request[:use],
             now
           ),
         true <- subset?(request[:repository_iris], authorization.repository_iris),
         true <- request[:repository_iris] != [],
         true <- request[:data_class] in authorization.data_classes,
         true <- expressly_covered?(request[:data_class], authorization.data_classes) do
      {:ok,
       %{
         authorization_iri: authorization.iri,
         partition_key: partition_key(authorization),
         repository_iris: Enum.sort(request.repository_iris),
         data_class: request.data_class,
         effective_cutoff: authorization.effective_cutoff,
         erasure_generations: Map.take(authorization.erasure_generations, request.repository_iris)
       }}
    else
      _invalid -> unauthorized()
    end
  rescue
    _error -> unauthorized()
  end

  def authorize_request(_authorization, _request, _now), do: unauthorized()

  def candidates(
        %CrossRepositoryAuthorization{} = authorization,
        partitioned_indexes,
        request,
        now
      )
      when is_map(partitioned_indexes) do
    with {:ok, permit} <- authorize_request(authorization, request, now),
         {:ok, partition} <- Map.fetch(partitioned_indexes, permit.partition_key),
         true <- is_list(partition),
         true <- Enum.all?(partition, &eligible?(&1, permit)) do
      {:ok, partition}
    else
      _invalid -> unauthorized()
    end
  end

  def candidates(_authorization, _indexes, _request, _now), do: unauthorized()

  def local_authority(candidate, target_repository_iri, acceptance) when is_map(candidate) do
    with :ok <- ResourceIdentity.validate(target_repository_iri),
         true <- candidate[:repository_iri] != target_repository_iri,
         true <- candidate[:non_authoritative?] == true,
         true <- is_map(acceptance),
         true <- acceptance[:accepted?] == true,
         true <- acceptance[:target_repository_iri] == target_repository_iri,
         :ok <- ResourceIdentity.validate(acceptance[:decision_iri]),
         true <- acceptance[:independent?] == true do
      {:ok,
       Map.merge(candidate, %{
         local_authority?: true,
         local_decision_iri: acceptance.decision_iri
       })}
    else
      _invalid -> {:ok, Map.put(candidate, :local_authority?, false)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :cross_repository_local_authority)}
  end

  def local_authority(_candidate, _target, _acceptance),
    do: {:error, Error.new(:invalid_input, :cross_repository_local_authority)}

  defp eligible?(candidate, permit) when is_map(candidate) do
    candidate[:repository_iri] in permit.repository_iris and
      candidate[:classification] == permit.data_class and
      candidate[:erasure_generation] ==
        Map.get(permit.erasure_generations, candidate[:repository_iri]) and
      is_struct(candidate[:effective_at], DateTime) and
      DateTime.compare(candidate.effective_at, permit.effective_cutoff) in [:lt, :eq] and
      candidate[:non_authoritative?] == true
  end

  defp eligible?(_candidate, _permit), do: false

  defp subset?(requested, allowed) when is_list(requested),
    do: Enum.all?(requested, &(&1 in allowed))

  defp subset?(_requested, _allowed), do: false
  defp expressly_covered?(class, classes) when class in @protected_classes, do: class in classes
  defp expressly_covered?(_class, _classes), do: true
  defp unauthorized, do: {:error, Error.new(:unauthorized, :cross_repository_policy)}
end
