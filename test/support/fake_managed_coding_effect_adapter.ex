defmodule JidoCode.TestSupport.FakeManagedCodingEffectAdapter do
  @behaviour JidoCode.Factory.Ports.ManagedCodingEffectAdapter

  alias JidoCode.Factory.AdapterError

  def dispatch({owner, results}, intent, request) do
    send(owner, {:effect_dispatch, intent, request})
    result(results, :dispatch)
  end

  def query({owner, results}, intent) do
    send(owner, {:effect_query, intent})
    result(results, :query)
  end

  def compare({owner, results}, intent, expected) do
    send(owner, {:effect_compare, intent, expected})
    result(results, :compare)
  end

  def compensate({owner, results}, intent) do
    send(owner, {:effect_compensate, intent})
    result(results, :compensate)
  end

  def timeout, do: {:error, AdapterError.new(:timeout, :effect_dispatch)}

  defp result(results, operation) when is_map(results), do: Map.fetch!(results, operation)
  defp result(result, _operation), do: result
end
