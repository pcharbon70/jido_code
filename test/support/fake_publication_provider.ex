defmodule JidoCode.TestSupport.FakePublicationProvider do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.PublicationProvider

  alias JidoCode.Factory.AdapterError

  @impl true
  def capabilities(state, _request, options) do
    notify(state, {:publication_provider, :capabilities})

    {:ok,
     Keyword.get(options, :capabilities, %{
       branch_protection?: true,
       ruleset_protection?: true,
       protected_merge_authority?: false,
       credential_scope: :repository_write,
       credential_scope_proven?: true
     })}
  end

  @impl true
  def compare_and_swap_branch(state, request, options) do
    notify(state, {:publication_provider, :compare_and_swap, request.expected_old_object})
    actual = Map.get(state, :actual_old_object, request.expected_old_object)

    if actual == request.expected_old_object do
      {:ok,
       Keyword.get(options, :branch_receipt, %{
         expected_old_object: request.expected_old_object,
         observed_old_object: actual,
         new_object: request.candidate_object,
         fast_forward?: true,
         external_branch_id: "branch:#{request.bot_branch}"
       })}
    else
      {:error, AdapterError.new(:conflict, :provider_compare_and_swap)}
    end
  end

  @impl true
  def open_or_update_pull_request(state, request, _branch_receipt, options) do
    notify(state, {:publication_provider, :pull_request, request.operation})

    {:ok,
     Keyword.get(options, :pull_request_receipt, %{
       operation: request.operation,
       base_branch: request.base_branch,
       head_branch: request.bot_branch,
       external_pull_request_id: "pr:42",
       provider_revision: "provider-revision-9",
       merge_performed?: false
     })}
  end

  defp notify(%{owner: owner}, message) when is_pid(owner), do: send(owner, message)
  defp notify(_state, _message), do: :ok
end
