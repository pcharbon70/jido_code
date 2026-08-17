defmodule JidoCode.Factory.Model.Outcome do
  @moduledoc """
  Bounded Phase 1 model-invocation outcome attributes.

  Success records observed token/cost values with a post-dispatch enforcement
  class. Failures expose only the stable adapter kind and operation.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.Model.Response
  alias JidoCode.Factory.Model.StreamResult

  @spec attributes(
          {:ok, Response.t()} | {:error, AdapterError.t()} | StreamResult.t(),
          Request.t()
        ) :: map()
  def attributes({:ok, %Response{} = response}, %Request{}) do
    %{
      status: :completed,
      model_call_ref: Map.get(response.call_metadata, :response_id),
      usage: response.usage,
      diagnostic: "gateway=buffered;cost_enforcement=observed_post_dispatch"
    }
  end

  def attributes({:error, %AdapterError{} = error}, %Request{}) do
    %{
      status: failure_status(error),
      model_call_ref: nil,
      usage: %{},
      diagnostic: "gateway=buffered;error=#{error.kind};operation=#{error.operation}"
    }
  end

  def attributes(%StreamResult{} = result, %Request{}) do
    %{
      status: result.status,
      model_call_ref: nil,
      usage: result.usage,
      diagnostic: result.diagnostic
    }
  end

  defp failure_status(%AdapterError{kind: :timeout}), do: :timed_out
  defp failure_status(%AdapterError{}), do: :failed
end
