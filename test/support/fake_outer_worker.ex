defmodule JidoCode.TestSupport.FakeOuterWorker do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.OuterWorker

  @impl true
  def kill_namespace(worker, request, cancellation, options) do
    notify(worker, {:outer_worker, :kill_namespace, request.attempt_iri, cancellation.reason})

    Keyword.get(
      options,
      :kill_result,
      {:ok, %{namespace: :terminated, within_bound: true}}
    )
  end

  @impl true
  def destroy(worker, request, cancellation, options) do
    notify(worker, {:outer_worker, :destroy, request.attempt_iri, cancellation.reason})
    Keyword.get(options, :destroy_result, {:ok, %{status: :destroyed}})
  end

  defp notify(%{owner: owner}, message) when is_pid(owner), do: send(owner, message)
  defp notify(_worker, _message), do: :ok
end
