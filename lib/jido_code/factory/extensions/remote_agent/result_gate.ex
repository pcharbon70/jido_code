defmodule JidoCode.Factory.Extensions.RemoteAgent.ResultGate do
  @moduledoc "Current-fence ingress for remote results on their local delegated attempt."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.DelegatedResultGate
  alias JidoCode.Factory.Extensions.RemoteAgent.Delegation
  alias JidoCode.Factory.Extensions.RemoteAgent.Result
  alias JidoCode.Factory.Extensions.RemoteAgent.Specification

  @spec admit(Specification.t(), Delegation.t(), map(), map(), keyword()) ::
          {:ok, %{result: Result.t(), fence_receipt: map()}} | {:error, AdapterError.t()}
  def admit(specification, delegation, attributes, current, options \\ [])

  def admit(
        %Specification{} = specification,
        %Delegation{} = delegation,
        attributes,
        current,
        options
      )
      when is_map(attributes) and is_map(current) and is_list(options) do
    at = Keyword.get(options, :at, DateTime.utc_now())
    sink = Keyword.get(options, :sink)

    with {:ok, %Result{} = result} <- Result.new(specification, delegation, attributes),
         {:ok, fence_receipt} <-
           DelegatedResultGate.dispatch(
             delegation.execution,
             current,
             :result,
             Result.persistent_attributes(result),
             at: at,
             sink: sink
           ) do
      {:ok, %{result: result, fence_receipt: fence_receipt}}
    end
  end

  def admit(_specification, _delegation, _attributes, _current, _options),
    do: {:error, AdapterError.new(:invalid_input, :remote_agent_result_gate)}
end
