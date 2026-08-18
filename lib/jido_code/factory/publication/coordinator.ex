defmodule JidoCode.Factory.Publication.Coordinator do
  @moduledoc "Governed bot-branch publication with provider-enforced compare-and-swap."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Publication.Request
  alias JidoCode.Factory.Publication.Result

  @spec publish(Request.t(), map(), module(), term(), keyword()) ::
          {:ok, Result.t()} | {:error, AdapterError.t()}
  def publish(request, current, adapter, adapter_state, options \\ [])

  def publish(%Request{} = request, current, adapter, adapter_state, options)
      when is_map(current) and is_atom(adapter) and is_list(options) do
    with true <- provider?(adapter),
         :ok <- revalidate(request, current, options),
         {:ok, capabilities} <- adapter.capabilities(adapter_state, request, options),
         {:ok, credential_scope} <- capabilities(capabilities, request),
         {:ok, branch_receipt} <-
           adapter.compare_and_swap_branch(adapter_state, request, options),
         :ok <- branch_receipt(branch_receipt, request),
         {:ok, pull_request_receipt} <-
           adapter.open_or_update_pull_request(adapter_state, request, branch_receipt, options),
         {:ok, result} <-
           result(request, branch_receipt, pull_request_receipt, credential_scope) do
      {:ok, result}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:publication)
    end
  rescue
    _error -> unavailable(:publication)
  catch
    :exit, _reason -> unavailable(:publication)
  end

  def publish(_request, _current, _adapter, _adapter_state, _options),
    do: invalid(:publication)

  defp revalidate(request, current, options) do
    expected = %{
      task_iri: request.task_iri,
      attempt_iri: request.attempt_iri,
      run_graph_iri: request.run_graph_iri,
      run_graph_state: :open,
      eligibility_iri: request.eligibility_iri,
      eligibility_state: :eligible,
      authorization_iri: request.authorization_iri,
      authorization_state: :authorized,
      lease_iri: request.lease_iri,
      lease_state: :active,
      fencing_token: request.fencing_token,
      capability_iri: request.capability_iri,
      approval_iri: request.approval_iri,
      approval_consumption_iri: request.approval_consumption_iri,
      approval_state: :consumed,
      policy_revision: request.policy_revision,
      bot_branch: request.bot_branch,
      base_branch: request.base_branch,
      observed_old_object: request.expected_old_object
    }

    clock = Keyword.get(options, :clock)

    cond do
      Map.take(current, Map.keys(expected)) != expected ->
        unauthorized(:publication_revalidation)

      not is_function(clock, 0) ->
        invalid(:publication_clock)

      not match?(%DateTime{}, current[:lease_expires_at]) ->
        unauthorized(:publication_lease)

      DateTime.compare(clock.(), current.lease_expires_at) != :lt ->
        unauthorized(:publication_lease)

      true ->
        :ok
    end
  end

  defp capabilities(
         %{
           branch_protection?: true,
           ruleset_protection?: true,
           protected_merge_authority?: false,
           credential_scope: credential_scope,
           credential_scope_proven?: proven?
         },
         request
       )
       when credential_scope in [:repository_write, :provider_write] and is_boolean(proven?) do
    cond do
      request.requested_credential_scope == :repository_write and
        credential_scope == :repository_write and proven? ->
        {:ok, :repository_write}

      request.requested_credential_scope == :provider_write and
          credential_scope == :provider_write ->
        {:ok, :provider_write}

      true ->
        unauthorized(:publication_credential_scope)
    end
  end

  defp capabilities(_capabilities, _request), do: unauthorized(:publication_provider_protection)

  defp branch_receipt(
         %{
           expected_old_object: expected,
           observed_old_object: observed,
           new_object: new_object,
           fast_forward?: true,
           external_branch_id: external_branch_id
         },
         request
       ) do
    if expected == request.expected_old_object and observed == expected and
         new_object == request.candidate_object and is_binary(external_branch_id) and
         byte_size(external_branch_id) in 1..256 do
      :ok
    else
      conflict(:publication_compare_and_swap)
    end
  end

  defp branch_receipt(_receipt, _request), do: conflict(:publication_non_fast_forward)

  defp result(
         request,
         branch,
         %{
           operation: operation,
           base_branch: base_branch,
           head_branch: head_branch,
           external_pull_request_id: pull_request_id,
           provider_revision: provider_revision,
           merge_performed?: false
         },
         credential_scope
       ) do
    if operation == request.operation and base_branch == request.base_branch and
         head_branch == request.bot_branch and is_binary(pull_request_id) and
         byte_size(pull_request_id) in 1..256 and is_binary(provider_revision) and
         byte_size(provider_revision) in 1..256 do
      {:ok,
       %Result{
         attempt_iri: request.attempt_iri,
         run_graph_iri: request.run_graph_iri,
         base_branch: base_branch,
         bot_branch: head_branch,
         old_object: branch.observed_old_object,
         new_object: branch.new_object,
         external_branch_id: branch.external_branch_id,
         external_pull_request_id: pull_request_id,
         provider_revision: provider_revision,
         credential_scope: credential_scope,
         merge_authority?: false,
         terminal?: true
       }}
    else
      unauthorized(:publication_pull_request_receipt)
    end
  end

  defp result(_request, _branch, _pull_request, _scope),
    do: unauthorized(:publication_merge_authority)

  defp provider?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :capabilities, 3) and
      function_exported?(module, :compare_and_swap_branch, 3) and
      function_exported?(module, :open_or_update_pull_request, 4)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
