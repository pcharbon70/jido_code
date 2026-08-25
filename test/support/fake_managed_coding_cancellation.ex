defmodule JidoCode.TestSupport.FakeManagedCodingCancellation do
  @behaviour JidoCode.Factory.Ports.ManagedCodingCancellation

  def commit_request(owner, request), do: notify(owner, {:cancel_commit, request})
  def stop_dispatch(owner, request), do: notify(owner, {:cancel_stop_dispatch, request})
  def revoke_capabilities(owner, request), do: notify(owner, {:cancel_revoke, request})
  def cancel_queued(owner, request), do: notify(owner, {:cancel_queue, request})

  def terminate_effects(owner, request, grace),
    do: notify(owner, {:cancel_terminate, request, grace})

  def release_capacity(owner, request), do: notify(owner, {:cancel_release, request})
  def observe_late(owner, request, output), do: notify(owner, {:cancel_late, request, output})

  def cleanup(owner, request) do
    send(owner, {:cancel_cleanup, request})
    {:ok, request.retention}
  end

  def finalize(owner, request, proposed) do
    send(owner, {:cancel_finalize, request, proposed})
    {:ok, :cancelled}
  end

  defp notify(owner, message) do
    send(owner, message)
    :ok
  end
end
