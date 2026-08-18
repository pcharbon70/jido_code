defmodule JidoCode.Factory.Publication.Request do
  @moduledoc "A separately leased publication attempt limited to bot branches and pull requests."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @enforce_keys [
    :operation,
    :task_iri,
    :attempt_iri,
    :run_graph_iri,
    :eligibility_iri,
    :authorization_iri,
    :lease_iri,
    :fencing_token,
    :capability_iri,
    :candidate_task_iri,
    :candidate_attempt_iri,
    :repository_iri,
    :credential_reference_iri,
    :requested_credential_scope,
    :approval_iri,
    :approval_consumption_iri,
    :base_branch,
    :bot_branch,
    :expected_old_object,
    :candidate_object,
    :patch_digest,
    :evidence_iris,
    :policy_revision
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @operations ~w[open_pull_request update_pull_request]a
  @credential_scopes ~w[repository_write provider_write]a
  @branch ~r/^[A-Za-z0-9._-][A-Za-z0-9._\/-]{0,199}$/
  @object ~r/^[a-f0-9]{40}(?:[a-f0-9]{24})?$/
  @digest ~r/^[a-f0-9]{64}$/

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    resources = ~w[
      task_iri attempt_iri eligibility_iri authorization_iri lease_iri capability_iri
      candidate_task_iri candidate_attempt_iri repository_iri credential_reference_iri
      approval_iri approval_consumption_iri
    ]a

    with operation when operation in @operations <- attributes[:operation],
         true <- Enum.all?(resources, &resource?(attributes[&1])),
         true <- attributes[:task_iri] != attributes[:candidate_task_iri],
         true <- attributes[:attempt_iri] != attributes[:candidate_attempt_iri],
         {:ok, expected_run_graph} <- Knowledge.run_graph_identity(attributes[:attempt_iri]),
         true <- attributes[:run_graph_iri] == expected_run_graph,
         true <- positive_integer?(attributes[:fencing_token]),
         scope when scope in @credential_scopes <- attributes[:requested_credential_scope],
         true <- branch?(attributes[:base_branch]),
         true <- branch?(attributes[:bot_branch]),
         true <- String.starts_with?(attributes[:bot_branch], "agent/"),
         true <- attributes[:base_branch] != attributes[:bot_branch],
         true <- object?(attributes[:expected_old_object]),
         true <- object?(attributes[:candidate_object]),
         true <- attributes[:expected_old_object] != attributes[:candidate_object],
         true <- digest?(attributes[:patch_digest]),
         {:ok, evidence_iris} <- resource_list(attributes[:evidence_iris]),
         true <- text?(attributes[:policy_revision], 256) do
      {:ok,
       struct!(
         __MODULE__,
         attributes
         |> Map.take(@enforce_keys)
         |> Map.put(:evidence_iris, evidence_iris)
       )}
    else
      _invalid -> invalid(:publication_request)
    end
  rescue
    _error -> invalid(:publication_request)
  end

  def new(_attributes), do: invalid(:publication_request)

  defp resource_list(values) when is_list(values) and values != [] and length(values) <= 100 do
    values = values |> Enum.uniq() |> Enum.sort()
    if Enum.all?(values, &resource?/1), do: {:ok, values}, else: invalid(:publication_evidence)
  end

  defp resource_list(_values), do: invalid(:publication_evidence)
  defp resource?(value), do: Knowledge.validate_resource_identity(value) == :ok

  defp branch?(value) when is_binary(value) do
    Regex.match?(@branch, value) and not String.starts_with?(value, [".", "/"]) and
      not String.ends_with?(value, [".", "/"]) and
      not String.contains?(value, ["..", "@{", "\\", " "])
  end

  defp branch?(_value), do: false
  defp object?(value), do: is_binary(value) and Regex.match?(@object, value)
  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp positive_integer?(value), do: is_integer(value) and value > 0

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
