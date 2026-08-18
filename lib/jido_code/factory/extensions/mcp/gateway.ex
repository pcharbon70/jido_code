defmodule JidoCode.Factory.Extensions.MCP.Gateway do
  @moduledoc """
  Fail-closed MCP call gate over the Phase 3 reference monitor and effect journal.

  Every invocation is bound into a one-call registered command. `ToolGateway`
  performs admission and reauthorization immediately before dispatch.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.MCP.Call
  alias JidoCode.Factory.Extensions.MCP.Observation
  alias JidoCode.Factory.Extensions.MCP.Specification
  alias JidoCode.Factory.Extensions.MCP.TransportAdapter
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.ExecutionReceipt
  alias JidoCode.Factory.Tool.Proposal
  alias JidoCode.Factory.ToolGateway

  @spec execute(Specification.t(), Proposal.t(), Capability.t(), map(), map(), keyword()) ::
          {:ok, %{execution_receipt: ExecutionReceipt.t(), observation: Observation.t() | nil}}
          | {:error, AdapterError.t()}
  def execute(
        %Specification{} = specification,
        %Proposal{} = proposal,
        %Capability{} = capability,
        call_attributes,
        admission_current,
        options
      )
      when is_map(call_attributes) and is_map(admission_current) and is_list(options) do
    with {:ok, %Call{} = call} <- Call.new(specification, call_attributes),
         :ok <- phase3_binding(proposal, capability, call),
         {transport_module, _transport} = transport when is_atom(transport_module) <-
           Keyword.get(options, :transport),
         true <- transport?(transport_module),
         gateway_options <- gateway_options(options, specification, call, transport),
         {:ok, %ExecutionReceipt{} = receipt} <-
           ToolGateway.execute(proposal, capability, admission_current, gateway_options),
         {:ok, outcome} <- outcome(specification, call, receipt, options) do
      {:ok, outcome}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:invalid_input, :mcp_gateway)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :mcp_gateway)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :mcp_gateway)}
  end

  def execute(_specification, _proposal, _capability, _call, _current, _options),
    do: {:error, AdapterError.new(:invalid_input, :mcp_gateway)}

  defp phase3_binding(proposal, capability, call) do
    with "run_governed_command" <- proposal.tool_name,
         %{command: command} <- proposal.arguments,
         true <- command == call.authorization_command,
         true <- call.arguments_ref in proposal.input_refs,
         true <- command in capability.registered_commands,
         true <- call.tool.max_output_bytes <= capability.resource_ceilings.output_bytes,
         :ok <- credential_scope(capability, call),
         :ok <- network_scope(capability, call) do
      :ok
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :mcp_phase3_binding)}
    end
  end

  defp credential_scope(capability, %{credential_reference_iri: nil}) do
    if capability.credential_reference_iris == [],
      do: :ok,
      else: {:error, AdapterError.new(:unauthorized, :mcp_credential_scope)}
  end

  defp credential_scope(capability, call) do
    if call.credential_reference_iri in capability.credential_reference_iris,
      do: :ok,
      else: {:error, AdapterError.new(:unauthorized, :mcp_credential_scope)}
  end

  defp network_scope(capability, %{connection: %{url: url}}) do
    uri = URI.parse(url)
    port = if uri.port in [nil, 443], do: "", else: ":" <> Integer.to_string(uri.port)
    origin = "https://" <> String.downcase(uri.host) <> port

    if origin in capability.network_destinations,
      do: :ok,
      else: {:error, AdapterError.new(:unauthorized, :mcp_network_scope)}
  end

  defp network_scope(capability, %{connection: %{network: :deny}}) do
    if capability.network_destinations == [],
      do: :ok,
      else: {:error, AdapterError.new(:unauthorized, :mcp_network_scope)}
  end

  defp network_scope(_capability, _call),
    do: {:error, AdapterError.new(:unauthorized, :mcp_network_scope)}

  defp gateway_options(options, specification, call, transport) do
    effect = "mcp:" <> call.namespaced_tool

    options
    |> Keyword.delete(:transport)
    |> Keyword.put(:expected_effect, effect)
    |> Keyword.put(:allowed_effects, [effect])
    |> Keyword.put(:adapter, {
      TransportAdapter,
      %{specification: specification, call: call, transport: transport}
    })
    |> Keyword.put(:adapter_options, [])
  end

  defp outcome(specification, call, %ExecutionReceipt{} = receipt, options) do
    if receipt.effect_dispatched and receipt.status in [:completed, :failed] do
      observed_at = Keyword.get(options, :observed_at, DateTime.utc_now())

      with {:ok, observation} <- Observation.new(specification, call, receipt, observed_at) do
        {:ok, %{execution_receipt: receipt, observation: observation}}
      end
    else
      {:ok, %{execution_receipt: receipt, observation: nil}}
    end
  end

  defp transport?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :identity, 1) and
      function_exported?(module, :invoke, 3)
  end
end
