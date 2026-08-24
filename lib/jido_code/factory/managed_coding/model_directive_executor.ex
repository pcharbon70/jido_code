defmodule JidoCode.Factory.ManagedCoding.ModelDirectiveExecutor do
  @moduledoc "Executes exactly one ledgered model turn through the selected ModelGateway."

  @behaviour JidoCode.Factory.Ports.ManagedCodingDirective

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.ModelDecision
  alias JidoCode.Factory.Model.Outcome
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.ModelGateway

  @impl true
  def execute(state, %{kind: :model} = envelope, _options) when is_map(state) do
    with %ModelGateway{} = gateway <- state[:gateway],
         {ledger_module, ledger} when is_atom(ledger_module) <- state[:ledger],
         request_provider when is_function(request_provider, 1) <- state[:request_provider],
         {:ok, request_attributes} <- request_provider.(envelope),
         {:ok, request} <- Request.new(request_attributes),
         true <- request.invocation_iri == envelope.invocation_iri,
         {:ok, receipt} <- ledger_module.start(ledger, correlation(envelope), request) do
      dispatch(gateway, ledger_module, ledger, receipt, request, envelope)
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_model_directive)}
  end

  def execute(_state, _envelope, _options), do: invalid()

  defp dispatch(gateway, ledger_module, ledger, receipt, request, envelope) do
    gateway_result = ModelGateway.generate(gateway, request)

    result =
      with {:ok, response} <- gateway_result,
           {:ok, decision} <- ModelDecision.parse(response),
           {:ok, next} <- next_invocation(decision.kind, envelope, decision.payload) do
        {:ok,
         %{
           outcome: :completed,
           kind: decision.kind,
           decision: decision.payload,
           next_invocation_iri: next
         }}
      end

    ledger_attributes =
      Outcome.attributes(gateway_result, request)
      |> Map.put(:decision_status, decision_status(result))

    case ledger_module.outcome(ledger, receipt, ledger_attributes) do
      :ok -> result
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:corrupt, :managed_coding_model_ledger_outcome)}
    end
  end

  defp next_invocation(:tool_proposal, envelope, payload),
    do: deterministic(:tool_invocation, envelope, payload)

  defp next_invocation(:clarification, envelope, payload),
    do: deterministic(:interaction_session, envelope, payload)

  defp next_invocation(:completion_proposal, envelope, payload),
    do: deterministic(:patch_artifact, envelope, payload)

  defp next_invocation(:abstention, _envelope, _payload), do: {:ok, nil}

  defp deterministic(kind, envelope, payload) do
    material =
      :erlang.term_to_binary(
        {envelope.attempt_iri, envelope.fencing_token, envelope.sequence, payload},
        [:deterministic]
      )
      |> Base.encode16(case: :lower)

    Identity.deterministic(kind, material)
  end

  defp correlation(envelope) do
    %{
      attempt_iri: envelope.attempt_iri,
      fencing_token: envelope.fencing_token,
      sequence: envelope.sequence,
      invocation_iri: envelope.invocation_iri,
      payload_digest: envelope.payload_digest
    }
  end

  defp decision_status({:ok, %{kind: kind}}), do: kind
  defp decision_status({:error, %AdapterError{kind: kind}}), do: kind
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_model_directive)}
end
