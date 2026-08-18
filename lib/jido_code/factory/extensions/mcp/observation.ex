defmodule JidoCode.Factory.Extensions.MCP.Observation do
  @moduledoc "Remote MCP completion evidence that cannot express local acceptance."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.MCP.Call
  alias JidoCode.Factory.Extensions.MCP.Specification
  alias JidoCode.Factory.Tool.ExecutionReceipt
  alias JidoCode.Factory.Tool.Result

  @enforce_keys [
    :specification_digest,
    :call_digest,
    :server_identity,
    :namespaced_tool,
    :external_reference_iri,
    :result_digest,
    :remote_status,
    :output_bytes,
    :observed_at,
    :verification,
    :decision,
    :accepted,
    :execution_receipt
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Specification.t(), Call.t(), ExecutionReceipt.t(), DateTime.t()) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def new(
        %Specification{} = specification,
        %Call{} = call,
        %ExecutionReceipt{
          effect_dispatched: true,
          result: %Result{} = result
        } = receipt,
        %DateTime{} = observed_at
      ) do
    with true <- Specification.valid?(specification),
         true <- Call.valid?(call, specification),
         true <- result.status in [:completed, :failed],
         [external_reference_iri] <- result.external_output_iris,
         true <- result.usage[:mcp_call_digest] == call.digest,
         result_digest when is_binary(result_digest) <- result.usage[:mcp_result_digest],
         output_bytes when is_integer(output_bytes) <- result.usage[:mcp_output_bytes],
         :required <- result.usage[:verification],
         :pending <- result.usage[:decision] do
      {:ok,
       %__MODULE__{
         specification_digest: specification.digest,
         call_digest: call.digest,
         server_identity: specification.server_identity,
         namespaced_tool: call.namespaced_tool,
         external_reference_iri: external_reference_iri,
         result_digest: result_digest,
         remote_status: result.status,
         output_bytes: output_bytes,
         observed_at: DateTime.truncate(observed_at, :microsecond),
         verification: :required,
         decision: :pending,
         accepted: false,
         execution_receipt: receipt
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_specification, _call, _receipt, _observed_at), do: invalid()

  @spec accepting_output?(t()) :: false
  def accepting_output?(%__MODULE__{}), do: false

  defp invalid, do: {:error, AdapterError.new(:corrupt, :mcp_completion_observation)}
end
