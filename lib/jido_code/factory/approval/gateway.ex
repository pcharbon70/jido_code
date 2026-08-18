defmodule JidoCode.Factory.Approval.Gateway do
  @moduledoc """
  Invocation-before-effect monitor for digest-bound human approval.

  The ledger must atomically record the invocation and consume the approval.
  Ambiguous delivery records reconciliation evidence but never a terminal
  outcome. Redelivery reuses that same semantic invocation only when its
  idempotency contract was proven in the signed request.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Approval.Outcome
  alias JidoCode.Factory.Approval.Request

  @contract_version "1.0.0"

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec execute(Request.t(), keyword()) :: {:ok, Outcome.t()} | {:error, AdapterError.t()}
  def execute(%Request{} = request, options) when is_list(options) do
    with {:ok, current, now} <- current(options),
         :ok <- revalidate(request, current, now),
         {ledger_module, ledger} <- Keyword.get(options, :ledger),
         true <- ledger?(ledger_module),
         {:ok, consumption} <- ledger_module.consume(ledger, request, current, options),
         :ok <- consumption_receipt(consumption, request) do
      dispatch(request, consumption, ledger_module, ledger, options)
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:approval_gateway)
    end
  rescue
    _error -> unavailable(:approval_gateway)
  catch
    :exit, _reason -> unavailable(:approval_gateway)
  end

  def execute(_request, _options), do: invalid(:approval_gateway)

  @spec redeliver(Request.t(), map(), keyword()) ::
          {:ok, Outcome.t()} | {:error, AdapterError.t()}
  def redeliver(%Request{idempotency: :proven} = request, consumption, options)
      when is_map(consumption) and is_list(options) do
    with :ok <- consumption_receipt(consumption, request),
         true <- consumption[:status] == :ambiguous,
         true <- consumption[:terminal_recorded?] == false,
         true <- consumption[:observation_count] in 1..3,
         {:ok, current, now} <- current(options),
         :ok <- revalidate(request, current, now),
         {ledger_module, ledger} <- Keyword.get(options, :ledger),
         true <- ledger?(ledger_module) do
      dispatch(request, consumption, ledger_module, ledger, options)
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> conflict(:approval_redelivery)
    end
  rescue
    _error -> unavailable(:approval_redelivery)
  catch
    :exit, _reason -> unavailable(:approval_redelivery)
  end

  def redeliver(%Request{}, _consumption, _options), do: unauthorized(:approval_redelivery)
  def redeliver(_request, _consumption, _options), do: invalid(:approval_redelivery)

  @spec revalidate(Request.t(), map(), DateTime.t()) :: :ok | {:error, AdapterError.t()}
  def revalidate(%Request{} = request, current, %DateTime{} = now) when is_map(current) do
    expected = %{
      approval_iri: Request.approval_iri(request),
      approval_state: :approved,
      approver_iri: request.approver_iri,
      approver_authorized?: true,
      approver_revocation_generation: request.approver_revocation_generation,
      approver_authorization_revision: request.approver_authorization_revision,
      delegated_scope_iri: request.delegated_scope_iri,
      policy_revision: request.policy_revision,
      base_revision: request.base_revision,
      patch_digest: request.patch_digest,
      tool_version: request.tool_version,
      model_version: request.model_version,
      sandbox_version: request.sandbox_version,
      context_version: request.context_version,
      capability_iri: request.capability_iri,
      attempt_iri: request.attempt_iri,
      invocation_iri: request.invocation_iri,
      lease_iri: request.lease_iri,
      lease_state: :active,
      fencing_token: request.fencing_token,
      destination_digest: request.destination_digest,
      artifact_digests: request.artifact_digests,
      evidence_iris: request.evidence_iris
    }

    cond do
      not Request.digest_valid?(request) ->
        unauthorized(:approval_digest_mismatch)

      DateTime.compare(now, request.expires_at) != :lt ->
        unauthorized(:approval_expired)

      not match?(%DateTime{}, current[:lease_expires_at]) or
          DateTime.compare(now, current.lease_expires_at) != :lt ->
        unauthorized(:approval_lease)

      request.separation_required? and request.approver_iri == request.execution_actor_iri ->
        unauthorized(:approval_actor_separation)

      Map.take(current, Map.keys(expected)) != expected ->
        unauthorized(:approval_revalidation)

      Map.get(current, :artifacts_available?) != true ->
        unauthorized(:approval_artifact_availability)

      true ->
        :ok
    end
  end

  def revalidate(_request, _current, _now), do: invalid(:approval_revalidation)

  defp dispatch(request, consumption, ledger_module, ledger, options) do
    with {effect_module, effect} <- Keyword.get(options, :effect),
         true <- effect?(effect_module) do
      case effect_module.execute(effect, request, Keyword.get(options, :effect_options, [])) do
        {:ok, effect_result} ->
          terminal(request, consumption, effect_result, ledger_module, ledger, options)

        {:error, %AdapterError{} = error} ->
          ambiguous(request, consumption, error, ledger_module, ledger, options)

        _invalid ->
          ambiguous(
            request,
            consumption,
            AdapterError.new(:corrupt, :approved_effect),
            ledger_module,
            ledger,
            options
          )
      end
    else
      _invalid -> invalid(:approved_effect)
    end
  end

  defp terminal(request, consumption, effect_result, ledger_module, ledger, options) do
    with {:ok, result} <- terminal_result(effect_result),
         {:ok, receipt} <- ledger_module.terminal(ledger, consumption, result, options),
         :ok <- terminal_receipt(receipt, request, result) do
      {:ok, outcome(request, result.status, true, true, consumption, receipt, nil, false)}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> unavailable(:approval_terminal_commit)
    end
  end

  defp ambiguous(request, consumption, error, ledger_module, ledger, options) do
    observation = %{
      status: :ambiguous,
      error_kind: error.kind,
      operation: error.operation,
      observed_at: Keyword.get(options, :observed_at)
    }

    with %DateTime{} <- observation.observed_at,
         {:ok, receipt} <- ledger_module.ambiguous(ledger, consumption, observation, options),
         :ok <- ambiguous_receipt(receipt, request) do
      {:ok,
       outcome(
         request,
         :ambiguous,
         false,
         true,
         Map.merge(consumption, receipt),
         nil,
         receipt,
         request.idempotency == :proven
       )}
    else
      {:error, %AdapterError{} = ledger_error} -> {:error, ledger_error}
      _invalid -> unavailable(:approval_ambiguity_commit)
    end
  end

  defp outcome(
         request,
         status,
         terminal?,
         dispatched?,
         consumption,
         terminal_receipt,
         reconciliation_receipt,
         redelivery?
       ) do
    %Outcome{
      approval_iri: Request.approval_iri(request),
      invocation_iri: request.invocation_iri,
      status: status,
      terminal?: terminal?,
      effect_dispatched?: dispatched?,
      consumption_receipt: consumption,
      terminal_receipt: terminal_receipt,
      reconciliation_receipt: reconciliation_receipt,
      redelivery_allowed?: redelivery?
    }
  end

  defp current(options) do
    with provider when is_function(provider, 0) <- Keyword.get(options, :current_provider),
         current when is_map(current) <- provider.(),
         clock when is_function(clock, 0) <- Keyword.get(options, :clock),
         %DateTime{} = now <- clock.() do
      {:ok, current, DateTime.truncate(now, :microsecond)}
    else
      _invalid -> unavailable(:approval_current_state)
    end
  end

  defp consumption_receipt(
         %{
           outcome: :committed,
           approval_iri: approval_iri,
           invocation_iri: invocation_iri,
           invocation_recorded?: true,
           approval_consumed?: true,
           atomic?: true,
           terminal_recorded?: false
         },
         request
       ) do
    if approval_iri == Request.approval_iri(request) and invocation_iri == request.invocation_iri,
      do: :ok,
      else: conflict(:approval_consumption_receipt)
  end

  defp consumption_receipt(_receipt, _request), do: conflict(:approval_consumption_receipt)

  defp terminal_receipt(
         %{outcome: :committed, terminal_recorded?: true, invocation_iri: invocation_iri},
         request,
         result
       ) do
    if invocation_iri == request.invocation_iri and result.status in [:succeeded, :failed],
      do: :ok,
      else: conflict(:approval_terminal_receipt)
  end

  defp terminal_receipt(_receipt, _request, _result), do: conflict(:approval_terminal_receipt)

  defp ambiguous_receipt(
         %{
           outcome: :committed,
           status: :ambiguous,
           terminal_recorded?: false,
           observation_count: count,
           invocation_iri: invocation_iri
         },
         request
       )
       when count in 1..3 do
    if invocation_iri == request.invocation_iri,
      do: :ok,
      else: conflict(:approval_ambiguous_receipt)
  end

  defp ambiguous_receipt(_receipt, _request), do: conflict(:approval_ambiguous_receipt)

  defp terminal_result(%{status: status, external_effect_id: external_id} = result)
       when status in [:succeeded, :failed] and is_binary(external_id) and
              byte_size(external_id) in 1..256 do
    {:ok, Map.take(result, [:status, :external_effect_id, :result_digest])}
  end

  defp terminal_result(_result), do: invalid(:approved_effect_result)

  defp ledger?(module) do
    is_atom(module) and Code.ensure_loaded?(module) and
      function_exported?(module, :consume, 4) and function_exported?(module, :terminal, 4) and
      function_exported?(module, :ambiguous, 4)
  end

  defp effect?(module),
    do:
      is_atom(module) and Code.ensure_loaded?(module) and function_exported?(module, :execute, 3)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
