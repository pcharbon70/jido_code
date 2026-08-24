defmodule JidoCode.Factory.ManagedCoding.ToolDirectiveExecutor do
  @moduledoc "Executes a host-resolved model tool proposal only through ToolGateway."

  @behaviour JidoCode.Factory.Ports.ManagedCodingDirective

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.ExecutionReceipt
  alias JidoCode.Factory.ToolGateway

  @impl true
  def execute(state, %{kind: :tool} = envelope, _options) when is_map(state) do
    with provider when is_function(provider, 2) <- state[:tool_provider],
         {:ok, proposal, capability, current, options} <- provider.(envelope, envelope.payload),
         {:ok, %ExecutionReceipt{} = receipt} <-
           ToolGateway.execute(proposal, capability, current, options) do
      {:ok,
       %{
         outcome: :completed,
         kind: result_kind(receipt.status),
         effect_dispatched: receipt.effect_dispatched,
         result_digest: digest(receipt.result),
         tool_status: receipt.result.status
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_tool_directive)}
  end

  def execute(_state, _envelope, _options), do: invalid()

  defp result_kind(:completed), do: :completed
  defp result_kind(:rejected), do: :denied
  defp result_kind(:ambiguous), do: :ambiguous
  defp result_kind(:cancelled), do: :cancelled
  defp result_kind(_status), do: :failed

  defp digest(result) do
    :crypto.hash(:sha256, :erlang.term_to_binary(result, [:deterministic]))
    |> Base.encode16(case: :lower)
  end

  defp invalid,
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_tool_directive)}
end
