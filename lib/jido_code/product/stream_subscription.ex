defmodule JidoCode.Product.StreamSubscription do
  @moduledoc "Product-owned lifecycle adapter over revision-only projection subscriptions."
  alias JidoCode.Knowledge.ProjectionSubscription

  def open(%{refresh: :identity_only}, _projection), do: {:ok, nil}

  def open(binding, projection) do
    ProjectionSubscription.start_page_stream(
      owner: self(),
      scopes: binding.scopes,
      families: binding.families,
      last_revision: Map.get(projection || %{}, :dataset_revision) || 0
    )
  end

  def poll(nil), do: :idle

  def poll(pid) do
    ProjectionSubscription.poll(pid)
  catch
    :exit, _ -> {:error, :subscription_lost}
  end

  def evaluated(pid, revision) do
    ProjectionSubscription.evaluated(pid, revision)
  catch
    :exit, _ -> {:error, :subscription_lost}
  end

  def close(nil), do: :ok

  def close(pid) do
    GenServer.stop(pid, :normal, 1_000)
  catch
    :exit, _ -> :ok
  end
end
