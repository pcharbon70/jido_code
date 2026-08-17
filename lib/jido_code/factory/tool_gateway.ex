defmodule JidoCode.Factory.ToolGateway do
  @moduledoc "Invocation-before-effect reference monitor for one governed tool call."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.Tool.Authorization
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.ExecutionReceipt
  alias JidoCode.Factory.Tool.Proposal
  alias JidoCode.Factory.Tool.ReferenceMonitor
  alias JidoCode.Factory.Tool.Request
  alias JidoCode.Factory.Tool.Result
  alias JidoCode.Factory.Tool.StartReceipt

  @spec execute(Proposal.t(), Capability.t(), map(), keyword()) ::
          {:ok, ExecutionReceipt.t()} | {:error, AdapterError.t()}
  def execute(proposal, capability, admission_current, options)

  def execute(%Proposal{} = proposal, %Capability{} = capability, admission_current, options)
      when is_map(admission_current) and is_list(options) do
    with {:ok, %Authorization{} = authorization} <-
           ReferenceMonitor.authorize(proposal, capability, admission_current),
         {:ok, request} <- build_request(authorization, options),
         {ledger_module, ledger} when is_atom(ledger_module) <- Keyword.get(options, :ledger),
         true <- ledger?(ledger_module),
         {:ok, %StartReceipt{} = start_receipt} <-
           ledger_module.start(ledger, authorization, request),
         current_provider when is_function(current_provider, 0) <-
           Keyword.get(options, :current_provider),
         current when is_map(current) <- current_provider.() do
      dispatch_after_revalidation(
        authorization,
        request,
        start_receipt,
        current,
        ledger_module,
        ledger,
        options
      )
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:invalid_input, :tool_gateway)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :tool_gateway)}
  catch
    :exit, _reason -> {:error, AdapterError.new(:unavailable, :tool_gateway)}
  end

  def execute(_proposal, _capability, _current, _options),
    do: {:error, AdapterError.new(:invalid_input, :tool_gateway)}

  defp dispatch_after_revalidation(
         authorization,
         request,
         start_receipt,
         current,
         ledger_module,
         ledger,
         options
       ) do
    case ReferenceMonitor.revalidate(authorization, current) do
      {:ok, _refreshed} ->
        dispatch_effect(request, start_receipt, ledger_module, ledger, options)

      {:error, %AdapterError{}} ->
        result = terminal_result!(:rejected, "tool=authorization_revoked")
        record_terminal(result, false, start_receipt, ledger_module, ledger)
    end
  end

  defp dispatch_effect(request, start_receipt, ledger_module, ledger, options) do
    with {adapter_module, adapter} when is_atom(adapter_module) <- Keyword.get(options, :adapter),
         true <- adapter?(adapter_module) do
      adapter_options = Keyword.get(options, :adapter_options, [])

      case adapter_module.execute(adapter, request, adapter_options) do
        {:ok, %Result{} = result} ->
          case Result.new(Map.from_struct(result), request.output_bytes) do
            {:ok, bounded} ->
              record_terminal(bounded, true, start_receipt, ledger_module, ledger)

            {:error, %AdapterError{}} ->
              result = terminal_result!(:failed, "tool=corrupt_adapter_result")
              record_terminal(result, true, start_receipt, ledger_module, ledger)
          end

        {:error, %AdapterError{} = error} ->
          result = terminal_result!(:failed, "tool=#{error.kind};operation=#{error.operation}")
          record_terminal(result, true, start_receipt, ledger_module, ledger)

        _invalid ->
          result = terminal_result!(:failed, "tool=invalid_adapter_result")
          record_terminal(result, true, start_receipt, ledger_module, ledger)
      end
    else
      _invalid ->
        result = terminal_result!(:failed, "tool=adapter_unavailable")
        record_terminal(result, false, start_receipt, ledger_module, ledger)
    end
  rescue
    _error ->
      result = terminal_result!(:failed, "tool=adapter_unavailable")
      record_terminal(result, true, start_receipt, ledger_module, ledger)
  catch
    :exit, _reason ->
      result = terminal_result!(:failed, "tool=adapter_unavailable")
      record_terminal(result, true, start_receipt, ledger_module, ledger)
  end

  defp record_terminal(result, dispatched?, start_receipt, ledger_module, ledger) do
    case ledger_module.outcome(ledger, start_receipt, result) do
      {:ok, outcome_receipt} ->
        {:ok,
         %ExecutionReceipt{
           status: result.status,
           effect_dispatched: dispatched?,
           result: result,
           start_receipt: start_receipt,
           outcome_receipt: outcome_receipt
         }}

      {:error, %AdapterError{} = error} ->
        {:error, error}

      _invalid ->
        {:error, AdapterError.new(:corrupt, :tool_outcome_commit)}
    end
  end

  defp build_request(authorization, options) do
    execution = Keyword.get(options, :execution_request)
    sequence = Keyword.get(options, :sequence)
    expected_effect = Keyword.get(options, :expected_effect)
    allowed_effects = Keyword.get(options, :allowed_effects, [])

    with %ExecutionRequest{} <- execution,
         true <- execution_matches?(execution, authorization.capability),
         sequence when is_integer(sequence) and sequence >= 0 <- sequence,
         effect when is_binary(effect) <- expected_effect,
         true <- effect in allowed_effects,
         %DateTime{} = now <- authorization.authorized_at do
      deadline =
        [
          authorization.capability.expires_at,
          DateTime.add(now, authorization.definition.timeout_ms, :millisecond)
        ]
        |> Enum.min_by(&DateTime.to_unix(&1, :microsecond))

      Request.new(%{
        execution: execution,
        invocation_iri: authorization.proposal.invocation_iri,
        tool_iri: authorization.definition.iri,
        tool_version: authorization.definition.version,
        sequence: sequence,
        deadline: deadline,
        expected_effect: effect,
        allowed_effects: allowed_effects,
        input_refs: authorization.proposal.input_refs,
        input_digests: %{
          "arguments.#{authorization.proposal.classification}" =>
            "sha256:" <> authorization.proposal.arguments_digest,
          "authorization" => "sha256:" <> authorization.decision_digest,
          "proposal" => "sha256:" <> authorization.proposal.proposal_digest
        },
        arguments: authorization.arguments,
        output_bytes: authorization.definition.max_output_bytes
      })
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :tool_request)}
    end
  end

  defp execution_matches?(execution, capability) do
    execution.attempt_iri == capability.attempt_iri and
      execution.lease_iri == capability.lease_iri and
      execution.repository_iri == capability.repository_iri and
      execution.snapshot_iri == capability.snapshot_iri and
      execution.actor_iri == capability.actor_iri and
      execution.agent_iri == capability.agent_iri and
      execution.fencing_token == capability.fencing_token
  end

  defp terminal_result!(status, diagnostic) do
    {:ok, result} =
      Result.new(
        %{
          status: status,
          exit_status: nil,
          stdout: "",
          stderr: diagnostic,
          external_output_iris: [],
          usage: %{},
          artifact_iris: [],
          redaction: :none
        },
        4_096
      )

    result
  end

  defp ledger?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :start, 3) and
      function_exported?(module, :outcome, 3)
  end

  defp adapter?(module),
    do: Code.ensure_loaded?(module) and function_exported?(module, :execute, 3)
end
