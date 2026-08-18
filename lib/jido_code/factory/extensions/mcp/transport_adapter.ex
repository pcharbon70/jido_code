defmodule JidoCode.Factory.Extensions.MCP.TransportAdapter do
  @moduledoc "Phase 3 tool adapter that contains one admitted MCP transport call."

  @behaviour JidoCode.Factory.Ports.Tool

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.MCP.Call
  alias JidoCode.Factory.Extensions.MCP.Specification
  alias JidoCode.Factory.Tool.Request
  alias JidoCode.Factory.Tool.Result
  alias JidoCode.Knowledge

  @state_keys [:specification, :call, :transport]
  @result_keys [:status, :external_reference_iri, :result_digest, :output_bytes, :redaction]

  @impl true
  def execute(state, %Request{} = request, options) when is_map(state) and is_list(options) do
    with true <- MapSet.new(Map.keys(state)) == MapSet.new(@state_keys),
         %Specification{} = specification <- state[:specification],
         true <- Specification.valid?(specification),
         %Call{} = call <- state[:call],
         true <- Call.valid?(call, specification),
         true <- request.arguments == %{command: call.authorization_command},
         true <- request.expected_effect == "mcp:" <> call.namespaced_tool,
         {module, transport} when is_atom(module) <- state[:transport],
         true <- transport?(module),
         {:ok, identity} <- module.identity(transport),
         :ok <- identity_matches(identity, specification),
         {:ok, response} <- module.invoke(transport, call, options),
         {:ok, result} <- result(response, request, call) do
      {:ok, result}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> corrupt()
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :mcp_transport)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :mcp_transport)}
  end

  def execute(_state, _request, _options), do: corrupt()

  defp identity_matches(identity, specification) when is_map(identity) do
    if MapSet.new(Map.keys(identity)) == MapSet.new([:identity, :digest]) and
         identity.identity == specification.adapter_identity and
         identity.digest == specification.adapter_digest do
      :ok
    else
      {:error, AdapterError.new(:unauthorized, :mcp_adapter_identity)}
    end
  end

  defp identity_matches(_identity, _specification),
    do: {:error, AdapterError.new(:unauthorized, :mcp_adapter_identity)}

  defp result(response, request, call) when is_map(response) do
    maximum = min(request.output_bytes, call.tool.max_output_bytes)

    with true <- MapSet.new(Map.keys(response)) == MapSet.new(@result_keys),
         status when status in [:completed, :failed] <- response[:status],
         :ok <- Knowledge.validate_resource_identity(response[:external_reference_iri]),
         true <- digest?(response[:result_digest]),
         bytes when is_integer(bytes) and bytes in 0..maximum//1 <- response[:output_bytes],
         redaction when redaction in [:none, :applied, :fully_redacted] <- response[:redaction],
         {:ok, result} <-
           Result.new(
             %{
               status: status,
               exit_status: nil,
               stdout: "",
               stderr: if(status == :failed, do: "mcp=remote_failed", else: ""),
               external_output_iris: [response.external_reference_iri],
               usage: %{
                 mcp_call_digest: call.digest,
                 mcp_result_digest: response.result_digest,
                 mcp_output_bytes: bytes,
                 remote_status: status,
                 verification: :required,
                 decision: :pending
               },
               artifact_iris: [],
               redaction: redaction
             },
             maximum
           ) do
      {:ok, result}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> corrupt()
    end
  end

  defp result(_response, _request, _call), do: corrupt()

  defp transport?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :identity, 1) and
      function_exported?(module, :invoke, 3)
  end

  defp digest?(value),
    do: is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp corrupt, do: {:error, AdapterError.new(:corrupt, :mcp_transport_result)}
end
