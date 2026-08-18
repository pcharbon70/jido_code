defmodule JidoCode.TestSupport.FakeVerificationWorkspace do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.VerificationWorkspace

  alias JidoCode.Factory.AdapterError

  @impl true
  def checkout(state, admission, options) do
    notify(state, {:verification_workspace, :checkout, admission.base_commit})

    Keyword.get(options, :checkout_result, %{
      handle: :base,
      base_commit: admission.base_commit,
      workspace_digest: digest("base")
    })
    |> ok()
  end

  @impl true
  def apply_candidate(state, base, artifacts, patch_digest, options) do
    notify(state, {:verification_workspace, :apply, base.handle, patch_digest})

    Keyword.get(options, :candidate_result, %{
      handle: :candidate,
      patch_digest: patch_digest,
      applied_artifact_digests: Enum.map(artifacts, & &1.digest),
      workspace_digest: digest("candidate"),
      complete?: true,
      executor_state_used?: false
    })
    |> ok()
  end

  @impl true
  def changed_paths(state, _candidate, options) do
    notify(state, {:verification_workspace, :changed_paths})
    {:ok, Keyword.get(options, :changed_paths, ["lib/jido_code/example.ex"])}
  end

  @impl true
  def run_check(state, workspace, check, options) do
    notify(state, {:verification_workspace, :check, workspace.handle, check.id})
    statuses = Keyword.get(options, :check_statuses, %{})
    status = Map.get(statuses, {workspace.handle, check.id}, :passed)

    {:ok,
     %{
       check_id: check.id,
       status: status,
       environment_digest: Keyword.fetch!(options, :environment_digest),
       command_digest: check.command_digest,
       result_digest: digest("result:#{workspace.handle}:#{check.id}:#{status}"),
       output_digest: digest("output:#{workspace.handle}:#{check.id}:#{status}"),
       workspace_digest: workspace.workspace_digest
     }}
  end

  @impl true
  def cleanup(state, handles, options) do
    notify(state, {:verification_workspace, :cleanup, Enum.map(handles, & &1.handle)})
    Keyword.get(options, :cleanup_result, :ok)
  end

  defp ok({:error, %AdapterError{} = error}), do: {:error, error}
  defp ok(value), do: {:ok, value}

  defp notify(%{owner: owner}, message) when is_pid(owner), do: send(owner, message)
  defp notify(_state, _message), do: :ok

  defp digest(material) do
    :crypto.hash(:sha256, material) |> Base.encode16(case: :lower)
  end
end
